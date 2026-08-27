// Zero-Inflated Negative Binomial (ZINB) regression.
//
// Model:
//   P(Y=0)   = pi + (1-pi) * (theta/(theta+mu))^theta
//   P(Y=y>0) = (1-pi) * NegBin(y; mu, theta)
//
// Parameter vector: [beta_cond(p_cond), beta_zi(p_zi), log_theta]
//   mu  = exp(eta_cond),  pi = sigmoid(eta_zi),  theta = exp(log_theta)
//
// Analytic gradient; analytic Hessian.

#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#include <Rmath.h>
#endif
#include <cmath>
#include <unordered_map>
#include <stdexcept>
#include "_negbin_boundary_convergence.h"

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif

namespace {

class ZeroInflatedNegBin {
    const Eigen::Ref<const Eigen::VectorXd> m_y;
    const Eigen::Ref<const Eigen::MatrixXd> m_Xc;
    const Eigen::Ref<const Eigen::MatrixXd> m_Xz;
    const int m_n, m_pc, m_pz;

    // Precomputed at construction from fixed data y.
    // m_y_slot[i]: index into m_distinct_y for obs i (or -1 if y_i == 0).
    // m_distinct_y: sorted unique positive y values (as double).
    // m_lgamma_y1: lgamma(y+1) for each entry of m_distinct_y — constant across calls.
    std::vector<int>    m_y_slot;
    std::vector<double> m_distinct_y;
    std::vector<double> m_lgamma_y1;
    std::vector<double> m_lgamma_yptheta;   // preallocated; filled per operator() call
    std::vector<double> m_digamma_yptheta;  // preallocated; filled per operator() call

    // Preallocated scratch vectors — avoid heap allocation on every operator() call.
    // operator() is non-const, so mutating members across calls is safe (matches ZeroAugmentedPoisson).
    Eigen::VectorXd m_eta_c, m_eta_z, m_w_c, m_w_z;

    // TODO-67 prototype: batched transcendental precompute buffers (vectorized when the package
    // is built with Eigen SIMD, i.e. without EIGEN_DONT_VECTORIZE; see Makevars).
    Eigen::ArrayXd m_mu, m_logden, m_p, m_lse, m_phi, m_ld0;

public:
    ZeroInflatedNegBin(const Eigen::Ref<const Eigen::VectorXd>& y,
                       const Eigen::Ref<const Eigen::MatrixXd>& Xc,
                       const Eigen::Ref<const Eigen::MatrixXd>& Xz)
        : m_y(y), m_Xc(Xc), m_Xz(Xz),
          m_n(y.size()), m_pc(Xc.cols()), m_pz(Xz.cols()),
          m_y_slot(y.size(), -1),
          m_eta_c(m_n), m_eta_z(m_n), m_w_c(m_n), m_w_z(m_n),
          m_mu(m_n), m_logden(m_n), m_p(m_n), m_lse(m_n), m_phi(m_n), m_ld0(m_n)
    {
        std::unordered_map<int, int> seen;
        for (int i = 0; i < m_n; ++i) {
            if (m_y[i] <= 0.0) continue;
            const int yi_int = static_cast<int>(m_y[i]);
            auto it = seen.find(yi_int);
            if (it == seen.end()) {
                const int slot = static_cast<int>(m_distinct_y.size());
                seen[yi_int] = slot;
                m_distinct_y.push_back(static_cast<double>(yi_int));
                m_lgamma_y1.push_back(std::lgamma(static_cast<double>(yi_int) + 1.0));
                m_y_slot[i] = slot;
            } else {
                m_y_slot[i] = it->second;
            }
        }
        const int nd = static_cast<int>(m_distinct_y.size());
        m_lgamma_yptheta.resize(nd);
        m_digamma_yptheta.resize(nd);
    }

    double operator()(const Eigen::VectorXd& par, Eigen::VectorXd& grad) {
        const double log_theta = par[m_pc + m_pz];
        const double theta     = std::exp(std::min(log_theta, 700.0));

        m_eta_c.noalias() = m_Xc * par.head(m_pc);
        m_eta_z.noalias() = m_Xz * par.segment(m_pc, m_pz);

        // TODO-67: batch all per-observation transcendentals into vectorized Eigen array
        // passes (SIMD packet exp/log when built with Eigen SIMD enabled). The branchy
        // accumulation loop below then uses these precomputed values with no transcendental calls.
        m_mu     = m_eta_c.array().exp();                          // mu = exp(eta_c)
        m_logden = (theta + m_mu).log();                          // log(theta + mu)
        m_p      = 1.0 / (1.0 + (-m_eta_z.array()).exp());        // sigmoid(eta_z)
        m_lse    = m_eta_z.array().max(0.0)
                 + (1.0 + (-(m_eta_z.array().abs())).exp()).log();// softplus(eta_z) = log(1+exp(eta_z))
        m_phi    = (theta * (log_theta - m_logden)).exp();        // (theta/(theta+mu))^theta
        m_ld0    = (m_p + (1.0 - m_p) * m_phi).log();             // log(p + (1-p)*phi), y==0 branch

        // Hoist theta-only special functions out of the observation loop.
        const double digamma_theta = fast_digamma(theta);
        const double lgamma_theta  = std::lgamma(theta);

        // Fill preallocated per-distinct-y tables.
        const int nd = static_cast<int>(m_distinct_y.size());
        for (int k = 0; k < nd; ++k) {
            const double ypt = m_distinct_y[k] + theta;
            m_lgamma_yptheta[k]  = std::lgamma(ypt);
            m_digamma_yptheta[k] = fast_digamma(ypt);
        }

        double nll = 0.0;
        double d_log_theta = 0.0;
        m_w_c.setZero();
        m_w_z.setZero();

        for (int i = 0; i < m_n; ++i) {
            const double yi        = m_y[i];
            const double ec        = m_eta_c[i];
            const double mu        = m_mu[i];
            const double p         = m_p[i];
            const double denom     = theta + mu;
            const double log_denom = m_logden[i];

            if (yi <= 0.0) {
                const double phi = m_phi[i];
                nll -= m_ld0[i];                                 // log(p + (1-p)*phi)

                const double den     = p + (1.0 - p) * phi;
                const double inv_den = 1.0 / den;
                m_w_z[i] = -(p * (1.0 - p) * (1.0 - phi)) * inv_den;

                const double d_phi_d_ec = -mu * theta * phi / denom;
                m_w_c[i] = -((1.0 - p) * d_phi_d_ec) * inv_den;

                const double d_phi_d_theta = phi * (log_theta - log_denom + 1.0 - theta / denom);
                d_log_theta -= (1.0 - p) * d_phi_d_theta * theta * inv_den;
            } else {
                const int slot = m_y_slot[i];
                nll -= -m_lse[i]  // log(1-p)
                     + m_lgamma_yptheta[slot] - lgamma_theta - m_lgamma_y1[slot]
                     + theta * (log_theta - log_denom) + yi * (ec - log_denom);

                m_w_z[i] = p;
                m_w_c[i] = -(yi - mu * (yi + theta) / denom);

                d_log_theta -= (m_digamma_yptheta[slot] - digamma_theta + log_theta - log_denom + 1.0 - (yi + theta) / denom) * theta;
            }
        }

        grad.head(m_pc).noalias()          = m_Xc.transpose() * m_w_c;
        grad.segment(m_pc, m_pz).noalias() = m_Xz.transpose() * m_w_z;
        grad[m_pc + m_pz]                  = d_log_theta;
        return nll;
    }

    Eigen::MatrixXd hessian(const Eigen::VectorXd& par) {
        return numerical_hessian(*this, par);
    }

    // Evaluate the exact theta -> infinity (Poisson) limit without ever
    // forming the enormous theta values that make the NegBin expression
    // suffer lgamma/cancellation overflow.  The final coordinate in par is
    // intentionally ignored; callers use it only to verify that the failed
    // optimizer was travelling toward this boundary.
    bool poisson_limit_value_gradient(const Eigen::VectorXd& par,
                                      Eigen::VectorXd& grad,
                                      double& nll) const {
        if (par.size() != m_pc + m_pz + 1 || !par.allFinite()) return false;
        Eigen::VectorXd eta_c = m_Xc * par.head(m_pc);
        Eigen::VectorXd eta_z = m_Xz * par.segment(m_pc, m_pz);
        Eigen::VectorXd w_c = Eigen::VectorXd::Zero(m_n);
        Eigen::VectorXd w_z = Eigen::VectorXd::Zero(m_n);
        nll = 0.0;

        auto softplus = [](double x) {
            return x > 0.0 ? x + std::log1p(std::exp(-x)) : std::log1p(std::exp(x));
        };
        auto log_add_exp = [](double a, double b) {
            const double hi = std::max(a, b);
            const double lo = std::min(a, b);
            return hi + std::log1p(std::exp(lo - hi));
        };

        for (int i = 0; i < m_n; ++i) {
            const double ec = eta_c[i];
            const double ez = eta_z[i];
            if (!std::isfinite(ec) || !std::isfinite(ez)) return false;
            const double mu = std::exp(ec);
            if (!std::isfinite(mu)) return false;
            const double log_pi = -softplus(-ez);
            const double log_q = -softplus(ez);
            const double pi = std::exp(log_pi);
            const double q = std::exp(log_q);

            if (m_y[i] <= 0.0) {
                const double exp_neg_mu = std::exp(-mu);
                const double log_p0 = log_add_exp(log_pi, log_q - mu);
                const double p0 = std::exp(log_p0);
                if (!std::isfinite(log_p0) || !(p0 > 0.0)) return false;
                nll -= log_p0;
                // d[-log{pi + (1-pi) exp(-mu)}]/d eta_c and d eta_z.
                w_c[i] = q * mu * exp_neg_mu / p0;
                w_z[i] = -pi * q * (1.0 - exp_neg_mu) / p0;
            } else {
                const double yi = m_y[i];
                nll += -log_q - yi * ec + mu + std::lgamma(yi + 1.0);
                // Poisson count score and zero-inflation score.
                w_c[i] = mu - yi;
                w_z[i] = pi;
            }
            if (!std::isfinite(nll) || !std::isfinite(w_c[i]) || !std::isfinite(w_z[i])) return false;
        }
        grad.resize(m_pc + m_pz + 1);
        grad.head(m_pc).noalias() = m_Xc.transpose() * w_c;
        grad.segment(m_pc, m_pz).noalias() = m_Xz.transpose() * w_z;
        grad[m_pc + m_pz] = 0.0;
        return grad.head(m_pc + m_pz).allFinite() && std::isfinite(nll);
    }
};

// Reduced ZIP likelihood used only when the ZINB boundary diagnostics reject
// the finite-theta evaluation.  Parameters contain [beta_cond, beta_zi]; the
// stable Poisson-limit evaluator supplies the exact objective and gradient.
class ZipLimitLikelihood {
    ZeroInflatedNegBin& m_zinb;
    const int m_p;
    Eigen::VectorXd full_params(const Eigen::VectorXd& p) const {
        Eigen::VectorXd full(p.size() + 1);
        full.head(m_p) = p;
        full[m_p] = kNegBinPoissonBoundaryLogTheta;
        return full;
    }
public:
    ZipLimitLikelihood(ZeroInflatedNegBin& zinb, int p) : m_zinb(zinb), m_p(p) {}
    double operator()(const Eigen::VectorXd& p, Eigen::VectorXd& grad) {
        Eigen::VectorXd full_grad;
        double value = std::numeric_limits<double>::quiet_NaN();
        if (!m_zinb.poisson_limit_value_gradient(full_params(p), full_grad, value)) {
            grad = Eigen::VectorXd::Constant(p.size(), std::numeric_limits<double>::quiet_NaN());
            return std::numeric_limits<double>::quiet_NaN();
        }
        grad = full_grad.head(m_p);
        return value;
    }
    Eigen::MatrixXd hessian(const Eigen::VectorXd& p) {
        const int k = p.size();
        Eigen::MatrixXd H = Eigen::MatrixXd::Zero(k, k);
        const double step = 1e-5;
        for (int j = 0; j < k; ++j) {
            Eigen::VectorXd lo = p, hi = p, glo, ghi;
            lo[j] -= step; hi[j] += step;
            double vlo = (*this)(lo, glo), vhi = (*this)(hi, ghi);
            if (!std::isfinite(vlo) || !std::isfinite(vhi) || !glo.allFinite() || !ghi.allFinite())
                return Eigen::MatrixXd::Constant(k, k, std::numeric_limits<double>::quiet_NaN());
            H.col(j) = (ghi - glo) / (2.0 * step);
        }
        return 0.5 * (H + H.transpose());
    }
};

bool fit_zip_reduced_fallback(ZeroInflatedNegBin& zinb, const FixedParamSpec& zinb_spec,
                              int dispersion_index, int maxit, double tol,
                              const std::string& optimization_alg, LikelihoodFitResult& fit) {
    if (fit.params.size() <= dispersion_index || !fit.params.allFinite()) return false;
    // A reduced ZIP model is appropriate only for the Poisson-limit failure:
    // do not replace an ordinary finite-dispersion ZINB fit merely because a
    // different diagnostic happened to reject it.
    if (fit.params[dispersion_index] < kNegBinPoissonBoundaryLogTheta &&
        std::isfinite(fit.value)) return false;
    const int k = dispersion_index;
    Eigen::VectorXd start = fit.params.head(k);
    FixedParamSpec zip_spec;
    zip_spec.free_idx.resize(k);
    for (int i = 0; i < k; ++i) zip_spec.free_idx[i] = i;
    if (zinb_spec.has_fixed) {
        std::vector<int> fi;
        std::vector<double> fv;
        for (int i = 0; i < zinb_spec.fixed_idx.size(); ++i) {
            if (zinb_spec.fixed_idx[i] == dispersion_index) continue;
            fi.push_back(zinb_spec.fixed_idx[i]);
            fv.push_back(zinb_spec.fixed_values[i]);
        }
        Eigen::VectorXi fi_e(fi.size());
        Eigen::VectorXd fv_e(fv.size());
        for (int i = 0; i < static_cast<int>(fi.size()); ++i) {
            fi_e[i] = fi[i];
            fv_e[i] = fv[i];
        }
        zip_spec = make_fixed_param_spec(k, fi_e, fv_e);
    }
    ZipLimitLikelihood zip(zinb, k);
    LikelihoodFitResult reduced = optimize_fixed_likelihood(
        zip, start, zip_spec, maxit, tol, optimization_alg, "lbfgs", 0, nullptr);
    if (!reduced.converged || reduced.params.size() != k || !reduced.params.allFinite()) return false;
    Eigen::VectorXd full(k + 1);
    full.head(k) = reduced.params;
    full[k] = kNegBinPoissonBoundaryLogTheta;
    fit = reduced;
    fit.params = full;
    fit.dispersion_at_poisson_boundary = true;
    fit.reduced_model = "ZIP";
    fit.value = reduced.value;
    return true;
}

// ZINB-specific extension of the generic boundary acceptance rule.  The
// generic helper needs the finite NegBin objective at the final iterate; at
// very large theta that objective can be NaN even when the exact Poisson limit
// and all treatment/zero-inflation scores are finite.  Keep this fallback
// local to ZINB so no other likelihood is allowed to reinterpret a nonfinite
// objective as convergence.
bool accept_zinb_poisson_boundary_convergence(
    ZeroInflatedNegBin& fun,
    const FixedParamSpec& fixed_spec,
    int dispersion_index,
    double tol,
    LikelihoodFitResult& fit) {
    if (fit.converged || fit.params.size() <= dispersion_index ||
        !fit.params.allFinite() || !std::isfinite(fit.params[dispersion_index]) ||
        fit.params[dispersion_index] < kNegBinPoissonBoundaryLogTheta ||
        !negbin_parameter_is_free(fixed_spec, dispersion_index)) return false;

    Eigen::VectorXd limit_gradient;
    double limit_value = std::numeric_limits<double>::quiet_NaN();
    if (!fun.poisson_limit_value_gradient(fit.params, limit_gradient, limit_value)) return false;

    const double coefficient_tol = std::max(10.0 * tol, 1e-6);
    double non_dispersion_gradient_sq = 0.0;
    for (int i = 0; i < fixed_spec.free_idx.size(); ++i) {
        const int index = fixed_spec.free_idx[i];
        if (index != dispersion_index) non_dispersion_gradient_sq += limit_gradient[index] * limit_gradient[index];
    }
    if (std::sqrt(non_dispersion_gradient_sq) > coefficient_tol) return false;

    // Require the original analytic dispersion score to point toward larger
    // theta.  Its objective value may be NaN, but the score remains useful in
    // the observed failure mode and is checked for finiteness independently.
    Eigen::VectorXd raw_gradient(fit.params.size());
    (void)fun(fit.params, raw_gradient);
    if (!raw_gradient.allFinite() || !(raw_gradient[dispersion_index] < 0.0)) return false;

    // Compare with a finite, conservative anchor at theta = 1e4.  This keeps
    // the fallback from accepting an unrelated failed fit merely because its
    // final dispersion coordinate is large.
    Eigen::VectorXd anchor = fit.params;
    anchor[dispersion_index] = kNegBinPoissonBoundaryLogTheta;
    Eigen::VectorXd anchor_gradient(anchor.size());
    const double anchor_value = fun(anchor, anchor_gradient);
    if (!std::isfinite(anchor_value) || !anchor_gradient.allFinite() ||
        !(anchor_gradient[dispersion_index] <= 0.0)) return false;
    const double slack = 64.0 * std::numeric_limits<double>::epsilon() *
        std::max(1.0, std::fabs(anchor_value));
    if (limit_value > anchor_value + slack) return false;

    fit.value = limit_value;
    fit.gradient_norm = std::sqrt(non_dispersion_gradient_sq);
    fit.converged = true;
    fit.hit_iteration_cap = false;
    fit.dispersion_at_poisson_boundary = true;
    return true;
}

} // namespace

LikelihoodFitResult fast_zinb_internal(const Eigen::Ref<const Eigen::MatrixXd>& Xc,
                                       const Eigen::Ref<const Eigen::MatrixXd>& Xz,
                                       const Eigen::Ref<const Eigen::VectorXd>& y_vec,
                                       std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
                                       int maxit = 1000, double tol = 1e-8,
                                       std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                       std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                       std::string optimization_alg = "lbfgs",
                                       bool smart_cold_start = true,
                                       std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt) {
    ZeroInflatedNegBin obj(y_vec, Xc, Xz);
    int n_par = Xc.cols() + Xz.cols() + 1;
    Eigen::VectorXd par = Eigen::VectorXd::Zero(n_par);

    if (warm_start_params.has_value()) {
        par = *warm_start_params;
        if (par.size() != n_par) throw std::invalid_argument("warm_start_params must have length equal to the number of model parameters");
    } else if (smart_cold_start) {
        // Simple initialization
        double mean_y = y_vec.mean();
        if (mean_y < 1e-8) mean_y = 1e-8;
        par.head(Xc.cols()).setZero();
        if (Xc.cols() > 0) par[0] = std::log(mean_y);
        par.segment(Xc.cols(), Xz.cols()).setZero();
        par[n_par - 1] = std::log(1.0); // theta = 1
    }

    FixedParamSpec fixed_spec = make_fixed_param_spec(n_par, fixed_idx, fixed_values);

    Eigen::MatrixXd info;
    const Eigen::MatrixXd* info_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info = *warm_start_fisher_info;
        if (info.rows() == n_par && info.cols() == n_par) {
            info_ptr = &info;
        }
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(
        obj, par, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_ptr);
    if (!accept_zinb_poisson_boundary_convergence(obj, fixed_spec, n_par - 1, tol, fit)) {
        // Prefer a direct stable ZIP fit whenever the finite-theta ZINB
        // predicates fail.  Retain the generic boundary acceptance only as a
        // final compatibility path if the reduced fit itself cannot run.
        if (!fit_zip_reduced_fallback(obj, fixed_spec, n_par - 1, maxit, tol, optimization_alg, fit))
            accept_negbin_poisson_boundary_convergence(obj, fixed_spec, n_par - 1, tol, fit);
    }
    return fit;
}

// Portable (EDI_CORE_ONLY-safe) sibling of fast_zinb_cpp below: fits via
// fast_zinb_internal, then always takes the extra
// ZeroInflatedNegBin::hessian(params) call, inverted into vcov, returning
// edi::ResultMap directly instead of going through
// make_uniform_likelihood_fit_result's Rcpp::List (that helper lives in the
// Rcpp-only _helper_functions.h), so a separate Python binding translation
// unit can call it. No estimate_only flag: fast_zinb_internal/fast_zinb
// already is the dedicated point-estimate-only backend, so this sibling's
// only reason to exist is the variance -- an estimate_only branch here
// would just be dead weight no caller needs.
edi::ResultMap fast_zinb_with_var_internal(const Eigen::Ref<const Eigen::MatrixXd>& Xc,
                                           const Eigen::Ref<const Eigen::MatrixXd>& Xz,
                                           const Eigen::Ref<const Eigen::VectorXd>& y_vec,
                                           std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
                                           int maxit = 1000, double tol = 1e-8,
                                           std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
                                           std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
                                           std::string optimization_alg = "lbfgs",
                                           bool smart_cold_start = true,
                                           std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt) {
    LikelihoodFitResult fit = fast_zinb_internal(
        Xc, Xz, y_vec, warm_start_params, maxit, tol, fixed_idx, fixed_values,
        optimization_alg, smart_cold_start, warm_start_fisher_info);

    ZeroInflatedNegBin obj(y_vec, Xc, Xz);
    const int n_par = (int)Xc.cols() + (int)Xz.cols() + 1;
    FixedParamSpec fixed_spec = make_fixed_param_spec(n_par, fixed_idx, fixed_values);
    Eigen::MatrixXd hess = obj.hessian(fit.params);
    if (fit.reduced_model == "ZIP") {
        ZipLimitLikelihood zip(obj, n_par - 1);
        Eigen::MatrixXd zip_hess = zip.hessian(fit.params.head(n_par - 1));
        hess = Eigen::MatrixXd::Zero(n_par, n_par);
        hess.topLeftCorner(n_par - 1, n_par - 1) = zip_hess;
    }
    FixedParamSpec information_spec = negbin_information_spec(
        fixed_spec, n_par - 1, fit.dispersion_at_poisson_boundary);
    Eigen::MatrixXd H_free = subset_matrix(hess, information_spec.free_idx, information_spec.free_idx);
    Eigen::MatrixXd cov_free = H_free.inverse();
    Eigen::MatrixXd vcov = expand_free_covariance(n_par, information_spec, cov_free, true);

    return edi::ResultMap()
        .set("params", fit.params)
        .set("vcov", vcov)
        .set("converged", fit.converged)
        .set("neg_ll", fit.value)
        .set("fisher_information", hess)
        .set("num_iter", fit.niter)
            .set("hit_iteration_cap", fit.hit_iteration_cap)
            .set("gradient_norm", fit.gradient_norm)
            .set("min_eigenvalue_information", fit.min_eigenvalue_information)
            .set("dispersion_at_poisson_boundary", fit.dispersion_at_poisson_boundary)
            .set("reduced_model", fit.reduced_model);
}

#ifndef EDI_CORE_ONLY
//' @title Fast Zero-Inflated Negative Binomial Regression (C++)
//' @description High-performance zero-inflated negative binomial model fitting via L-BFGS.
//' @param X Numeric matrix of predictors for the count component (including intercept).
//' @param Xzi Numeric matrix of predictors for the zero-inflation component (including intercept).
//' @param y Numeric vector of non-negative integer count responses.
//' @param warm_start_params Optional starting values for all parameters.
//' @param maxit Maximum number of iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm (default "lbfgs").
//' @param smart_cold_start Logical. If TRUE, use a heuristic initial guess.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix.
//' @param estimate_only Logical. If TRUE, skip variance computation and return only coefficients.
//' @return A list containing coefficients and convergence status.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_zinb_cpp(const Eigen::Map<Eigen::MatrixXd>& X, const Eigen::Map<Eigen::MatrixXd>& Xzi, SEXP y,
                   Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
                   int maxit = 1000, double tol = 1e-8,
                   Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                   Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                   std::string optimization_alg = "lbfgs",
                   bool smart_cold_start = true,
                   Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                   bool estimate_only = false) {
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());

    LikelihoodFitResult fit = fast_zinb_internal(
        X, Xzi, y_vec,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg, smart_cold_start,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));

    ZeroInflatedNegBin obj(y_vec, X, Xzi);
    const int p_cond = X.cols();
    const int p_zi = Xzi.cols();
    if (estimate_only) {
        List out = edi::to_rcpp_list(edi::ResultMap()
            .set("params", fit.params)
            .set("converged", fit.converged)
            .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("dispersion_at_poisson_boundary", fit.dispersion_at_poisson_boundary)
        .set("reduced_model", fit.reduced_model));
        out["coefficients"] = List::create(
            Named("cond") = fit.params.head(p_cond),
            Named("zi") = fit.params.segment(p_cond, p_zi)
        );
        return out;
    }

    Eigen::MatrixXd hess = obj.hessian(fit.params);
    Eigen::VectorXd score = likelihood_score(obj, fit.params);
    if (fit.reduced_model == "ZIP") {
        ZipLimitLikelihood zip(obj, p_cond + p_zi);
        Eigen::MatrixXd zip_hess = zip.hessian(fit.params.head(p_cond + p_zi));
        hess = Eigen::MatrixXd::Zero(p_cond + p_zi + 1, p_cond + p_zi + 1);
        hess.topLeftCorner(p_cond + p_zi, p_cond + p_zi) = zip_hess;
        Eigen::VectorXd zip_grad;
        (void)zip(fit.params.head(p_cond + p_zi), zip_grad);
        score = -zip_grad;
    }
    // likelihood_score(obj, params) already negates the raw grad the L-BFGS objective fills
    // (gradient of neg_loglik) to return the true (+loglik) score -- do not negate again here.
    Rcpp::List out = make_uniform_likelihood_fit_result(fit.params, fit.value, fit.converged, score, hess, false);
    if (fit.dispersion_at_poisson_boundary) {
        FixedParamSpec fixed_spec = make_fixed_param_spec(
            p_cond + p_zi + 1,
            nullable_to_optional<Eigen::VectorXi>(fixed_idx),
            nullable_to_optional<Eigen::VectorXd>(fixed_values));
        FixedParamSpec information_spec = negbin_information_spec(
            fixed_spec, p_cond + p_zi, true);
        Eigen::MatrixXd information_free = subset_matrix(
            hess, information_spec.free_idx, information_spec.free_idx);
        out["vcov"] = expand_free_covariance(
            p_cond + p_zi + 1, information_spec,
            covariance_from_information(information_free), true);
        out["covariance_type"] = "observed_conditional_on_poisson_boundary";
    }
    out["dispersion_at_poisson_boundary"] = fit.dispersion_at_poisson_boundary;
    out["reduced_model"] = fit.reduced_model;
    out["coefficients"] = List::create(
        Named("cond") = fit.params.head(p_cond),
        Named("zi") = fit.params.segment(p_cond, p_zi)
    );
    return out;
}
#endif // EDI_CORE_ONLY
