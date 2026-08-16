#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <Rcpp.h>
#include <RcppEigen.h>
#endif
#include "ordinal_fixed_link_helpers.h"
#include <algorithm>
#include <vector>
#include <optional>
#include <string>
#include <limits>
#include <stdexcept>

// [[Rcpp::depends(RcppEigen)]]

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

inline double plogis_stable_cpp(double x) {
    if (x >= 0.0) {
        const double z = std::exp(-x);
        return 1.0 / (1.0 + z);
    }
    const double z = std::exp(x);
    return z / (1.0 + z);
}

class OrdinalRegression {
private:
    edi_ordinal::FixedOrdinalRegression m_model;

public:
    OrdinalRegression(const Eigen::Ref<const Eigen::MatrixXd>& X, const Eigen::Ref<const Eigen::VectorXd>& y, const Eigen::Ref<const Eigen::VectorXd>& weights = Eigen::VectorXd()) :
        m_model(X, y, edi_ordinal::Link::Logit, -1.0, weights) {}

    static std::vector<double> init_levels(const Eigen::Ref<const Eigen::VectorXd>& y) {
        return edi_ordinal::init_levels(y);
    }

    double neg_log_likelihood(const Eigen::Ref<const Eigen::VectorXd>& params) const {
        return m_model.neg_log_likelihood(params);
    }

    double operator()(const Eigen::Ref<const Eigen::VectorXd>& params, Eigen::Ref<Eigen::VectorXd> grad) const {
        return m_model(params, grad);
    }

    MatrixXd hessian(const Eigen::Ref<const Eigen::VectorXd>& params) const {
        return m_model.hessian(params);
    }

    MatrixXd expected_hessian(const Eigen::Ref<const Eigen::VectorXd>& params) const {
        return m_model.expected_hessian(params);
    }
};

} // namespace

#ifndef EDI_CORE_ONLY
//' Proportional-Odds Ordinal Regression Score, Standalone (C++)
//'
//' Computes the (analytic) score vector (gradient of the log-likelihood) of the
//' logit-link cumulative (proportional-odds) ordinal regression model documented
//' in full at \code{\link{fast_ordinal_regression_cpp}}, at arbitrary
//' caller-supplied \code{params} (not necessarily the MLE). Exported standalone
//' — independent of any optimizer run — for direct numerical diagnostics (e.g.
//' verifying convergence) at a specific parameter value.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of
//'   distinct values matters, not their numeric coding.
//' @param params A numeric vector \eqn{[\alpha, \beta]}: the category thresholds
//'   followed by the regression coefficients, at which to evaluate the score.
//' @return The score vector (gradient of the log-likelihood) at \code{params}.
//' @seealso \code{\link{get_ordinal_regression_hessian_cpp}} for the
//'   corresponding Hessian at the same point; \code{\link{fast_ordinal_regression_cpp}}
//'   for the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_ordinal_regression_score_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, const Rcpp::NumericVector& params) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

    OrdinalRegression model(map_X, map_y);
    Eigen::VectorXd grad(map_params.size());
    model(map_params, grad);
    return -grad;
}

//' Proportional-Odds Ordinal Regression Hessian, Standalone (C++)
//'
//' Computes the (analytic) Hessian matrix of the log-likelihood of the logit-link
//' cumulative (proportional-odds) ordinal regression model documented in full at
//' \code{\link{fast_ordinal_regression_cpp}}, at arbitrary caller-supplied
//' \code{params} (not necessarily the MLE). Exported standalone — independent of
//' any optimizer run — for direct numerical diagnostics at a specific parameter
//' value.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of
//'   distinct values matters, not their numeric coding.
//' @param params A numeric vector \eqn{[\alpha, \beta]}: the category thresholds
//'   followed by the regression coefficients, at which to evaluate the Hessian.
//' @return The Hessian matrix of the log-likelihood at \code{params}.
//' @seealso \code{\link{get_ordinal_regression_score_cpp}} for the corresponding
//'   gradient at the same point; \code{\link{fast_ordinal_regression_cpp}} for
//'   the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_ordinal_regression_hessian_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, const Rcpp::NumericVector& params) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

    OrdinalRegression model(map_X, map_y);
    return -model.hessian(map_params);
}
#endif // EDI_CORE_ONLY

// Portable core. Unifies fast_ordinal_regression_cpp (unweighted fit) and
// fast_ordinal_regression_weighted_cpp (weighted fit) below via an optional
// weights vector, and folds in fast_ordinal_regression_with_var_cpp's
// full-inverse vcov (via FullPivLU) so a Python caller gets everything from
// one call, matching the pattern used across the other ordinal link files.
edi::ResultMap fast_ordinal_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> weights = std::nullopt,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    bool smart_cold_start = true,
    int maxit = 100,
    double tol = 1e-6,
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false
) {
    if (weights.has_value() && weights->size() != X.rows())
        throw std::invalid_argument("weights must have length equal to nrow(X)");

    OrdinalRegression model = weights.has_value()
        ? OrdinalRegression(X, y, *weights)
        : OrdinalRegression(X, y);
    int p = (int)X.cols();
    int K = (int)OrdinalRegression::init_levels(y).size();
    int n_alpha = K - 1;
    int n_params = n_alpha + p;

    VectorXd params(n_params);
    FixedParamSpec fixed_spec = make_fixed_param_spec(n_params, fixed_idx, fixed_values);
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
        if (params.size() != n_params) throw std::invalid_argument("warm_start_params must have length equal to the number of model parameters");
    } else {
        OrdinalStart legacy_start;
        legacy_start.alpha = VectorXd(n_alpha);
        for (int k = 0; k < n_alpha; ++k) {
            legacy_start.alpha[k] = -1.0 + 2.0 * (k + 1) / K;
        }
        legacy_start.beta = VectorXd::Zero(p);

        if (smart_cold_start) {
            // Use OLS on rank-transformed y
            Eigen::VectorXd y_rank = (y.array() - 1.0) / static_cast<double>(K - 1);
            Eigen::VectorXd beta;
            if (edi_opt::robust_ols_solve(X, y_rank, beta)) {
                legacy_start.beta = beta;
            }
        }
        params = ordinal_start_to_params(legacy_start);
    }
    params = apply_fixed_values(params, fixed_spec);

    Eigen::MatrixXd H_start;
    const Eigen::MatrixXd* h_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        H_start = *warm_start_fisher_info;
        h_ptr = &H_start;
    } else if (smart_cold_start) {
        H_start = model.hessian(params);
        h_ptr = &H_start;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(model, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, h_ptr);
    params = fit.params;

    if (estimate_only) {
        return edi::ResultMap()
            .set("b", params.tail(p))
            .set("alpha", params.head(n_alpha))
            .set("n_params", n_params)
            .set("params", params)
            .set("converged", fit.converged)
            .set("iterations", fit.niter);
    }

    MatrixXd H = model.hessian(params);

    edi::ResultMap rm = edi::ResultMap()
        .set("b", params.tail(p))
        .set("alpha", params.head(n_alpha))
        .set("n_params", n_params)
        .set("params", params)
        .set("neg_loglik", fit.value)
        .set("converged", fit.converged)
        .set("iterations", fit.niter)
        .set("observed_information", H)
        .set("fisher_information", H)
        .set("information", H)
        .set("information_type", std::string("observed"));

    MatrixXd H_free = subset_matrix(H, fixed_spec.free_idx, fixed_spec.free_idx);
    FullPivLU<MatrixXd> lu(H_free);
    if (!lu.isInvertible()) {
        rm.set("ssq_b_j", std::numeric_limits<double>::quiet_NaN());
        rm.set("vcov", std::monostate{});
        return rm;
    }

    MatrixXd vcov_free = lu.inverse();
    MatrixXd vcov_full = expand_free_covariance(n_params, fixed_spec, vcov_free, true);
    double ssq_b_j = (p >= 1) ? vcov_full(n_alpha, n_alpha) : std::numeric_limits<double>::quiet_NaN();

    rm.set("vcov", vcov_full);
    rm.set("ssq_b_j", ssq_b_j);
    return rm;
}

#ifndef EDI_CORE_ONLY
// Simple solver using Newton-Raphson as we have a small number of parameters (usually)
//' Fast Cumulative Ordinal Regression with a Logit Link, i.e. Proportional-Odds
//' Regression (C++)
//'
//' Fits the classical proportional-odds ordinal regression model (a cumulative-link
//' model with the \strong{logit} link) via direct maximum likelihood, jointly
//' optimizing the category thresholds and regression coefficients. \code{y}'s
//' distinct values (in sorted order, whatever their original coding) are treated as
//' \eqn{K} ordered categories; for observation \eqn{i} in category \eqn{k}
//' (\eqn{k = 0, \ldots, K-1}),
//' \deqn{\mathrm{logit}\,\Pr(Y_i \le k \mid x_i) = \alpha_k - x_i^\top \beta,}
//' with \eqn{\alpha_0 < \alpha_1 < \cdots < \alpha_{K-2}} the (increasing) category
//' thresholds and \eqn{\beta} the regression coefficients on \code{X} (no separate
//' intercept column is needed — the thresholds serve that role); the category
//' probability is the corresponding CDF difference, each clamped below at
//' \eqn{10^{-12}} before taking logs for numerical safety. The "proportional odds"
//' name reflects that \eqn{\beta} does not depend on \eqn{k}: the odds ratio
//' \eqn{\exp(-\beta_j)} for a unit increase in covariate \eqn{j} is the same across
//' every cumulative cutpoint. If \code{y} has fewer than 2 distinct levels, fitting
//' still proceeds with \code{K = 1}, \code{n_alpha = 0} (degenerate: no thresholds
//' to estimate); unlike the cauchit/probit/cloglog variants in this package, this
//' function does not special-case that as an early return.
//'
//' @section Fixed parameters, warm starts, and optimization:
//' \code{fixed_idx} (1-indexed into the combined \eqn{[\alpha, \beta]} parameter
//' vector, thresholds first) and \code{fixed_values} optionally hold a subset of
//' parameters at caller-supplied constant values rather than estimating them.
//' \code{warm_start_params} supplies starting values for \eqn{[\alpha, \beta]}
//' directly (skipping \code{smart_cold_start}); otherwise thresholds always start
//' evenly spaced on \eqn{(-1, 1)} at \eqn{-1 + 2(k+1)/K}, and \eqn{\beta} starts at
//' either zero, or (when \code{smart_cold_start = TRUE}, the default) an OLS fit of
//' the rank-rescaled response \eqn{(y - 1)/(K - 1)} on \code{X} — falling back
//' silently to zero if that OLS solve is not well-posed. When
//' \code{smart_cold_start = TRUE} and no \code{warm_start_fisher_info} is supplied,
//' the Hessian at the starting values is additionally used to seed the optimizer's
//' first-iteration curvature estimate. Optimization runs via \code{optimization_alg}
//' (default \code{"lbfgs"}) for up to \code{maxit} iterations or until the
//' parameter/gradient change falls below \code{tol}.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see Details).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//' @param estimate_only If \code{TRUE}, skip the post-fit Hessian/variance computation and
//'   return only point estimates (faster). If \code{FALSE} (the default), also compute and
//'   return the observed information matrix and (if the resulting free-parameter information
//'   submatrix is invertible via \code{Eigen::FullPivLU}) the full variance-covariance matrix.
//'
//' @return A list with components \code{b} (the \eqn{\beta} coefficients), \code{alpha}
//'   (the \eqn{K-1} category thresholds), \code{params} (the concatenated
//'   \eqn{[\alpha, \beta]} vector), \code{n_params}, \code{converged}, and \code{iterations};
//'   when \code{estimate_only = FALSE} (the default), additionally \code{neg_loglik},
//'   \code{observed_information}/\code{fisher_information}/\code{information} (all the same
//'   observed-information matrix), \code{information_type} (always \code{"observed"}),
//'   \code{ssq_b_j} (the variance of \code{b[1]}, i.e. the coefficient on \code{X}'s first
//'   column — conventionally the treatment effect, since \code{X} carries no separate
//'   intercept column here), and \code{vcov} (the full parameter covariance matrix) — the
//'   latter two are \code{NA}/omitted (\code{vcov} becomes \code{NULL}) if the free-parameter
//'   information matrix is not invertible.
//' @seealso \code{\link{fast_ordinal_regression_weighted_cpp}} for the observation-weighted
//'   variant; \code{\link{fast_ordinal_regression_with_var_cpp}}, which additionally guards
//'   the non-invertible case with explicit \code{NA} placeholders.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_regression_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, Nullable<NumericVector> warm_start_params = R_NilValue, bool smart_cold_start = true, int maxit = 100, double tol = 1e-6,
                                  Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                  Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                  std::string optimization_alg = "lbfgs",
                                  Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                  bool estimate_only = false) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    edi::ResultMap res = fast_ordinal_regression_internal(
        map_X, map_y, std::nullopt,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);
    return edi::to_rcpp_list(res);
}

//' Fast Cumulative Ordinal Regression with a Logit Link, Weighted (C++)
//'
//' As \code{\link{fast_ordinal_regression_cpp}} (see that page for the full
//' proportional-odds model), but each observation's log-likelihood contribution is
//' multiplied by a nonnegative \code{weights[i]} (negative weights are clamped to
//' zero internally by the underlying weighted log-likelihood). Always fits with
//' \code{estimate_only = FALSE} (equivalent to that function's default), so the
//' observed information and, when invertible, the full variance-covariance matrix
//' are always computed.
//'
//' @inheritSection fast_ordinal_regression_cpp Fixed parameters, warm starts, and optimization
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param weights A numeric vector of observation weights, length \code{nrow(X)}
//'   (negative entries are treated as zero).
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//'
//' @return A list with components \code{b}, \code{alpha}, \code{params}, \code{n_params},
//'   \code{converged}, \code{iterations}, \code{neg_loglik},
//'   \code{observed_information}/\code{fisher_information}/\code{information} (all the same
//'   observed-information matrix), \code{information_type} (\code{"observed"}),
//'   \code{ssq_b_j} (the variance of \code{b[1]}), and \code{vcov} — the latter two are
//'   \code{NA}/omitted if the free-parameter information matrix is not invertible.
//' @seealso \code{\link{fast_ordinal_regression_cpp}} for the unweighted variant and the
//'   full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_regression_weighted_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y, const Rcpp::NumericVector& weights,
                                          Nullable<NumericVector> warm_start_params = R_NilValue, bool smart_cold_start = true, int maxit = 100, double tol = 1e-6,
                                          Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                          Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                          std::string optimization_alg = "lbfgs",
                                          Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_weights(weights.begin(), weights.size());

    if (map_weights.size() != map_X.rows()) {
        stop("weights must have length equal to nrow(X)");
    }

    edi::ResultMap res = fast_ordinal_regression_internal(
        map_X, map_y, Eigen::VectorXd(map_weights),
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        false);
    return edi::to_rcpp_list(res);
}

//' Fast Cumulative Ordinal Regression with a Logit Link, with Variance (C++)
//'
//' Identical to \code{\link{fast_ordinal_regression_cpp}} (see that page for the full
//' proportional-odds model) called with \code{estimate_only = FALSE} — this is simply
//' a convenience export that hardcodes that default rather than exposing the flag, so
//' the observed information and, when invertible, the full variance-covariance matrix
//' are always computed. Unlike the cauchit/probit/cloglog families' \verb{_with_var}
//' variants, this function does \strong{not} add any extra degenerate-case guarding
//' beyond what \code{\link{fast_ordinal_regression_cpp}} already does.
//'
//' @inheritSection fast_ordinal_regression_cpp Fixed parameters, warm starts, and optimization
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//'
//' @return A list with components \code{b}, \code{alpha}, \code{params}, \code{n_params},
//'   \code{converged}, \code{iterations}, \code{neg_loglik},
//'   \code{observed_information}/\code{fisher_information}/\code{information} (all the same
//'   observed-information matrix), \code{information_type} (\code{"observed"}),
//'   \code{ssq_b_j} (the variance of \code{b[1]}, i.e. the coefficient on \code{X}'s first
//'   column — conventionally the treatment effect), and \code{vcov} — the latter two are
//'   \code{NA}/omitted if the free-parameter information matrix is not invertible.
//' @seealso \code{\link{fast_ordinal_regression_cpp}} for the estimate-only-capable variant
//'   and the full model documentation; \code{\link{fast_ordinal_regression_weighted_cpp}}
//'   for the observation-weighted variant.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_regression_with_var_cpp(const Rcpp::NumericMatrix& X, const Rcpp::NumericVector& y,
                                           Nullable<NumericVector> warm_start_params = R_NilValue,
                                           bool smart_cold_start = true,
                                           int maxit = 100, double tol = 1e-6,
                                           Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
                                           Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
                                           std::string optimization_alg = "lbfgs",
                                           Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    edi::ResultMap res = fast_ordinal_regression_internal(
        map_X, map_y, std::nullopt,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, maxit, tol,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        false);
    return edi::to_rcpp_list(res);
}

//' Fast G-Computation (Standardization) Point Estimate and Model-Based Inference
//' for a Proportional-Odds Ordinal Model (C++)
//'
//' Computes the same standardized (G-computation) marginal difference in
//' \strong{expected ordinal category score} as
//' \code{\link{gcomp_ordinal_proportional_odds_post_fit_cpp}} — under a fitted
//' proportional-odds (cumulative logit) model \eqn{\mathrm{logit}\,\Pr(Y_i \le k
//' \mid x_i) = \alpha_k - x_i^\top\beta}, \eqn{k = 1, \ldots, K-1} — but
//' additionally supplies \strong{model-based} inferential quantities that the
//' other function omits. The fitted linear predictor for each subject is
//' recomputed with the treatment column (\code{j_treat}) forced to 1
//' (\eqn{\eta_{1,i}}) and to 0 (\eqn{\eta_{0,i}}), the standardized expected
//' scores \code{mean1}, \code{mean0}, and their difference \code{md} are formed
//' exactly as in \code{\link{gcomp_ordinal_proportional_odds_post_fit_cpp}}, and
//' then:
//' \itemize{
//'   \item An \code{\link[=OrdinalRegression]{OrdinalRegression}} log-likelihood
//'     Hessian is evaluated at \eqn{[\hat\alpha, \hat\beta]} and inverted (with a
//'     symmetrization step and a finiteness check) to give the
//'     \strong{model-based} (non-sandwich) variance-covariance matrix of the full
//'     parameter vector; \code{vcov}/\code{std_err}/\code{z_vals} report the
//'     \eqn{\hat\beta}-block of this covariance.
//'   \item The delta-method standard error of \code{md}, \code{se_md}, is obtained
//'     by numerically differentiating \code{md} (central differences, step
//'     \eqn{10^{-5}}) with respect to every element of \eqn{[\alpha,\beta]} to get
//'     a gradient \eqn{g}, then computing \eqn{\sqrt{g^\top V g}} where \eqn{V} is
//'     the full parameter covariance above; \code{NA} if any perturbed \code{md}
//'     evaluation is non-finite (e.g. a perturbed \eqn{\alpha} violates
//'     monotonicity) or the resulting variance is negative/non-finite.
//' }
//' Unlike the sandwich-based post-fit helpers elsewhere in this package (e.g.
//' \code{\link{gcomp_logistic_post_fit_cpp}}), the covariance here comes purely
//' from the model's observed information and does not attempt to be robust to
//' misspecification.
//'
//' @param X_fit Numeric matrix of predictors used to fit the model.
//' @param y Numeric vector of the ordinal responses used to fit the model
//'   (needed to reconstruct the \code{OrdinalRegression} likelihood for the
//'   Hessian; only categorization, not numeric coding, matters).
//' @param coef_hat Numeric vector of fitted proportional-odds regression
//'   coefficients \eqn{\hat\beta}, same length and column order as \code{X_fit}.
//' @param alpha_hat Numeric vector of the \eqn{K-1} fitted, increasing category
//'   thresholds \eqn{\hat\alpha_1, \ldots, \hat\alpha_{K-1}}.
//' @param j_treat 1-based column index of the treatment indicator in \code{X_fit}.
//' @return A list with elements \code{vcov} (model-based covariance of
//'   \eqn{\hat\beta}), \code{std_err}, \code{z_vals} (both length \code{p}, one
//'   per column of \code{X_fit}), \code{mean1}, \code{mean0}, \code{md}
//'   (\code{mean1 - mean0}), and \code{se_md} (delta-method SE of \code{md}).
//'   Errors (via \code{stop()}) if \code{j_treat} is out of bounds, the
//'   dimensions of \code{y}/\code{coef_hat} are inconsistent with \code{X_fit},
//'   the Hessian is not invertible, or the resulting covariance has any
//'   non-finite entry.
//' @seealso \code{\link{gcomp_ordinal_proportional_odds_post_fit_cpp}} for the
//'   point-estimate-only variant (no \code{y}, no Hessian, no inference) that
//'   this function's point estimates match; \code{\link{fast_ordinal_regression_cpp}}
//'   for the fitting routine that produces \code{coef_hat}/\code{alpha_hat}.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List ordinal_gcomp_post_fit_cpp(const Rcpp::NumericMatrix& X_fit,
                                const Rcpp::NumericVector& y,
                                const Rcpp::NumericVector& coef_hat,
                                const Rcpp::NumericVector& alpha_hat,
                                int j_treat) {
    Eigen::Map<const Eigen::MatrixXd> map_X_fit(X_fit.begin(), X_fit.rows(), X_fit.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXd> map_coef_hat(coef_hat.begin(), coef_hat.size());
    Eigen::Map<const Eigen::VectorXd> map_alpha_hat(alpha_hat.begin(), alpha_hat.size());

    const int n = map_X_fit.rows();
    const int p = map_X_fit.cols();
    const int n_alpha = map_alpha_hat.size();
    const int j_treat0 = j_treat - 1;

    if (j_treat0 < 0 || j_treat0 >= p) {
        stop("treatment column index is out of bounds");
    }
    if (map_y.size() != n || map_coef_hat.size() != p) {
        stop("dimension mismatch in ordinal_gcomp_post_fit_cpp");
    }

    VectorXd params(n_alpha + p);
    params.head(n_alpha) = map_alpha_hat;
    params.tail(p) = map_coef_hat;

    OrdinalRegression model(map_X_fit, map_y);
    MatrixXd H = model.hessian(params);
    FullPivLU<MatrixXd> lu(H);
    if (!lu.isInvertible()) {
        stop("failed to invert ordinal Hessian");
    }
    MatrixXd vcov_full = lu.inverse();
    vcov_full = 0.5 * (vcov_full + vcov_full.transpose());

    for (int j = 0; j < vcov_full.rows(); ++j) {
        for (int k = 0; k < vcov_full.cols(); ++k) {
            if (!R_finite(vcov_full(j, k))) {
                stop("non-finite ordinal covariance");
            }
        }
    }

    MatrixXd X1 = map_X_fit;
    MatrixXd X0 = map_X_fit;
    X1.col(j_treat0).setOnes();
    X0.col(j_treat0).setZero();
    VectorXd eta1 = X1 * map_coef_hat;
    VectorXd eta0 = X0 * map_coef_hat;

    auto compute_mean = [&](const VectorXd& eta_vec) {
        double total_mean = 0.0;
        for (int i = 0; i < n; ++i) {
            double mean_i = 1.0;
            for (int k = 0; k < n_alpha; ++k) {
                mean_i += plogis_stable_cpp(eta_vec[i] - map_alpha_hat[k]);
            }
            total_mean += mean_i;
        }
        return total_mean / static_cast<double>(n);
    };

    VectorXd eta1_scratch(n);
    VectorXd eta0_scratch(n);
    auto compute_md_from_alpha_eta = [&](const auto& alpha,
                                         const VectorXd& eta1_values,
                                         const VectorXd& eta0_values) {
        for (int k = 1; k < n_alpha; ++k) {
            if (alpha[k] <= alpha[k - 1]) return NA_REAL;
        }
        double mean1_loc = 0.0;
        double mean0_loc = 0.0;
        for (int i = 0; i < n; ++i) {
            double m1 = 1.0;
            double m0 = 1.0;
            for (int k = 0; k < n_alpha; ++k) {
                m1 += plogis_stable_cpp(eta1_values[i] - alpha[k]);
                m0 += plogis_stable_cpp(eta0_values[i] - alpha[k]);
            }
            mean1_loc += m1;
            mean0_loc += m0;
        }
        return (mean1_loc - mean0_loc) / static_cast<double>(n);
    };

    const double mean1 = compute_mean(eta1);
    const double mean0 = compute_mean(eta0);
    const double md = mean1 - mean0;

    const double h_step = 1e-5;
    VectorXd grad_md(params.size());
    VectorXd p_plus = params;
    VectorXd p_minus = params;
    for (int j = 0; j < params.size(); ++j) {
        p_plus[j] = params[j] + h_step;
        p_minus[j] = params[j] - h_step;
        double f_plus;
        double f_minus;
        if (j < n_alpha) {
            f_plus = compute_md_from_alpha_eta(p_plus.head(n_alpha), eta1, eta0);
            f_minus = compute_md_from_alpha_eta(p_minus.head(n_alpha), eta1, eta0);
        } else {
            const int beta_j = j - n_alpha;
            eta1_scratch.noalias() = eta1 + h_step * X1.col(beta_j);
            eta0_scratch.noalias() = eta0 + h_step * X0.col(beta_j);
            f_plus = compute_md_from_alpha_eta(params.head(n_alpha), eta1_scratch, eta0_scratch);
            eta1_scratch.noalias() = eta1 - h_step * X1.col(beta_j);
            eta0_scratch.noalias() = eta0 - h_step * X0.col(beta_j);
            f_minus = compute_md_from_alpha_eta(params.head(n_alpha), eta1_scratch, eta0_scratch);
        }
        if (!R_finite(f_plus) || !R_finite(f_minus)) {
            grad_md[j] = NA_REAL;
        } else {
            grad_md[j] = (f_plus - f_minus) / (2.0 * h_step);
        }
        p_plus[j] = params[j];
        p_minus[j] = params[j];
    }

    double se_md = NA_REAL;
    bool grad_is_finite = true;
    for (int j = 0; j < grad_md.size(); ++j) {
        if (!R_finite(grad_md[j])) {
            grad_is_finite = false;
            break;
        }
    }
    if (grad_is_finite) {
        const double var_md = (grad_md.transpose() * vcov_full * grad_md)(0, 0);
        if (R_finite(var_md) && var_md >= 0.0) {
            se_md = std::sqrt(var_md);
        }
    }

    MatrixXd vcov_beta = vcov_full.block(n_alpha, n_alpha, p, p);
    VectorXd std_err(p);
    VectorXd z_vals(p);
    for (int j = 0; j < p; ++j) {
        const double var_j = vcov_beta(j, j);
        std_err[j] = (R_finite(var_j) && var_j >= 0.0) ? std::sqrt(var_j) : NA_REAL;
        z_vals[j] = (R_finite(std_err[j]) && std_err[j] > 0.0) ? map_coef_hat[j] / std_err[j] : NA_REAL;
    }

    return edi::to_rcpp_list(edi::ResultMap()
        .set("vcov", vcov_beta)
        .set("std_err", std_err)
        .set("z_vals", z_vals)
        .set("mean1", mean1)
        .set("mean0", mean0)
        .set("md", md)
        .set("se_md", se_md));
}

//' Expand Ordinal Data into Stacked Binary Comparisons for Continuation-Ratio
//' Regression (C++ Backend)
//'
//' Reshapes an ordinal response \code{y} (levels \eqn{1, \dots, K}) into the stacked
//' binary-outcome, per-cut-stratified form required to fit a (forward) continuation-
//' ratio logit model as a single conditional (stratified) logistic regression —
//' the discrete-time-hazard analog for ordinal data — so the package's existing
//' binary/conditional-logit fitting backends can be reused unchanged rather than
//' needing a bespoke ordinal solver. This is the continuation-ratio counterpart of
//' \code{expand_adjacent_category_data_cpp()}; the two share the same stacking and
//' combined-stratum trick but differ in which rows each subject contributes (see
//' Details).
//'
//' @details
//' \strong{Model.} The continuation-ratio model treats reaching each successive
//' category as a sequence of conditional "continue past this cut" events, analogous
//' to a discrete-time survival/hazard model: for cut \eqn{j = 1, \dots, K-1}, among
//' subjects who have reached at least category \eqn{j} (\eqn{Y \ge j}),
//' \deqn{\log\frac{\Pr(Y = j \mid Y \ge j)}{\Pr(Y > j \mid Y \ge j)} = \alpha_j + \beta^\top x,}
//' i.e. the log-odds of "stopping" (being observed) exactly at category \eqn{j}
//' versus "continuing" past it, given the subject has reached at least \eqn{j}, with
//' a cut-specific intercept \eqn{\alpha_j} and covariate effects \eqn{\beta}
//' constrained equal across cuts (the proportional continuation-ratio assumption).
//' Unlike the adjacent-category model (which only compares the two categories
//' immediately flanking a cut), every subject contributes to every cut up to and
//' including the one at which they are observed to stop.
//'
//' \strong{Expansion mechanics.} For each subject \eqn{i} with observed category
//' \code{y[i]}, a stacked row is emitted for every cut
//' \eqn{j = 1, \dots, \min(\code{y[i]}, K-1)}: the stacked binary outcome is \code{1}
//' ("stopped here") if \code{y[i] == j}, and \code{0} ("continued past") for every
//' earlier cut the subject passed through. A subject observed at the top category
//' (\code{y[i] == K}) contributes a \code{0} at every one of the \code{K - 1} cuts
//' (having "survived" all of them without stopping); a subject observed at category
//' \code{j <= K - 1} contributes \code{0}s for cuts \code{1:(j-1)} and a single
//' \code{1} at cut \code{j}, then no further rows (later cuts are irrelevant once a
//' subject has already stopped). As in \code{expand_adjacent_category_data_cpp()},
//' the stacked stratum ID is \code{strata[i] + (j - 1) * num_strata} (with
//' \code{num_strata = max(strata)}): fitting a conditional logistic regression
//' stratified on this combined ID and pooling all stacked rows estimates a single
//' shared treatment coefficient \eqn{\beta} across all cuts, while each (original
//' stratum, cut) combination absorbs its own nuisance intercept via strata
//' conditioning.
//'
//' \strong{Input conventions.} \code{y} must take integer values in \code{1:K};
//' \code{w} is passed through unchanged into each stacked row for that subject
//' (typically the treatment indicator/covariate to estimate a coefficient for);
//' \code{strata} must be positive integers, with \code{max(strata)} used as the
//' per-cut stratum-ID offset. No input validation is performed at this layer.
//'
//' @param y Integer vector of length \eqn{n}: each subject's ordinal category label,
//'   in \code{1:K}.
//' @param w Integer vector of length \eqn{n}: a covariate (typically treatment
//'   assignment) carried through unchanged into each stacked row for that subject.
//' @param strata Integer vector of length \eqn{n}: positive-integer stratum/block
//'   labels; \code{max(strata)} is used as the per-cut stratum-ID offset (see
//'   Details).
//' @param K Integer; the number of ordinal categories (so there are \code{K - 1}
//'   continuation-ratio cuts).
//' @return A list with components \code{y} (stacked 0/1 "stopped here" outcome),
//'   \code{w} (stacked covariate, passed through unchanged), and \code{strata}
//'   (stacked combined stratum-by-cut ID); all three are integer vectors of the
//'   same, generally-longer-than-\eqn{n} length (each subject contributes between 1
//'   and \code{K - 1} stacked rows, depending on their observed category).
//' @seealso \code{expand_adjacent_category_data_cpp()} for the analogous expansion
//'   used by adjacent-category ordinal models.
//'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal regression} for
//'   orientation; analogous Python API:
//'   \href{https://www.statsmodels.org/stable/discretemod.html}{statsmodels discrete
//'   models} (no direct continuation-ratio equivalent; the closest analog is fitting
//'   the expanded data as a conditional/grouped logit, or discrete-time survival
//'   packages).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List expand_continuation_ratio_data_cpp(const Rcpp::IntegerVector& y, const Rcpp::IntegerVector& w, const Rcpp::IntegerVector& strata, int K) {
    Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXi> map_w(w.begin(), w.size());
    Eigen::Map<const Eigen::VectorXi> map_strata(strata.begin(), strata.size());

    int n = map_y.size();
    int n_alpha = K - 1;
    int num_strata = map_strata.maxCoeff();
    
    std::vector<int> y_stack;
    std::vector<int> w_stack;
    std::vector<int> strata_stack;
    
    for (int i = 0; i < n; ++i) {
        int yi = map_y[i];
        int wi = map_w[i];
        int si = map_strata[i];
        
        for (int j = 1; j <= std::min(yi, n_alpha); ++j) {
            y_stack.push_back((yi == j) ? 1 : 0);
            w_stack.push_back(wi);
            strata_stack.push_back(si + (j - 1) * num_strata);
        }
    }
    
    return List::create(
        Named("y") = wrap(y_stack),
        Named("w") = wrap(w_stack),
        Named("strata") = wrap(strata_stack)
    );
}

//' Expand Ordinal Data into Stacked Binary Comparisons for Adjacent-Category Logit
//' Regression (C++ Backend)
//'
//' Reshapes an ordinal response \code{y} (levels \eqn{1, \dots, K}) into the stacked
//' binary-outcome, per-cut-stratified form required to fit an adjacent-category logit
//' model as a single conditional (stratified) logistic regression, so the package's
//' existing binary/conditional-logit fitting backends can be reused unchanged for
//' ordinal adjacent-category models rather than needing a bespoke ordinal solver.
//'
//' @details
//' \strong{Model.} The adjacent-category logit model compares each pair of
//' consecutive categories \eqn{j} and \eqn{j+1} (\eqn{j = 1, \dots, K-1}) via
//' \deqn{\log\frac{\Pr(Y = j+1 \mid Y \in \{j, j+1\})}{\Pr(Y = j \mid Y \in \{j, j+1\})} = \alpha_j + \beta^\top x,}
//' i.e. a logistic model for "category \eqn{j+1} vs. category \eqn{j}" fit using only
//' the subjects actually observed in one of those two categories, with a
//' cut-specific intercept \eqn{\alpha_j} and covariate effects \eqn{\beta} constrained
//' equal across all \eqn{K-1} cuts (the proportional/parallel adjacent-category
//' assumption). This differs from the cumulative-logit (proportional-odds) model,
//' which instead compares \eqn{Y \le j} vs. \eqn{Y > j} using \emph{every} subject at
//' every cut.
//'
//' \strong{Expansion mechanics.} For each subject \eqn{i} and each cut
//' \eqn{j = 1, \dots, K-1} (\code{n_alpha = K - 1}), a stacked row is emitted
//' \strong{only if} \code{y[i]} equals \eqn{j} or \eqn{j+1}; subjects at any other
//' level contribute nothing to that cut's comparison (so each subject contributes to
//' at most 2 of the \eqn{K-1} cuts: the ones immediately adjacent to their observed
//' level, and exactly 1 cut if at an extreme level). The stacked binary outcome is
//' \code{1} if \code{y[i] == j + 1} (upper category) and \code{0} if
//' \code{y[i] == j} (lower category). The stacked stratum ID is
//' \code{strata[i] + (j - 1) * num_strata} (where \code{num_strata = max(strata)}),
//' i.e. the original stratum crossed with the cut index \eqn{j}: fitting a
//' conditional logistic regression stratified on this combined ID and pooling all
//' stacked rows together estimates a \emph{single shared} treatment coefficient
//' \eqn{\beta} across all cuts, while allowing each (original stratum, cut)
//' combination to absorb its own nuisance intercept via strata conditioning (the same
//' stratified-conditional-logit trick used elsewhere in the package, e.g. for
//' continuation-ratio models via \code{expand_continuation_ratio_data_cpp()}).
//'
//' \strong{Input conventions.} \code{y} must take integer values in
//' \code{1:K} (1-based category labels); \code{w} is typically the treatment
//' indicator/covariate to estimate a coefficient for, passed through unchanged per
//' stacked row (not itself expanded/transformed); \code{strata} must be positive
//' integers with \code{max(strata) == num_strata} (no gaps assumed beyond that
//' maximum, since combined stratum IDs are computed by simple integer arithmetic on
//' \code{num_strata}, not by re-indexing distinct values). No input validation is
//' performed at this layer (no range/type checks on \code{y}/\code{strata}); passing
//' out-of-range values silently produces incorrect stratum IDs or drops rows rather
//' than erroring.
//'
//' @param y Integer vector of length \eqn{n}: each subject's ordinal category label,
//'   in \code{1:K}.
//' @param w Integer vector of length \eqn{n}: a covariate (typically treatment
//'   assignment) carried through unchanged into each stacked row for that subject.
//' @param strata Integer vector of length \eqn{n}: positive-integer stratum/block
//'   labels; \code{max(strata)} is used as the per-cut stratum-ID offset (see
//'   Details).
//' @param K Integer; the number of ordinal categories (so there are \code{K - 1}
//'   adjacent-category cuts).
//' @return A list with components \code{y} (stacked 0/1 binary outcome), \code{w}
//'   (stacked covariate, passed through unchanged), and \code{strata} (stacked
//'   combined stratum-by-cut ID); all three are integer vectors of the same,
//'   generally-longer-than-\eqn{n} length (each subject contributes 0, 1, or 2
//'   stacked rows depending on their observed category).
//' @seealso \code{expand_continuation_ratio_data_cpp()} for the analogous expansion
//'   used by continuation-ratio ordinal models.
//'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal regression} for
//'   orientation; analogous Python API:
//'   \href{https://www.statsmodels.org/stable/discretemod.html}{statsmodels discrete
//'   models} (no direct adjacent-category equivalent; the closest analog is fitting
//'   the expanded data as a conditional/grouped logit).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List expand_adjacent_category_data_cpp(const Rcpp::IntegerVector& y, const Rcpp::IntegerVector& w, const Rcpp::IntegerVector& strata, int K) {
    Eigen::Map<const Eigen::VectorXi> map_y(y.begin(), y.size());
    Eigen::Map<const Eigen::VectorXi> map_w(w.begin(), w.size());
    Eigen::Map<const Eigen::VectorXi> map_strata(strata.begin(), strata.size());

    int n = map_y.size();
    int n_alpha = K - 1;
    int num_strata = map_strata.maxCoeff();
    
    std::vector<int> y_stack;
    std::vector<int> w_stack;
    std::vector<int> strata_stack;
    
    for (int i = 0; i < n; ++i) {
        int yi = map_y[i];
        int wi = map_w[i];
        int si = map_strata[i];
        
        for (int j = 1; j <= n_alpha; ++j) {
            if (yi == j || yi == j + 1) {
                y_stack.push_back((yi == j + 1) ? 1 : 0);
                w_stack.push_back(wi);
                strata_stack.push_back(si + (j - 1) * num_strata);
            }
        }
    }

    return List::create(
        Named("y") = wrap(y_stack),
        Named("w") = wrap(w_stack),
        Named("strata") = wrap(strata_stack)
    );
}
#endif // EDI_CORE_ONLY
