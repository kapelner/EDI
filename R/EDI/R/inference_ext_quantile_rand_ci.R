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
		compute_rand_confidence_interval = function(alpha = 0.05, r = 501, pval_epsilon = 0.005, show_progress = TRUE, ci_search_control = NULL){
			if (should_run_asserts()) {
				assertNumeric(alpha, lower = .Machine$double.xmin, upper = 1 - .Machine$double.xmin)
				assertNumeric(pval_epsilon, lower = .Machine$double.xmin, upper = 1)
				assertCount(r, positive = TRUE)
			}
			# Emergency stopgap (2026-09-17, user decision), same pattern as
			# compute_rand_confidence_interval()'s incidence-response stop()
			# in inference_all_abstract_rand_ci.R: this Zhang test-inversion
			# bisection requires private$compute_rand_pval_matched_pairs()/
			# compute_rand_pval_reservoir() from its host. KKQuantileRegrIVWC
			# supplies both (inference_all_KK_quantile_regr_ivwc_abstract.R);
			# KKQuantileRegrOneLik never does, so on
			# InferenceContinKKQuantileRegrOneLik/InferencePropKKQuantileRegrOneLik
			# p_fn() threw "attempt to apply non-function" on every bisection
			# step, silently caught by zhang_bisect_ci_boundary()'s tryCatch and
			# coerced to p_mid = 0 (always <= pval_th), which collapsed both
			# bounds onto the point estimate instead of erroring -- a raw
			# comprehensive_tests results audit (2026-09-16/17) found this
			# 100% zero-width across every affected row (~1644), ~0-1%
			# empirical coverage vs. the ~95% nominal target. Checked
			# structurally (not by class name) so any future host missing
			# these hooks fails the same way instead of silently returning a
			# wrong answer. See
			# R/package_metadata/new_feature_plans/fix_KKQuantileRegrOneLik_rand_ci.md.
			if (!is.function(private$compute_rand_pval_matched_pairs) || !is.function(private$compute_rand_pval_reservoir)) {
				stop(
					"Randomization confidence intervals are temporarily disabled for ",
					class(self)[1], " (2026-09-17): the Zhang test-inversion bisection this ",
					"class's compute_rand_confidence_interval() dispatches to requires ",
					"compute_rand_pval_matched_pairs()/compute_rand_pval_reservoir() from its ",
					"host, which this class's composition never supplies -- the bisection was ",
					"silently converging to a zero-width interval at the point estimate instead ",
					"of erroring. See R/package_metadata/new_feature_plans/",
					"fix_KKQuantileRegrOneLik_rand_ci.md.",
					call. = FALSE
				)
			}
			private$nsim_rand = as.integer(r)
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
