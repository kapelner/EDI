#ifdef EDI_CORE_ONLY
#include "_helper_functions_core.h"
#include "result_map.h"
#else
#include "_helper_functions.h"
#include "result_map_rcpp.h"
#include <RcppEigen.h>
#endif
#include <optional>
#include <string>
#include <limits>
#include <stdexcept>

#ifndef EDI_CORE_ONLY
using namespace Rcpp;
#endif
using namespace Eigen;

namespace {

// plogis_array is now the canonical version in _helper_functions_core.h
// (already in this file's include chain) -- see its comment for why.

inline Eigen::ArrayXd log1pexp_array(const Eigen::ArrayXd& eta) {
	const Eigen::Array<bool, Eigen::Dynamic, 1> nonnegative = (eta >= 0.0);
	const Eigen::ArrayXd pos = eta + (1.0 + (-eta).exp()).log();
	const Eigen::ArrayXd neg = (1.0 + eta.exp()).log();
	return nonnegative.select(pos, neg);
}

}  // namespace

// Fast optimizer for the combined conditional-Poisson + Poisson log-likelihood:
//   L_total = L_cond_Poisson(pairs) + L_Poisson(reservoir)
//
// Pair component (conditional Poisson = weighted binomial logistic):
//   eta_k = beta_T + X_diff_k' beta_xs
//   ll_pairs = sum(yT_k * eta_k - n_k * log(1 + exp(eta_k)))
//
// Reservoir component (marginal Poisson):
//   eta_i = beta_0 + w_i * beta_T + X_i' beta_xs
//   ll_res = sum(y_i * eta_i - exp(eta_i))
//
// Parameter layout: [beta_0 (0), beta_T (1), beta_xs (2..p+1)]  (size p+2)
// beta_T is at 0-based index 1; pass j=2 (1-based) to extract its variance.
//
// Uses Newton's method with the analytic Fisher-information matrix as Hessian.
// At each iteration:
//   grad = gradient of neg-log-lik (= -score)
//   H    = Fisher info = X_pairs_eff' W_pairs X_pairs_eff + X_res_eff' W_res X_res_eff
//   params -= H^{-1} * grad
//
// Converges in O(1) iterations near the optimum (quadratic convergence).
// At convergence H = observed information; vcov = H^{-1}; ssq_b_j = H^{-1}[1,1].
//

// Plain struct (not edi::ResultMap) since this is only ever consumed within
// this same translation unit -- see result_map.h's comment on when a plain
// struct is preferable to ResultMap for internal (non-R/Python-boundary)
// helper return values.
struct ScoreInfoResult {
	VectorXd score;
	MatrixXd info;
};

static ScoreInfoResult cpoisson_combined_score_info_cpp_impl(
	const Eigen::Ref<const Eigen::VectorXd>& yT_v,
	const Eigen::Ref<const Eigen::VectorXd>& n_k_v,
	const Eigen::Ref<const Eigen::MatrixXd>& X_diff_v,
	const Eigen::Ref<const Eigen::VectorXd>& y_r,
	const Eigen::Ref<const Eigen::VectorXd>& w_r,
	const Eigen::Ref<const Eigen::MatrixXd>& X_r,
	const Eigen::Ref<const Eigen::VectorXd>& params
) {
	const int nd = (int)yT_v.size();
	const int nR = (int)y_r.size();
	const int p  = (int)X_diff_v.cols();
	const int np = p + 2;

	VectorXd score = VectorXd::Zero(np);
	MatrixXd info = MatrixXd::Zero(np, np);

	const double beta_0 = params[0];
	const double beta_T = params[1];
	const VectorXd beta_xs = params.tail(p);

	VectorXd eta_p = VectorXd::Constant(nd, beta_T);
	if (p > 0) eta_p.noalias() += X_diff_v * beta_xs;
	ArrayXd p_k_arr = plogis_array(eta_p.array());
	ArrayXd w_p_arr = n_k_v.array() * p_k_arr * (1.0 - p_k_arr);
	VectorXd score_p = (yT_v.array() - n_k_v.array() * p_k_arr).matrix();
	score[1] += score_p.sum();
	if (p > 0) score.tail(p).noalias() += X_diff_v.transpose() * score_p;

	VectorXd w_p_vec = w_p_arr.matrix();
	info(1, 1) += w_p_vec.sum();
	if (p > 0) {
		VectorXd Xdw = X_diff_v.transpose() * w_p_vec;
		info.block(1, 2, 1, p).noalias() += Xdw.transpose();
		info.block(2, 1, p, 1).noalias() += Xdw;
		info.block(2, 2, p, p).noalias() += weighted_crossprod(X_diff_v, w_p_vec);
	}

	VectorXd eta_r = VectorXd::Constant(nR, beta_0) + beta_T * w_r;
	if (p > 0) eta_r.noalias() += X_r * beta_xs;
	VectorXd mu_r = eta_r.array().exp();
	VectorXd score_r = y_r - mu_r;
	score[0] += score_r.sum();
	score[1] += score_r.dot(w_r);
	if (p > 0) score.tail(p).noalias() += X_r.transpose() * score_r;

	const double mu_sum = mu_r.sum();
	const double muw_sum = mu_r.dot(w_r);
	info(0, 0) += mu_sum;
	info(0, 1) += muw_sum;
	info(1, 0) += muw_sum;
	info(1, 1) += (mu_r.array() * w_r.array().square()).sum();
	if (p > 0) {
		VectorXd Xrmu = X_r.transpose() * mu_r;
		VectorXd Xrwmu = X_r.transpose() * mu_r.cwiseProduct(w_r);
		info.block(0, 2, 1, p).noalias() += Xrmu.transpose();
		info.block(2, 0, p, 1).noalias() += Xrmu;
		info.block(1, 2, 1, p).noalias() += Xrwmu.transpose();
		info.block(2, 1, p, 1).noalias() += Xrwmu;
		info.block(2, 2, p, p).noalias() += weighted_crossprod(X_r, mu_r);
	}

	return ScoreInfoResult{score, info};
}

static double cpoisson_combined_neg_loglik_cpp_impl(
	const Eigen::Ref<const Eigen::VectorXd>& yT_v,
	const Eigen::Ref<const Eigen::VectorXd>& n_k_v,
	const Eigen::Ref<const Eigen::MatrixXd>& X_diff_v,
	const Eigen::Ref<const Eigen::VectorXd>& y_r,
	const Eigen::Ref<const Eigen::VectorXd>& w_r,
	const Eigen::Ref<const Eigen::MatrixXd>& X_r,
	const Eigen::Ref<const Eigen::VectorXd>& params
) {
	const int nd = (int)yT_v.size();
	const int nR = (int)y_r.size();
	const int p  = (int)X_diff_v.cols();

	const double beta_0 = params[0];
	const double beta_T = params[1];
	const VectorXd beta_xs = params.tail(p);

	VectorXd eta_p = VectorXd::Constant(nd, beta_T);
	if (p > 0) eta_p.noalias() += X_diff_v * beta_xs;
	double loglik =
		(yT_v.array() * eta_p.array() - n_k_v.array() * log1pexp_array(eta_p.array())).sum();

	VectorXd eta_r = VectorXd::Constant(nR, beta_0) + beta_T * w_r;
	if (p > 0) eta_r.noalias() += X_r * beta_xs;
	loglik += (y_r.array() * eta_r.array() - eta_r.array().exp()).sum();
	for (int i = 0; i < nR; ++i) {
		loglik -= fast_lgamma(y_r[i] + 1.0);
	}
	return -loglik;
}

#ifndef EDI_CORE_ONLY
//' Combined Conditional-Poisson/Poisson Score, Standalone (C++)
//'
//' Computes the score vector (gradient of the log-likelihood) of the combined KK
//' matched-pair conditional-Poisson (conditional-Binomial) plus reservoir
//' marginal-Poisson model documented in full at
//' \code{\link{fast_cpoisson_combined_with_var_cpp}}, at arbitrary
//' caller-supplied \code{params_r} (not necessarily the MLE). Exported standalone
//' — independent of any optimizer run — for direct numerical diagnostics (e.g.
//' verifying convergence, or building a custom estimating-equation solver) at a
//' specific parameter value.
//'
//' @param yT_v_r Treated-subject outcome count per matched pair.
//' @param n_k_v_r Total (treated + control) outcome count per matched pair.
//' @param X_diff_v_r Covariate differences (treated minus control) between the
//'   members of each matched pair.
//' @param y_r_r Reservoir (unmatched) subjects' outcomes.
//' @param w_r_r Reservoir subjects' treatment indicators.
//' @param X_r_r Reservoir subjects' covariates.
//' @param params_r A numeric vector of model parameters at which to evaluate the score.
//' @return The score vector (gradient of the log-likelihood) at \code{params_r}.
//' @seealso \code{\link{get_cpoisson_combined_hessian_cpp}} for the corresponding
//'   Hessian at the same point; \code{\link{fast_cpoisson_combined_with_var_cpp}}
//'   for the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::VectorXd get_cpoisson_combined_score_cpp(
	const NumericVector& yT_v_r,
	const NumericVector& n_k_v_r,
	const NumericMatrix& X_diff_v_r,
	const NumericVector& y_r_r,
	const NumericVector& w_r_r,
	const NumericMatrix& X_r_r,
	const NumericVector& params_r
) {
	Eigen::Map<const Eigen::VectorXd> yT_v(yT_v_r.begin(), yT_v_r.size());
	Eigen::Map<const Eigen::VectorXd> n_k_v(n_k_v_r.begin(), n_k_v_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_diff_v(X_diff_v_r.begin(), X_diff_v_r.rows(), X_diff_v_r.cols());
	Eigen::Map<const Eigen::VectorXd> y_r(y_r_r.begin(), y_r_r.size());
	Eigen::Map<const Eigen::VectorXd> w_r(w_r_r.begin(), w_r_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_r(X_r_r.begin(), X_r_r.rows(), X_r_r.cols());
	Eigen::Map<const Eigen::VectorXd> params(params_r.begin(), params_r.size());

	ScoreInfoResult out = cpoisson_combined_score_info_cpp_impl(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, params);
	return out.score;
}

//' Combined Conditional-Poisson/Poisson Hessian, Standalone (C++)
//'
//' Computes the Hessian matrix of the log-likelihood of the combined KK
//' matched-pair conditional-Poisson (conditional-Binomial) plus reservoir
//' marginal-Poisson model documented in full at
//' \code{\link{fast_cpoisson_combined_with_var_cpp}}, at arbitrary
//' caller-supplied \code{params_r} (not necessarily the MLE). Internally reuses
//' the same score-and-information computation as
//' \code{\link{get_cpoisson_combined_score_cpp}} (a single shared routine
//' computes both at once) and returns the negative of the resulting information
//' matrix, i.e. the actual Hessian of the log-likelihood. Exported standalone —
//' independent of any optimizer run — for direct numerical diagnostics at a
//' specific parameter value.
//'
//' @param yT_v_r Treated-subject outcome count per matched pair.
//' @param n_k_v_r Total (treated + control) outcome count per matched pair.
//' @param X_diff_v_r Covariate differences (treated minus control) between the
//'   members of each matched pair.
//' @param y_r_r Reservoir (unmatched) subjects' outcomes.
//' @param w_r_r Reservoir subjects' treatment indicators.
//' @param X_r_r Reservoir subjects' covariates.
//' @param params_r A numeric vector of model parameters at which to evaluate the Hessian.
//' @return The Hessian matrix of the log-likelihood (the negative of the
//'   information matrix) at \code{params_r}.
//' @seealso \code{\link{get_cpoisson_combined_score_cpp}} for the corresponding
//'   gradient at the same point; \code{\link{fast_cpoisson_combined_with_var_cpp}}
//'   for the full model documentation.
//' @export
//' @keywords internal
// [[Rcpp::export]]
Eigen::MatrixXd get_cpoisson_combined_hessian_cpp(
	const NumericVector& yT_v_r,
	const NumericVector& n_k_v_r,
	const NumericMatrix& X_diff_v_r,
	const NumericVector& y_r_r,
	const NumericVector& w_r_r,
	const NumericMatrix& X_r_r,
	const NumericVector& params_r
) {
	Eigen::Map<const Eigen::VectorXd> yT_v(yT_v_r.begin(), yT_v_r.size());
	Eigen::Map<const Eigen::VectorXd> n_k_v(n_k_v_r.begin(), n_k_v_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_diff_v(X_diff_v_r.begin(), X_diff_v_r.rows(), X_diff_v_r.cols());
	Eigen::Map<const Eigen::VectorXd> y_r(y_r_r.begin(), y_r_r.size());
	Eigen::Map<const Eigen::VectorXd> w_r(w_r_r.begin(), w_r_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_r(X_r_r.begin(), X_r_r.rows(), X_r_r.cols());
	Eigen::Map<const Eigen::VectorXd> params(params_r.begin(), params_r.size());

	ScoreInfoResult out = cpoisson_combined_score_info_cpp_impl(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, params);
	return -out.info;
}
#endif // EDI_CORE_ONLY

edi::ResultMap fast_cpoisson_combined_internal(
	const Eigen::Ref<const Eigen::VectorXd>& yT_v,       // treated count per valid pair (nd)
	const Eigen::Ref<const Eigen::VectorXd>& n_k_v,      // total count per valid pair (nd)
	const Eigen::Ref<const Eigen::MatrixXd>& X_diff_v,   // covariate diffs (nd x p; p=0 valid)
	const Eigen::Ref<const Eigen::VectorXd>& y_r,        // reservoir outcomes (nR)
	const Eigen::Ref<const Eigen::VectorXd>& w_r,        // reservoir treatment indicator (nR)
	const Eigen::Ref<const Eigen::MatrixXd>& X_r,        // reservoir covariates (nR x p)
	int    maxit = 100,
	double tol   = 1e-8,
	std::optional<Eigen::VectorXi> fixed_idx = std::nullopt,
	std::optional<Eigen::VectorXd> fixed_values = std::nullopt,
	std::optional<Eigen::MatrixXd> warm_start_fisher_info = std::nullopt,
	std::optional<Eigen::VectorXd> warm_start_params = std::nullopt,
	std::optional<Eigen::VectorXd> warm_start_beta = std::nullopt,
	bool estimate_only = false
) {
	const int nd = (int)yT_v.size();
	const int nR = (int)y_r.size();
	const int p  = (int)X_diff_v.cols();
	const int np = p + 2;              // beta_0, beta_T, beta_xs (p)

	// ---- Initialise params -----------------------------------------------
	VectorXd params = VectorXd::Zero(np);

	if (warm_start_params.has_value()) {
		params = *warm_start_params;
		if (params.size() != np) throw std::invalid_argument("warm_start_params size mismatch");
	} else if (warm_start_beta.has_value()) {
		VectorXd sb = *warm_start_beta;
		if (sb.size() == np) {
			params = sb;
		} else if (sb.size() == p + 1) {
			// Assume [beta_T, beta_xs]
			params.tail(p + 1) = sb;
		}
	} else {
		if (nR > 0) params[0] = std::log(std::max(1.0, y_r.mean()));
	}

	FixedParamSpec fixed_spec = make_fixed_param_spec(np, fixed_idx, fixed_values);
	for (int k = 0; k < (int)fixed_spec.fixed_idx.size(); ++k) {
		params[fixed_spec.fixed_idx[k]] = fixed_spec.fixed_values[k];
	}

	VectorXd grad(np);
	MatrixXd H(np, np);
	bool converged = false;
	int iterations_run = 0;
	double last_grad_norm = std::numeric_limits<double>::quiet_NaN();

	for (int iter = 0; iter < maxit; ++iter) {
		iterations_run = iter + 1;
		edi_check_R_user_interrupt_every(iter);
		const double  beta_0  = params[0];
		const double  beta_T  = params[1];
		const VectorXd beta_xs = params.tail(p);

		grad.setZero();
		H.setZero();

        if (iter == 0 && warm_start_fisher_info.has_value()) {
            H = *warm_start_fisher_info;
            if (H.rows() != np || H.cols() != np) throw std::invalid_argument("warm_start_fisher_info must be a (p+2) x (p+2) matrix");
            
            // Still need to compute gradient
            VectorXd eta_p = VectorXd::Constant(nd, beta_T);
            if (p > 0) eta_p.noalias() += X_diff_v * beta_xs;
            ArrayXd  p_k_arr  = plogis_array(eta_p.array());
            VectorXd resid_p  = (n_k_v.array() * p_k_arr - yT_v.array()).matrix();
            grad[1] += resid_p.sum();
            if (p > 0) grad.tail(p).noalias() += X_diff_v.transpose() * resid_p;

            VectorXd eta_r = VectorXd::Constant(nR, beta_0) + beta_T * w_r;
            if (p > 0) eta_r.noalias() += X_r * beta_xs;
            VectorXd mu_r   = eta_r.array().exp();
            VectorXd score_r = y_r - mu_r;
            grad[0] -= score_r.sum();
            grad[1] -= score_r.dot(w_r);
            if (p > 0) grad.tail(p).noalias() -= X_r.transpose() * score_r;
        } else {
            // ---- Pair component (conditional Poisson) -------------------------
            // X_pairs_eff row k = [0, 1, X_diff_v[k,:]]  →  cols 1..np-1 only
            VectorXd eta_p = VectorXd::Constant(nd, beta_T);
            if (p > 0) eta_p.noalias() += X_diff_v * beta_xs;

            // Logistic probabilities and Fisher weights
            ArrayXd  p_k_arr  = plogis_array(eta_p.array());
            ArrayXd  w_p_arr  = n_k_v.array() * p_k_arr * (1.0 - p_k_arr);
            VectorXd resid_p  = (n_k_v.array() * p_k_arr - yT_v.array()).matrix();

            // Gradient contributions from pairs  (d(-L)/d beta_T and d beta_xs)
            grad[1] += resid_p.sum();
            if (p > 0) grad.tail(p).noalias() += X_diff_v.transpose() * resid_p;

            // Fisher block H[1..np-1, 1..np-1]:
            //   [1 | X_diff_v]' * diag(w_p) * [1 | X_diff_v]
            VectorXd w_p_vec = w_p_arr.matrix();
            H(1, 1) += w_p_vec.sum();
            if (p > 0) {
                VectorXd Xdw = X_diff_v.transpose() * w_p_vec;        // p-vector
                H.block(1, 2, 1, p).noalias() += Xdw.transpose();
                H.block(2, 1, p, 1).noalias() += Xdw;
                H.block(2, 2, p, p).noalias() += weighted_crossprod(X_diff_v, w_p_vec);
            }

            // ---- Reservoir component (marginal Poisson) -----------------------
            // X_res_eff row i = [1, w_r[i], X_r[i,:]]
            VectorXd eta_r = VectorXd::Constant(nR, beta_0) + beta_T * w_r;
            if (p > 0) eta_r.noalias() += X_r * beta_xs;

            VectorXd mu_r   = eta_r.array().exp();
            VectorXd resid_r = mu_r - y_r;

            // Gradient contributions from reservoir
            grad[0] += resid_r.sum();
            grad[1] += resid_r.dot(w_r);
            if (p > 0) grad.tail(p).noalias() += X_r.transpose() * resid_r;

            // Fisher block H += [1|w_r|X_r]' * diag(mu_r) * [1|w_r|X_r]
            const double mu_sum  = mu_r.sum();
            const double muw_sum = mu_r.dot(w_r);
            H(0, 0) += mu_sum;
            H(0, 1) += muw_sum;
            H(1, 0) += muw_sum;
            H(1, 1) += (mu_r.array() * w_r.array().square()).sum();
            if (p > 0) {
                VectorXd Xrmu  = X_r.transpose() * mu_r;
                VectorXd Xrwmu = X_r.transpose() * mu_r.cwiseProduct(w_r);
                H.block(0, 2, 1, p).noalias() += Xrmu.transpose();
                H.block(2, 0, p, 1).noalias() += Xrmu;
                H.block(1, 2, 1, p).noalias() += Xrwmu.transpose();
                H.block(2, 1, p, 1).noalias() += Xrwmu;
                H.block(2, 2, p, p).noalias() += weighted_crossprod(X_r, mu_r);
            }
        }

		// Gradient-norm-based convergence check (optimizer_diagnostics_report.md
		// TODO-4), added ahead of the existing step-size fallback below --
		// this loop previously had no explicit gradient check at all.
		last_grad_norm = grad.norm();
		if (last_grad_norm < tol) {
			converged = true;
			break;
		}

		// ---- Newton step over free parameters ----------------------------
		VectorXd delta_full = VectorXd::Zero(np);
		if (fixed_spec.free_idx.size() > 0) {
			MatrixXd H_free = subset_matrix(H, fixed_spec.free_idx, fixed_spec.free_idx);
			VectorXd grad_free(fixed_spec.free_idx.size());
			for (int k = 0; k < (int)fixed_spec.free_idx.size(); ++k) grad_free[k] = grad[fixed_spec.free_idx[k]];
			VectorXd delta_free = H_free.ldlt().solve(grad_free);
			for (int k = 0; k < (int)fixed_spec.free_idx.size(); ++k) {
				delta_full[fixed_spec.free_idx[k]] = delta_free[k];
				params[fixed_spec.free_idx[k]] -= delta_free[k];
			}
		}
		for (int k = 0; k < (int)fixed_spec.fixed_idx.size(); ++k) {
			params[fixed_spec.fixed_idx[k]] = fixed_spec.fixed_values[k];
		}

		if (delta_full.norm() < tol) {
			// Step-size-only exit: last_grad_norm above (checked at the top
			// of this same iteration) is already known >= tol, so leaving
			// `converged` false here is correct under the uniform
			// gradient-norm rule (optimizer_diagnostics_report.md TODO-4) --
			// unlike other fitters in this codebase, the gradient isn't
			// recomputed post-step here (this loop's per-iteration gradient
			// computation is comparatively expensive, folded into the same
			// pass as the Fisher-information block), so a fit that stalls on
			// step size just short of a small-enough gradient is reported
			// as a distinct "stalled, not converged, not out of iterations"
			// case rather than optimistically marked converged.
			break;
		}
	}

	const bool hit_iteration_cap = (iterations_run >= maxit) && !converged;

	if (estimate_only) {
		return edi::ResultMap()
			.set("b", params)
			.set("params", params)
			.set("converged", converged)
			.set("num_iter", iterations_run)
			.set("hit_iteration_cap", hit_iteration_cap)
			.set("gradient_norm", last_grad_norm);
	}

	// ---- Extract Var(beta_T) from H^{-1}[1,1] (1-based index 2) ---------
	ScoreInfoResult final_si = cpoisson_combined_score_info_cpp_impl(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, params);
	VectorXd score = final_si.score;
	MatrixXd info = final_si.info;
	MatrixXd info_free = subset_matrix(info, fixed_spec.free_idx, fixed_spec.free_idx);
	int free_2 = -1;
	for (int jj = 0; jj < (int)fixed_spec.free_idx.size(); ++jj)
		if (fixed_spec.free_idx[jj] == 1) { free_2 = jj + 1; break; }
	double ssq_b_j = (np >= 2 && free_2 > 0) ? compute_diagonal_inverse_entry(info_free, free_2) : std::numeric_limits<double>::quiet_NaN();
	double neg_loglik = cpoisson_combined_neg_loglik_cpp_impl(yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, params);

	Eigen::MatrixXd neg_info = -info;
	return edi::ResultMap()
		.set("b", params)
		.set("params", params)
		.set("ssq_b_j", ssq_b_j)
		.set("score", score)
		.set("observed_information", info)
		.set("fisher_information", info)
		.set("information", info)
		.set("information_type", std::string("fisher"))
		.set("hessian", neg_info)
		.set("neg_loglik", neg_loglik)
		.set("neg_ll", neg_loglik)
		.set("loglik", std::isfinite(neg_loglik) ? -neg_loglik : std::numeric_limits<double>::quiet_NaN())
		.set("converged", converged)
		.set("num_iter", iterations_run)
		.set("hit_iteration_cap", hit_iteration_cap)
		.set("gradient_norm", last_grad_norm);
}

#ifndef EDI_CORE_ONLY
//' Fast Combined Conditional-Poisson + Poisson Regression for KK Matched-Pair/
//' Reservoir Designs, with Variance (C++ Backend)
//'
//' Jointly fits a single treatment-effect coefficient \eqn{\beta_T} (and shared
//' covariate effects \eqn{\beta_{xs}}) across two structurally different count
//' likelihoods at once — the matched-pair (conditional Poisson) component from
//' subjects paired on-the-fly by a KK matching design (e.g.
//' \code{\link[EDI:DesignSeqOneByOneKK14]{DesignSeqOneByOneKK14}}) and the
//' marginal Poisson component from unmatched "reservoir" subjects — rather than
//' fitting the two subsets separately and combining estimates afterward (as an
//' inverse-variance-weighted combination does elsewhere in the package). This
//' one-likelihood joint fit is what backs
//' \code{InferenceCountKKCondPoissonOneLik}-style estimators.
//'
//' @details
//' \strong{Matched-pair component (conditional Poisson).} For pair \eqn{k} with
//' total count \eqn{n_k} (sum of both members' counts) and treated-member count
//' \eqn{y_{T,k}}, conditioning on \eqn{n_k} (the sufficient statistic that
//' eliminates the pair's nuisance baseline rate) reduces the joint Poisson
//' likelihood of the pair to a Binomial: \eqn{y_{T,k} \mid n_k \sim
//' \mathrm{Binomial}(n_k, p_k)}, \eqn{p_k = \mathrm{logit}^{-1}(\beta_T +
//' x_{\Delta,k}^\top \beta_{xs})}, where \eqn{x_{\Delta,k}} is the pair's
//' covariate \emph{difference} (treated minus control). This is exactly the
//' count-response analog of conditional logistic regression for matched pairs —
//' no per-pair intercept is estimated (it is conditioned out entirely), so only
//' \eqn{\beta_T} and \eqn{\beta_{xs}} appear in this component.
//'
//' \strong{Reservoir component (marginal Poisson).} Unmatched reservoir subjects
//' contribute an ordinary Poisson log-linear likelihood,
//' \eqn{y_i \sim \mathrm{Poisson}(\mu_i)}, \eqn{\log \mu_i = \beta_0 + w_i \beta_T +
//' x_i^\top \beta_{xs}}, sharing the \emph{same} \eqn{\beta_T} and
//' \eqn{\beta_{xs}} as the pair component but additionally estimating an
//' intercept \eqn{\beta_0} (which the conditional pair likelihood has no use
//' for).
//'
//' \strong{Combined likelihood and optimization.} The total log-likelihood is the
//' simple sum of the pair (conditional Poisson/Binomial) and reservoir (Poisson)
//' log-likelihoods, jointly maximized over \code{c(beta_0, beta_T, beta_xs)}
//' (length \code{p + 2}) via Newton's method using the analytic Fisher
//' information as the Hessian (quadratic convergence near the optimum, typically
//' very few iterations). \code{fixed_idx}/\code{fixed_values} hold specific
//' parameters fixed rather than estimated; \code{warm_start_params} (full vector)
//' or \code{warm_start_beta} (either the full vector, or just
//' \code{c(beta_T, beta_xs)} when of length \code{p + 1}, in which case
//' \code{beta_0} is initialized separately) seed the optimizer, with a
//' log-mean-based default cold start for \code{beta_0} when neither is supplied.
//'
//' \strong{Variance.} \code{ssq_b_j} is the variance of \eqn{\hat\beta_T}
//' specifically (index 1, 0-based, in the parameter layout — the package's usual
//' single-treatment-coefficient convention), obtained via a targeted diagonal
//' inverse of the observed/Fisher information restricted to free parameters;
//' \code{NA} if \eqn{\beta_T} was itself fixed via \code{fixed_idx}.
//'
//' \strong{Estimate-only mode.} If \code{estimate_only = TRUE}, optimization
//' still runs to convergence but the score/information/variance computation is
//' skipped entirely, returning only \code{b}, \code{params}, and
//' \code{converged}.
//'
//' @param yT_v_r Numeric vector of length \eqn{n_{\mathrm{pairs}}}: the treated
//'   member's count for each matched pair.
//' @param n_k_v_r Numeric vector of length \eqn{n_{\mathrm{pairs}}}: the total
//'   (treated + control) count for each matched pair.
//' @param X_diff_v_r Numeric matrix, \eqn{n_{\mathrm{pairs}} \times p}: each
//'   pair's covariate difference (treated minus control); \eqn{p = 0} (zero
//'   columns) is valid (no covariate adjustment).
//' @param y_r_r Numeric vector of length \eqn{n_R}: reservoir subjects' counts.
//' @param w_r_r Numeric vector of length \eqn{n_R} with values in \code{{0, 1}}:
//'   reservoir subjects' treatment indicators.
//' @param X_r_r Numeric matrix, \eqn{n_R \times p}: reservoir subjects'
//'   covariates (same \eqn{p} as \code{X_diff_v_r}).
//' @param maxit Maximum number of Newton iterations.
//' @param tol Convergence tolerance (on the norm of the parameter update step).
//' @param fixed_idx Optional integer indices (into the
//'   \code{c(beta_0, beta_T, beta_xs)} parameter layout) of parameters to hold
//'   fixed rather than estimate.
//' @param fixed_values Optional values to fix the parameters named by
//'   \code{fixed_idx} at.
//' @param warm_start_fisher_info Optional initial Fisher Information matrix (over
//'   the full \code{p + 2} parameters) to warm-start the first Newton iteration.
//' @param warm_start_params Optional starting values for the full parameter
//'   vector \code{c(beta_0, beta_T, beta_xs)}.
//' @param warm_start_beta Optional starting values for just
//'   \code{c(beta_T, beta_xs)} (length \code{p + 1}); \code{beta_0} is still
//'   initialized separately. Ignored if \code{warm_start_params} is supplied.
//' @param estimate_only Logical; if \code{TRUE}, skip score/information/variance
//'   computation after optimization (see Details).
//' @return A list with components \code{b}/\code{params} (the fitted
//'   \code{c(beta_0, beta_T, beta_xs)} vector), \code{converged} (logical), and,
//'   unless \code{estimate_only = TRUE}: \code{ssq_b_j} (the variance of
//'   \eqn{\hat\beta_T}), \code{score} (the score vector at the fitted
//'   parameters), \code{observed_information}/\code{fisher_information}/
//'   \code{information} (three aliases for the same Fisher information matrix,
//'   also tagged by \code{information_type = "fisher"}), \code{hessian} (the
//'   Hessian of the negative log-likelihood, i.e. \code{-information}),
//'   \code{neg_loglik}/\code{neg_ll} (aliases for the combined negative
//'   log-likelihood at the fitted parameters), and \code{loglik} (its negation).
//' @seealso \href{https://en.wikipedia.org/wiki/Conditional_logistic_regression}{Conditional
//'   logistic regression} for the matched-pair likelihood's structural analog;
//'   \href{https://en.wikipedia.org/wiki/Poisson_regression}{Poisson regression}
//'   for the reservoir component; analogous Python API:
//'   \href{https://www.statsmodels.org/dev/generated/statsmodels.discrete.conditional_models.ConditionalPoisson.html}{statsmodels
//'   ConditionalPoisson} for the conditional-Poisson matched-set likelihood alone
//'   (not the combined pair+reservoir model implemented here).
//' @export
//' @keywords internal
// [[Rcpp::export]]
List fast_cpoisson_combined_with_var_cpp(
	const NumericVector& yT_v_r,       // treated count per valid pair (nd)
	const NumericVector& n_k_v_r,      // total count per valid pair (nd)
	const NumericMatrix& X_diff_v_r,   // covariate diffs (nd x p; p=0 valid)
	const NumericVector& y_r_r,        // reservoir outcomes (nR)
	const NumericVector& w_r_r,        // reservoir treatment indicator (nR)
	const NumericMatrix& X_r_r,        // reservoir covariates (nR x p)
	int    maxit = 100,
	double tol   = 1e-8,
	Rcpp::Nullable<Rcpp::IntegerVector> fixed_idx = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericVector> fixed_values = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericMatrix> warm_start_fisher_info = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericVector> warm_start_params = R_NilValue,
	Rcpp::Nullable<Rcpp::NumericVector> warm_start_beta = R_NilValue,
	bool estimate_only = false
) {
	Eigen::Map<const Eigen::VectorXd> yT_v(yT_v_r.begin(), yT_v_r.size());
	Eigen::Map<const Eigen::VectorXd> n_k_v(n_k_v_r.begin(), n_k_v_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_diff_v(X_diff_v_r.begin(), X_diff_v_r.rows(), X_diff_v_r.cols());
	Eigen::Map<const Eigen::VectorXd> y_r(y_r_r.begin(), y_r_r.size());
	Eigen::Map<const Eigen::VectorXd> w_r(w_r_r.begin(), w_r_r.size());
	Eigen::Map<const Eigen::MatrixXd> X_r(X_r_r.begin(), X_r_r.rows(), X_r_r.cols());

	edi::ResultMap res = fast_cpoisson_combined_internal(
		yT_v, n_k_v, X_diff_v, y_r, w_r, X_r, maxit, tol,
		nullable_to_optional<Eigen::VectorXi>(fixed_idx),
		nullable_to_optional<Eigen::VectorXd>(fixed_values),
		nullable_to_optional<Eigen::MatrixXd>(warm_start_fisher_info),
		nullable_to_optional<Eigen::VectorXd>(warm_start_params),
		nullable_to_optional<Eigen::VectorXd>(warm_start_beta),
		estimate_only);
	return edi::to_rcpp_list(res);
}
#endif // EDI_CORE_ONLY
