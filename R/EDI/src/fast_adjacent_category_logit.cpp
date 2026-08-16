#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <Rcpp.h>
#include <RcppEigen.h>
#endif
#include <algorithm>
#include <vector>
#include <stdexcept>

// [[Rcpp::depends(RcppEigen)]]

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

class AdjacentCategoryLogitNegLogLik {
private:
    const Eigen::Ref<const MatrixXd> m_X;
    const std::vector<int>& m_y;
    int m_n;
    int m_p;
    int m_K;

public:
    AdjacentCategoryLogitNegLogLik(const Eigen::Ref<const MatrixXd>& X, const std::vector<int>& y, int K) :
        m_X(X), m_y(y), m_n(X.rows()), m_p(X.cols()), m_K(K) {}

    double operator()(const VectorXd& params, VectorXd& grad) const {
        const int n_alpha = m_K - 1;
        Eigen::Map<const VectorXd> beta(params.data() + n_alpha, m_p);

        grad.setZero(params.size());

        // Precompute exp(alpha[k]) once per call — amortised over n obs
        // unnorm[k] = u^(K-1-k) * prod_{j=k}^{K-2} exp_alpha[j],  u = exp(-eta)
        std::vector<double> exp_alpha(n_alpha);
        for (int k = 0; k < n_alpha; ++k) exp_alpha[k] = std::exp(params[k]);

        double neg_ll = 0.0;
        std::vector<double> prob(m_K);
        std::vector<double> cdf(n_alpha);

        for (int i = 0; i < m_n; ++i) {
            const double eta = (m_p > 0) ? m_X.row(i).dot(beta) : 0.0;
            const double u   = std::exp(-eta);

            // Build unnorm probs right-to-left via product recurrence
            prob[n_alpha] = 1.0;
            double total = 1.0;
            for (int k = n_alpha - 1; k >= 0; --k) {
                prob[k] = prob[k + 1] * exp_alpha[k] * u;
                total += prob[k];
            }
            const double inv_total = 1.0 / total;
            for (int k = 0; k < m_K; ++k) prob[k] *= inv_total;

            const int y_i = m_y[i];
            neg_ll -= std::log(prob[y_i - 1]);

            // CDF and E[Y] in one pass
            double running_cdf = 0.0, ey = 0.0;
            for (int k = 0; k < m_K; ++k) {
                ey += static_cast<double>(k + 1) * prob[k];
                if (k < n_alpha) { running_cdf += prob[k]; cdf[k] = running_cdf; }
            }

            // Alpha gradient: split at y_i to avoid branch inside hot inner loop
            const int thresh = y_i - 1;
            for (int j = 0;      j < thresh;  ++j) grad[j] += cdf[j];
            for (int j = thresh; j < n_alpha; ++j) grad[j] -= (1.0 - cdf[j]);

            if (m_p > 0)
                grad.tail(m_p).noalias() -= m_X.row(i).transpose() * (static_cast<double>(y_i) - ey);
        }

        return neg_ll;
    }

    MatrixXd hessian(const VectorXd& params) const {
        const int n_alpha = m_K - 1;
        Eigen::Map<const VectorXd> beta(params.data() + n_alpha, m_p);

        MatrixXd hess = MatrixXd::Zero(params.size(), params.size());

        std::vector<double> exp_alpha(n_alpha);
        for (int k = 0; k < n_alpha; ++k) exp_alpha[k] = std::exp(params[k]);

        std::vector<double> prob(m_K);
        std::vector<double> cdf(n_alpha);
        std::vector<double> prefix_first_moment(n_alpha);
        const int total_p = params.size();
        double* H_data = hess.data();

        for (int i = 0; i < m_n; ++i) {
            const double eta = (m_p > 0) ? m_X.row(i).dot(beta) : 0.0;
            const double u   = std::exp(-eta);

            prob[n_alpha] = 1.0;
            double total = 1.0;
            for (int k = n_alpha - 1; k >= 0; --k) {
                prob[k] = prob[k + 1] * exp_alpha[k] * u;
                total += prob[k];
            }
            const double inv_total = 1.0 / total;
            for (int k = 0; k < m_K; ++k) prob[k] *= inv_total;

            double ey = 0.0, ey2 = 0.0;
            double running_cdf = 0.0, running_first_moment = 0.0;
            for (int k = 0; k < m_K; ++k) {
                const double kp1 = static_cast<double>(k + 1);
                ey  += kp1 * prob[k];
                ey2 += kp1 * kp1 * prob[k];
                if (k < n_alpha) {
                    running_cdf += prob[k];
                    running_first_moment += kp1 * prob[k];
                    cdf[k] = running_cdf;
                    prefix_first_moment[k] = running_first_moment;
                }
            }
            const double var_y = std::max(0.0, ey2 - ey * ey);

            // Alpha-alpha block: val = cdf[j] * (1 - cdf[k])  (since k >= j => cdf[j]=min)
            for (int j = 0; j < n_alpha; ++j) {
                for (int k = j; k < n_alpha; ++k) {
                    const double val = cdf[j] * (1.0 - cdf[k]);
                    hess(j, k) += val;
                    if (j != k) hess(k, j) += val;
                }
            }

            if (m_p > 0) {
                const double* xi = m_X.data() + i;
                for (int j = 0; j < n_alpha; ++j) {
                    const double cov_ind_y = prefix_first_moment[j] - ey * cdf[j];
                    for (int b = 0; b < m_p; ++b) {
                        const double val = cov_ind_y * xi[b * m_n];
                        H_data[j + (n_alpha + b) * total_p] += val;
                        H_data[(n_alpha + b) + j * total_p] += val;
                    }
                }
                for (int c = 0; c < m_p; ++c) {
                    const double s = var_y * xi[c * m_n];
                    for (int r = 0; r <= c; ++r)
                        H_data[(n_alpha + r) + (n_alpha + c) * total_p] += s * xi[r * m_n];
                }
            }
        }

        if (m_p > 0) {
            for (int c = 0; c < m_p; ++c)
                for (int r = 0; r < c; ++r)
                    H_data[(n_alpha + c) + (n_alpha + r) * total_p] = H_data[(n_alpha + r) + (n_alpha + c) * total_p];
        }

        return hess;
    }
};

} // namespace

// External linkage (unlike the rest of this file's helpers) so a Python
// binding can call these directly to replicate the same y -> (levels, 1..K
// mapping) prep the exported wrapper below does.
std::vector<double> get_levels(const Eigen::Ref<const VectorXd>& y) {
    std::vector<double> levels(y.data(), y.data() + y.size());
    std::sort(levels.begin(), levels.end());
    levels.erase(std::unique(levels.begin(), levels.end()), levels.end());
    return levels;
}

std::vector<int> map_y_to_1K(const Eigen::Ref<const VectorXd>& y, const std::vector<double>& levels) {
    int n = y.size();
    std::vector<int> y_mapped(n);
    for (int i = 0; i < n; ++i) {
        double yi = y[i];
        auto it = std::lower_bound(levels.begin(), levels.end(), yi);
        y_mapped[i] = static_cast<int>(std::distance(levels.begin(), it)) + 1;
    }
    return y_mapped;
}

LikelihoodFitResult fast_adjacent_category_logit_internal(
		const Eigen::Ref<const Eigen::MatrixXd>& X,
		const std::vector<int>& y_mapped,
		int K,
		int maxit = 100,
		double tol = 1e-8,
		bool smart_cold_start = true,
		std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
		std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
		std::string optimization_alg = "lbfgs",
		std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
		std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
		std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt) {
	AdjacentCategoryLogitNegLogLik fun(X, y_mapped, K);

	int n_alpha = K - 1;
	int p = X.cols();
	int n_par = n_alpha + p;
	VectorXd params = VectorXd::Zero(n_par);

	if (warm_start_params.has_value()) {
		params = *warm_start_params;
		if (params.size() != n_par) throw std::invalid_argument("warm_start_params size mismatch");
	} else if (warm_start_beta.has_value()) {
		const Eigen::VectorXd& sb = *warm_start_beta;
		if (sb.size() == p) {
			params.tail(p) = sb;
		}
	} else if (smart_cold_start) {
		// Smart warm_start_params: OLS on y_mapped
		Eigen::VectorXd y_double(y_mapped.size());
		for(size_t i=0; i<y_mapped.size(); ++i) y_double[i] = (double)y_mapped[i];
		params.tail(p) = ols_smart_cold_start_beta(X, y_double);
	}

	FixedParamSpec fixed_spec = make_fixed_param_spec(n_par, fixed_idx, fixed_values);

	Eigen::MatrixXd info_start;
	const Eigen::MatrixXd* info_start_ptr = nullptr;
	if (warm_start_fisher_info.has_value()) {
		info_start = *warm_start_fisher_info;
		info_start_ptr = &info_start;
	}

	return optimize_fixed_likelihood(fun, params, fixed_spec, maxit, tol, optimization_alg, "lbfgs", 0, info_start_ptr);
}

#ifndef EDI_CORE_ONLY
// [[Rcpp::export]]
Eigen::VectorXd get_adjacent_category_logit_score_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    std::vector<double> levels = get_levels(y_vec_coerced);
    std::vector<int> y_mapped = map_y_to_1K(y_vec_coerced, levels);
    AdjacentCategoryLogitNegLogLik fun(X, y_mapped, levels.size());
    VectorXd grad(params.size());
    fun(params, grad);
    return -grad;
}

// [[Rcpp::export]]
Eigen::MatrixXd get_adjacent_category_logit_hessian_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Eigen::Map<Eigen::VectorXd>& params) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    

    std::vector<double> levels = get_levels(y_vec_coerced);
    std::vector<int> y_mapped = map_y_to_1K(y_vec_coerced, levels);
    AdjacentCategoryLogitNegLogLik fun(X, y_mapped, levels.size());
    return -fun.hessian(params);
}

//' Fast Adjacent-Category Logit Regression, Direct MLE (C++ Backend)
//'
//' Fits the adjacent-category logit ordinal regression model
//' \deqn{\log\frac{\Pr(Y = k+1)}{\Pr(Y = k)} = \alpha_k + \beta^\top x, \quad k = 1, \dots, K-1,}
//' by direct maximum likelihood on the full multinomial likelihood of \code{y},
//' rather than via the stacked-binary / stratified-conditional-logit reduction
//' implemented by \code{expand_adjacent_category_data_cpp()} elsewhere in the
//' package. \eqn{\beta} (the covariate effects, shared across all \code{K - 1} cuts)
//' and the \code{K - 1} cut-specific intercepts \eqn{\alpha_k} are estimated jointly
//' by numerically optimizing the exact multinomial log-likelihood, which is
//' generally more accurate and can be faster than fitting the row-stacked expansion
//' as a stratified logistic regression, at the cost of a custom (rather than reused)
//' optimizer implementation.
//'
//' @details
//' \strong{Category coding.} \code{y} need not already be coded \code{1:K}: the
//' distinct values of \code{y} are extracted and sorted (\code{get_levels()}), and
//' each observation is remapped to its 1-based \strong{rank} among those sorted
//' distinct values (\code{map_y_to_1K()}) — e.g. \code{y = c(10, 30, 20, 10)} is
//' treated identically to \code{y = c(1, 3, 2, 1)}, with \code{K = 3}. \code{K} is
//' therefore the number of \emph{distinct observed} values, not any externally
//' supplied category count, and requires at least 2 (an error is raised otherwise).
//'
//' \strong{Parameterization and likelihood.} Internally, category probabilities are
//' computed from a numerically stable right-to-left product recurrence in terms of
//' \eqn{u = e^{-\eta}} (\eqn{\eta = x^\top \beta}) and \eqn{e^{\alpha_k}}, avoiding
//' repeated exponentiation and keeping partial products bounded; the returned
//' \code{neg_loglik} is the resulting exact multinomial negative log-likelihood
//' (\eqn{-\sum_i \log \Pr(Y_i = y_i)}), with the analytic gradient computed in the
//' same pass and used internally for optimization. See
//' \code{\link{fast_adjacent_category_logit_with_var_cpp}} for the variant that
//' additionally returns the variance-covariance matrix of the estimates.
//'
//' \strong{Parameter vector layout.} The optimizer's parameter vector (returned as
//' \code{params}) is \code{c(alpha_1, ..., alpha_{K-1}, beta_1, ..., beta_p)} — the
//' \code{K - 1} cut intercepts first, then the \code{p} shared covariate
//' coefficients (\code{p = ncol(X)}).
//'
//' \strong{Optimization.} Optimized via \code{optimization_alg} (\code{"lbfgs"}
//' default; see \code{\link{.normalize_optimizer_algorithm}} for the supported set),
//' for at most \code{maxit} iterations at tolerance \code{tol}. When no warm start is
//' supplied, \code{smart_cold_start = TRUE} (default) seeds the optimizer from an
//' OLS-based initial guess rather than a naive zero/arbitrary start; supplying
//' \code{warm_start_params} (the full parameter vector) or \code{warm_start_beta}
//' (just the covariate coefficients, with cut intercepts initialized separately)
//' overrides \code{smart_cold_start} entirely. \code{fixed_idx}/\code{fixed_values}
//' allow holding specific parameters (by index into the layout above) fixed at
//' supplied values during optimization rather than estimating them, and
//' \code{warm_start_fisher_info} allows reusing a previously computed Fisher
//' information matrix to warm-start curvature information for faster convergence.
//'
//' @param X A numeric matrix of predictors, \eqn{n \times p}, with \strong{no}
//'   intercept column (the model's cut-specific intercepts \eqn{\alpha_k} serve that
//'   role).
//' @param y A numeric vector of length \eqn{n} giving each subject's ordinal
//'   category; need not be pre-coded \code{1:K} (see Details for the rank-based
//'   remapping).
//' @param maxit Maximum number of optimizer iterations.
//' @param tol Convergence tolerance.
//' @param smart_cold_start Logical. If TRUE, use an initial OLS-based guess when starting from scratch (a "cold start") with no prior knowledge. This is ignored if a warm start is provided.
//' @param fixed_idx Optional integer indices (into the
//'   \code{c(alpha, beta)} parameter layout described in Details) of parameters to
//'   hold fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at; must be the same length as \code{fixed_idx}.
//' @param optimization_alg Optimization algorithm; see Details.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix (over
//'   the full \code{c(alpha, beta)} parameter vector) to warm-start curvature
//'   information.
//' @param warm_start_params Optional starting values for the full parameter vector
//'   \code{c(alpha, beta)}. If provided, \code{smart_cold_start} is ignored.
//' @param warm_start_beta Optional starting values for just the covariate
//'   coefficients \eqn{\beta} (cut intercepts \eqn{\alpha} are still initialized
//'   separately). If provided, \code{smart_cold_start} is ignored.
//' @return A list with components \code{b} (the shared covariate coefficients
//'   \eqn{\hat\beta}, length \code{p}), \code{alpha} (the \code{K - 1} estimated
//'   cut intercepts \eqn{\hat\alpha_k}), \code{params} (the full
//'   \code{c(alpha, b)} parameter vector, as optimized), \code{neg_loglik} (the
//'   multinomial negative log-likelihood at convergence), and \code{converged}
//'   (logical).
//' @seealso \code{\link{fast_adjacent_category_logit_with_var_cpp}} for the
//'   variance-augmented variant; \code{expand_adjacent_category_data_cpp()} for the
//'   alternative stacked-binary reduction of the same model.
//'   \href{https://en.wikipedia.org/wiki/Ordinal_regression}{Ordinal regression} for
//'   orientation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_adjacent_category_logit_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, int maxit = 100, double tol = 1e-8, bool smart_cold_start = true, Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue, std::string optimization_alg = "lbfgs", Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue, Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    std::vector<double> levels = get_levels(y_vec_coerced);
    int K = levels.size();
    if (K < 2) {
        stop("Adjacent-category logits require at least two observed outcome categories.");
    }
    std::vector<int> y_mapped = map_y_to_1K(y_vec_coerced, levels);

    LikelihoodFitResult fit = fast_adjacent_category_logit_internal(
        X, y_mapped, K, maxit, tol, smart_cold_start,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta));

    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", fit.params.tail(X.cols()))
        .set("alpha", fit.params.head(K - 1))
        .set("params", fit.params)
        .set("neg_loglik", fit.value)
        .set("converged", fit.converged));
}

//' @title Fast Adjacent-Category Logit with Variance (C++)
//' @description Adjacent-category logit model fitting with full variance-covariance matrix.
//' @param X A numeric matrix of predictors.
//' @param y A numeric vector of responses (categorical).
//' @param maxit Maximum number of iterations.
//' Fast Adjacent-Category Logit Regression with Variance, Direct MLE (C++ Backend)
//'
//' Fits the same adjacent-category logit model as
//' \code{\link{fast_adjacent_category_logit_cpp}} (see that page for the model,
//' category-coding/remapping, parameter layout, and optimizer contract, all shared
//' unchanged here) and additionally computes the observed-information-based
//' variance-covariance matrix of the fitted parameters.
//'
//' @details
//' \strong{Variance computation.} The observed Fisher information (the Hessian of the
//' negative log-likelihood, via \code{AdjacentCategoryLogitNegLogLik::hessian()}) is
//' evaluated at the fitted parameter vector over \emph{all} \code{n_alpha + p}
//' parameters (returned in full as \code{fisher_information}), then restricted to the
//' free (non-\code{fixed_idx}) parameters and inverted via a rank-aware
//' (\code{symmetric_pseudo_inverse()}, not a plain Cholesky/LDLT solve) inverse
//' before being expanded back to full \code{(n_alpha + p) x (n_alpha + p)} size as
//' \code{vcov}. The pseudo-inverse is used deliberately: adjacent-category fits can
//' have an estimable treatment effect even when nuisance columns make the full
//' information matrix rank-deficient, a case where a standard Cholesky/LDLT solve
//' can report spurious success with an invalid (sometimes negative) variance rather
//' than failing cleanly. \code{vcov} is only populated when \code{converged} is
//' \code{TRUE}; otherwise it is \code{NULL}.
//'
//' \strong{First-covariate variance shortcut.} \code{ssq_b_1} (aliased as
//' \code{ssq_b_j} for interface consistency with the package's other
//' \code{fast_*_with_var_cpp} functions) is the variance of \eqn{\hat\beta_1}, the
//' coefficient on the \strong{first} column of \code{X} — by the package's usual
//' convention, the treatment-effect column — extracted directly from the free-parameter
//' covariance block rather than requiring the caller to index into the full
//' \code{vcov} matrix; it is \code{NA} if that coefficient was fixed
//' (via \code{fixed_idx}) or if its estimated variance is non-finite or non-positive.
//'
//' @inheritParams fast_adjacent_category_logit_cpp
//' @return A list with all the components of
//'   \code{\link{fast_adjacent_category_logit_cpp}} (\code{b}, \code{alpha},
//'   \code{params}, \code{neg_loglik}, \code{converged}), plus \code{ssq_b_1}
//'   (equivalently \code{ssq_b_j}, the variance of the first covariate's
//'   coefficient), \code{vcov} (the full parameter variance-covariance matrix, or
//'   \code{NULL} if not converged), and \code{fisher_information} (the full observed
//'   information matrix at the fitted parameters, over all parameters regardless of
//'   \code{fixed_idx}).
//' @seealso \code{\link{fast_adjacent_category_logit_cpp}} for the estimate-only
//'   variant and the full model/parameterization documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_adjacent_category_logit_with_var_cpp( const Eigen::Map<Eigen::MatrixXd>& X,
		SEXP y,
		int maxit = 100,
		double tol = 1e-8,
		bool smart_cold_start = true,
		Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
		std::string optimization_alg = "lbfgs",
		Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
		Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue) {

    // See fast_logistic_regression_with_var_cpp for why y is coerced here
    // rather than taken as a direct Eigen::Map.
    NumericVector y_r(y);
    Eigen::Map<const Eigen::VectorXd> y_vec(y_r.begin(), y_r.size());
    std::vector<double> levels = get_levels(y_vec);
    int K = levels.size();
    if (K < 2) {
        stop("Adjacent-category logits require at least two observed outcome categories.");
    }
    std::vector<int> y_mapped = map_y_to_1K(y_vec, levels);
    int n_alpha = K - 1;
    int p = X.cols();
    int n_par = n_alpha + p;

    LikelihoodFitResult fit = fast_adjacent_category_logit_internal(
        X, y_mapped, K, maxit, tol, smart_cold_start,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values),
        optimization_alg,
        nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
        nullable_to_optional<Eigen::VectorXd>(warm_start_params),
        nullable_to_optional<Eigen::VectorXd>(warm_start_beta));

    AdjacentCategoryLogitNegLogLik fun(X, y_mapped, K);
    FixedParamSpec fixed_spec = make_fixed_param_spec(
        n_par,
        nullable_to_optional<Eigen::VectorXi>(fixed_idx),
        nullable_to_optional<Eigen::VectorXd>(fixed_values));

    MatrixXd info = fun.hessian(fit.params);
    MatrixXd info_free = subset_matrix(info, fixed_spec.free_idx, fixed_spec.free_idx);
    int free_j = -1;
    for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
        if (fixed_spec.free_idx[jj] == n_alpha) { free_j = jj; break; }

    // Adjacent-category fits can have estimable treatment effects even when
    // nuisance columns make the information matrix rank deficient.  LDLT may
    // report success for such matrices while returning a finite but invalid
    // (often negative) diagonal entry, so use the rank-aware inverse here.
    MatrixXd cov_free = symmetric_pseudo_inverse(info_free);
    double ssq_b_1 = NA_REAL;
    if (X.cols() >= 1 && free_j >= 0 && cov_free.allFinite()) {
        const double treatment_variance = cov_free(free_j, free_j);
        if (R_finite(treatment_variance) && treatment_variance > 0.0) {
            ssq_b_1 = treatment_variance;
        }
    }

    edi::ResultValue vcov_value = std::monostate{};
    if (fit.converged) {
        vcov_value = Eigen::MatrixXd(expand_free_covariance(n_par, fixed_spec, cov_free, true));
    }
    return edi::to_rcpp_list(edi::ResultMap()
        .set("b", fit.params.tail(X.cols()))
        .set("alpha", fit.params.head(K - 1))
        .set("params", fit.params)
        .set("neg_loglik", fit.value)
        .set("ssq_b_1", ssq_b_1)
        .set("ssq_b_j", ssq_b_1)
        .set("vcov", vcov_value)
        .set("fisher_information", info)
        .set("converged", fit.converged));
}

#ifdef _OPENMP
#include <omp.h>
#endif

// [[Rcpp::plugins(openmp)]]

// [[Rcpp::export]]
NumericVector compute_adj_cat_logit_distr_parallel_cpp(const Eigen::Map<Eigen::MatrixXd>& X, SEXP y, const Rcpp::IntegerMatrix& w_mat, double delta, int num_cores) {
	NumericVector y_r_coerced(y); Eigen::Map<const Eigen::VectorXd> y_vec_coerced(y_r_coerced.begin(), y_r_coerced.size());


    

    

    int nsim = w_mat.cols();
    int n = y_vec_coerced.size();
    int p_covars = X.cols();
    int p_full = p_covars + 1;

    std::vector<double> results(nsim, NA_REAL);
    const int* w_ptr = w_mat.begin();

#ifdef _OPENMP
    omp_set_num_threads(num_cores);
#endif

#pragma omp parallel for schedule(static)
    for (int b = 0; b < nsim; ++b) {
        const int* w_col = w_ptr + (size_t)b * n;

        Eigen::MatrixXd X_full(n, p_full);
        Eigen::VectorXd y_shifted(n);

        for (int i = 0; i < n; ++i) {
            X_full(i, 0) = (double)w_col[i];
            for (int k = 0; k < p_covars; ++k) {
                X_full(i, 1 + k) = X(i, k);
            }
            y_shifted[i] = (w_col[i] == 1) ? y_vec_coerced[i] + delta : y_vec_coerced[i];
        }

        std::vector<double> levels = get_levels(y_shifted);
        int K = levels.size();
        if (K < 2) continue;

        std::vector<int> y_mapped = map_y_to_1K(y_shifted, levels);
        AdjacentCategoryLogitNegLogLik fun(X_full, y_mapped, K);
        VectorXd params = VectorXd::Zero((K - 1) + p_full);

        LikelihoodFitResult fit = optimize_likelihood(fun, params, 100, 1e-8, "newton_raphson", "newton_raphson");

        int n_alpha = K - 1;
        if ((int)fit.params.size() >= n_alpha + 1 && std::isfinite(fit.params[n_alpha])) {
            results[b] = fit.params[n_alpha];
        }
    }

    return wrap(results);
}
#endif // EDI_CORE_ONLY
