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

class OrdinalProbitRegression {
private:
    edi_ordinal::FixedOrdinalRegression m_model;

public:
    OrdinalProbitRegression(const Eigen::Ref<const Eigen::MatrixXd>& X, const Eigen::Ref<const Eigen::VectorXd>& y) :
        m_model(X, y, edi_ordinal::Link::Probit, -1.0) {}

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

static MatrixXd pseudo_inverse_symmetric_probit(const Eigen::Ref<const Eigen::MatrixXd>& A, double tol = 1e-8) {
    JacobiSVD<MatrixXd> svd(A, ComputeThinU | ComputeThinV);
    VectorXd sing = svd.singularValues();
    MatrixXd Dinv = MatrixXd::Zero(sing.size(), sing.size());
    for (int i = 0; i < sing.size(); ++i) {
        if (sing[i] > tol) {
            Dinv(i, i) = 1.0 / sing[i];
        }
    }
    return svd.matrixV() * Dinv * svd.matrixU().transpose();
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
Eigen::VectorXd get_ordinal_probit_regression_score_cpp(const Rcpp::NumericMatrix& X,
														const Rcpp::NumericVector& y,
														const Rcpp::NumericVector& params,
														Nullable<IntegerVector> fixed_idx = R_NilValue,
														Nullable<NumericVector> fixed_values = R_NilValue) {
	Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
	Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
	Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

	OrdinalProbitRegression model(map_X, map_y);
	FixedParamSpec fixed_spec = make_fixed_param_spec(
		map_params.size(),
		nullable_to_optional<Eigen::VectorXi>(fixed_idx),
		nullable_to_optional<Eigen::VectorXd>(fixed_values));
	Eigen::VectorXd par = apply_fixed_values(map_params, fixed_spec);
	Eigen::VectorXd grad(par.size());
	model(par, grad);
	return -grad;
}

// [[Rcpp::export]]
Eigen::MatrixXd get_ordinal_probit_regression_hessian_cpp(const Rcpp::NumericMatrix& X,
														  const Rcpp::NumericVector& y,
														  const Rcpp::NumericVector& params,
														  Nullable<IntegerVector> fixed_idx = R_NilValue,
														  Nullable<NumericVector> fixed_values = R_NilValue) {
	Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
	Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());
	Eigen::Map<const Eigen::VectorXd> map_params(params.begin(), params.size());

	OrdinalProbitRegression model(map_X, map_y);
	FixedParamSpec fixed_spec = make_fixed_param_spec(
		map_params.size(),
		nullable_to_optional<Eigen::VectorXi>(fixed_idx),
		nullable_to_optional<Eigen::VectorXd>(fixed_values));
	Eigen::VectorXd par = apply_fixed_values(map_params, fixed_spec);
	return -model.hessian(par);
}
#endif // EDI_CORE_ONLY

// Portable core: fit + (if !estimate_only) Hessian/vcov, mirroring both
// fast_ordinal_probit_regression_cpp (fit only) and
// fast_ordinal_probit_regression_with_var_cpp (fit + vcov) below -- the
// latter's ssq_b_j/vcov logic is folded in here directly (via
// compute_diagonal_inverse_entry / covariance_from_information) so a
// Python caller gets everything from one call.
edi::ResultMap fast_ordinal_probit_regression_internal(
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
    OrdinalProbitRegression model(X, y);
    const int p = (int)X.cols();
    const int K = (int)OrdinalProbitRegression::init_levels(y).size();
    const int n_alpha = K - 1;
    const int n_params = n_alpha + p;

    VectorXd params(n_params);
    FixedParamSpec fixed_spec = make_fixed_param_spec(n_params, fixed_idx, fixed_values);
    if (warm_start_params.has_value()) {
        params = *warm_start_params;
        if (params.size() != n_params) throw std::invalid_argument("warm_start_params must have length equal to the number of model parameters");
    } else {
        OrdinalStart legacy_start;
        legacy_start.alpha = VectorXd(n_alpha);
        for (int k = 0; k < n_alpha; ++k) {
            double q = static_cast<double>(k + 1) / static_cast<double>(K);
            legacy_start.alpha[k] = fast_qnorm(q);
        }
        legacy_start.beta = VectorXd::Zero(p);
        params = ordinal_start_to_params(
            smart_cold_start ? ordinal_smart_cold_start_or_legacy(X, y, edi_ordinal::Link::Probit, legacy_start, fixed_spec)
                        : legacy_start
        );
    }

    params = apply_fixed_values(params, fixed_spec);

    Eigen::MatrixXd info_start;
    const Eigen::MatrixXd* info_start_ptr = nullptr;
    if (warm_start_fisher_info.has_value()) {
        info_start = *warm_start_fisher_info;
        info_start_ptr = &info_start;
    }

    LikelihoodFitResult fit = optimize_fixed_likelihood(model, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_start_ptr);
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

    MatrixXd H_full = model.hessian(params);

    double ssq_b_2 = std::numeric_limits<double>::quiet_NaN();
    MatrixXd vcov;
    bool have_vcov = false;
    if (fit.converged) {
        FixedParameterFunctor<OrdinalProbitRegression> fixed_obj(model, fixed_spec, params);
        VectorXd params_free = subset_vector(params, fixed_spec.free_idx);
        MatrixXd H_free = fixed_obj.hessian(params_free);
        const int n_alpha2 = n_params - p;
        int free_j = -1;
        for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
            if (fixed_spec.free_idx[jj] == n_alpha2) { free_j = jj + 1; break; }
        if (p >= 1 && free_j > 0) {
            ssq_b_2 = compute_diagonal_inverse_entry(H_free, free_j);
            if (!std::isfinite(ssq_b_2) || ssq_b_2 <= 0) ssq_b_2 = std::numeric_limits<double>::quiet_NaN();
        }
        MatrixXd cov_free = covariance_from_information(H_free);
        vcov = expand_free_covariance(n_params, fixed_spec, cov_free, true);
        have_vcov = true;
    }

    edi::ResultMap rm = edi::ResultMap()
        .set("b", params.tail(p))
        .set("alpha", params.head(n_alpha))
        .set("n_params", n_params)
        .set("params", params)
        .set("neg_loglik", fit.value)
        .set("converged", fit.converged)
        .set("iterations", fit.niter)
        .set("ssq_b_j", ssq_b_2)
        .set("observed_information", H_full)
        .set("fisher_information", H_full)
        .set("information", H_full)
        .set("information_type", std::string("observed"));
    if (have_vcov) {
        rm.set("vcov", vcov);
    } else {
        rm.set("vcov", std::monostate{});
    }
    return rm;
}

#ifndef EDI_CORE_ONLY
//' Fast Cumulative Ordinal Regression with a Probit Link (C++)
//'
//' Fits a cumulative-link ordinal regression model with the \strong{probit} link
//' (the standard normal CDF) via direct maximum likelihood, jointly optimizing the
//' category thresholds and regression coefficients. \code{y}'s distinct values (in
//' sorted order, whatever their original coding) are treated as \eqn{K} ordered
//' categories; for observation \eqn{i} in category \eqn{k} (\eqn{k = 0, \ldots, K-1}),
//' \deqn{\Pr(Y_i \le k \mid x_i) = \Phi(\alpha_k - x_i^\top \beta),}
//' with \eqn{\alpha_0 < \alpha_1 < \cdots < \alpha_{K-2}} the (increasing) category
//' thresholds and \eqn{\beta} the regression coefficients on \code{X} (no separate
//' intercept column is needed — the thresholds serve that role); the category
//' probability is the corresponding CDF difference,
//' \eqn{\Pr(Y_i = k \mid x_i) = \Phi(\alpha_k - x_i^\top\beta) - \Phi(\alpha_{k-1} - x_i^\top\beta)}
//' (with \eqn{\Phi(\alpha_{-1} - \cdot) := 0} and \eqn{\Phi(\alpha_{K-1} - \cdot) := 1}
//' at the boundaries), each clamped below at \eqn{10^{-12}} before taking logs for
//' numerical safety. This is the ordinal generalization of probit regression, and
//' the thin-tailed counterpart to
//' \code{\link{fast_ordinal_cauchit_regression_cpp}} and the standard-logit ordinal
//' model. If \code{y} has fewer than 2 distinct levels, an empty result list is
//' returned (the model is degenerate).
//'
//' @section Fixed parameters, warm starts, and optimization:
//' \code{fixed_idx} (1-indexed into the combined \eqn{[\alpha, \beta]} parameter
//' vector, thresholds first) and \code{fixed_values} optionally hold a subset of
//' parameters at caller-supplied constant values rather than estimating them.
//' \code{warm_start_params} supplies starting values for \eqn{[\alpha, \beta]}
//' directly (skipping \code{smart_cold_start}); otherwise, when
//' \code{smart_cold_start = TRUE} (the default), starting values come from an
//' OLS-based heuristic, and when \code{FALSE}, thresholds start at
//' \eqn{\Phi^{-1}(k/K)} (inverse-normal spacing of the empirical marginal category
//' proportions) with \eqn{\beta} at zero. Optimization runs via
//' \code{optimization_alg} (default \code{"lbfgs"}) for up to \code{maxit}
//' iterations or until the parameter/gradient change falls below \code{tol};
//' \code{warm_start_fisher_info}, if supplied, seeds the first iteration's
//' curvature estimate.
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see Details).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//' @param estimate_only If \code{TRUE}, skip the post-fit Hessian/variance computation and
//'   return only point estimates (faster). If \code{FALSE} (the default), also compute and
//'   return the observed information matrix and, when the fit converged, the full
//'   variance-covariance matrix (identical to what
//'   \code{\link{fast_ordinal_probit_regression_with_var_cpp}} always computes).
//'
//' @return A list with components \code{b} (the \eqn{\beta} coefficients), \code{alpha}
//'   (the \eqn{K-1} category thresholds), \code{params} (the concatenated
//'   \eqn{[\alpha, \beta]} vector), \code{n_params}, \code{converged}, and \code{iterations};
//'   when \code{estimate_only = FALSE} (the default) and the fit converged, additionally
//'   \code{neg_loglik}, \code{observed_information}/\code{fisher_information}/\code{information}
//'   (all the same observed-information matrix), \code{information_type} (always
//'   \code{"observed"}), \code{vcov} (the parameter covariance matrix), and \code{ssq_b_j}
//'   (the variance of \code{b[1]}, i.e. the coefficient on \code{X}'s first column —
//'   conventionally the treatment effect, since \code{X} carries no separate intercept
//'   column here; the thresholds \code{alpha} play that role — set to \code{NA} if it comes
//'   out non-finite or non-positive). Empty if \code{y} has fewer than 2 distinct levels.
//' @seealso \code{\link{fast_ordinal_probit_regression_with_var_cpp}}, which always computes
//'   the variance quantities (equivalent to calling this function with
//'   \code{estimate_only = FALSE}) and additionally guards against the degenerate/non-converged
//'   case by returning \code{NA} placeholders instead of an empty list.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_probit_regression_cpp(const Rcpp::NumericMatrix& X,
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

    edi::ResultMap res = fast_ordinal_probit_regression_internal(
        map_X, map_y,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, maxit, tol, optimization_alg,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        estimate_only);
    return edi::to_rcpp_list(res);
}

//' Fast Cumulative Ordinal Regression with a Probit Link, with Variance (C++)
//'
//' As \code{\link{fast_ordinal_probit_regression_cpp}} (see that page for the full
//' cumulative probit-link model, \eqn{\Pr(Y_i \le k \mid x_i) = \Phi(\alpha_k -
//' x_i^\top\beta)}), but always fits with \code{estimate_only = FALSE} (equivalent
//' to calling that function with its default), so the observed information matrix
//' and variance-covariance matrix are always computed. It additionally guards the
//' degenerate case: if \code{y} has fewer than 2 distinct levels (so the underlying
//' fit is empty), this function returns \code{list(b = NA, ssq_b_2 = NA)} instead of
//' an empty list.
//'
//' @inheritSection fast_ordinal_probit_regression_cpp Fixed parameters, warm starts, and optimization
//'
//' @param X A numeric matrix of predictors (no intercept column needed; see
//'   \code{\link{fast_ordinal_probit_regression_cpp}}).
//' @param y A numeric vector of ordinal responses; only the rank order of distinct
//'   values matters, not their numeric coding.
//' @param warm_start_params Optional starting values for \eqn{[\alpha, \beta]}. If provided, \code{smart_cold_start} is ignored.
//' @param smart_cold_start Logical. If \code{TRUE}, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param optimization_alg Optimization algorithm (default \code{"lbfgs"}).
//' @param fixed_idx Optional 1-indexed positions (into \eqn{[\alpha,\beta]}) of parameters to hold fixed.
//' @param fixed_values Optional values, parallel to \code{fixed_idx}, of the fixed parameters.
//' @param warm_start_fisher_info Optional initial curvature (Fisher/observed information) matrix.
//'
//' @return A list with components \code{b}, \code{alpha}, \code{params}, \code{n_params},
//'   \code{neg_loglik}, \code{converged}, \code{iterations},
//'   \code{observed_information}/\code{fisher_information}/\code{information} (all the same
//'   observed-information matrix), \code{information_type} (\code{"observed"}), \code{vcov},
//'   and \code{ssq_b_2} (the variance of \code{b[1]}, i.e. \code{X}'s first-column coefficient
//'   — conventionally the treatment effect; \code{NA} if it comes out non-finite or
//'   non-positive). \code{vcov} is omitted (and \code{ssq_b_2} is \code{NA}) if the fit did
//'   not converge; \code{list(b = NA, ssq_b_2 = NA)} if \code{y} has fewer than 2 distinct levels.
//' @seealso \code{\link{fast_ordinal_probit_regression_cpp}} for the estimate-only-capable
//'   variant and the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_ordinal_probit_regression_with_var_cpp(const Rcpp::NumericMatrix& X,
                                                  const Rcpp::NumericVector& y,
                                                  Nullable<NumericVector> warm_start_params = R_NilValue,
                                                  bool smart_cold_start = true,
                                                  std::string optimization_alg = "lbfgs",
                                                  Nullable<IntegerVector> fixed_idx = R_NilValue,
                                                  Nullable<NumericVector> fixed_values = R_NilValue,
                                                  Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    Eigen::Map<const Eigen::MatrixXd> map_X(X.begin(), X.rows(), X.cols());
    Eigen::Map<const Eigen::VectorXd> map_y(y.begin(), y.size());

    edi::ResultMap res = fast_ordinal_probit_regression_internal(
        map_X, map_y,
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        smart_cold_start, 100, 1e-6, optimization_alg,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        false);
    return edi::to_rcpp_list(res);
}
#endif // EDI_CORE_ONLY
