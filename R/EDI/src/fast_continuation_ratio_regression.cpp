#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <Rcpp.h>
#include <RcppEigen.h>
#endif
#include <algorithm>
#include <cmath>
#include <vector>
#include <stdexcept>

// [[Rcpp::depends(RcppEigen)]]

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

inline Eigen::ArrayXd plogis_array_clamped(const Eigen::ArrayXd& eta) {
    const Eigen::ArrayXd eta_clamped = eta.max(-20.0).min(20.0);
    return 1.0 / (1.0 + (-eta_clamped).exp());
}

struct ContinuationRatioObjective {
    const Eigen::Ref<const MatrixXd> X_aug;
    const Eigen::Ref<const VectorXd> z;
    const Eigen::Ref<const VectorXd> weights_aug;
    VectorXd eta;
    VectorXd mu;
    VectorXd work;
    ArrayXd log_mu;
    ArrayXd log_one_minus_mu;

    ContinuationRatioObjective(const Eigen::Ref<const MatrixXd>& X_aug,
            const Eigen::Ref<const VectorXd>& z,
            const Eigen::Ref<const VectorXd>& weights_aug) :
        X_aug(X_aug), z(z), weights_aug(weights_aug), eta(X_aug.rows()), mu(X_aug.rows()), work(X_aug.rows()),
        log_mu(X_aug.rows()), log_one_minus_mu(X_aug.rows()) {}

    double operator()(const VectorXd& beta, VectorXd& grad) {
        eta.noalias() = X_aug * beta;
        mu = plogis_array_clamped(eta.array()).matrix();
        work = (weights_aug.array() * (mu - z).array()).matrix();
        grad.noalias() = X_aug.transpose() * work; // Negative log-likelihood gradient

        log_mu = mu.array().max(1e-12).log();
        log_one_minus_mu = (1.0 - mu.array()).max(1e-12).log();
        return -(weights_aug.array() *
            (z.array() * log_mu + (1.0 - z.array()) * log_one_minus_mu)).sum();
    }

    MatrixXd hessian(const VectorXd& beta) {
        eta.noalias() = X_aug * beta;
        mu = plogis_array_clamped(eta.array()).matrix();
        work = (weights_aug.array() * mu.array() * (1.0 - mu.array())).matrix();
        return weighted_crossprod(X_aug, work);
    }
};

// Rcpp-free internal-only carrier (never returned to R) -- was an Rcpp::List
// prior to the EDI_CORE_ONLY split; a plain struct is all this needs (only
// consumed by the 3 call sites in this same file).
struct ContinuationRatioAugmentedData {
	MatrixXd X_aug;
	VectorXd z;
	VectorXd weights_aug;
	int n_alpha;
};

static ContinuationRatioAugmentedData build_continuation_ratio_augmented_data(const Eigen::Ref<const MatrixXd>& X,
											const Eigen::Ref<const VectorXd>& y,
											const VectorXd* subject_weights = nullptr) {
	int n = X.rows();
	int p = X.cols();
	if (y.size() != n) throw std::invalid_argument("y length must equal nrow(X)");
	if (subject_weights != nullptr) {
		if (subject_weights->size() != n)
			throw std::invalid_argument("weights length must equal nrow(X)");
		double weight_sum = 0.0;
		for (int i = 0; i < n; ++i) {
			const double wi = (*subject_weights)[i];
			if (!std::isfinite(wi) || wi < 0.0)
				throw std::invalid_argument("weights must be finite and nonnegative");
			weight_sum += wi;
		}
		if (!(weight_sum > 0.0))
			throw std::invalid_argument("weights must contain at least one positive value");
	}

	std::vector<double> levels;
	for (int i = 0; i < y.size(); ++i) {
		if (std::find(levels.begin(), levels.end(), y[i]) == levels.end()) {
			levels.push_back(y[i]);
		}
	}
	std::sort(levels.begin(), levels.end());
	int K = levels.size();
	if (K < 2) {
		return ContinuationRatioAugmentedData{MatrixXd(0, p), VectorXd(0), VectorXd(0), 0};
	}
	int n_alpha = K - 1;

	std::vector<int> y_level(n);
	int total_rows = 0;
	for (int i = 0; i < n; ++i) {
		y_level[i] = static_cast<int>(
			std::lower_bound(levels.begin(), levels.end(), y[i]) - levels.begin());
		total_rows += std::min(y_level[i] + 1, n_alpha);
	}

	MatrixXd X_aug = MatrixXd::Zero(total_rows, n_alpha + p);
	VectorXd z(total_rows);
	VectorXd weights_aug(total_rows);
	int row = 0;
	for (int i = 0; i < n; ++i) {
		const int yi_level = y_level[i];
		const int rows_i = std::min(yi_level + 1, n_alpha);
		for (int j = 0; j < rows_i; ++j, ++row) {
			X_aug(row, j) = 1.0;
			if (p > 0) X_aug.row(row).tail(p) = X.row(i);
			z[row] = (yi_level == j) ? 1.0 : 0.0;
			weights_aug[row] = subject_weights == nullptr ? 1.0 : (*subject_weights)[i];
		}
	}
	return ContinuationRatioAugmentedData{X_aug, z, weights_aug, n_alpha};
}

} // namespace

// Fits the continuation-ratio model given already-augmented (X_aug, z, n_alpha)
// data. Returns the fit plus the augmented data the caller needs afterward
// (for the fisher_information/hessian call, which needs X_aug/z again).
struct ContinuationRatioFit {
	LikelihoodFitResult fit;
	Eigen::MatrixXd X_aug;
	Eigen::VectorXd z;
	Eigen::VectorXd weights_aug;
	int n_alpha;
	int p;
};

ContinuationRatioFit fast_continuation_ratio_internal(
		const Eigen::Ref<const Eigen::MatrixXd>& X,
		const Eigen::Ref<const Eigen::VectorXd>& y,
		int maxit = 100,
		double tol = 1e-8,
		std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
		bool smart_cold_start = true,
		std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
		std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
		std::string optimization_alg = "lbfgs",
		std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
		std::optional<Eigen::VectorXd> subject_weights = std::nullopt) {
	ContinuationRatioFit result;
	result.p = X.cols();
	const VectorXd* subject_weights_ptr = subject_weights.has_value() ? &(*subject_weights) : nullptr;
	ContinuationRatioAugmentedData aug = build_continuation_ratio_augmented_data(X, y, subject_weights_ptr);
	result.X_aug = aug.X_aug;
	result.z = aug.z;
	result.weights_aug = aug.weights_aug;
	result.n_alpha = aug.n_alpha;
	if (result.n_alpha == 0) {
		return result;
	}

	int p_aug = result.n_alpha + result.p;
	ContinuationRatioObjective fun(result.X_aug, result.z, result.weights_aug);
	VectorXd beta = VectorXd::Zero(p_aug);
	if (warm_start_beta.has_value()) {
		beta = *warm_start_beta;
		if (beta.size() != p_aug) throw std::invalid_argument("warm_start_beta size mismatch");
	} else if (smart_cold_start) {
		// Smart warm_start_params: OLS on z (the augmented binary response)
		beta = ols_smart_cold_start_beta(result.X_aug, result.z);
	}
	FixedParamSpec fixed_spec = make_fixed_param_spec(p_aug, fixed_idx, fixed_values);

	Eigen::MatrixXd info_start;
	const Eigen::MatrixXd* info_start_ptr = nullptr;
	if (warm_start_fisher_info.has_value()) {
		info_start = *warm_start_fisher_info;
		info_start_ptr = &info_start;
	}

	result.fit = optimize_fixed_likelihood(fun, beta, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_start_ptr);
	return result;
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
Eigen::VectorXd get_continuation_ratio_regression_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	

	

	ContinuationRatioAugmentedData aug = build_continuation_ratio_augmented_data(X, y_vec_coerced);
	MatrixXd X_aug = aug.X_aug;
	VectorXd z = aug.z;
	if (X_aug.rows() == 0) return VectorXd::Zero(params.size());
	VectorXd eta = X_aug * params;
	VectorXd mu = plogis_array_clamped(eta.array()).matrix();
	return X_aug.transpose() * (z - mu);
}

// [[Rcpp::export]]
Eigen::MatrixXd get_continuation_ratio_regression_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


	

	

	

	ContinuationRatioAugmentedData aug = build_continuation_ratio_augmented_data(X, y_vec_coerced);
	MatrixXd X_aug = aug.X_aug;
	if (X_aug.rows() == 0) return MatrixXd::Zero(params.size(), params.size());
	VectorXd eta = X_aug * params;
	VectorXd mu = plogis_array_clamped(eta.array()).matrix();
	VectorXd w = mu.array() * (1.0 - mu.array());
	return -weighted_crossprod(X_aug, w);
}

//' Fast Continuation-Ratio Regression, Direct MLE via Row Augmentation (C++ Backend)
//'
//' Fits the (forward) continuation-ratio logit ordinal regression model — the same
//' model documented in full at \code{expand_continuation_ratio_data_cpp()}: for cut
//' \eqn{j = 1, \dots, K-1}, \eqn{\log \Pr(Y = j \mid Y \ge j) / \Pr(Y > j \mid Y \ge j)
//' = \alpha_j + \beta^\top x}. Unlike the R-level stratified-conditional-logit path
//' built on \code{expand_continuation_ratio_data_cpp()}'s row expansion (used
//' elsewhere in the package when cut effects must be conditioned out alongside
//' matched-pair or block nuisance effects), this backend fits the model as a single
//' \strong{unconditional} logistic regression MLE on an internally-built augmented
//' design: \code{build_continuation_ratio_augmented_data()} constructs an augmented
//' matrix \code{X_aug} with one dummy column per cut (\code{n_alpha = K - 1}
//' columns) followed by the original \code{p} covariate columns, and an augmented
//' binary response \code{z} (1 = "stopped at this cut"), exactly as described in
//' \code{expand_continuation_ratio_data_cpp()}. Because the cut effects
//' \eqn{\alpha_j} are simply \code{K - 1} ordinary coefficients on dummy columns
//' (not nuisance parameters requiring conditioning), an unconditional logistic fit
//' on the augmented data is exactly equivalent to the continuation-ratio likelihood
//' — no stratification/conditioning machinery is needed for this standalone use
//' case.
//'
//' @details
//' \strong{Category coding.} As in \code{expand_continuation_ratio_data_cpp()},
//' distinct values of \code{y} are extracted and sorted; \code{K} is the number of
//' distinct observed values (not an externally supplied count), and each
//' observation contributes \code{min(observed_level + 1, K - 1)} augmented rows.
//'
//' \strong{Parameter vector layout.} The optimizer's parameter vector (returned as
//' \code{params}/\code{beta_full}) is \code{c(alpha_1, ..., alpha_{K-1}, beta_1,
//' ..., beta_p)}. Optimized via \code{optimization_alg} (\code{"lbfgs"} default),
//' for at most \code{maxit} iterations at tolerance \code{tol}; when no warm start
//' is supplied, \code{smart_cold_start = TRUE} seeds the optimizer via OLS on the
//' augmented binary response \code{z}. \code{fixed_idx}/\code{fixed_values} hold
//' specific parameters (by index into this layout) fixed rather than estimated, and
//' \code{warm_start_fisher_info} warm-starts curvature information.
//'
//' \strong{Degenerate case.} If \code{y} has fewer than 2 distinct observed values
//' (\code{K < 2}), no model can be fit: the function returns early with \code{b}
//' zeroed (length \code{p}) and an empty \code{alpha}, without attempting
//' optimization or setting \code{converged}/\code{neg_loglik}/etc.
//'
//' @param X A numeric matrix of predictors, \eqn{n \times p} (no intercept column; threshold intercepts are estimated internally).
//' @param y A numeric vector of length \eqn{n} giving each subject's ordinal
//'   category; need not be pre-coded \code{1:K} (see Details).
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param warm_start_beta Optional starting values for the full
//'   \code{c(alpha, beta)} parameter vector.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when no warm start is provided.
//' @param fixed_idx Optional integer indices (into the \code{c(alpha, beta)}
//'   parameter layout) of parameters to hold fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param optimization_alg Optimization algorithm; see Details.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix (over
//'   the full \code{c(alpha, beta)} parameter vector) to warm-start curvature
//'   information.
//' @return A list with components \code{b} (the shared covariate coefficients
//'   \eqn{\hat\beta}, length \code{p}), \code{alpha} (the \code{K - 1} estimated
//'   cut intercepts), \code{params}/\code{beta_full} (the full
//'   \code{c(alpha, b)} parameter vector, identical to each other),
//'   \code{neg_loglik} (the augmented-data logistic negative log-likelihood, which
//'   equals the continuation-ratio model's negative log-likelihood), \code{X_aug}/
//'   \code{z} (the augmented design matrix and binary response actually fit, exposed
//'   for reuse, e.g. by
//'   \code{get_continuation_ratio_regression_hessian_cpp()}), \code{converged}
//'   (logical), and \code{fisher_information} (the exact observed information
//'   Hessian at the fitted parameters). See Details for the degenerate
//'   fewer-than-2-categories case, which returns a reduced subset of these fields.
//' @seealso \code{expand_continuation_ratio_data_cpp()} for the full continuation-
//'   ratio model equation and the shared row-augmentation logic;
//'   \code{\link{fast_continuation_ratio_regression_with_var_cpp}} for the
//'   variance-augmented variant; \code{\link{fast_adjacent_category_logit_cpp}} for
//'   the analogous direct-MLE fit of the adjacent-category (rather than
//'   continuation-ratio) ordinal model.
//'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal regression} for
//'   orientation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_continuation_ratio_regression_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, int maxit = 100, double tol = 1e-8, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue, bool smart_cold_start = true, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "lbfgs", Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    int p = X.cols();
    ContinuationRatioFit cr = fast_continuation_ratio_internal(
        X, y_vec_coerced, maxit, tol,
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));
    if (cr.n_alpha == 0) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("b", VectorXd::Zero(p))
            .set("alpha", VectorXd::Zero(0)));
    }

    ContinuationRatioObjective fun(cr.X_aug, cr.z, cr.weights_aug);
    LikelihoodFitResult& fit = cr.fit;

    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", fit.params.tail(p))
        .set("alpha", fit.params.head(cr.n_alpha))
        .set("beta_full", fit.params)
        .set("params", fit.params)
        .set("neg_loglik", fit.value)
        .set("X_aug", cr.X_aug)
        .set("z", cr.z)
        .set("converged", fit.converged)
        .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("fisher_information", fun.hessian(fit.params)));
}

//' Fast Weighted Continuation-Ratio Regression, Direct MLE (C++ Backend)
//'
//' Fits the same continuation-ratio likelihood as
//' \code{fast_continuation_ratio_regression_cpp()}, weighting every augmented
//' binary row for subject \eqn{i} by that subject's nonnegative weight
//' \eqn{w_i}. This entry point is intended for bootstrap and other weighted
//' refits whose estimates must retain the continuation-ratio coefficient
//' convention.
//'
//' @inheritParams fast_continuation_ratio_regression_cpp
//' @param weights A finite, nonnegative subject-level weight vector of length
//'   \code{nrow(X)} containing at least one positive value.
//' @return The same result fields as
//'   \code{fast_continuation_ratio_regression_cpp()}, plus
//'   \code{weights_aug}, the weights copied onto the augmented binary rows.
//' @keywords internal
// [[Rcpp::export]]
List fast_continuation_ratio_regression_weighted_cpp(
        const Eigen::Map<Eigen::MatrixXd>& X,
        SEXP y,
        const Eigen::Map<Eigen::VectorXd>& weights,
        int maxit = 100,
        double tol = 1e-8,
        Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
        bool smart_cold_start = true,
        Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
        Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
        std::string optimization_alg = "lbfgs",
        Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    int p = X.cols();
    ContinuationRatioFit cr = fast_continuation_ratio_internal(
        X, y_vec, maxit, tol,
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        VectorXd(weights));
    if (cr.n_alpha == 0) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("b", VectorXd::Zero(p))
            .set("alpha", VectorXd::Zero(0))
            .set("weights_aug", cr.weights_aug));
    }

    ContinuationRatioObjective fun(cr.X_aug, cr.z, cr.weights_aug);
    LikelihoodFitResult& fit = cr.fit;

    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", fit.params.tail(p))
        .set("alpha", fit.params.head(cr.n_alpha))
        .set("beta_full", fit.params)
        .set("params", fit.params)
        .set("neg_loglik", fit.value)
        .set("X_aug", cr.X_aug)
        .set("z", cr.z)
        .set("weights_aug", cr.weights_aug)
        .set("converged", fit.converged)
        .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("fisher_information", fun.hessian(fit.params)));
}

//' Fast Continuation-Ratio Regression with Variance, Direct MLE (C++ Backend)
//'
//' Fits the same continuation-ratio model as
//' \code{\link{fast_continuation_ratio_regression_cpp}} (see that page for the full
//' model, row-augmentation mechanics, category coding, and parameter layout) and
//' additionally computes the variance of the first covariate coefficient and (when
//' converged) the full parameter variance-covariance matrix, from the same observed
//' information Hessian.
//'
//' @details
//' \strong{Variance computation.} The observed information (Hessian of the
//' augmented-data logistic negative log-likelihood, evaluated at the fitted
//' parameters over all \code{n_alpha + p} parameters) is restricted to the free
//' (non-\code{fixed_idx}) parameters. \code{ssq_b_j} — the variance of
//' \eqn{\hat\beta_1} (the coefficient on the \strong{first} covariate column of
//' \code{X}, the package's usual treatment-effect position) — is obtained via a
//' single targeted diagonal-entry inversion (\code{compute_diagonal_inverse_entry()}),
//' not a full matrix inverse, and is \code{NA} if that coefficient is fixed via
//' \code{fixed_idx}. The full \code{vcov} (over all \code{n_alpha + p} parameters,
//' expanded back from the free-parameter block) is computed only when
//' \code{converged} is \code{TRUE} (via \code{covariance_from_information()});
//' otherwise \code{vcov} is \code{NULL}.
//'
//' \strong{Degenerate case.} As in \code{\link{fast_continuation_ratio_regression_cpp}},
//' if \code{y} has fewer than 2 distinct observed values, the function returns early
//' with \code{b = NA_real_}, \code{ssq_b_j = NA_real_}, and \code{converged = FALSE},
//' without \code{vcov}/\code{params}/\code{fisher_information}.
//'
//' @inheritParams fast_continuation_ratio_regression_cpp
//' @return A list with components \code{b} (the shared covariate coefficients
//'   \eqn{\hat\beta}), \code{ssq_b_j} (the variance of the first covariate's
//'   coefficient), \code{neg_loglik}, \code{vcov} (the full parameter
//'   variance-covariance matrix, or \code{NULL} if not converged), \code{converged}
//'   (logical), \code{params} (the full \code{c(alpha, b)} parameter vector — cut
//'   intercepts are recoverable as \code{params[1:n_alpha]} but are not returned as
//'   a separate \code{alpha} field, unlike
//'   \code{\link{fast_continuation_ratio_regression_cpp}}), and
//'   \code{fisher_information} (the full observed information Hessian). See Details
//'   for the degenerate fewer-than-2-categories case, which returns a reduced subset
//'   of these fields.
//' @seealso \code{\link{fast_continuation_ratio_regression_cpp}} for the
//'   estimate-only variant and the full model/row-augmentation documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_continuation_ratio_regression_with_var_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		SEXP y,
		int maxit = 100,
		double tol = 1e-8,
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
		bool smart_cold_start = true,
		Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
		std::string optimization_alg = "lbfgs",
		Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue) {

    // See fast_logistic_regression_with_var_cpp for why y is coerced here
    // rather than taken as a direct Eigen::Map.
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    int p = X.cols();
    ContinuationRatioFit cr = fast_continuation_ratio_internal(
        X, y_vec, maxit, tol,
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
        smart_cold_start,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info));
    if (cr.n_alpha == 0) {
        return edi::to_rcpp_list(edi::ResultMap()
            .set("b", VectorXd::Constant(1, NA_REAL))
            .set("ssq_b_j", NA_REAL)
            .set("converged", false)
            .set("hit_iteration_cap", false));
    }
    int n_alpha = cr.n_alpha;
    LikelihoodFitResult& fit = cr.fit;

    ContinuationRatioObjective fun(cr.X_aug, cr.z, cr.weights_aug);
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        n_alpha + p,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));

    MatrixXd info = fun.hessian(fit.params);
    MatrixXd info_free = subset_matrix(info, fixed_spec.free_idx, fixed_spec.free_idx);
    int free_j = -1;
    for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
        if (fixed_spec.free_idx[jj] == n_alpha) { free_j = jj + 1; break; }
    double ssq_b_j = (p >= 1 && free_j > 0) ? compute_diagonal_inverse_entry(info_free, free_j) : NA_REAL;

    edi::ResultValue vcov_value = std::monostate{};
    if (fit.converged) {
        MatrixXd cov_free = covariance_from_information(info_free);
        vcov_value = Eigen::MatrixXd(expand_free_covariance(n_alpha + p, fixed_spec, cov_free, true));
    }
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", fit.params.tail(p))
        .set("ssq_b_j", ssq_b_j)
        .set("neg_loglik", fit.value)
        .set("vcov", vcov_value)
        .set("converged", fit.converged)
        .set("num_iter", fit.niter)
        .set("hit_iteration_cap", fit.hit_iteration_cap)
        .set("gradient_norm", fit.gradient_norm)
        .set("min_eigenvalue_information", fit.min_eigenvalue_information)
        .set("params", fit.params)
        .set("fisher_information", info));
}
#endif // EDI_CORE_ONLY
