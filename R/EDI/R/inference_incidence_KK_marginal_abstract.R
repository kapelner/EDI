#' Abstract class for all-subject marginal incidence inference in KK designs
#'
#' @keywords internal
InferenceAbstractKKMarginalIncid = define_inference_class(
	classname = "InferenceAbstractKKMarginalIncid",
	inherit = Inference,
	# 2026-08-19 (fix_inference_hierarchy.md "Full-Likelihood Estimators",
	# "ModifiedPoisson full-likelihood migration"): flipped from the
	# raw-splice `utils::modifyList(as.list(InferenceMixinKKPassThrough$
	# public/private), list(...))` state (manual harvesting of the
	# `KKPassThrough` raw source under `inherit = InferenceParamBootstrap`,
	# not even a `define_inference_class()` call) to composing the
	# registered `KKPassThrough` component directly, plus
	# `BayesianBootstrap`/`ParametricLikelihoodBootstrap` -- same
	# hybrid-state fix as every other KK GLMM/GEE/partial-likelihood class
	# migrated this stretch. `ParametricLikelihoodBootstrap` (not
	# Wald-only) because this base's real concrete descendant,
	# `InferenceAbstractKKModifiedPoisson`/`InferenceIncidKKModifiedPoisson`,
	# overrides `supports_likelihood_tests()`/`supports_lik_ratio_param_
	# bootstrap()` to `TRUE` with its own real `get_likelihood_test_spec()`/
	# `simulate_under_lik_null()` -- unlike `InferenceOrdinalKKCondAdjCatLogitRegr`/
	# `InferenceAbstractKKOrdinalCLMM` earlier this stretch, which both hard-
	# disable likelihood tests. This base's OWN `supports_likelihood_tests()`
	# stays `FALSE` (its default, overridden by the ModifiedPoisson
	# descendant); `InferenceIncidKKGCompAbstract` (a sibling descendant,
	# `likelihood_tier = "none"`, already migrated to its own
	# `define_inference_class()` composing `IncidenceKKGComputation`
	# directly per the "KK And IVWC Estimators" section) is deliberately
	# left as a real R6 generator still inheriting this class -- its own
	# component harvest (`inference_component_source_parts()`) only
	# captures its own directly-defined layer, not anything inherited, so
	# this migration does not affect it (verified: no `super$...()` calls
	# anywhere in inference_incidence_KK_gcomp_abstract.R).
	components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "KKPassThrough"),
	# capabilities = "likelihood_ratio" is required explicitly -- same
	# rationale as every class composing ParametricLikelihoodBootstrap
	# directly (bypassing StandardModelCache) this stretch.
	metadata = list(likelihood_tier = "full", capabilities = "likelihood_ratio"),
	public = list(
		# Pinned from InferenceRandCI (confirmed via the pre-migration R6
		# ancestor walk documented in test-incid-kk-gcomp-migration-golden.R:
		# this class's legacy ladder InferenceParamBootstrap -> ... ->
		# InferenceRandCI resolves to InferenceRandCI's version, which
		# handles incidence data; InferenceRand's raw version refuses it).
		compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval,
		#' @description Initialize the shared KK marginal-incidence inference base,
		#'   validate the binary matched/reservoir design, and prepare caches used by
		#'   \code{\link[EDI:InferenceAbstractKKMarginalIncid]{InferenceAbstractKKMarginalIncid}}.
		#' @param des_obj A completed \code{Design} object.
		#' @param model_formula   Optional formula for covariate adjustment. If \code{NULL} (default),
		#'   the formula from the design object is used and its pre-computed design matrix is
		#'   reused. If a formula is provided, a new design matrix is constructed from the
		#'   design's imputed covariates.
		#' @param verbose A flag indicating whether messages should be displayed.
		#' @param smart_cold_start_default   Whether to use smart cold start values.
		initialize = function(des_obj, model_formula = NULL,  verbose = FALSE, smart_cold_start_default = NULL){
			if (should_run_asserts()) {
				assertResponseType(des_obj$get_response_type(), "incidence")
			}
			super$initialize(des_obj, verbose = verbose, model_formula = model_formula, smart_cold_start_default = smart_cold_start_default)
			if (should_run_asserts()) {
				assertNoCensoring(private$any_censoring)
			}
			private$init_kk_passthrough(des_obj)
		}
	),
	private = list(
		is_a_kk_marginal_incid = function() TRUE,
		compute_basic_match_data = function() private$compute_basic_kk_match_data_impl(),
		supports_likelihood_tests = function() FALSE,
		get_covariate_names = function(){
			X = private$get_X()
			p = ncol(X)
			x_names = colnames(X)
			if (is.null(x_names)){
				x_names = paste0("x", seq_len(p))
			}
			x_names
		},
		get_cluster_ids = function(){
			des_priv = private$des_obj_priv_int
			m_vec = private$m
			if (is.null(m_vec)) m_vec = rep(NA_integer_, private$n)
			m_vec_int = as.integer(m_vec)
			m_vec_int[is.na(m_vec_int)] = 0L
			# Normalize design's m_vec the same way
			des_m = des_priv$m
			if (is.null(des_m)) des_m = rep(NA_integer_, private$n)
			des_m_int = as.integer(des_m)
			des_m_int[is.na(des_m_int)] = 0L
			# Check design-level cache (only when m_vec matches design's m_vec)
			if (!is.null(des_priv$cluster_id) && identical(m_vec_int, des_m_int)){
				return(des_priv$cluster_id)
			}
			# Check inference-level cache (for bootstrap resamples)
			if (!is.null(private$cached_values$cluster_id) &&
				identical(m_vec_int, private$cached_values$cluster_id_m_vec)){
				return(private$cached_values$cluster_id)
			}
			cluster_id = des_priv$compute_matching_cluster_ids(m_vec_int)
			# Store at design level if this is the original m_vec
			if (identical(m_vec_int, des_m_int)){
				des_priv$cluster_id = cluster_id
				des_priv$cluster_id_m_vec = m_vec_int
			} else {
				private$cached_values$cluster_id = cluster_id
				private$cached_values$cluster_id_m_vec = m_vec_int
			}
			cluster_id
		}
	),
	overrides = list(
		public = c(
			"compute_rand_two_sided_pval",
			"compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval",
			"get_supported_testing_types",
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_estimate_with_bootstrap_weights"
		),
		private = c(
			"compute_basic_match_data",
			"supports_likelihood_tests",
			"resolve_jackknife_unit",
			"jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"supports_reusable_bootstrap_worker",
			"create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"compute_bootstrap_worker_estimate",
			"get_supported_testing_types_impl",
			"compute_treatment_estimate_during_randomization_inference",
			"get_standard_error",
			"get_degrees_of_freedom",
			"assert_finite_se",
			"supports_lik_ratio_param_bootstrap",
			"supports_information_preference",
			"supports_observed_information",
			"get_supported_information_preferences_impl",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"get_likelihood_test_spec",
			"simulate_under_lik_null",
			"shared",
			"get_complexity_tier"
		)
	)
)
