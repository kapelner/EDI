#' Extended Robins Blocked Incidence Inference
#'
#' Unadjusted blocked-design incidence inference using the simple mean-difference
#' point estimate with a block-stratified standard error.
#'
#' Legacy inference class. This class is retained for backwards compatibility
#' and is not comprehensively tested by the package comprehensive-test harness.
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
#' inf = InferenceIncidExtendedRobins$new(seq_des)
#' inf$compute_estimate()
#' }
#' }
#' @export
InferenceIncidExtendedRobins = define_inference_class(
	classname = "InferenceIncidExtendedRobins",
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
		#'   had its own stale copy of the old \code{InferenceRand} pin (same bug
		#'   as \code{InferenceIncidWald}/\code{InferenceIncidCMH}, fixed
		#'   alongside them even though this class's own golden test's design
		#'   doesn't happen to trigger the Zhang-eligible path that would have
		#'   caught it).
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Uses the shared asymptotic confidence-interval contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param alpha Numeric. Significance level (default 0.05).
		compute_asymp_confidence_interval = function(alpha = 0.05){
			private$get_standard_error()
			private$compute_z_or_t_ci_from_s_and_df(alpha)
		},
		#' @description Uses the shared asymptotic two-sided p-value contract; see
		#'   \code{\link[EDI:InferenceAsymp]{InferenceAsymp}}.
		#' @param delta Numeric. Null treatment effect value (default 0).
		compute_asymp_two_sided_pval = function(delta = 0){
			private$get_standard_error()
			private$compute_z_or_t_two_sided_pval_from_s_and_df(delta)
		},
		#' @description Initialize Extended Robins blocked-design incidence inference.
		#' @param des_obj A completed design object.
		#' @param model_formula Optional formula for covariate adjustment.
		#' @param verbose Logical. Whether to print progress messages.
		#' @return A new \code{InferenceIncidExtendedRobins} object.
		initialize = function(des_obj, model_formula = NULL, verbose = FALSE){
			if (!des_obj$is_blocking_design()) {
				stop("InferenceIncidExtendedRobins requires a blocking design with equal block sizes and even allocation.")
			}
			if (des_obj$get_prob_T() != 0.5) {
				stop("InferenceIncidExtendedRobins requires a blocking design with even allocation.")
			}
			block_ids = des_obj$get_block_ids()
			block_sizes = as.integer(table(block_ids))
			if (length(block_sizes) > 1L && any(block_sizes != block_sizes[1L])) {
				stop("InferenceIncidExtendedRobins requires a blocking design with equal block sizes.")
			}

			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		}
	),
	private = list(
		requires_blocking_design = function() TRUE,
		# Discovery-time counterpart of initialize()'s design-structure stop()s
		# above (even allocation; equal block sizes) -- requires_blocking_design
		# = TRUE above already covers "blocking or not" generically, but even
		# allocation and equal block sizes are structure requirements neither
		# that flag nor infer_inference_response_types() has vocabulary for.
		# Self/private-free so it's safe to call unbound against a candidate
		# des_obj before construction (a non-blocking des_obj is already
		# filtered out by requires_blocking_design before this would run, but
		# this stays defensive and correct either way). See
		# infer_inference_design_compatibility_reason_fn() in
		# inference_class_registry.R.
		design_compatibility_reason = function(des_obj){
			if (!isTRUE(des_obj$is_blocking_design())) {
				return("extended_robins_requires_blocking_design")
			}
			if (!isTRUE(des_obj$get_prob_T() == 0.5)) {
				return("extended_robins_requires_even_allocation")
			}
			block_sizes = as.integer(table(des_obj$get_block_ids()))
			if (length(block_sizes) > 1L && any(block_sizes != block_sizes[1L])) {
				return("extended_robins_requires_equal_block_sizes")
			}
			NA_character_
		},
		supports_lik_ratio_param_bootstrap = function() FALSE,
		supports_likelihood_tests = function() FALSE,
		get_supported_testing_types_impl = function(){
			"wald"
		},
		get_standard_error = function(){
			if (!is.null(private$cached_values$robins_s_beta_hat_T)) {
				se = private$cached_values$robins_s_beta_hat_T
				if (is.finite(se) && se > 0) return(se)
				private$cache_nonestimable_se("extended_robins_standard_error_unavailable")
				return(NA_real_)
			}
			# private$w is already {0,1} (identical to des_obj$get_w() -- both read the
			# same observed assignment); recode to signed {-1,+1} locally since the C++
			# kernel's input contract requires it (see cmh_speedups.cpp).
			private$cached_values$robins_s_beta_hat_T = compute_extended_robins_block_se_cpp(
				private$des_obj_priv_int$y,
				private$get_w_signed(private$w),
				private$des_obj$get_block_ids(),
				private$des_obj_priv_int$n
			)
			if (!is.finite(private$cached_values$robins_s_beta_hat_T) || private$cached_values$robins_s_beta_hat_T <= 0) {
				private$cached_values$robins_s_beta_hat_T = NA_real_
				private$cache_nonestimable_se("extended_robins_standard_error_unavailable")
				return(NA_real_)
			}
			private$cached_values$s_beta_hat_T = private$cached_values$robins_s_beta_hat_T
			private$cached_values$df = NA_real_
			private$cached_values$robins_s_beta_hat_T
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
