#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
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

// Fast path: exact/right-censored responses only (dead == 1 exact, dead ==
// 0 right-censored). Restored from the pre-TODO-3 implementation (see
// interval_censored_survival_response.md TODO-28) -- fully vectorized via
// Eigen array expressions (SIMD-batched .exp()/.log()), no per-row scalar
// loop or branching. TODO-28 measured this is ~3-4x faster per call than
// WeibullAFTLikelihoodGeneral below on exact/right-censored-only data, and
// that gap is a real, unavoidable cost of general-censoring support (see
// that TODO's perf investigation), not a fixable inefficiency -- hence
// keeping both kernels rather than routing everything through one.
class WeibullAFTLikelihood {
private:
    const Eigen::Ref<const Eigen::VectorXd> m_y;
    const Eigen::Ref<const Eigen::VectorXd> m_dead;
    const Eigen::Ref<const Eigen::MatrixXd> m_X;
    const int m_n;
    const int m_p;
    const Eigen::VectorXd m_log_y;
    Eigen::VectorXd m_eta;
    Eigen::ArrayXd m_w;
    Eigen::ArrayXd m_exp_w;
    Eigen::VectorXd m_d_eta;
    Eigen::VectorXd m_beta_weights;
    Eigen::VectorXd m_cross_weights;

public:
    WeibullAFTLikelihood(const Eigen::Ref<const Eigen::VectorXd>& y,
                         const Eigen::Ref<const Eigen::VectorXd>& dead,
                         const Eigen::Ref<const Eigen::MatrixXd>& X) :
        m_y(y), m_dead(dead), m_X(X), m_n(y.size()), m_p(X.cols()),
        m_log_y(y.array().log().matrix()), m_eta(m_n), m_w(m_n),
        m_exp_w(m_n), m_d_eta(m_n), m_beta_weights(m_n),
        m_cross_weights(m_n) {}

    double operator()(const Eigen::VectorXd& params, Eigen::VectorXd& grad) {
        // params: [beta (p), log_sigma (1)]
        const auto beta = params.head(m_p);
        double log_sigma = params[m_p];
        double sigma = std::exp(log_sigma);

        m_eta.noalias() = m_X * beta;
        m_w = ((m_log_y - m_eta) / sigma).array().min(700.0);
        m_exp_w = m_w.exp();
        const auto dead = m_dead.array();
        const double loglik = (dead * (m_w - log_sigma - m_log_y.array()) - m_exp_w).sum();
        m_d_eta = ((m_exp_w - dead) / sigma).matrix();
        const double d_ll_d_log_sigma = (m_exp_w * m_w - dead * (m_w + 1.0)).sum();

        grad.setZero();

        grad.head(m_p).noalias() = -m_X.transpose() * m_d_eta;
        grad[m_p] = - d_ll_d_log_sigma;

        return -loglik;
    }

    Eigen::MatrixXd hessian(const Eigen::VectorXd& params) {
        int total_p = params.size();
        Eigen::MatrixXd H = Eigen::MatrixXd::Zero(total_p, total_p);
        const auto beta = params.head(m_p);
        double sigma = std::exp(params[m_p]);
        m_eta.noalias() = m_X * beta;
        m_w = ((m_log_y - m_eta) / sigma).array().min(700.0);
        m_exp_w = m_w.exp();
        m_beta_weights = (m_exp_w / (sigma * sigma)).matrix();
        m_cross_weights =
            ((m_exp_w * (m_w + 1.0) - m_dead.array()) / sigma).matrix();

        H.topLeftCorner(m_p, m_p).noalias() = weighted_crossprod(m_X, m_beta_weights);
        H.topRightCorner(m_p, 1).noalias() = m_X.transpose() * m_cross_weights;
        H(m_p, m_p) = (m_exp_w * (m_w.square() + m_w) - m_dead.array() * m_w).sum();
        H.bottomLeftCorner(1, m_p) = H.topRightCorner(m_p, 1).transpose();
        return H;
    }
};

// General path: left-/interval-/right-censored responses (see TODO-3 in
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

} // namespace

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
    FixedParamSpec fixed_spec = make_fixed_param_spec(p + 1, fixed_idx, fixed_values);
    WeibullAFTLikelihood fun(y, dead, X);

    Eigen::VectorXd params = Eigen::VectorXd::Zero(p + 1);
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
        if (params.size() != p + 1) throw std::invalid_argument("warm_start_params must have length equal to ncol(X) + 1");
    } else {
        WeibullStart legacy_start;
        legacy_start.beta = Eigen::VectorXd::Zero(p);
        legacy_start.log_sigma = 0.0;

        WeibullStart start = smart_cold_start ? weibull_aft_start_or_legacy(X, y, dead, legacy_start, fixed_spec) : legacy_start;
        params = weibull_start_to_params(start);
    }

    params = apply_fixed_values(params, fixed_spec);

    Eigen::MatrixXd info;
    const Eigen::MatrixXd* info_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info = *warm_start_fisher_info;
        info_ptr = &info;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(fun, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_ptr);

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
    Eigen::MatrixXd vcov = covariance_from_information(hess);
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
//' @param warm_start_params Optional starting values for coefficients.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess.
//' @param estimate_only Logical. If TRUE, do not compute variance-covariance.
//' @param maxit Maximum number of iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix.
//' @return A list containing coefficients, log_sigma, and convergence status.
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
    FixedParamSpec fixed_spec = make_fixed_param_spec(p + 1, fixed_idx, fixed_values);
    WeibullAFTLikelihoodGeneral fun(y, y_L, y_R, X);

    Eigen::VectorXd params = Eigen::VectorXd::Zero(p + 1);
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
        if (params.size() != p + 1) throw std::invalid_argument("warm_start_params must have length equal to ncol(X) + 1");
    } else {
        WeibullStart legacy_start;
        legacy_start.beta = Eigen::VectorXd::Zero(p);
        legacy_start.log_sigma = 0.0;

        Eigen::VectorXd y_eff, dead_eff;
        general_to_effective(y, y_L, y_R, y_eff, dead_eff);
        WeibullStart start = smart_cold_start ? weibull_aft_start_or_legacy(X, y_eff, dead_eff, legacy_start, fixed_spec) : legacy_start;
        params = weibull_start_to_params(start);
    }

    params = apply_fixed_values(params, fixed_spec);

    Eigen::MatrixXd info;
    const Eigen::MatrixXd* info_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info = *warm_start_fisher_info;
        info_ptr = &info;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(fun, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_ptr);

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
    Eigen::MatrixXd vcov = covariance_from_information(hess);
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

#ifndef EDI_CORE_ONLY
//' @title Compute Weibull Regression Score (General Censoring)
//' @description Score vector for the Weibull AFT log-likelihood extended to
//'   left-, right-, and interval-censored responses (see TODO-3 in
//'   interval_censored_survival_response.md). Exactly one of \code{y[i]} or
//'   (\code{y_L[i]}, \code{y_R[i]}) must be finite per subject: \code{NA} in
//'   the unused slot(s).
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
//' @param warm_start_params Optional starting values for coefficients.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess.
//' @param estimate_only Logical. If TRUE, do not compute variance-covariance.
//' @param maxit Maximum number of iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional indices of fixed parameters.
//' @param fixed_values Optional values for fixed parameters.
//' @param optimization_alg Optimization algorithm.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix.
//' @return A list containing coefficients, log_sigma, and convergence status.
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
    const int n       = i_mat.nrow();
    const int nsim    = i_mat.ncol();
    const int n_full  = y0.size();
    const int p_cov   = Xc.ncol();
    const int p       = 2 + p_cov;   // intercept + treatment + covariates
    const int n_params = p + 1;       // +1 for log_sigma

    const double* y0_ptr   = y0.begin();
    const int*    dead_ptr = dead.begin();
    const double* xc_ptr   = (p_cov > 0) ? Xc.begin() : nullptr;
    const int*    i_ptr    = i_mat.begin();
    const int*    w_ptr    = w_mat.begin();
    const double  mult     = (delta != 0.0) ? std::exp(delta) : 1.0;

    FixedParamSpec fspec = make_fixed_param_spec(n_params);

    std::vector<double> results(nsim, NA_REAL);
    double* res_ptr = results.data();

    const bool has_noise = noise_mat.isNotNull();
    NumericMatrix noise_m;
    const double* noise_ptr = nullptr;
    if (has_noise) {
        noise_m = NumericMatrix(noise_mat);
        noise_ptr = noise_m.begin();
    }

#ifdef _OPENMP
    if (num_cores > 1) omp_set_num_threads(num_cores);
#endif

#pragma omp parallel if(num_cores > 1)
    {
        Eigen::VectorXd y_b(n), dead_b(n), params0(n_params);
        Eigen::MatrixXd X_b(n, p);

#pragma omp for schedule(dynamic)
        for (int b = 0; b < nsim; ++b) {
            const int* ic = i_ptr + (size_t)b * n;
            const int* wc = w_ptr + (size_t)b * n;

            int n_t = 0, n_c = 0;
            for (int i = 0; i < n; ++i) {
                const int r  = ic[i] - 1;
                const int wt = (wc[i] == 1) ? 1 : 0;
                X_b(i, 0) = 1.0;
                X_b(i, 1) = static_cast<double>(wt);
                for (int j = 0; j < p_cov; ++j)
                    X_b(i, j + 2) = xc_ptr[(size_t)j * n_full + r];
                double yv = y0_ptr[r];
                if (has_noise) yv += noise_ptr[(size_t)b * n + i];
                y_b(i)    = (wt && mult != 1.0) ? yv * mult : yv;
                dead_b(i) = static_cast<double>(dead_ptr[r]);
                n_t += wt;
                n_c += (1 - wt);
            }
            if (n_t < 2 || n_c < 2) continue;

            params0.setZero();
            // Bootstrap replicates are always exact/right-censored by
            // construction (never interval/left-censored) -- route through
            // the fast kernel per TODO-28's routing principle, no
            // y_exact/y_L/y_R conversion needed.
            WeibullAFTLikelihood fun(y_b, dead_b, X_b);
            LikelihoodFitResult fit = optimize_fixed_likelihood(
                fun, params0, fspec, 100, 1e-8, "lbfgs", "", 0, nullptr);
            if (fit.converged && fit.params.size() > 1 && std::isfinite(fit.params[1]))
                res_ptr[b] = fit.params[1];
        }
    }
    return wrap(results);
}

#endif // EDI_CORE_ONLY
