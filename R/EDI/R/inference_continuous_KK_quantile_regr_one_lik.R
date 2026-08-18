#' Quantile Regression Combined-Likelihood Compound Estimator for KK Designs (Continuous)
#'
#' Fits the combined stacked quantile regression (matched-pair differences + reservoir)
#' using the treatment indicator and all recorded covariates for continuous responses.
#' Minimises the joint check-function loss over both data sources simultaneously.
#' Inference is based on the stacked combined-likelihood quantile-regression fit.
#'
#' @examples
#' \donttest{
#' seq_des = DesignSeqOneByOneKK14$new(n = 10, response_type = 'continuous')
#' for (i in 1:10) {
#'   seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
#' }
#' seq_des$add_all_subject_responses(rnorm(10))
#' inf = InferenceContinKKQuantileRegrOneLik$new(seq_des)
#' inf$compute_estimate()
#' }
#' @export
# Migrated 2026-08-18 (fix_inference_hierarchy.md "Full-Likelihood
# Estimators" / "KK And IVWC Estimators"): formerly a thin R6 leaf on the
# abstract base `InferenceAbstractKKQuantileRegrOneLik`; the machinery now
# arrives via the registered `KKQuantileRegrOneLik` component (which itself
# depends on `KKCompound` and `QuantileRandomizationCI` -- see
# inference_all_KK_quantile_regr_one_lik_abstract.R). `compute_rand_two_sided_
# pval` is pinned from `InferenceRand`, same rationale as every other
# continuous/survival KK migration this stretch.
InferenceContinKKQuantileRegrOneLik = define_inference_class(
	classname = "InferenceContinKKQuantileRegrOneLik",
	inherit = Inference,
	components = c("BayesianBootstrap", "Wald", "KKQuantileRegrOneLik"),
	metadata = list(likelihood_tier = "none"),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"initialize",
			"compute_estimate",
			"compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"compute_rand_confidence_interval",
			"approximate_bootstrap_distribution_beta_hat_T"
		),
		private = c(
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data",
			"compute_fast_randomization_distr",
			"assert_finite_se",
			"get_standard_error"
		)
	),
	public = list(
		# Pinned from InferenceRand -- same flattened-super$ rationale as every
		# other continuous/survival KK migration this stretch.
		compute_rand_two_sided_pval = InferenceRand$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize continuous-response KK combined-likelihood quantile-regression inference.
		#'   The shared stacked quantile-regression fit is documented in
		#'   \code{\link[EDI:InferenceAbstractKKQuantileRegrOneLik]{InferenceAbstractKKQuantileRegrOneLik}}.
		#' @param des_obj A DesignSeqOneByOne object whose entire n subjects
		#'   are assigned and response y is recorded within.
		#' @param  tau  			The quantile level for regression, strictly between 0 and 1. Default is 0.5.
		#' @param  verbose  		Whether to print progress messages.
		#' @examples
		#' set.seed(1)
		#' x_dat <- data.frame(
		#'   x1 = c(-1.2, -0.7, -0.2, 0.3, 0.8, 1.3, 1.8, 2.3),
		#'   x2 = c(0, 1, 0, 1, 0, 1, 0, 1)
		#' )
		#' seq_des <- DesignSeqOneByOneKK14$new(n = nrow(x_dat), response_type = "continuous", verbose =
		#' FALSE)
		#' for (i in seq_len(nrow(x_dat))) {
		#'   seq_des$add_one_subject_to_experiment_and_assign(x_dat[i, , drop = FALSE])
		#' }
		#' seq_des$add_all_subject_responses(c(1.2, 0.9, 1.5, 1.8, 2.1, 1.7, 2.6, 2.2))
		#' infer <- InferenceContinKKQuantileRegrOneLik$new(seq_des, verbose
		#' = FALSE)
		#' infer
		#'
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		initialize = function(des_obj, model_formula = NULL, tau = 0.5, verbose = FALSE){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "continuous")
			}
			# Calls the KKQuantileRegrOneLik component's shared init logic via
			# the free-function helper, not super$initialize() -- see
			# .init_kk_quantile_regr_one_lik()'s comment in
			# inference_all_KK_quantile_regr_one_lik_abstract.R (Lesson 1
			# corollary for two leaves sharing one component).
			.init_kk_quantile_regr_one_lik(self, private, super, des_obj, model_formula, tau, identity, verbose)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
		}
		# The pre-migration leaf's compute_estimate = function(estimate_only =
		# FALSE) super$compute_estimate() was a pure delegating passthrough with
		# no added logic (it did not even forward estimate_only) -- dropped
		# rather than declared as an override collision, letting the composed
		# KKQuantileRegrOneLik component's real compute_estimate win directly
		# (same reasoning as the Lesson 1 corollary: a component-level method
		# is not reachable via super$ in a flat composition, so a leaf override
		# that only ever forwarded to super was already dead weight even
		# pre-migration).
	)
)
