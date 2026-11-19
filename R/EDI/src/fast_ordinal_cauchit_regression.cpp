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
#include "ordinal_scale_guard.h"
#include "ordinal_fixed_link_internal.h"
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

class OrdinalCauchitRegression {
private:
    edi_ordinal::FixedOrdinalRegression m_model;

public:
    OrdinalCauchitRegression(const Eigen::Ref<const Eigen::MatrixXd>& X, const Eigen::Ref<const Eigen::VectorXd>& y) :
        m_model(X, y, edi_ordinal::Link::Cauchit, -1.0) {}

    int n_levels() const {
        return m_model.n_levels();
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

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
NumericVector fast_atan_cauchit_cpp(const NumericVector& x) {
    NumericVector result(no_init(x.size()));
    for (R_xlen_t i = 0; i < x.size(); ++i) {
        result[i] = edi_ordinal::fast_atan(x[i]);
    }
    return result;
}

// [[Rcpp::export]]
Eigen::VectorXd get_ordinal_cauchit_regression_score_cpp(const Rcpp::NumericMatrix& X,
														 const Rcpp::NumericVector& y,
														 const Rcpp::NumericVector& params,
														 Nullable<IntegerVector> fixed_idx = R_NilValue,
														 Nullable<NumericVector> fixed_values = R_NilValue) {
	return edi_ordinal::fixed_link_ordinal_score<OrdinalCauchitRegression>(X, y, params, fixed_idx, fixed_values);
}

// [[Rcpp::export]]
Eigen::MatrixXd get_ordinal_cauchit_regression_hessian_cpp(const Rcpp::NumericMatrix& X,
														   const Rcpp::NumericVector& y,
														   const Rcpp::NumericVector& params,
														   Nullable<IntegerVector> fixed_idx = R_NilValue,
														   Nullable<NumericVector> fixed_values = R_NilValue) {
	return edi_ordinal::fixed_link_ordinal_hessian<OrdinalCauchitRegression>(X, y, params, fixed_idx, fixed_values);
}
#endif // EDI_CORE_ONLY

static double cauchit_legacy_alpha(int k, int K) {
    double prob = static_cast<double>(k + 1) / static_cast<double>(K);
    return std::tan(M_PI * (prob - 0.5));
}

// Portable core: mirrors fast_ordinal_cauchit_regression_cpp (fit only) when
// estimate_only or before the "with_var" step; when !estimate_only, also
// folds in fast_ordinal_cauchit_regression_with_var_cpp's vcov/ssq_b_j logic
// (via compute_diagonal_inverse_entry / covariance_from_information) so a
// Python caller gets everything from one call. K < 2 (degenerate outcome)
// returns an empty ResultMap, matching the original fit-only R export.
edi::ResultMap fast_ordinal_cauchit_regression_internal(
    const Eigen::Ref<const Eigen::MatrixXd>& X,
    const Eigen::Ref<const Eigen::VectorXd>& y,
    std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
    bool smart_cold_start = true,
    int maxit = 100,
    double tol = 1e-6,
    std::string optimization_alg = "lbfgs",
    std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
    std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
    std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
    bool estimate_only = false
) {
    // Shared pipeline: ordinal_fixed_link_internal.h (v1.0.6-TODO-193).
    static const edi_ordinal::FixedLinkFitSpec spec = {
        edi_ordinal::Link::Cauchit, cauchit_legacy_alpha,
        edi_ordinal::DegenerateLevelsPolicy::EmptyBeforeValidation, false};
    return edi_ordinal::fixed_link_ordinal_internal<OrdinalCauchitRegression>(
        spec, X, y, std::move(warm_start_params), smart_cold_start, maxit, tol, std::move(optimization_alg),
        std::move(fixed_idx), std::move(fixed_values), std::move(warm_start_fisher_info), estimate_only);
}

#ifndef EDI_CORE_ONLY
//' Fast Cumulative Ordinal Regression with a Cauchit Link (C++)
//'
//' Fits a cumulative-link ordinal regression model with the \strong{cauchit} link
//' (the inverse CDF of the standard Cauchy distribution) via direct maximum
//' likelihood, jointly optimizing the category thresholds and regression
//' coefficients. \code{y}'s distinct values (in sorted order, whatever their
//' original coding) are treated as \eqn{K} ordered categories; for observation
//' \eqn{i} in category \eqn{k} (\eqn{k = 0, \ldots, K-1}),
//' \deqn{\Pr(Y_i \le k \mid x_i) = F(\alpha_k - x_i^\top \beta), \qquad
//'   F(z) = \frac{1}{2} + \frac{\arctan(z)}{\pi},}
//' with \eqn{\alpha_0 < \alpha_1 < \cdots < \alpha_{K-2}} the (increasing)
//' category thresholds and \eqn{\beta} the regression coefficients on \code{X}
//' (no separate intercept column is needed — the thresholds serve that role);
//' the category probability is the corresponding CDF difference,
//' \eqn{\Pr(Y_i = k \mid x_i) = F(\alpha_k - x_i^\top\beta) - F(\alpha_{k-1} - x_i^\top\beta)}
//' (with \eqn{F(\alpha_{-1} - \cdot) := 0} and \eqn{F(\alpha_{K-1} - \cdot) := 1}
//' at the boundaries), each clamped below at \eqn{10^{-12}} before taking logs
//' for numerical safety. This is a direct-likelihood analogue of ordinal
//' logistic regression with the logit link swapped for the heavier-tailed
//' Cauchy CDF, which is more robust to outlying/misclassified extreme
//' categories at the cost of less standard interpretability (no proportional-odds
//' log-odds-ratio reading of \eqn{\beta}). If \code{y} has fewer than 2 distinct
//' levels, an empty result list is returned (the model is degenerate).
//'
//' @section Fixed parameters, warm starts, and optimization:
//' \code{fixed_idx} (1-indexed into the combined \eqn{[\alpha, \beta]} parameter
//' vector, thresholds first) and \code{fixed_values} optionally hold a subset of
//' parameters at caller-supplied constant values rather than estimating them.
//' \code{warm_start_params} supplies starting values for \eqn{[\alpha, \beta]}
//' directly (skipping \code{smart_cold_start}); otherwise, when
//' \code{smart_cold_start = TRUE} (the default), starting values come from an
//' OLS-based heuristic, and when \code{FALSE}, thresholds start at
//' \eqn{\tan(\pi(k/K - 1/2))} (an inverse-cauchit spacing of the empirical
//' marginal category proportions) with \eqn{\beta} at zero. Optimization runs
//' via \code{optimization_alg} (default \code{"lbfgs"}) for up to \code{maxit}
//' iterations or until the gradient norm falls below \code{tol};
//' \code{warm_start_fisher_info}, if supplied, seeds the first iteration's
//' curvature estimate.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see the description).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance on the gradient norm.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//' @param estimate_only If \code{TRUE}, skip the post-fit Hessian/variance computation and
//'   return only point estimates (faster). If \code{FALSE} (the default), also compute and
//'   return the observed information matrix and, when the fit converged, the full
//'   variance-covariance matrix (identical to what
//'   \code{\link{fast_ordinal_cauchit_regression_with_var_cpp}} always computes).
//'
//' @return A list with components \code{b} (the \eqn{\beta} coefficients), \code{alpha}
//'   (the \eqn{K-1} category thresholds), \code{params} (the concatenated
//'   \eqn{[\alpha, \beta]} vector), \code{n_params}, \code{converged}, \code{num_iter},
//'   \code{hit_iteration_cap}, \code{gradient_norm} and \code{min_eigenvalue_information};
//'   when \code{estimate_only = FALSE} (the default), additionally
//'   \code{neg_loglik}, \code{observed_information}/\code{fisher_information}/\code{information}
//'   (all the same observed-information matrix), \code{information_type} (always
//'   \code{"observed"}), \code{ssq_b_j} (the variance of \code{b[1]}, i.e. the coefficient
//'   on \code{X}'s first column — conventionally the treatment effect, since \code{X}
//'   carries no separate intercept column here; the thresholds \code{alpha} play that
//'   role) and \code{vcov} (the parameter covariance matrix). Only these last two depend
//'   on convergence: when the fit did not converge, \code{ssq_b_j} is \code{NaN} and
//'   \code{vcov} is \code{NULL}. Empty if \code{y} has fewer than 2 distinct levels.
//' @seealso \code{\link{fast_ordinal_cauchit_regression_with_var_cpp}}, which always computes
//'   the variance quantities (equivalent to calling this function with
//'   \code{estimate_only = FALSE}) and additionally guards against the degenerate
//'   case by returning \code{NA} placeholders instead of an empty list.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_cauchit_regression_cpp(const Rcpp::NumericMatrix& X,
                                          const Rcpp::NumericVector& y,
                                          Nullable<NumericVector> warm_start_params = R_NilValue,
                                          bool smart_cold_start = true,
                                          int maxit = 100,
                                          double tol = 1e-6,
                                          std::string optimization_alg = "lbfgs",
                                          Nullable<IntegerVector> fixed_idx = R_NilValue,
                                          Nullable<NumericVector> fixed_values = R_NilValue,
                                          Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
                                          bool estimate_only = false) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    edi::ResultMap res = fast_ordinal_cauchit_regression_internal(
        map_X, map_y,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, maxit, tol, optimization_alg,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);
    return edi::to_rcpp_list(res);
}

//' Fast Cumulative Ordinal Regression with a Cauchit Link, with Variance (C++)
//'
//' As \code{\link{fast_ordinal_cauchit_regression_cpp}} (see that page for the full
//' cumulative cauchit-link model, \eqn{\Pr(Y_i \le k \mid x_i) = F(\alpha_k -
//' x_i^\top\beta)}), but always fits with \code{estimate_only = FALSE} (equivalent
//' to calling that function with its default), so the observed information matrix
//' and variance-covariance matrix are always computed. It additionally guards the
//' degenerate case: if \code{y} has fewer than 2 distinct levels (so the underlying
//' fit is empty), this function returns \code{list(b = NA, ssq_b_2 = NA)} instead of
//' an empty list.
//'
//' @inheritSection fast_ordinal_cauchit_regression_cpp Fixed parameters, warm starts, and optimization
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_cauchit_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//'
//' @return The same list as \code{\link{fast_ordinal_cauchit_regression_cpp}} with
//'   \code{estimate_only = FALSE}: \code{b}, \code{alpha}, \code{params}, \code{n_params},
//'   \code{neg_loglik}, \code{converged}, \code{num_iter}, \code{hit_iteration_cap},
//'   \code{gradient_norm}, \code{min_eigenvalue_information},
//'   \code{observed_information}/\code{fisher_information}/\code{information} (all the same
//'   observed-information matrix), \code{information_type} (\code{"observed"}), \code{vcov},
//'   and \code{ssq_b_j} (the variance of \code{b[1]}, i.e. \code{X}'s first-column coefficient
//'   — conventionally the treatment effect). \code{vcov} is \code{NULL} (and \code{ssq_b_j} is
//'   \code{NaN}) if the fit did not converge. Note the different variance name in the
//'   degenerate case: if \code{y} has fewer than 2 distinct levels the result is
//'   \code{list(b = NA, ssq_b_2 = NA)}.
//' @seealso \code{\link{fast_ordinal_cauchit_regression_cpp}} for the estimate-only-capable
//'   variant and the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_cauchit_regression_with_var_cpp(const Rcpp::NumericMatrix& X,
                                                   const Rcpp::NumericVector& y,
                                                   Nullable<NumericVector> warm_start_params = R_NilValue,
                                                   bool smart_cold_start = true,
                                                   std::string optimization_alg = "lbfgs",
                                                   Nullable<IntegerVector> fixed_idx = R_NilValue,
                                                   Nullable<NumericVector> fixed_values = R_NilValue,
                                                   Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    edi::ResultMap res = fast_ordinal_cauchit_regression_internal(
        map_X, map_y,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, 100, 1e-6, optimization_alg,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        false);
    if (res.entries().empty()) return edi::to_rcpp_list(edi::ResultMap().set("b", NA_REAL).set("ssq_b_2", NA_REAL));
    return edi::to_rcpp_list(res);
}
#endif // EDI_CORE_ONLY
