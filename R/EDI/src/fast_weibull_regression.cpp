#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include "survival_rand_bootstrap_rcpp.h"
#include <RcppEigen.h>
#include <Rmath.h>
#endif
#ifdef _OPENMP
#include <omp.h>
#endif

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

// Terms needed at one interval bound w (= (log(bound) - eta) / sigma) for the
// censored-branch log-likelihood/gradient/Hessian below. S = survivor value
// exp(-exp(w)); the "u"-weighted terms are exactly the quantities that appear
// (always multiplied together, never alone) in the derivatives of
// log(S(y_L) - S(y_R)) -- see interval_censored_survival_response.md TODO-3
// for the derivation. Bundling them here means the two degenerate limits
// (y_L = 0, i.e. w -> -Inf; y_R = Inf, i.e. w -> +Inf) can be special-cased
// as "all these vanish" without ever forming an Inf * 0 / -Inf * 0 product:
// S itself is safe to compute literally at either infinity (exp(-Inf) = 0,
// exp(-0) = 1), but e.g. w * exp(w) * S is only safe away from the limits.
struct BoundTerms {
    double S;
    double uS, wuS, w2uS, u2S, wu2S, w2u2S;
};

inline BoundTerms bound_terms_finite(double w) {
    const double u = std::exp(w);
    const double S = std::exp(-u);
    BoundTerms t;
    t.S = S;
    t.uS = u * S;
    t.wuS = w * t.uS;
    t.w2uS = w * t.wuS;
    t.u2S = u * t.uS;
    t.wu2S = w * t.u2S;
    t.w2u2S = w * t.wu2S;
    return t;
}

inline BoundTerms bound_terms_degenerate(double S_limit) {
    BoundTerms t;
    t.S = S_limit;
    t.uS = 0.0; t.wuS = 0.0; t.w2uS = 0.0;
    t.u2S = 0.0; t.wu2S = 0.0; t.w2u2S = 0.0;
    return t;
}

// The shared WeibullAFTLikelihood in _helper_functions_core.h is the fast
// exact/right-censoring path.  Keep this general path only for left/interval
// censoring (see TODO-3 in
// interval_censored_survival_response.md). Optimized per TODO-28: exact
// rows use the same vectorized Eigen-array strategy as WeibullAFTLikelihood
// above (arithmetic-blended via m_is_exact_d, not .select(), which measured
// faster); only censored rows pay the CensoredRow/BoundTerms cost, in a
// scalar loop over just those rows. All scratch is preallocated as member
// variables (see constructor), reused in place every call rather than
// heap-allocated fresh each time LBFGS's line search invokes operator().
class WeibullAFTLikelihoodGeneral {
private:
    const Eigen::Ref<const Eigen::VectorXd> m_y;
    const Eigen::Ref<const Eigen::VectorXd> m_y_L;
    const Eigen::Ref<const Eigen::VectorXd> m_y_R;
    const Eigen::Ref<const Eigen::MatrixXd> m_X;
    const int m_n;
    const int m_p;
    Eigen::VectorXd m_eta;
    // Preallocated scratch, reused (overwritten) every call -- avoids a
    // fresh heap allocation per operator()/hessian() call, which LBFGS line
    // search invokes many times per outer iteration. See TODO-28.
    Eigen::Array<bool, Eigen::Dynamic, 1> m_is_exact;
    Eigen::ArrayXd m_is_exact_d;  // 0/1 double weights, arithmetic-blend style (see WeibullAFTLikelihood above)
    Eigen::ArrayXd m_y_safe, m_log_y_safe, m_w, m_exp_w;
    Eigen::VectorXd m_d_eta, m_beta_weights, m_cross_weights;

    // Per-row censored-branch derivative pieces, valid uniformly for
    // right-censored (y_R = Inf), left-censored (y_L = 0), and
    // interval-censored (both finite) rows -- exact rows (m_y[i] finite)
    // never reach this. See interval_censored_survival_response.md TODO-3.
    struct CensoredRow {
        double D, D_eta, D_logsigma, D_aa, D_bb;
        BoundTerms L, U;
    };

    CensoredRow censored_row_terms(int i, double eta_i, double sigma) const {
        const bool left = m_y_L[i] <= 0.0;
        const bool right = !std::isfinite(m_y_R[i]);
        const double a = left ? 0.0 : std::min((std::log(m_y_L[i]) - eta_i) / sigma, 700.0);
        const double b = right ? 0.0 : std::min((std::log(m_y_R[i]) - eta_i) / sigma, 700.0);
        CensoredRow r;
        r.L = left ? bound_terms_degenerate(1.0) : bound_terms_finite(a);
        r.U = right ? bound_terms_degenerate(0.0) : bound_terms_finite(b);
        r.D = r.L.S - r.U.S;
        r.D_eta = (r.L.uS - r.U.uS) / sigma;
        r.D_logsigma = r.L.wuS - r.U.wuS;
        r.D_aa = r.L.u2S - r.L.uS;
        r.D_bb = r.U.uS - r.U.u2S;
        return r;
    }

public:
    WeibullAFTLikelihoodGeneral(const Eigen::Ref<const Eigen::VectorXd>& y,
                         const Eigen::Ref<const Eigen::VectorXd>& y_L,
                         const Eigen::Ref<const Eigen::VectorXd>& y_R,
                         const Eigen::Ref<const Eigen::MatrixXd>& X) :
        m_y(y), m_y_L(y_L), m_y_R(y_R), m_X(X), m_n(y.size()), m_p(X.cols()),
        m_eta(m_n), m_is_exact(y.array().isFinite()),
        m_is_exact_d(m_is_exact.template cast<double>()),
        // y (hence is_exact/y_safe/its log) never changes across calls --
        // precompute once here rather than every operator()/hessian() call.
        m_y_safe(m_is_exact.select(y.array(), 1.0)),
        m_log_y_safe(m_y_safe.log()),
        m_w(m_n), m_exp_w(m_n), m_d_eta(m_n), m_beta_weights(m_n),
        m_cross_weights(m_n) {}

    double operator()(const Eigen::VectorXd& params, Eigen::VectorXd& grad) {
        // params: [beta (p), log_sigma (1)]
        const auto beta = params.head(m_p);
        double log_sigma = params[m_p];
        double sigma = std::exp(log_sigma);

        m_eta.noalias() = m_X * beta;

        // Vectorized exact-row path (the common case): Eigen's array .log()/
        // .exp() are SIMD-batched, unlike a scalar std::log/std::exp per row
        // -- a scalar per-row loop over ALL rows (exact included) cost a
        // real, measured ~3x slowdown vs. WeibullAFTLikelihood's fully-
        // vectorized implementation (interval_censored_survival_response.md
        // TODO-28). Arithmetic-blended via m_is_exact_d (0/1 weights, same
        // style as WeibullAFTLikelihood's `dead`-weighted formula) rather
        // than .select(), which measured slower. Bit-identical to the
        // scalar formula on exact rows -- only the vectorization strategy
        // changed.
        m_w = ((m_log_y_safe - m_eta.array()) / sigma).min(700.0);
        m_exp_w = m_w.exp();

        double loglik = (m_is_exact_d * (m_w - log_sigma - m_log_y_safe - m_exp_w)).sum();
        m_d_eta = (m_is_exact_d * (m_exp_w - 1.0) / sigma).matrix();
        double d_ll_d_log_sigma = (m_is_exact_d * (m_exp_w * m_w - (m_w + 1.0))).sum();

        // Scalar pass, censored rows only (typically the minority).
        for (int i = 0; i < m_n; ++i) {
            if (!m_is_exact[i]) {
                const CensoredRow r = censored_row_terms(i, m_eta[i], sigma);
                loglik += std::log(r.D);
                m_d_eta[i] = r.D_eta / r.D;
                d_ll_d_log_sigma += r.D_logsigma / r.D;
            }
        }

        grad.setZero();
        grad.head(m_p).noalias() = -m_X.transpose() * m_d_eta;
        grad[m_p] = -d_ll_d_log_sigma;

        return -loglik;
    }

    Eigen::MatrixXd hessian(const Eigen::VectorXd& params) {
        int total_p = params.size();
        Eigen::MatrixXd H = Eigen::MatrixXd::Zero(total_p, total_p);
        const auto beta = params.head(m_p);
        double sigma = std::exp(params[m_p]);
        m_eta.noalias() = m_X * beta;

        m_w = ((m_log_y_safe - m_eta.array()) / sigma).min(700.0);
        m_exp_w = m_w.exp();

        m_beta_weights = (m_is_exact_d * m_exp_w / (sigma * sigma)).matrix();
        m_cross_weights =
            (m_is_exact_d * (m_exp_w * (m_w + 1.0) - 1.0) / sigma).matrix();
        double diag_logsigma =
            (m_is_exact_d * (m_exp_w * (m_w.square() + m_w) - m_w)).sum();

        for (int i = 0; i < m_n; ++i) {
            const double eta_i = m_eta[i];
            if (!m_is_exact[i]) {
                const CensoredRow r = censored_row_terms(i, eta_i, sigma);
                const double d2ll_deta2 =
                    -(r.D_eta * r.D_eta) / (r.D * r.D) + (r.D_aa + r.D_bb) / (sigma * sigma * r.D);
                const double bracket_eta_logsigma =
                    (r.L.wu2S - r.L.wuS - r.L.uS) + (r.U.wuS - r.U.wu2S + r.U.uS);
                const double d2ll_deta_dlogsigma =
                    -(r.D_eta * r.D_logsigma) / (r.D * r.D) + bracket_eta_logsigma / (sigma * r.D);
                const double bracket_logsigma2 =
                    (r.L.w2u2S - r.L.w2uS - r.L.wuS) + (r.U.w2uS - r.U.w2u2S + r.U.wuS);
                const double d2ll_dlogsigma2 =
                    -(r.D_logsigma * r.D_logsigma) / (r.D * r.D) + bracket_logsigma2 / r.D;

                m_beta_weights[i] = -d2ll_deta2;
                m_cross_weights[i] = -d2ll_deta_dlogsigma;
                diag_logsigma += -d2ll_dlogsigma2;
            }
        }

        H.topLeftCorner(m_p, m_p).noalias() = weighted_crossprod(m_X, m_beta_weights);
        H.topRightCorner(m_p, 1).noalias() = m_X.transpose() * m_cross_weights;
        H(m_p, m_p) = diag_logsigma;
        H.bottomLeftCorner(1, m_p) = H.topRightCorner(m_p, 1).transpose();
        return H;
    }
};

// OLS-on-log-scale smart-start needs one number per subject; left-censored
// rows have no usable lower bound and are excluded by the start heuristic.
void general_to_effective(const Eigen::Ref<const Eigen::VectorXd>& y,
                           const Eigen::Ref<const Eigen::VectorXd>& y_L,
                           const Eigen::Ref<const Eigen::VectorXd>& y_R,
                           Eigen::VectorXd& y_eff,
                           Eigen::VectorXd& dead_eff) {
    const int n = (int)y.size();
    y_eff.resize(n);
    dead_eff.resize(n);
    for (int i = 0; i < n; ++i) {
        if (std::isfinite(y[i])) {
            y_eff[i] = y[i];
            dead_eff[i] = 1.0;
        } else {
            y_eff[i] = y_L[i];
            dead_eff[i] = 0.0;
        }
    }
}

// Internal column standardization for the Weibull AFT fitters
// (v1.0.6-TODO-112). With covariates on their raw scale (age in years,
// lymph-node counts, ...) next to an intercept, the likelihood is badly
// conditioned and both L-BFGS and Newton-Raphson hit maxit far from the
// optimum, so callers saw non-convergence (and dropped covariates). The fit
// therefore runs on X_s = X A, where A rescales (and, when an intercept
// column is present and free, centers) every column that is far from unit
// scale. eta = X beta = X_s theta with beta = A theta, so the original-scale
// parameters are a linear map of the standardized ones:
//   params_orig = T params_s,  T = blockdiag(A, 1)  (log_sigma unchanged).
// Column j transformed with mean m_j, sd s_j, intercept column k holding the
// constant c:  A(j,j) = 1/s_j,  A(k,j) = -m_j / (c s_j);  inverse
// Ainv(j,j) = s_j,  Ainv(k,j) = m_j / c.
//
// Columns left alone: the intercept, other constant columns, columns
// already near unit scale (sd in [0.25, 4] and, when centering is possible,
// |mean| <= 1; this keeps a balanced 0/1 treatment column untouched while a
// rare 0/1 indicator such as a missingness dummy, sd ~0.15, is rescaled),
// and any column whose coefficient is
// fixed via fixed_idx. If the intercept itself is fixed, columns are scaled
// but not centered. With those rules every fixed parameter maps to itself
// (its row of T is a unit row), so fixed values carry over unchanged. Data
// that need no transformation run exactly the code path used before.
struct WeibullColumnScaling {
    bool active = false;
    Eigen::MatrixXd Xs;    // standardized design, n x p
    Eigen::MatrixXd T;     // (p+1) x (p+1): params_orig = T * params_s
    Eigen::MatrixXd Tinv;  // params_s = Tinv * params_orig
};

inline WeibullColumnScaling make_weibull_column_scaling(const Eigen::Ref<const Eigen::MatrixXd>& X,
                                                        const FixedParamSpec& fixed_spec) {
    WeibullColumnScaling sc;
    const int n = (int)X.rows();
    const int p = (int)X.cols();
    if (n < 2 || p < 1 || !X.allFinite()) return sc;

    std::vector<char> is_fixed(p + 1, 0);
    if (fixed_spec.has_fixed) {
        for (int i = 0; i < fixed_spec.fixed_idx.size(); ++i) is_fixed[fixed_spec.fixed_idx[i]] = 1;
    }

    // Intercept: the first constant, nonzero column.
    int k = -1;
    double c = 0.0;
    for (int j = 0; j < p && k < 0; ++j) {
        const double v0 = X(0, j);
        if (v0 != 0.0 && (X.col(j).array() == v0).all()) { k = j; c = v0; }
    }
    const bool can_center = (k >= 0) && !is_fixed[k];

    Eigen::VectorXd m = Eigen::VectorXd::Zero(p), s = Eigen::VectorXd::Ones(p);
    std::vector<char> transform(p, 0);
    bool any = false;
    for (int j = 0; j < p; ++j) {
        if (j == k || is_fixed[j]) continue;
        const auto col = X.col(j).array();
        const double mean = col.mean();
        const double sd = std::sqrt((col - mean).square().sum() / (n - 1));
        if (!(sd > 1e-12 * std::max(1.0, std::abs(mean)))) continue;  // constant
        const bool scale_off = sd < 0.25 || sd > 4.0;
        const bool center_off = can_center && std::abs(mean) > 1.0;
        if (!scale_off && !center_off) continue;
        transform[j] = 1;
        any = true;
        s[j] = sd;
        m[j] = can_center ? mean : 0.0;
    }
    if (!any) return sc;

    sc.active = true;
    sc.T = Eigen::MatrixXd::Identity(p + 1, p + 1);
    sc.Tinv = Eigen::MatrixXd::Identity(p + 1, p + 1);
    sc.Xs = X;
    for (int j = 0; j < p; ++j) {
        if (!transform[j]) continue;
        sc.Xs.col(j) = (X.col(j).array() - m[j]) / s[j];
        sc.T(j, j) = 1.0 / s[j];
        sc.Tinv(j, j) = s[j];
        if (m[j] != 0.0) {
            sc.T(k, j) = -m[j] / (c * s[j]);
            sc.Tinv(k, j) = m[j] / c;
        }
    }
    return sc;
}

// Shared optimizer step of the two Weibull AFT fitters below: starting
// values, the (possibly standardized) optimization, and mapping the
// optimizer's params, gradient norm and minimum information eigenvalue back
// to the original scale. `fun` is the original-scale likelihood;
// `make_fun_s(Xs)` builds the same likelihood on a standardized design.
// `start_fun(Xfit)` returns the cold-start params for design Xfit.
template <typename Fun, typename MakeFun, typename StartFun>
LikelihoodFitResult fit_weibull_aft_with_column_scaling(
    Fun& fun,
    MakeFun make_fun_s,
    StartFun start_fun,
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const FixedParamSpec& fixed_spec,
    const std::optional<Eigen::VectorXd>& warm_start_params,
    int maxit,
    double tol,
    const std::string& optimization_alg,
    const std::optional<Eigen::MatrixXd>& warm_start_fisher_info) {
    const int p = (int)X.cols();
    Eigen::VectorXd params;
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
        if (params.size() != p + 1) throw std::invalid_argument("warm_start_params must have length equal to ncol(X) + 1");
    }

    WeibullColumnScaling sc = make_weibull_column_scaling(X, fixed_spec);
    if (!sc.active) {
        if (!warm_start_params.has_value()) params = start_fun(Eigen::MatrixXd(X));
        params = apply_fixed_values(params, fixed_spec);
        Eigen::MatrixXd info;
        const Eigen::MatrixXd* info_ptr = nullptr;
        if (warm_start_fisher_info.has_value()) {
            info = *warm_start_fisher_info;
            info_ptr = &info;
        }
        return optimize_fixed_likelihood(fun, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_ptr);
    }

    // Standardized scale. Fixed parameters map to themselves (see
    // make_weibull_column_scaling), so apply_fixed_values works on either scale.
    params = warm_start_params.has_value() ? Eigen::VectorXd(sc.Tinv * params) : start_fun(sc.Xs);
    params = apply_fixed_values(params, fixed_spec);
    Eigen::MatrixXd info;
    const Eigen::MatrixXd* info_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        // l_s(theta) = l(T theta)  =>  I_s = T' I T.
        info = sc.T.transpose() * (*warm_start_fisher_info) * sc.T;
        info_ptr = &info;
    }
    auto fun_s = make_fun_s(sc.Xs);
    LikelihoodFitResult fit = optimize_fixed_likelihood(fun_s, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_ptr);
    if (fit.params.size() != p + 1) return fit;

    // Newton polish on the standardized scale. L-BFGS stops on its relative
    // function-decrease rule (delta = tol on a log-likelihood in the
    // thousands) while coefficients are still ~1e-3 off, and the damped
    // Newton path falls back to L-BFGS when its start is outside the concave
    // region. Once on the well-conditioned standardized scale and next to the
    // optimum, a few full Newton steps reach gradient ~tol. A step is taken
    // only when the free information block is positive definite and the step
    // lowers the gradient norm without raising the objective beyond rounding.
    if (fit.params.allFinite()) {
        const Eigen::VectorXi& free = fixed_spec.free_idx;
        Eigen::VectorXd grad(p + 1);
        double value = fun_s(fit.params, grad);
        double gnorm = subset_vector(grad, free).norm();
        for (int it = 0; it < 5 && std::isfinite(value) && std::isfinite(gnorm) && gnorm >= tol; ++it) {
            Eigen::LLT<Eigen::MatrixXd> llt(subset_matrix(fun_s.hessian(fit.params), free, free));
            if (llt.info() != Eigen::Success) break;
            const Eigen::VectorXd step = llt.solve(subset_vector(grad, free));
            if (!step.allFinite()) break;
            Eigen::VectorXd cand = fit.params;
            for (int i = 0; i < free.size(); ++i) cand[free[i]] -= step[i];
            Eigen::VectorXd cand_grad(p + 1);
            const double cand_value = fun_s(cand, cand_grad);
            const double cand_gnorm = subset_vector(cand_grad, free).norm();
            if (!std::isfinite(cand_value) || !std::isfinite(cand_gnorm) || cand_gnorm >= gnorm ||
                cand_value > value + 1e-10 * std::max(1.0, std::abs(value))) break;
            fit.params = cand;
            grad = cand_grad;
            value = cand_value;
            gnorm = cand_gnorm;
        }
        if (std::isfinite(value)) fit.value = value;  // objective at fit.params
        if (gnorm < tol) {
            fit.converged = true;
            fit.hit_iteration_cap = false;
        }
    }
    fit.params = sc.T * fit.params;
    fit.params = apply_fixed_values(fit.params, fixed_spec);  // exact, no round-off drift
    if (fit.params.allFinite()) {
        // Report the free-parameter gradient norm on the original scale.
        Eigen::VectorXd grad(p + 1);
        fun(fit.params, grad);
        if (grad.allFinite()) fit.gradient_norm = subset_vector(grad, fixed_spec.free_idx).norm();
        if (std::isfinite(fit.min_eigenvalue_information)) {
            const Eigen::MatrixXd H = fun.hessian(fit.params);
            Eigen::SelfAdjointEigenSolver<Eigen::MatrixXd> es(
                subset_matrix(H, fixed_spec.free_idx, fixed_spec.free_idx), Eigen::EigenvaluesOnly);
            if (es.info() == Eigen::Success) fit.min_eigenvalue_information = es.eigenvalues().minCoeff();
        }
    }
    return fit;
}

} // namespace

template <typename WeibullLikelihood>
static edi::ResultMap weibull_aft_fit_result(WeibullLikelihood& fun, const LikelihoodFitResult& fit,
    const FixedParamSpec& fixed_spec, int p, bool estimate_only) {
    if (estimate_only) {
        return edi::ResultMap()
            .set("b", fit.params.head(p))
            .set("log_sigma", fit.params[p])
            .set("converged", fit.converged)
            .set("num_iter", fit.niter)
            .set("hit_iteration_cap", fit.hit_iteration_cap)
            .set("gradient_norm", fit.gradient_norm)
            .set("min_eigenvalue_information", fit.min_eigenvalue_information);
    }

    Eigen::MatrixXd hess = fun.hessian(fit.params);
    Eigen::VectorXd score = -likelihood_score(fun, fit.params);
    Eigen::MatrixXd neg_hess = -hess;
    // Fixed coefficients have no estimated covariance. Keep full information
    // for likelihood tests, but invert only the free-parameter block here.
    Eigen::MatrixXd vcov = fixed_spec.has_fixed
        ? expand_free_covariance(p + 1, fixed_spec,
            covariance_from_information(subset_matrix(hess, fixed_spec.free_idx, fixed_spec.free_idx)), true)
        : covariance_from_information(hess);
    return edi::ResultMap()
        .set("params", fit.params)
        .set("neg_loglik", fit.value)
        .set("neg_ll", fit.value)
        .set("loglik", std::isfinite(fit.value) ? -fit.value : std::numeric_limits<double>::quiet_NaN())
        .set("converged", fit.converged)
        .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("score", score)
        .set("observed_information", hess)
        .set("hessian", neg_hess)
        .set("information", hess)
        .set("information_type", std::string("observed"))
        .set("vcov", vcov);
}

// Portable core: same fit as fast_weibull_regression_cpp below, but built
// directly on edi::ResultMap rather than _helper_functions.h's Rcpp-coupled
// make_uniform_likelihood_fit_result (params/neg_loglik/converged/score/
// observed_information/hessian/information/information_type/vcov -- same
// field set, information_type fixed at "observed" since fisher_information
// is never passed here, matching that helper's own default). Fast path:
// exact/right-censored responses only -- see WeibullAFTLikelihood's own
// comment and TODO-28. For left-/interval-censored responses, use
// fast_weibull_regression_left_interval_censoring_internal below instead.
edi::ResultMap fast_weibull_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& dead,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    bool smart_cold_start = true,
    bool estimate_only = false,
    int maxit = 100,
    double tol = 1e-8,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt
) {
    int p = (int)X.cols();
    require_square_matrix(warm_start_fisher_info, p + 1, "warm_start_fisher_info");
    FixedParamSpec fixed_spec = make_fixed_param_spec(p + 1, fixed_idx, fixed_values);
    WeibullAFTLikelihood fun(y, dead, X);

    // Fit on internally standardized columns when X is badly scaled, results
    // mapped back to X's scale (v1.0.6-TODO-112; see make_weibull_column_scaling).
    LikelihoodFitResult fit = fit_weibull_aft_with_column_scaling(
        fun,
        [&](const Eigen::MatrixXd& Xs) { return WeibullAFTLikelihood(y, dead, Xs); },
        [&](const Eigen::MatrixXd& Xfit) {
            WeibullStart legacy_start;
            legacy_start.beta = Eigen::VectorXd::Zero(p);
            legacy_start.log_sigma = 0.0;
            WeibullStart start = smart_cold_start ? weibull_aft_start_or_legacy(Xfit, y, dead, legacy_start, fixed_spec) : legacy_start;
            return weibull_start_to_params(start);
        },
        X, fixed_spec, warm_start_params, maxit, tol, optimization_alg, warm_start_fisher_info);

    return weibull_aft_fit_result(fun, fit, fixed_spec, p, estimate_only);
}

#ifndef EDI_CORE_ONLY
//' @title Compute Weibull Regression Score
//' @description Calculates the score vector (gradient of the log-likelihood) for a Weibull AFT regression model.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of survival times.
//' @param dead A numeric vector of event indicators.
//' @param params A numeric vector of parameters [beta, log_sigma].
//' @return A numeric vector representing the score.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_weibull_regression_score_cpp(SEXP X,
                                                 SEXP y,
                                                 SEXP dead,
                                                 SEXP params) {
    NumericMatrix X_r(X);
    NumericVector y_r(y);
    NumericVector dead_r(dead);
    NumericVector params_r(params);
    Eigen::Map<const Eigen::MatrixXd> X_mat(X_r.begin(), X_r.nrow(), X_r.ncol());
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> dead_vec(dead_r.begin(), dead_r.size());
    Eigen::Map<const Eigen::VectorXd> params_vec(params_r.begin(), params_r.size());

    WeibullAFTLikelihood fun(y_vec, dead_vec, X_mat);
    Eigen::VectorXd grad(params_vec.size());
    fun(params_vec, grad);
    return -grad;
}

//' @title Compute Weibull Regression Hessian
//' @description Calculates the Hessian matrix (second derivatives of the log-likelihood) for a Weibull AFT regression model.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of survival times.
//' @param dead A numeric vector of event indicators.
//' @param params A numeric vector of parameters [beta, log_sigma].
//' @return A numeric matrix representing the Hessian.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_weibull_regression_hessian_cpp(SEXP X,
                                                   SEXP y,
                                                   SEXP dead,
                                                   SEXP params) {
    NumericMatrix X_r(X);
    NumericVector y_r(y);
    NumericVector dead_r(dead);
    NumericVector params_r(params);
    Eigen::Map<const Eigen::MatrixXd> X_mat(X_r.begin(), X_r.nrow(), X_r.ncol());
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> dead_vec(dead_r.begin(), dead_r.size());
    Eigen::Map<const Eigen::VectorXd> params_vec(params_r.begin(), params_r.size());

    WeibullAFTLikelihood fun(y_vec, dead_vec, X_mat);
    return -fun.hessian(params_vec);
}

//' @title Fast Weibull AFT Regression (C++)
//' @description Weibull Accelerated Failure Time model fitting, exact/
//'   right-censored responses only. See fast_weibull_regression_general_cpp
//'   for the left-/interval-censored extension.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of survival times.
//' @param dead A numeric vector of event indicators (1=event, 0=censored).
//' @param warm_start_params Optional starting values for the full
//'   \eqn{[\beta, \log\sigma]} parameter vector (length \code{ncol(X) + 1}).
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess.
//' @param estimate_only Logical. If TRUE, do not compute variance-covariance.
//' @param maxit Maximum number of iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or \code{"newton_raphson"}.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix.
//' @return A list. If \code{estimate_only = TRUE}: \code{b} (the coefficients
//'   \eqn{\hat\beta} on the columns of \code{X}), \code{log_sigma}, \code{converged},
//'   \code{num_iter}, \code{hit_iteration_cap}, \code{gradient_norm} and
//'   \code{min_eigenvalue_information}. Otherwise: \code{params} (the full
//'   \eqn{[\hat\beta, \log\hat\sigma]} vector), \code{neg_loglik}/\code{neg_ll} (two
//'   aliases for the negative log-likelihood), \code{loglik}, the same convergence fields,
//'   \code{score}, \code{observed_information}/\code{information} (the observed
//'   information matrix), \code{hessian} (its negative), \code{information_type}
//'   (\code{"observed"}) and \code{vcov} (the covariance matrix of \code{params}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_weibull_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                 SEXP y,
                                 SEXP dead,
                                 Nullable<NumericVector> warm_start_params = R_NilValue,
                                 bool smart_cold_start = true,
                                 bool estimate_only = false,
                                 int maxit = 100,
                                 double tol = 1e-8,
                                 Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                 Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                 std::string optimization_alg = "lbfgs",
                                 Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_r(y);
    NumericVector dead_r(dead);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> dead_vec(dead_r.begin(), dead_r.size());

    return edi::to_rcpp_list(fast_weibull_regression_internal(
        X, y_vec, dead_vec,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, estimate_only, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info)));
}
#endif // EDI_CORE_ONLY

// Portable core, left-/interval-/right-censored responses (see TODO-3 in
// interval_censored_survival_response.md). Built directly on edi::ResultMap
// rather than _helper_functions.h's Rcpp-coupled
// make_uniform_likelihood_fit_result (params/neg_loglik/converged/score/
// observed_information/hessian/information/information_type/vcov -- same
// field set, information_type fixed at "observed" since fisher_information
// is never passed here, matching that helper's own default).
edi::ResultMap fast_weibull_regression_left_interval_censoring_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    const Eigen::Ref<const Eigen::VectorXd>& y_L,
    const Eigen::Ref<const Eigen::VectorXd>& y_R,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    bool smart_cold_start = true,
    bool estimate_only = false,
    int maxit = 100,
    double tol = 1e-8,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt
) {
    int p = (int)X.cols();
    require_square_matrix(warm_start_fisher_info, p + 1, "warm_start_fisher_info");
    FixedParamSpec fixed_spec = make_fixed_param_spec(p + 1, fixed_idx, fixed_values);
    WeibullAFTLikelihoodGeneral fun(y, y_L, y_R, X);

    // Same optimizer as the exact/right-censored path, same conditioning
    // problem on raw-scale covariates: same internal standardization
    // (v1.0.6-TODO-112; see make_weibull_column_scaling).
    LikelihoodFitResult fit = fit_weibull_aft_with_column_scaling(
        fun,
        [&](const Eigen::MatrixXd& Xs) { return WeibullAFTLikelihoodGeneral(y, y_L, y_R, Xs); },
        [&](const Eigen::MatrixXd& Xfit) {
            WeibullStart legacy_start;
            legacy_start.beta = Eigen::VectorXd::Zero(p);
            legacy_start.log_sigma = 0.0;
            Eigen::VectorXd y_eff, dead_eff;
            general_to_effective(y, y_L, y_R, y_eff, dead_eff);
            WeibullStart start = smart_cold_start ? weibull_aft_start_or_legacy(Xfit, y_eff, dead_eff, legacy_start, fixed_spec) : legacy_start;
            return weibull_start_to_params(start);
        },
        X, fixed_spec, warm_start_params, maxit, tol, optimization_alg, warm_start_fisher_info);

    return weibull_aft_fit_result(fun, fit, fixed_spec, p, estimate_only);
}

#ifndef EDI_CORE_ONLY
//' @title Compute Weibull Regression Score (General Censoring)
//' @description Score vector for the Weibull AFT log-likelihood extended to
//'   left-, right-, and interval-censored responses (see TODO-3 in
//'   interval_censored_survival_response.md). Each subject is either exact
//'   (\code{y[i]} finite, \code{y_L[i]} and \code{y_R[i]} \code{NA}) or censored
//'   (\code{y[i]} \code{NA}, \code{y_L[i]} finite, \code{y_R[i]} finite or \code{Inf}).
//' @param X A numeric matrix of predictors.
//' @param y Exact survival times, \code{NA} for censored subjects.
//' @param y_L Censored-interval lower bounds, \code{NA} for exact subjects;
//'   \code{0} for left-censored.
//' @param y_R Censored-interval upper bounds, \code{NA} for exact subjects;
//'   \code{Inf} for right-censored.
//' @param params A numeric vector of parameters [beta, log_sigma].
//' @return A numeric vector representing the score.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_weibull_regression_general_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                          SEXP y,
                                                          SEXP y_L,
                                                          SEXP y_R,
                                                          const Eigen::Map<Eigen::VectorXd>& params) {
    NumericVector y_r(y);
    NumericVector y_L_r(y_L);
    NumericVector y_R_r(y_R);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> y_L_vec(y_L_r.begin(), y_L_r.size());
    Eigen::Map<const Eigen::VectorXd> y_R_vec(y_R_r.begin(), y_R_r.size());

    WeibullAFTLikelihoodGeneral fun(y_vec, y_L_vec, y_R_vec, X);
    Eigen::VectorXd grad(params.size());
    fun(params, grad);
    return -grad;
}

//' @title Compute Weibull Regression Hessian (General Censoring)
//' @description Hessian matrix for the Weibull AFT log-likelihood extended
//'   to left-, right-, and interval-censored responses. See
//'   \code{get_weibull_regression_general_score_cpp()} for the input
//'   convention.
//' @param X A numeric matrix of predictors.
//' @param y Exact survival times, \code{NA} for censored subjects.
//' @param y_L Censored-interval lower bounds, \code{NA} for exact subjects;
//'   \code{0} for left-censored.
//' @param y_R Censored-interval upper bounds, \code{NA} for exact subjects;
//'   \code{Inf} for right-censored.
//' @param params A numeric vector of parameters [beta, log_sigma].
//' @return A numeric matrix representing the Hessian.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_weibull_regression_general_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                                            SEXP y,
                                                            SEXP y_L,
                                                            SEXP y_R,
                                                            const Eigen::Map<Eigen::VectorXd>& params) {
    NumericVector y_r(y);
    NumericVector y_L_r(y_L);
    NumericVector y_R_r(y_R);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> y_L_vec(y_L_r.begin(), y_L_r.size());
    Eigen::Map<const Eigen::VectorXd> y_R_vec(y_R_r.begin(), y_R_r.size());

    WeibullAFTLikelihoodGeneral fun(y_vec, y_L_vec, y_R_vec, X);
    return -fun.hessian(params);
}

//' @title Fast Weibull AFT Regression, General Censoring (C++)
//' @description Weibull Accelerated Failure Time model fitting extended to
//'   left-, right-, and interval-censored responses (TODO-3 in
//'   interval_censored_survival_response.md). Zero-regression by
//'   construction: exact/right-censored-only input uses the same likelihood
//'   contributions as the corresponding \code{survival::Surv()} response.
//' @param X A numeric matrix of predictors.
//' @param y Exact survival times, \code{NA} for censored subjects.
//' @param y_L Censored-interval lower bounds, \code{NA} for exact subjects;
//'   \code{0} for left-censored.
//' @param y_R Censored-interval upper bounds, \code{NA} for exact subjects;
//'   \code{Inf} for right-censored.
//' @param warm_start_params Optional starting values for the full
//'   \eqn{[\beta, \log\sigma]} parameter vector (length \code{ncol(X) + 1}).
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess.
//' @param estimate_only Logical. If TRUE, do not compute variance-covariance.
//' @param maxit Maximum number of iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm: \code{"lbfgs"} (default) or \code{"newton_raphson"}.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix.
//' @return A list. If \code{estimate_only = TRUE}: \code{b} (the coefficients
//'   \eqn{\hat\beta} on the columns of \code{X}), \code{log_sigma}, \code{converged},
//'   \code{num_iter}, \code{hit_iteration_cap}, \code{gradient_norm} and
//'   \code{min_eigenvalue_information}. Otherwise: \code{params} (the full
//'   \eqn{[\hat\beta, \log\hat\sigma]} vector), \code{neg_loglik}/\code{neg_ll} (two
//'   aliases for the negative log-likelihood), \code{loglik}, the same convergence fields,
//'   \code{score}, \code{observed_information}/\code{information} (the observed
//'   information matrix), \code{hessian} (its negative), \code{information_type}
//'   (\code{"observed"}) and \code{vcov} (the covariance matrix of \code{params}).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_weibull_regression_general_cpp(const Eigen::Map<Eigen::MatrixXd>& X,
                                         SEXP y,
                                         SEXP y_L,
                                         SEXP y_R,
                                         Nullable<NumericVector> warm_start_params = R_NilValue,
                                         bool smart_cold_start = true,
                                         bool estimate_only = false,
                                         int maxit = 100,
                                         double tol = 1e-8,
                                         Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                         Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                         std::string optimization_alg = "lbfgs",
                                         Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_r(y);
    NumericVector y_L_r(y_L);
    NumericVector y_R_r(y_R);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    Eigen::Map<const Eigen::VectorXd> y_L_vec(y_L_r.begin(), y_L_r.size());
    Eigen::Map<const Eigen::VectorXd> y_R_vec(y_R_r.begin(), y_R_r.size());

    return edi::to_rcpp_list(fast_weibull_regression_left_interval_censoring_internal(
        X, y_vec, y_L_vec, y_R_vec,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, estimate_only, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info)));
}

// [[Rcpp::export]]
NumericVector compute_weibull_rand_bootstrap_parallel_cpp(
    const NumericVector& y0,
    const IntegerVector& dead,
    const NumericMatrix& Xc,
    const IntegerMatrix& i_mat,
    const IntegerMatrix& w_mat,
    double delta,
    Rcpp::Nullable<Rcpp::NumericMatrix> noise_mat,
    int num_cores)
{
    const int n_params = 3 + Xc.ncol();
    const FixedParamSpec fspec = make_fixed_param_spec(n_params);
    return survival_rand_bootstrap(y0, dead, Xc, i_mat, w_mat, delta, noise_mat, num_cores, 1, n_params,
        [&](const Eigen::MatrixXd& X_b, const Eigen::VectorXd& y_b,
            const Eigen::VectorXd& dead_b, Eigen::VectorXd& params0) {
            params0.setZero();
            // Bootstrap replicates are always exact/right-censored by
            // construction (never interval/left-censored) -- route through
            // the fast kernel per TODO-28's routing principle, no
            // y_exact/y_L/y_R conversion needed. Raw-scale covariates are
            // standardized for the fit and the treatment coefficient mapped
            // back (v1.0.6-TODO-112; see make_weibull_column_scaling).
            WeibullColumnScaling sc = make_weibull_column_scaling(X_b, fspec);
            WeibullAFTLikelihood fun(y_b, dead_b, sc.active ? sc.Xs : X_b);
            LikelihoodFitResult fit = optimize_fixed_likelihood(
                fun, params0, fspec, 100, 1e-8, "lbfgs", "", 0, nullptr);
            if (sc.active && fit.params.size() == n_params) fit.params = sc.T * fit.params;
            if (fit.converged && fit.params.size() > 1 && std::isfinite(fit.params[1]))
                return fit.params[1];
            return NA_REAL;
        });
}

#endif // EDI_CORE_ONLY
