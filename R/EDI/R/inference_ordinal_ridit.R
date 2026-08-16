#' Ridit Analysis for Ordinal Responses
#'
#' Performs Ridit analysis (Relative to an Identified Distribution unit) for
#' comparing two groups on an ordinal scale. Every subject's category \eqn{k} is
#' converted to a \strong{ridit score} — its relative rank position within the
#' \strong{reference} distribution's empirical CDF: \eqn{r_k = F_{\mathrm{ref}}(k{-}1)
#' + \tfrac12 f_{\mathrm{ref}}(k)}, where \eqn{F_{\mathrm{ref}}} and
#' \eqn{f_{\mathrm{ref}}} are the reference group's empirical cumulative and
#' point probabilities. The \code{reference} distribution — controlled by the
#' \code{reference} constructor argument — may be the \strong{control} arm
#' (default), the \strong{treatment} arm, or the \strong{pooled} sample. The
#' treatment effect is the mean ridit score among treated subjects minus
#' \eqn{0.5} (the value it would take under the null of no group difference,
#' since a group's own ridit scores against itself as reference always average
#' to 0.5); this mean ridit score also has a direct interpretation as (an
#' estimate of) the probability that a randomly selected treated subject's
#' outcome exceeds a randomly selected reference-distribution subject's outcome
#' (a Mann-Whitney-type stochastic superiority probability), similar in spirit
#' to \code{\link[EDI:InferenceOrdinalJonckheereTerpstraTest]{InferenceOrdinalJonckheereTerpstraTest}}'s
#' superiority measure but referenced against a chosen distribution rather than
#' always symmetric between the two arms. Standard errors and p-values come
#' from \code{fast_ridit_analysis_cpp}'s asymptotic formula, not a resampling
#' approximation.
#'
#' @references Bross, I. D. J. (1958). "How to Use Ridit Analysis."
#'   \emph{Biometrics}, 14(1), 18-38, \doi{10.2307/2527727}, for the ridit
#'   transformation and its interpretation used here.
#'
#' @concept ridit analysis
#' @export
#' @examples
#' set.seed(1)
#' x_dat <- data.frame(
#'   x1 = c(-1.2, -0.7, -0.2, 0.3, 0.8, 1.3, 1.8, 2.3),
#'   x2 = c(0, 1, 0, 1, 0, 1, 0, 1)
#' )
#' seq_des <- DesignSeqOneByOneBernoulli$new(n = nrow(x_dat), response_type = "ordinal",
#'   verbose = FALSE)
#' for (i in seq_len(nrow(x_dat))) {
#'   seq_des$add_one_subject_to_experiment_and_assign(x_dat[i, , drop = FALSE])
#' }
#' seq_des$add_all_subject_responses(as.integer(c(1, 2, 2, 3, 3, 4, 4, 5)))
#' infer <- InferenceOrdinalRidit$
#'   new(seq_des, verbose = FALSE)
#' infer
#'
InferenceOrdinalRidit = define_inference_class(
	classname = "InferenceOrdinalRidit",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald"),
	public = list(
		#' @description Uses the shared randomization two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceRand]{InferenceRand}}.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize a Ridit analysis inference object for a
		#'   completed design with an ordinal, uncensored response.
		#' @param des_obj A DesignSeqOneByOne object whose entire n subjects are assigned and
		#'   response y is recorded within.
		#' @param reference The group to use as the "Identified Distribution" (reference).
		#'   Must be one of "control", "treatment", or "pooled". Default is "control".
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose A flag indicating whether messages should be displayed.
		#' @param max_resample_attempts Maximum number of times a single bootstrap replicate
		#'   may be redrawn when the drawn sample fails validity screening. If all attempts
		#'   fail the replicate is recorded as \code{NA}, silently reducing the effective \code{B}.
		#'   Must be a positive integer. Default \code{50L}.
		initialize = function(des_obj, model_formula = NULL, reference = "control", verbose = FALSE, max_resample_attempts = 50L){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "ordinal")
				assertChoice(reference, c("control", "treatment", "pooled"))
				assertCount(max_resample_attempts, positive = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			private$reference = reference
			private$max_resample_attempts = max_resample_attempts
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		},
		#' @description Returns the estimated treatment effect: the mean ridit
		#'   score among treated subjects minus 0.5 (see class documentation for
		#'   the full ridit-score definition and reference-distribution choice).
		#' @return The numeric estimate.
		#' @param estimate_only If TRUE, skip variance component calculations.
		compute_estimate = function(estimate_only = FALSE){
			private$shared(estimate_only = estimate_only)
			private$cached_values$beta_hat_T
		},
		#' @description Recomputes the ridit treatment estimate under subject/block
		#'   bootstrap weights: the reference distribution's category proportions
		#'   and every subject's ridit score are recomputed using the weights, then
		#'   the weighted mean ridit score among treated subjects (minus 0.5) is
		#'   returned. Used by the Bayesian bootstrap and related
		#'   weighted-resampling machinery. Always leaves the standard error and
		#'   degrees of freedom unavailable (\code{NA}) regardless of
		#'   \code{estimate_only} — this weighted path never computes the
		#'   asymptotic variance.
		#' @param subject_or_block_weights Subject-, block-, cluster-, or matched-set
		#'   bootstrap weights.
		#' @param estimate_only Present for interface parity; this method never
		#'   computes variance components regardless of its value.
		compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only = FALSE){
			row_weights = as.numeric(private$expand_subject_or_block_weights_to_row_weights(subject_or_block_weights))
			y = as.integer(private$y)
			w = as.integer(private$w)
			ok = is.finite(row_weights) & row_weights > 0 & is.finite(y) & is.finite(w)
			if (!any(ok)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			cat_vals = sort(unique(y[ok]))
			ref_idx = switch(
				private$reference,
				control = ok & (w == 0L),
				treatment = ok & (w == 1L),
				pooled = ok
			)
			if (!any(ref_idx)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			ref_total = sum(row_weights[ref_idx])
			if (!is.finite(ref_total) || ref_total <= 0) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			probs = vapply(cat_vals, function(k) sum(row_weights[ref_idx & y == k]) / ref_total, numeric(1))
			cum_prev = c(0, cumsum(probs))[seq_along(probs)]
			ridit_vals = cum_prev + 0.5 * probs
			names(ridit_vals) = as.character(cat_vals)
			scores = unname(ridit_vals[as.character(y)])
			t_idx = ok & (w == 1L)
			c_idx = ok & (w == 0L)
			if (!any(t_idx) || !any(c_idx)) {
				private$cached_values$beta_hat_T = NA_real_
				private$cached_values$s_beta_hat_T = NA_real_
				private$cached_values$df = NA_real_
				return(NA_real_)
			}
			mean_t = sum(row_weights[t_idx] * scores[t_idx]) / sum(row_weights[t_idx])
			mean_c = sum(row_weights[c_idx] * scores[c_idx]) / sum(row_weights[c_idx])
			private$cached_values$mean_ridit_t = mean_t
			private$cached_values$mean_ridit_c = mean_c
			private$cached_values$scores = scores
			private$cached_values$beta_hat_T = as.numeric(mean_t - 0.5)
			private$cached_values$s_beta_hat_T = NA_real_
			private$cached_values$df = NA_real_
			private$cached_values$beta_hat_T
		},
		#' @description Returns the mean ridit score among treated subjects (not
		#'   centered — this is the raw mean, unlike \code{$compute_estimate()}
		#'   which subtracts 0.5).
		#' @return The numeric Mean Ridit.
		get_mean_ridit_treatment = function(){
			private$shared()
			private$cached_values$mean_ridit_t
		},
		#' @description Returns each subject's individual ridit score (see class
		#'   documentation for the ridit-score formula), in subject order.
		#' @return A numeric vector of scores.
		get_ridit_scores = function(){
			private$shared()
			private$cached_values$scores
		},
		#' @description Computes the asymptotic confidence interval for the
		#'   treatment effect (mean ridit \eqn{- 0.5}), using
		#'   \code{fast_ridit_analysis_cpp}'s asymptotic standard error.
		#' @param alpha Significance level.
		#' @return A numeric vector of length 2.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$shared()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Computes a two-sided Wald p-value testing \eqn{H_0:
		#'   \text{mean ridit} - 0.5 = \code{delta}} (i.e. \code{delta = 0} tests
		#'   the null of no group difference, mean ridit \eqn{= 0.5}), using
		#'   \code{fast_ridit_analysis_cpp}'s asymptotic standard error.
		#' @param delta The null value (centered at 0, so delta=0 means Ridit=0.5).
		#' @return The p-value.
		compute_asymp_two_sided_pval = function(delta = 0){
			if (should_run_asserts()) {
				assertNumeric(delta)
			}
			private$shared()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		}
	),
	private = list(
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			if (!is.null(private[["custom_randomization_statistic_function"]]) || !is.null(private[["compiled_cpp_stat_fn"]])) return(NULL)
			# ordinal: no sharp-null shift supported
			if (delta != 0) return(NULL)
			# "smoothed" adds continuous Gaussian noise, which is not meaningful for integer
			# ordinal category codes; decline and let the R-level fallback (which truncates
			# via as.integer()) handle it, unchanged from before this kernel existed.
			if (length(rand_bootstrap_draws) > 0L && !is.null(rand_bootstrap_draws[[1L]][["smooth_noise"]])) return(NULL)
			mats = private$rand_bootstrap_draw_matrices(rand_bootstrap_draws)
			if (is.null(mats)) return(NULL)
			compute_ridit_rand_bootstrap_parallel_cpp(
				as.integer(y0_full), mats$i_mat, mats$w_mat, private$reference,
				private$n_cpp_threads(ncol(mats$w_mat))
			)
		},
		max_resample_attempts = 50L,
		shared = function(estimate_only = FALSE){
			if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
			if (!estimate_only && !is.null(private$cached_values$beta_hat_T) && is.null(private$cached_values$s_beta_hat_T)) {
				private$cached_values$beta_hat_T = NULL
			}
			res = fast_ridit_analysis_cpp(
				w = as.integer(private$w),
				y = as.integer(private$y),
				reference = private$reference
			)
			if (is.null(res) || length(res) == 0){
				private$cache_nonestimable_estimate("ordinal_ridit_fit_unavailable")
				return(invisible(NULL))
			}
			private$cached_values$mean_ridit_t = res$mean_ridit_t
			private$cached_values$mean_ridit_c = res$mean_ridit_c
			private$cached_values$beta_hat_T   = res$estimate
			private$cached_values$s_beta_hat_T = if (estimate_only) NA_real_ else res$se
			private$cached_values$scores       = res$scores
		},
		compute_fast_randomization_distr = function(y, permutations, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			if (delta != 0 || transform_responses != "none") return(NULL)
			compute_ridit_distr_parallel_cpp(
			        as.integer(y),
			        matrix(as.integer(permutations$w_mat), nrow = nrow(permutations$w_mat)),
			        private$reference,
			        private$n_cpp_threads(ncol(permutations$w_mat))
			)

		},
		compute_fast_bootstrap_distr = function(B, ...){
			if (!is.null(private[["custom_randomization_statistic_function"]])) return(NULL)
			# KK designs use design-aware resampling not available via these args; fall back to R loop.
			if (private$is_KK) return(NULL)
			# Simple (non-KK) bootstrap: args = (n, y, dead, w)
			args = list(...)
			max_resample_attempts = private$max_resample_attempts
			n = args[[1]]
			y = args[[2]]
			dead = args[[3]]
			w = args[[4]]
			# Generate bootstrap indices
			indices_mat = matrix(NA_integer_, nrow = n, ncol = B)
			for (b in 1:B) {
				attempt = 1
				repeat {
					i_b = sample(n, n, replace = TRUE)
					w_b = w[i_b]
					if (any(w_b == 1, na.rm = TRUE) && any(w_b == 0, na.rm = TRUE)) {
						indices_mat[, b] = i_b - 1L
						break
					}
					attempt = attempt + 1
					if (attempt > max_resample_attempts) break
				}
			}
			compute_ridit_bootstrap_parallel_cpp(
				as.integer(w),
				as.integer(y),
				indices_mat,
				private$reference,
				private$n_cpp_threads(B)
			)
		}
	),
	overrides = list(
		public = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_rand_two_sided_pval"
		),
		private = c(
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
		)
	),
	metadata = list(likelihood_tier = "none")
)
