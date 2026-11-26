#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include "_glmm_links.h"
#include "_glmm_engine.h"
#include <limits>
#include <string>
#include <optional>
#include <stdexcept>
#include <memory>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace glmm;

namespace {

// v1.1.0-TODO-265 follow-up (owner 2026-11-24): coarse-to-fine quadrature. With more than this
// many Gauss-Hermite nodes (the KK CLMM classes pass 60, v1.0.6-TODO-13), the variance multistart
// runs on a 20-node objective and only its winner is refit on the requested rule, warm-started.
// The likelihood and gradient cost are linear in the node count, so the multistart costs a
// third; the reported fit (estimate, gradient test, SE) is the requested rule's optimum.
constexpr int kClmmCoarseNGH = 20;
// The R acceptance threshold (InferenceAbstractKKOrdinalCLMM's clmm_gradient_accept). A fit whose
// projected gradient is already below it is not polished and counts as converged, so a fit never
// pays for both the kernel polish and the R Newton retry.
constexpr double kClmmAcceptGradient = 1e-4;

// Ordinal model with thresholds
template <typename Link>
class OrdinalLikelihood {
    int K;
public:
    OrdinalLikelihood(int K_) : K(K_) {}

    int n_model_params() const { return K - 1; }

    // Precompute all K-1 cumulative thresholds from par once per optimizer step.
    // alpha[0] = par[0]; alpha[k] = alpha[k-1] + exp(par[k]) for k >= 1.
    void fill_alpha(const Eigen::VectorXd& par, double* alpha) const {
        if (K <= 1) return;
        alpha[0] = par[0];
        for (int k = 1; k < K - 1; ++k)
            alpha[k] = alpha[k - 1] + std::exp(par[k]);
    }

    // O(1) lookup into precomputed alpha buffer — no exp calls.
    inline void get_alpha_bounds(const double* alpha, int y_ir, double& alpha_lo, double& alpha_up) const {
        alpha_lo = (y_ir <= 1) ? 0.0 : alpha[y_ir - 2];
        alpha_up = (y_ir >= K) ? 0.0 : alpha[y_ir - 1];
    }

    double log_prob(double y_val, double eta, const double* alpha) const {
        int y_ir = static_cast<int>(y_val);
        double alpha_lo, alpha_up;
        get_alpha_bounds(alpha, y_ir, alpha_lo, alpha_up);
        double F_up = (y_ir >= K) ? 1.0 : Link::cdf(alpha_up - eta);
        double F_lo = (y_ir <= 1) ? 0.0 : Link::cdf(alpha_lo - eta);
        return std::log(std::max(1e-15, F_up - F_lo));
    }

    double log_prob_derivs(double y_val, double eta, const double* alpha, double& de, Eigen::VectorXd& dp) const {
        int y_ir = static_cast<int>(y_val);
        int na = K - 1;

        double alpha_lo, alpha_up;
        get_alpha_bounds(alpha, y_ir, alpha_lo, alpha_up);

        double F_up = (y_ir >= K) ? 1.0 : Link::cdf(alpha_up - eta);
        double F_lo = (y_ir <= 1) ? 0.0 : Link::cdf(alpha_lo - eta);
        double prob = std::max(1e-15, F_up - F_lo);
        double lp = std::log(prob);

        // pdf_from_cdf avoids re-calling cdf() inside pdf() — F_up/F_lo already computed.
        const double g_up = (y_ir >= K) ? 0.0 : Link::pdf_from_cdf(alpha_up - eta, F_up) / prob;
        const double g_lo = (y_ir <= 1) ? 0.0 : Link::pdf_from_cdf(alpha_lo - eta, F_lo) / prob;

        dp.setZero(na);
        de = -(g_up - g_lo);
        if (na > 0) dp[0] = g_up - g_lo;

        if (y_ir <= 1) return lp;

        // alpha diffs replace exp(par[j]) — no exp calls here.
        const int lower_idx = y_ir - 2;
        const double base_suffix = (y_ir >= K) ? -g_lo : (g_up - g_lo);
        for (int j = 1; j <= lower_idx; ++j)
            dp[j] = base_suffix * (alpha[j] - alpha[j - 1]);
        if (y_ir < K) {
            const int upper_idx = y_ir - 1;
            dp[upper_idx] = g_up * (alpha[upper_idx] - alpha[upper_idx - 1]);
        }
        return lp;
    }
};

template <typename Link>
edi::ResultMap run_fast_ordinal_clmm(const GLMMData& dat, int K, int j_T, bool estimate_only, int maxit, double eps_g,
                           const Eigen::Ref<const Eigen::VectorXd>& start_full, const std::string& optimization_alg,
                           const FixedParamSpec& fixed_spec,
                           const Eigen::MatrixXd* info_start_ptr = nullptr,
                           bool variance_multistart = true,
                           const GLMMData* coarse_dat = nullptr) {
    OrdinalLikelihood<Link> model(K);
    GLMMObjective<OrdinalLikelihood<Link>> obj(dat, model);

    Eigen::VectorXd par = start_full;
    double neg_ll = std::numeric_limits<double>::quiet_NaN();
    bool converged = false;
    int niter = maxit;
    bool hit_iteration_cap = false;
    double gradient_norm = std::numeric_limits<double>::quiet_NaN();
    double lbfgs_gradient_norm = std::numeric_limits<double>::quiet_NaN();
    double tau_score = std::numeric_limits<double>::quiet_NaN();
    bool newton_polish_attempted = false;
    bool newton_polish_accepted = false;
    int newton_polish_iterations = 0;
    bool log_sigma_is_fixed = false;
    Eigen::VectorXd nll_gradient = Eigen::VectorXd::Constant(par.size(), std::numeric_limits<double>::quiet_NaN());

    try {
        const int total = par.size();
        for (int ii = 0; ii < fixed_spec.fixed_idx.size(); ++ii)
            if (fixed_spec.fixed_idx[ii] == total - 1) log_sigma_is_fixed = true;
        std::vector<Eigen::VectorXd> starts{apply_fixed_values(par, fixed_spec)};
        // v1.1.0-TODO-265: variance_multistart = false runs only the supplied start. The R
        // Newton retry (clmm_accept_fit) uses it to polish an L-BFGS multistart winner from
        // that point; rerunning Newton from four far log-sigma values was ~95% of the retry.
        if (!log_sigma_is_fixed && variance_multistart) {
            for (double z : std::vector<double>{-1.0, 0.0, 1.0, -dat.max_abs_log_sigma}) {
                bool duplicate = false;
                for (const auto& existing : starts)
                    if (std::abs(existing[total - 1] - z) < 1e-12) duplicate = true;
                if (!duplicate) {
                    Eigen::VectorXd candidate = par;
                    candidate[total - 1] = z;
                    starts.push_back(apply_fixed_values(candidate, fixed_spec));
                }
            }
        }

        // Coarse-to-fine (kClmmCoarseNGH): run the starts on the coarse objective, then refit on the
        // requested rule from the coarse endpoint that is best under the requested rule (one
        // evaluation each, so a mode the coarse rule misranks is not chosen). When that endpoint
        // sits at the sigma -> 0 boundary far from stationary (the loose-eps_g guard below), every
        // coarse endpoint is refit instead, so the guard sees all of them.
        int coarse_niter = 0;
        const bool lbfgs_requested = normalize_optimizer_algorithm(optimization_alg, "lbfgs", false) == "lbfgs";
        if (coarse_dat != nullptr && lbfgs_requested) {
            GLMMObjective<OrdinalLikelihood<Link>> coarse_obj(*coarse_dat, model);
            std::vector<LikelihoodFitResult> coarse_fits;
            for (const auto& start_candidate : starts) {
                LikelihoodFitResult fit = optimize_fixed_likelihood(
                    coarse_obj, start_candidate, fixed_spec, maxit, eps_g,
                    optimization_alg, "lbfgs", 0, info_start_ptr);
                if (std::isfinite(fit.value) && fit.params.allFinite()) coarse_fits.push_back(fit);
            }
            int best_i = -1;
            double best_fine = std::numeric_limits<double>::infinity();
            Eigen::VectorXd g_tmp(total);
            for (int ii = 0; ii < (int)coarse_fits.size(); ++ii) {
                const double v = obj(coarse_fits[ii].params, g_tmp);
                if (std::isfinite(v) && v < best_fine) { best_fine = v; best_i = ii; }
            }
            if (best_i >= 0) {
                const LikelihoodFitResult& cb = coarse_fits[best_i];
                const bool boundary_guard = !log_sigma_is_fixed && cb.params[total - 1] <= -4.5 &&
                    std::isfinite(cb.gradient_norm) && cb.gradient_norm > 1e-3 && coarse_fits.size() > 1;
                starts.clear();
                if (boundary_guard) {
                    for (const auto& f : coarse_fits) starts.push_back(f.params);
                } else {
                    starts.push_back(cb.params);
                }
                coarse_niter = cb.niter;
                info_start_ptr = nullptr;  // the warm-start information belongs to the original start
            }
        }

        std::vector<LikelihoodFitResult> finite_fits;
        LikelihoodFitResult best_fit = glmm::best_multistart_fit(
            obj, starts, fixed_spec, maxit, eps_g, optimization_alg, info_start_ptr,
            "ordinal CLMM produced no finite multistart fit", &finite_fits);
        lbfgs_gradient_norm = best_fit.gradient_norm;

        // v1.1.0-TODO-265 / clmm_sigma_collapse_false_convergence.md TODO-5 (owner 2026-11-23,
        // DECISION-v1.1.0-TODO-265 (d)), ported from fast_ordinal_glmm.cpp: the multistart
        // winner's `converged` is LBFGSpp's lenient flag (a relative-f stop counts), so
        // (1) polish the winner with a tight L-BFGS restart, (2) judge convergence by the
        // projected gradient (KKT at the lower variance bound), and (3) when that still fails,
        // take damped Newton steps on the active set.
        const bool used_lbfgs = normalize_optimizer_algorithm(optimization_alg, "lbfgs", false) == "lbfgs";
        const double polish_tol = std::min(eps_g, 1e-10);
        auto polish = [&](const LikelihoodFitResult& from) {
            LikelihoodFitResult polished = optimize_fixed_likelihood(
                obj, from.params, fixed_spec, maxit, polish_tol,
                optimization_alg, "lbfgs", 0, nullptr);
            if (std::isfinite(polished.value) && polished.params.allFinite() &&
                polished.value <= from.value + 1e-10) {
                polished.niter += from.niter;
                return polished;
            }
            return from;
        };

        // Tau-score: d nll / d tau (tau = sigma^2) from the likelihood-only log-sigma
        // derivative (the soft penalty removed). The lower bound is active, so log sigma
        // leaves the convergence norm and the Newton system, iff log sigma sits at the soft
        // bound and s > 0 (moving inward would increase the objective: KKT). With s <= 0 the
        // coordinate stays free and the polish pushes it inward. The upper bound is never active.
        // convergence_gradient_tol is where a polish aims; accept_gradient_tol decides whether a
        // polish is needed and whether the fit converged (kClmmAcceptGradient, 2026-11-24).
        const double convergence_gradient_tol = std::max(1e-5, eps_g);
        const double accept_gradient_tol = std::max(kClmmAcceptGradient, eps_g);
        auto tau_score_at = [&](const Eigen::VectorXd& params, const Eigen::VectorXd& gradient) {
            const double ls = params[total - 1];
            const double g_lik = gradient[total - 1] - sigma_penalty_grad(ls);
            return g_lik / (2.0 * std::exp(2.0 * ls));
        };
        auto active_indices_and_gradient = [&](const Eigen::VectorXd& params, const Eigen::VectorXd& gradient) {
            const bool lower_variance_kkt = !log_sigma_is_fixed &&
                params[total - 1] <= -kSigmaPenaltyCenter + 1e-4 && tau_score_at(params, gradient) > 0;
            std::vector<int> active_vec;
            for (int ii = 0; ii < fixed_spec.free_idx.size(); ++ii) {
                const int idx = fixed_spec.free_idx[ii];
                if (!(lower_variance_kkt && idx == total - 1)) active_vec.push_back(idx);
            }
            Eigen::VectorXi active_idx(active_vec.size());
            for (int ii = 0; ii < (int)active_vec.size(); ++ii) active_idx[ii] = active_vec[ii];
            return std::make_pair(active_idx, subset_vector(gradient, active_idx));
        };

        if (used_lbfgs) {
            // A winner at the sigma -> 0 boundary that is far from stationary was picked among
            // poorly converged starts (a loose eps_g): the flat boundary can hold a local optimum
            // while another start's basin holds the interior MLE. Then polish every start and
            // re-select. Otherwise polish the winner only when it fails the projected test (a
            // winner that passes is returned as is).
            if (!log_sigma_is_fixed && best_fit.params[total - 1] <= -4.5 &&
                std::isfinite(best_fit.gradient_norm) && best_fit.gradient_norm > 1e-3 &&
                finite_fits.size() > 1) {
                LikelihoodFitResult best_polished = polish(best_fit);
                for (const auto& f : finite_fits) {
                    LikelihoodFitResult pf = polish(f);
                    if (pf.value < best_polished.value) best_polished = pf;
                }
                best_fit = best_polished;
            } else {
                Eigen::VectorXd g0(total);
                const double f0 = obj(best_fit.params, g0);
                if (!(std::isfinite(f0) && g0.allFinite() &&
                      active_indices_and_gradient(best_fit.params, g0).second.norm() <= accept_gradient_tol))
                    best_fit = polish(best_fit);
            }
        }
        par = best_fit.params;
        neg_ll = obj(par, nll_gradient);
        hit_iteration_cap = std::isfinite(neg_ll) && best_fit.hit_iteration_cap;
        niter = best_fit.niter + coarse_niter;

        auto active_state = active_indices_and_gradient(par, nll_gradient);
        if (used_lbfgs && std::isfinite(neg_ll) && par.allFinite() && nll_gradient.allFinite() &&
            active_state.second.norm() > accept_gradient_tol) {
            newton_polish_attempted = true;
            Eigen::VectorXd candidate_params = par;
            Eigen::VectorXd candidate_gradient = nll_gradient;
            double candidate_value = neg_ll;
            const int polish_maxit = std::min(maxit, 50);
            int stalled_steps = 0;
            for (int iter = 0; iter < polish_maxit; ++iter) {
                edi_check_R_user_interrupt_every(iter);
                active_state = active_indices_and_gradient(candidate_params, candidate_gradient);
                const Eigen::VectorXi& active_idx = active_state.first;
                const Eigen::VectorXd& active_gradient = active_state.second;
                if (active_gradient.norm() <= convergence_gradient_tol || active_idx.size() == 0) break;

                Eigen::MatrixXd information_full = obj.hessian(candidate_params);
                if (!information_full.allFinite()) break;
                Eigen::MatrixXd information_active = subset_matrix(information_full, active_idx, active_idx);
                Eigen::LDLT<Eigen::MatrixXd> ldlt(information_active);
                if (ldlt.info() != Eigen::Success || !ldlt.isPositive()) break;
                Eigen::VectorXd step = ldlt.solve(active_gradient);
                const double predicted_decrease = active_gradient.dot(step);
                if (!step.allFinite() || !std::isfinite(predicted_decrease) || predicted_decrease <= 0) break;

                bool step_accepted = false;
                double step_scale = 1.0;
                const double prev_gnorm = active_gradient.norm();
                for (int line_iter = 0; line_iter < 30; ++line_iter) {
                    edi_check_R_user_interrupt_every(line_iter);
                    Eigen::VectorXd trial = candidate_params;
                    for (int jj = 0; jj < active_idx.size(); ++jj)
                        trial[active_idx[jj]] -= step_scale * step[jj];
                    trial = apply_fixed_values(trial, fixed_spec);
                    Eigen::VectorXd trial_gradient(total);
                    const double trial_value = obj(trial, trial_gradient);
                    if (std::isfinite(trial_value) && trial.allFinite() && trial_gradient.allFinite() &&
                        trial_value <= candidate_value - 1e-4 * step_scale * predicted_decrease) {
                        candidate_params = trial;
                        candidate_gradient = trial_gradient;
                        candidate_value = trial_value;
                        step_accepted = true;
                        ++newton_polish_iterations;
                        break;
                    }
                    step_scale *= 0.5;
                }
                if (!step_accepted) break;
                // Stop when the steps no longer shrink the gradient (two in a row by < 10%): the
                // numerical Hessian's accuracy floor, where more steps only cost Hessians. The fit
                // is then reported not converged and the R-side retry judges it.
                const double new_gnorm = active_indices_and_gradient(candidate_params, candidate_gradient).second.norm();
                stalled_steps = (new_gnorm > 0.9 * prev_gnorm) ? stalled_steps + 1 : 0;
                if (stalled_steps >= 2) break;
            }
            if (candidate_params.allFinite() && candidate_gradient.allFinite() &&
                std::isfinite(candidate_value) && candidate_value <= neg_ll + 1e-10 &&
                newton_polish_iterations > 0) {
                par = candidate_params;
                nll_gradient = candidate_gradient;
                neg_ll = candidate_value;
                niter += newton_polish_iterations;
                newton_polish_accepted = true;
            }
        }

        active_state = active_indices_and_gradient(par, nll_gradient);
        gradient_norm = active_state.second.norm();
        tau_score = tau_score_at(par, nll_gradient);
        // Never best_fit.converged (the lenient flag): converged iff the projected gradient is small.
        converged = std::isfinite(neg_ll) && par.allFinite() && nll_gradient.allFinite() &&
                    gradient_norm <= accept_gradient_tol;
        if (converged) hit_iteration_cap = false;
    } catch (...) {
        converged = false;
        hit_iteration_cap = false;
    }

    int total = par.size();
    int na = K - 1;
    int j_T_full = na + j_T;
    double ssq_b_T = std::numeric_limits<double>::quiet_NaN();

    if (!estimate_only && converged) {
        FixedParameterFunctor<GLMMObjective<OrdinalLikelihood<Link>>> fixed_obj(obj, fixed_spec, par);
        Eigen::VectorXd params_free = subset_vector(par, fixed_spec.free_idx);
        Eigen::MatrixXd H_free = fixed_obj.hessian(params_free);
        Eigen::LDLT<Eigen::MatrixXd> ldlt(H_free);
        if (ldlt.info() == Eigen::Success) {
            Eigen::MatrixXd inv_free = ldlt.solve(Eigen::MatrixXd::Identity(H_free.rows(), H_free.cols()));
            if (inv_free.allFinite()) {
                Eigen::MatrixXd inv = expand_free_covariance(total, fixed_spec, inv_free, true);
                if (j_T_full < total) ssq_b_T = inv(j_T_full, j_T_full);
            }
        }
    }

    Eigen::VectorXd b_vec = par.segment(na, dat.p);
    Eigen::VectorXd alpha_vec = par.head(na);
    return edi::ResultMap()
        .set("b", b_vec)
        .set("alpha", alpha_vec)
        .set("params", par)
        .set("log_sigma", par[total - 1])
        .set("ssq_b_T", ssq_b_T)
        .set("converged", converged)
        .set("num_iter", niter)
        .set("hit_iteration_cap", hit_iteration_cap)
        .set("gradient_norm", gradient_norm)
        .set("lbfgs_gradient_norm", lbfgs_gradient_norm)
        .set("neg_loglik", neg_ll)
        .set("variance_boundary_hit", glmm_variance_boundary_hit(par[total - 1]))
        .set("variance_boundary_tau_score", tau_score)
        .set("newton_polish_attempted", newton_polish_attempted)
        .set("newton_polish_accepted", newton_polish_accepted)
        .set("newton_polish_iterations", newton_polish_iterations);
}

} // namespace

edi::ResultMap fast_ordinal_clmm_internal_vm(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int K,
    int j_T,
    std::string link = "logit",
    bool estimate_only = false,
    int n_gh = 20,
    double max_abs_log_sigma = 8.0,
    int maxit = 300,
    double eps_g = 1e-6,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool variance_multistart = true
) {
    int n = (int)X.rows();
    int p = (int)X.cols();
    int na = K - 1;
    int total = na + p + 1;

    require_length(warm_start_params, total, "warm_start_params");
    require_square_matrix(warm_start_fisher_info, total, "warm_start_fisher_info");

    Eigen::VectorXd y_v(n);
    std::vector<int> gid_v(n);
    for (int i = 0; i < n; ++i) {
        y_v[i] = static_cast<double>(y[i]);
        gid_v[i] = group_id[i];
    }

    GLMMData dat(X, y_v, gid_v, n_gh, max_abs_log_sigma);
    std::unique_ptr<GLMMData> coarse_dat;
    if (n_gh > kClmmCoarseNGH)
        coarse_dat = std::make_unique<GLMMData>(X, y_v, gid_v, kClmmCoarseNGH, max_abs_log_sigma);
    FixedParamSpec fixed_spec = make_fixed_param_spec(total, fixed_idx, fixed_values);

    Eigen::VectorXd start_full(total);
    if (warm_start_params.has_value()) {
        start_full = *warm_start_params;
    } else {
        start_full.setZero();
        start_full[total - 1] = -3.0;
    }
    start_full = apply_fixed_values(start_full, fixed_spec);

    Eigen::MatrixXd info_start;
    const Eigen::MatrixXd* info_start_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info_start = *warm_start_fisher_info;
        info_start_ptr = &info_start;
    }

    if (link == "logit")   return run_fast_ordinal_clmm<LogitLink>(dat, K, j_T, estimate_only, maxit, eps_g, start_full, optimization_alg, fixed_spec, info_start_ptr, variance_multistart, coarse_dat.get());
    if (link == "probit")  return run_fast_ordinal_clmm<ProbitLink>(dat, K, j_T, estimate_only, maxit, eps_g, start_full, optimization_alg, fixed_spec, info_start_ptr, variance_multistart, coarse_dat.get());
    if (link == "cauchit") return run_fast_ordinal_clmm<CauchitLink>(dat, K, j_T, estimate_only, maxit, eps_g, start_full, optimization_alg, fixed_spec, info_start_ptr, variance_multistart, coarse_dat.get());
    if (link == "cloglog") return run_fast_ordinal_clmm<CloglogLink>(dat, K, j_T, estimate_only, maxit, eps_g, start_full, optimization_alg, fixed_spec, info_start_ptr, variance_multistart, coarse_dat.get());

    throw std::invalid_argument("Unknown link: " + link);
}

// The 16-argument entry point declared by python/cpp/bindings_ordinal.cpp (always the full
// variance multistart).
edi::ResultMap fast_ordinal_clmm_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXi>& y,
    const Eigen::Ref<const Eigen::VectorXi>& group_id,
    int K,
    int j_T,
    std::string link,
    bool estimate_only,
    int n_gh,
    double max_abs_log_sigma,
    int maxit,
    double eps_g,
    std::optional<Eigen::VectorXd> warm_start_params,
    std::string optimization_alg,
    std::optional<Eigen::VectorXi> fixed_idx,
    std::optional<Eigen::VectorXd> fixed_values,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info
) {
    return fast_ordinal_clmm_internal_vm(X, y, group_id, K, j_T, link, estimate_only, n_gh, max_abs_log_sigma,
        maxit, eps_g, warm_start_params, optimization_alg, fixed_idx, fixed_values, warm_start_fisher_info, true);
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
List fast_ordinal_clmm_cpp(
    const Rcpp::NumericMatrix& X,
    const Rcpp::IntegerVector& y,
    const Rcpp::IntegerVector& group_id,
    int K,
    int j_T,
    std::string link = "logit",
    bool estimate_only = false,
    int n_gh = 20,
    double max_abs_log_sigma = 8.0,
    int maxit = 300,
    double eps_g = 1e-6,
    Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
    std::string optimization_alg = "lbfgs",
    Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
    Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
    bool variance_multistart = true
) {
    if (X.nrow() != y.size() || X.nrow() != group_id.size()) {
        Rcpp::stop("Dimension mismatch: X has %d rows, y has %d elements, group_id has %d elements",
                   X.nrow(), (int)y.size(), (int)group_id.size());
    }
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXi> map_group_id(group_id.begin(), group_id.size());

    edi::ResultMap res = fast_ordinal_clmm_internal_vm(
        map_X, map_y, map_group_id, K, j_T, link, estimate_only, n_gh, max_abs_log_sigma,
        maxit, eps_g,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        optimization_alg,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        variance_multistart);

    return edi::to_rcpp_list(res);
}
#endif // EDI_CORE_ONLY
