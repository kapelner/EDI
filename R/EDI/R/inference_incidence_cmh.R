#' CMH Blocked Incidence Inference
#'
#' Unadjusted blocked-design incidence inference using the simple mean-difference
#' point estimate with a randomization-based standard error.
#'
#' Legacy inference class. This class is retained for backwards compatibility
#' and is not comprehensively tested by the package comprehensive-test harness.
#'
#' @details
#' Internally, this class recodes treatment assignments to \eqn{w_i \in \{-1, +1\}}
#' (the package-wide convention is \eqn{\{0,1\}}; see \code{Design}). For a balanced
#' design the treatment-effect estimator is \eqn{\hat\tau = (2/n)\,\mathbf{y}'\mathbf{w}},
#' and since \eqn{E_w[\mathbf{y}'\mathbf{w}] = 0} for any balanced randomization the
#' standard error is
#' \deqn{SE(\hat\tau) = \frac{2}{n}\sqrt{\frac{\sum_k (\mathbf{y}'\mathbf{w}_k)^2}{K}}}{SE = (2/n) * sqrt(sum(ytw^2) / K)}
#' where \eqn{K} draws \eqn{\mathbf{w}_1,\ldots,\mathbf{w}_K} come from the design's
#' reference distribution.  Centering at the known zero mean (rather than the sample mean)
#' makes the denominator \eqn{K} rather than \eqn{K-1}.
#'
#' For blocking designs the expectation is evaluated exactly:
#' \deqn{SE(\hat\tau) = \frac{2}{n}\sqrt{\sum_b \frac{n_{1b}\,n_{0b}}{n_B - 1}}}{SE = (2/n) * sqrt(sum_b n1b*n0b / (nB - 1))}
#' where \eqn{n_{1b}, n_{0b}} are the numbers of positive and negative responses in
#' block \eqn{b} and \eqn{n_B} is the (common) block size.  This equals
#' \eqn{2\sqrt{V_{\rm CMH}}} where \eqn{V_{\rm CMH}} is the CMH variance from
#' Azriel et al. (2026), Equation 3.
#'
#' For non-blocking designs, the "balanced design" precondition above requires
#' the observed treatment allocation to be \emph{exactly} balanced
#' (\eqn{n_T = n_C}), not merely drawn from a \eqn{prob\_T = 0.5} mechanism --
#' e.g. plain Bernoulli randomization has \eqn{prob\_T = 0.5} but does not
#' guarantee an exactly balanced realized allocation. A warning (not an error)
#' is issued once, the first time the standard error is actually computed
#' (i.e. on the first confidence-interval / p-value / standard-error request,
#' not at construction or for estimate-only use), when this is violated --
#' erroring would make this class unusable with Bernoulli-style non-blocking
#' designs entirely; the warning tells the caller the reported standard error
#' may be miscalibrated.
#'
#' @examples
#' \dontrun{
#' \donttest{
#' seq_des = DesignSeqOneByOneRandomBlockSize$new(n = 20, response_type = 'incidence',
#'   strata_cols = 'x1')
#' for (i in 1:20) {
#'   seq_des$add_one_subject_to_experiment_and_assign(
#'     data.frame(x1 = factor(rep(1:2, 10)[i], levels=1:2)))
#' }
#' seq_des$add_all_subject_responses(rbinom(20, 1, 0.5))
#' inf = InferenceIncidCMH$new(seq_des)
#' inf$compute_estimate()
#' }
#' }
#' @export
InferenceIncidCMH = define_inference_class(
	classname = "InferenceIncidCMH",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "SimpleMeanDifference"),
	public = list(
		#' @description Uses the randomization-CI layer's two-sided p-value contract
		#'   (\code{InferenceRandCI}'s version, not \code{InferenceRand}'s): for
		#'   incidence responses this dispatches to the Zhang exact randomization
		#'   test where applicable rather than refusing outright, matching this
		#'   class's pre-migration old-ladder behavior (it inherited from
		#'   \code{InferenceAllSimpleMeanDiff}, whose own pin was already
		#'   corrected to \code{InferenceRandCI} -- see that file's identical
		#'   rationale). This class independently composes the same components
		#'   rather than truly inheriting \code{InferenceAllSimpleMeanDiff}, so it
		#'   had its own stale copy of the old \code{InferenceRand} pin, which
		#'   silently regressed Zhang dispatch for the non-blocking balanced-design
		#'   path -- found via
		#'   \code{test-incid-cmh-extended-robins-migration-golden.R}'s
		#'   \code{randomization_pval} case going from `"ok"` to `"unsupported"`.
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Wald confidence interval for the balanced-design/CMH risk-difference
		#'   estimate \eqn{\hat\tau}, using the randomization-based (blocking-design: exact CMH
		#'   variance formula; non-blocking design: Monte Carlo over \code{se_est_num_vectors}
		#'   design draws) standard error documented in the class \code{@details}. See
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}} for the shared Wald contract.
		#' @param alpha The confidence level in the computed confidence interval is 1 -
		#'   \code{alpha}. The default is 0.05.
		#' @return A length-2 numeric vector \code{c(lower, upper)} on the risk-difference scale.
		compute_asymp_confidence_interval = function(alpha = 0.05){
			self$compute_estimate()
			private$get_standard_error()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Two-sided Wald p-value for \eqn{H_0: \tau = \code{delta}} vs.
		#'   \eqn{H_1: \tau \neq \code{delta}}, using the same randomization-based standard error
		#'   as \code{compute_asymp_confidence_interval()}.
		#' @param delta The null value of \eqn{\tau} to test against; 0 (the default) tests for
		#'   any treatment effect at all.
		#' @return Numeric scalar p-value in \eqn{[0, 1]}.
		compute_asymp_two_sided_pval = function(delta = 0){
			self$compute_estimate()
			private$get_standard_error()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Initialize Cochran-Mantel-Haenszel incidence inference,
		#'   validate the stratified binary-response design, and prepare the
		#'   stratum-adjusted test used by
		#'   \code{\link[EDI:InferenceIncidCMH]{InferenceIncidCMH}}.
		#' @param des_obj A completed design object.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param se_est_num_vectors For non-block designs, the number of randomization vectors
		#'   drawn from the design to estimate the standard error. Default \code{1000L}.
		#' @param verbose Logical. Whether to print progress messages.
		#' @return A new \code{InferenceIncidCMH} object.
		initialize = function(des_obj, model_formula = NULL, se_est_num_vectors = 5000L, verbose = FALSE){
			stop_if_design_incompatible(private$design_compatibility_reason, des_obj, list(
				cmh_requires_even_allocation_for_blocking_design = "InferenceIncidCMH requires even treatment allocation for blocking designs.",
				cmh_requires_equal_block_sizes = "InferenceIncidCMH requires equal block sizes for blocking designs.",
				cmh_requires_even_allocation = "InferenceIncidCMH requires even treatment allocation (prob_T = 0.5) for non-blocking designs."
			))
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
				assertCount(se_est_num_vectors, positive = TRUE)
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$se_est_num_vectors = as.integer(se_est_num_vectors)
		}
	),
	private = list(
		# Discovery-time counterpart of initialize()'s design-structure stop()s
		# above (even allocation; equal block sizes when blocking) -- these are
		# design-*structure* requirements infer_inference_response_types()/
		# requires_blocking_design have no vocabulary for (a design can be
		# blocking with unequal prob_T, or blocking with unequal block sizes,
		# and still pass both of those). Self/private-free so it's safe to call
		# unbound against a candidate des_obj before construction. See
		# infer_inference_design_compatibility_reason_fn() in
		# inference_class_registry.R.
		design_compatibility_reason = function(des_obj){
			if (isTRUE(des_obj$is_blocking_design())) {
				if (!isTRUE(des_obj$get_prob_T() == 0.5)) {
					return("cmh_requires_even_allocation_for_blocking_design")
				}
				block_sizes = as.integer(table(des_obj$get_block_ids()))
				if (length(block_sizes) > 1L && any(block_sizes != block_sizes[1L])) {
					return("cmh_requires_equal_block_sizes")
				}
			} else if (!isTRUE(des_obj$get_prob_T() == 0.5)) {
				return("cmh_requires_even_allocation")
			}
			NA_character_
		},
		se_est_num_vectors = NULL,
		warned_realized_imbalance = FALSE,
		supports_lik_ratio_param_bootstrap = function() FALSE,
		supports_likelihood_tests = function() FALSE,
		get_supported_testing_types_impl = function(){
			"wald"
		},
		get_standard_error = function(){
			if (!is.null(private$cached_values$cmh_s_beta_hat_T)) {
				se = private$cached_values$cmh_s_beta_hat_T
				if (is.finite(se) && se > 0) return(se)
				private$cache_nonestimable_se("cmh_standard_error_unavailable")
				return(NA_real_)
			}
			if (private$des_obj$is_blocking_design()) {
				private$cached_values$cmh_s_beta_hat_T = compute_cmh_block_se_cpp(
					private$des_obj_priv_int$y,
					private$des_obj$get_block_ids(),
					private$des_obj_priv_int$n
				)
			} else {
				# The SE formula's "for a balanced design" precondition (see @details) requires
				# E_w[y'w] = 0, which needs the *realized* observed allocation to be exactly
				# balanced -- prob_T = 0.5 alone only guarantees this in expectation (e.g. plain
				# Bernoulli randomization). Under realized imbalance, compute_estimate()'s group
				# mean-difference and this (2/n)*y'w-based SE describe different estimators, so
				# warn rather than silently reporting a miscalibrated SE. Emitted here (once, the
				# first time the SE is actually computed) rather than at construction, so
				# estimate-only use and construction-only sweeps (InferenceSuite discovery,
				# the introspection audit) stay quiet while any SE/CI/p-value consumer still
				# sees it -- and InferenceSuite records it in its per-row `warnings` column.
				n_T = sum(private$w)
				n_C = private$n - n_T
				if (n_T != n_C && !isTRUE(private$warned_realized_imbalance)) {
					private$warned_realized_imbalance = TRUE
					warning(
						"InferenceIncidCMH: this non-blocking design's realized treatment allocation ",
						"is not exactly balanced (n_T = ", n_T, ", n_C = ", n_C, "); the standard error ",
						"formula assumes exact balance and may be miscalibrated."
					)
				}
				# get_cmh_se_w_mat() is an optional blocking-layer precompute; after the
				# design-hierarchy rework non-blocking designs (e.g. DesignFixedBernoulli,
				# now Design -> DesignFixed with no blocking ancestor) no longer carry the
				# method at all, so calling it unconditionally was "attempt to apply
				# non-function" -- guard with is.function() and fall through to drawing
				# reference vectors from the design directly.
				precomp = if (is.function(private$des_obj$get_cmh_se_w_mat)) private$des_obj$get_cmh_se_w_mat() else NULL
				w_mat = if (!is.null(precomp)) precomp else private$des_obj$draw_ws_according_to_design(private$se_est_num_vectors)
				# Both sources return {0,1}; recode to signed {-1,+1} locally -- this
				# formula requires E_w[y'w] = 0 under any randomization, which only
				# holds for signed coding (see @details above).
				w_mat = private$get_w_signed(w_mat)
				ytw      = drop(private$y %*% w_mat)
				# With {-1,+1} encoding: τ̂ = (2/n)*y'w, so SE[τ̂] = (2/n)*SD[ytw].
				# E[y·w] = 0 exactly for all balanced designs, so the unbiased variance
				# estimator uses K (not K-1) in the denominator.
				K        = length(ytw)
				private$cached_values$cmh_s_beta_hat_T = 2 / private$n * sqrt(max(0, sum(ytw^2) / K))
			}
			if (!is.finite(private$cached_values$cmh_s_beta_hat_T) || private$cached_values$cmh_s_beta_hat_T <= 0) {
				private$cached_values$cmh_s_beta_hat_T = NA_real_
				private$cache_nonestimable_se("cmh_standard_error_unavailable")
				return(NA_real_)
			}
			private$cached_values$s_beta_hat_T = private$cached_values$cmh_s_beta_hat_T
			private$cached_values$df = NA_real_
			private$cached_values$cmh_s_beta_hat_T
		},
		get_degrees_of_freedom = function(){
			NA_real_
		}
	),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"initialize"
		),
		private = c(
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"compute_fast_bootstrap_distr",
			"compute_fast_randomization_distr",
			"compute_fast_rand_bootstrap_distr",
			"compute_rand_bootstrap_ci_affine_coefs",
			"shared",
			"supports_lik_ratio_param_bootstrap",
			"supports_likelihood_tests",
			"get_supported_testing_types_impl",
			"simulate_under_lik_null",
			"compute_brt_null_statistics_with_se",
			"get_likelihood_test_spec"
		)
	)
)
