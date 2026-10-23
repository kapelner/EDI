#' Pattern-1 file-split extension: quantile randomization confidence interval (Zhang combined)
#'
#' Provides \code{compute_rand_confidence_interval()} via Zhang's combined
#' test-inversion method for both Bernoulli (\eqn{m = 0}) and KK
#' matching-on-the-fly designs (\eqn{m > 0}). Composed into exactly one class
#' (\code{InferenceAbstractQuantileRandCI}) as a factory component.
#'
#' Registered as the \code{QuantileRandomizationCI} component and composed into
#' \code{InferenceAbstractQuantileRandCI}, its only host.
#' The capability flag \code{private$quantile_rand_ci} is set to \code{TRUE}.
#'
#' @keywords internal
#' @noRd
InferenceExtQuantileRandCI = list(
	public = list(
		#' @description Computes a randomization-based confidence interval via Zhang's combined test.
		#'
		#' @param alpha  				The confidence level is 1 - \code{alpha}.
		#' @param r  	Number of random sign-flips / permutations.
		#' @param pval_epsilon  		Bisection convergence tolerance.
		#' @param show_progress  		Ignored.
		#' @param ci_search_control Ignored for this Zhang-based CI implementation.
		#' @return 	A length-2 numeric vector giving the lower and upper CI boundary.
		compute_rand_confidence_interval = function(alpha = 0.05, r = 501, pval_epsilon = 1e-6, show_progress = TRUE, ci_search_control = NULL){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				assertNumeric(pval_epsilon, lower = .Machine$double.xmin, upper = 1)
				assertCount(r, positive = TRUE)
			}
			# TODO-119 / G6: same exact-0/1 refusal as the generic randomization CI,
			# raised outside the tryCatch below so it is not turned into NA bounds.
			if (inference_randomization_ci_exact_zero_one_refusal(
				private$des_obj$get_response_type(),
				inference_uses_model_scale_randomization_transform(self),
				private$y
			)) {
				inference_stop_rand_ci_exact_zero_one(class(self)[1L])
			}
			private$nsim_rand = as.integer(r)
			# v1.0.5 TODO-129 sweep: the sign-flip / permutation draws in
			# compute_rand_pval_matched_pairs()/compute_rand_pval_reservoir() came
			# from the caller's global RNG stream. Seed them like every other
			# randomization procedure (TODO-112: inference seed, else design seed;
			# caller's RNG restored on exit; no-op when unseeded).
			restore_draw_rng = private$seed_global_rng_for_draws()
			on.exit(restore_draw_rng(), add = TRUE)
			tryCatch(
				private$ci_exact_zhang_combined(alpha, pval_epsilon),
				error = function(e) c(NA_real_, NA_real_)
			)
		}
	),
	private = list(
		quantile_rand_ci = TRUE,
		nsim_rand = 499L,
		ci_exact_zhang_combined = function(alpha, pval_epsilon, combination_method = "Fisher"){
			est = self$compute_estimate()
			if (!is.finite(est)) return(c(NA_real_, NA_real_))
			KKstats = private$cached_values$KKstats
			m   = KKstats$m
			nRT = KKstats$nRT
			nRC = KKstats$nRC
			p_fn = function(delta_0){
				p_M = if (m > 0) private$compute_rand_pval_matched_pairs(delta_0) else NA_real_
				p_R = if (nRT > 0 && nRC > 0) private$compute_rand_pval_reservoir(delta_0) else NA_real_
				zhang_combine_exact_pvals(p_M, p_R, m, nRT, nRC, combination_method)
			}
			asym_ci = tryCatch(self$compute_asymp_confidence_interval(alpha = alpha), error = function(e) NULL)
			if (!is.null(asym_ci) && all(is.finite(asym_ci))){
				ci_width = asym_ci[2] - asym_ci[1]
				lo_bound = asym_ci[1] - 0.5 * ci_width
				hi_bound = asym_ci[2] + 0.5 * ci_width
			} else {
				se_approx = private$cached_values$s_beta_hat_T
				if (!is.null(se_approx) && is.finite(se_approx) && se_approx > 0){
					lo_bound = est - 10 * se_approx
					hi_bound = est + 10 * se_approx
				} else {
					lo_bound = est - 10
					hi_bound = est + 10
				}
			}
			c(
				zhang_bisect_ci_boundary(p_fn, inside = est, outside = lo_bound, pval_th = alpha, tol = pval_epsilon),
				zhang_bisect_ci_boundary(p_fn, inside = est, outside = hi_bound, pval_th = alpha, tol = pval_epsilon)
			)
		}
	)
)
