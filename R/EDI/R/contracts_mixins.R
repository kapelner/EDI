#' Internal Mixin Host Contracts
#'
#' Pattern-1 mixins are lists spliced into an R6 class's \code{public} and
#' \code{private} lists. \code{EDI_MIXIN_CONTRACTS} documents the host-private
#' methods and state which a mixin requires but does not define itself.
#' Empty vectors mean that the mixin is self-contained (or is an intentionally
#' empty future extension point). These contracts are deliberately narrow: a
#' method supplied by the mixin itself is not repeated as a host requirement.
#'
#' Single-class-use extensions (\code{InferenceExt*}) are file-splits, not
#' reusable mixins, and are deliberately not tracked here -- this registry
#' exists to guard against silent method-name collisions when two or more
#' mixins are spliced into the same host, which cannot happen for an
#' extension spliced into exactly one class.
#'
#' \code{EDI_MIXIN_COMPOSITIONS} lists every base class that combines two or
#' more mixins. \code{EDI_MIXIN_ALLOWED_COLLISIONS} records the sole deliberate
#' overwrite: the compound KK mixin replaces the pass-through implementation of
#' \code{compute_basic_match_data()}. Tests use these objects to guard against
#' silent method-name overwrites as new mixins are added.
#'
#' @keywords internal
#' @noRd
EDI_MIXIN_CONTRACTS = list(
	InferenceMixinCordeiroFerrariApprox = list(
		file = "inference_mixin_cordeiro_ferrari_approx.R",
		private_methods = character(),
		private_state = character()
	),
	InferenceMixinKKGEEShared = list(
		file = "inference_mixin_kk_gee_shared.R",
		private_methods = c(
			"cache_nonestimable_estimate", "cache_nonestimable_se", "clear_nonestimable_state",
			"compute_z_or_t_ci_from_s_and_df", "compute_z_or_t_two_sided_pval_from_s_and_df",
			"create_design_matrix", "expand_subject_or_block_weights_to_row_weights",
			"fit_with_hardened_qr_column_dropping", "gee_family", "gee_response_type",
			"get_fit_warm_start_fisher", "get_fit_warm_start_for_length",
			"get_fit_warm_start_weights", "set_fit_warm_start", "shared_gee_dispatch"
		),
		private_state = c("any_censoring", "cached_values", "harden", "n", "w", "y")
	),
	InferenceMixinKKGLMMShared = list(
		file = "inference_mixin_kk_glmm_shared.R",
		private_methods = c(
			"cache_nonestimable_estimate", "compute_standard_error_from_information_matrix",
			"compute_z_or_t_ci_from_s_and_df", "compute_z_or_t_two_sided_pval_from_s_and_df",
			"create_design_matrix", "expand_subject_or_block_weights_to_row_weights",
			"fit_with_hardened_qr_column_dropping", "glmm_family", "glmm_response_type",
			"shared"
		),
		private_state = c("any_censoring", "cached_values", "harden", "n", "w", "y")
	),
	InferenceMixinKKPassThrough = list(
		file = "inference_mixin_kk_passthrough.R",
		private_methods = c(
			"assert_valid_bootstrap_type", "cache_nonestimable_estimate",
			"effective_parallel_cores",
			"expand_subject_or_block_weights_to_row_weights", "get_X", "has_private_method",
			"object_has_private_method", "par_lapply"
		),
		private_state = c("cached_values", "des_obj_priv_int", "has_match_structure", "n")
	),
	InferenceMixinKKPassThroughCompound = list(
		file = "inference_mixin_kk_passthrough_compound.R",
		private_methods = c("cache_nonestimable_estimate", "compute_basic_kk_match_data_impl"),
		private_state = c("cached_values", "has_match_structure")
	),
	InferenceMixinLemonteGradientApprox = list(
		file = "inference_mixin_lemonte_gradient_approx.R",
		private_methods = character(),
		private_state = character()
	),
	InferenceMixinOffOptimumLikelihoodEval = list(
		file = "inference_mixin_off_optimum_likelihood_eval.R",
		private_methods = c("get_default_information_source", "get_likelihood_test_spec"),
		private_state = character()
	)
)

EDI_MIXIN_COMPOSITIONS = list(
	InferenceKKPassThroughCompound = c(
		"InferenceMixinKKPassThrough", "InferenceMixinKKPassThroughCompound"
	),
	InferenceKKPassThroughCompoundNoParamBootstrap = c(
		"InferenceMixinKKPassThrough", "InferenceMixinKKPassThroughCompound"
	)
)

EDI_MIXIN_ALLOWED_COLLISIONS = list(
	InferenceKKPassThroughCompound = list(
		private = "compute_basic_match_data",
		public = character()
	),
	InferenceKKPassThroughCompoundNoParamBootstrap = list(
		private = "compute_basic_match_data",
		public = character()
	)
)

EDI_MIXIN_ALLOWED_OVERRIDES = list(
	InferenceKKPassThroughCompound = list(
		private = character(),
		public = c("approximate_bootstrap_distribution_beta_hat_T", "compute_estimate_with_bootstrap_weights")
	),
	InferenceKKPassThroughCompoundNoParamBootstrap = list(
		private = character(),
		public = c("approximate_bootstrap_distribution_beta_hat_T", "compute_estimate_with_bootstrap_weights")
	)
)

EDI_MIXIN_DEPENDENCIES = list(
	InferenceMixinKKPassThroughCompound = "InferenceMixinKKPassThrough"
)

EDI_LEGACY_MIXIN_COMPONENT_NAMES = c(
	InferenceMixinKKGEEShared = "KKGEE",
	InferenceMixinKKGLMMShared = "KKGLMM",
	InferenceMixinKKPassThrough = "KKPassThrough",
	InferenceMixinKKPassThroughCompound = "KKCompound",
	InferenceMixinOffOptimumLikelihoodEval = "OffOptimumLikelihoodEval"
)

EDI_INFERENCE_COMPONENTS = new.env(parent = emptyenv())

EDI_COMPONENT_ALLOWED_STATUSES = c("active", "scaffold")

EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS = c("none", "quasi", "partial", "full")

capability_requires = list(
	exact_test = list(),
	exact_binomial_incidence = list(
		capabilities = "exact_test"
	),
	exact_fisher_incidence = list(
		capabilities = "exact_test"
	),
	exact_zhang_incidence = list(
		capabilities = "exact_test"
	),
	randomization_test = list(),
	randomization_ci = list(
		capabilities = "randomization_test"
	),
	randomization_bootstrap = list(
		capabilities = c("randomization_test", "nonparametric_bootstrap")
	),
	# 2026-08-19 (inference_suite_inspect.md audit): same shape as
	# randomization_ci's own "capabilities = randomization_test" entry
	# above -- RandomizationBootstrapCI depends on RandomizationBootstrap,
	# so its capability requires that one.
	randomization_bootstrap_ci = list(
		capabilities = "randomization_bootstrap"
	),
	jackknife = list(),
	wald = list(),
	likelihood_tests = list(
		likelihood_tier = c("quasi", "partial", "full"),
		private_methods = "get_likelihood_test_spec"
	),
	likelihood_ratio = list(
		likelihood_tier = c("partial", "full"),
		private_methods = "get_likelihood_test_spec"
	),
	estimating_equation_likelihood_ratio = list(
		likelihood_tier = "quasi",
		private_methods = "get_likelihood_test_spec"
	),
	parametric_likelihood_bootstrap = list(
		likelihood_tier = c("partial", "full"),
		capabilities = "likelihood_ratio",
		private_methods = c("get_likelihood_test_spec", "simulate_under_lik_null")
	),
	bayesian_bootstrap = list(
		public_methods = "compute_estimate_with_bootstrap_weights"
	),
	nonparametric_bootstrap = list(
		public_methods = "compute_estimate"
	),
	standard_model_cache = list(
		capabilities = "likelihood_tests"
	),
	count_likelihood_plumbing = list(
		likelihood_tier = c("quasi", "full"),
		capabilities = "likelihood_tests"
	),
	bartlett_approximation = list(
		capabilities = "parametric_likelihood_bootstrap",
		private_methods = c("run_param_bootstrap_replicates", "param_bootstrap_lr_extreme")
	),
	kk_passthrough = list(),
	kk_compound = list(),
	robust_sandwich = list(likelihood_tier = "quasi"),
	kk_gee = list(likelihood_tier = "quasi"),
	kk_glmm = list(likelihood_tier = c("partial", "full")),
	off_optimum_likelihood_eval = list(
		likelihood_tier = c("partial", "full"),
		private_methods = c("get_default_information_source", "get_likelihood_test_spec")
	)
)

public_methods_for_capability = list(
	exact_test = c(
		"compute_exact_confidence_interval",
		"compute_exact_two_sided_pval_for_treatment_effect"
	),
	randomization_test = c(
		"approximate_randomization_distribution_beta_hat_T",
		"compute_rand_two_sided_pval"
	),
	randomization_ci = c(
		"compute_rand_confidence_interval"
	),
	randomization_bootstrap = c(
		"approximate_rand_bootstrap_distribution_beta_hat_T",
		"compute_rand_bootstrap_two_sided_pval",
		"get_supported_rand_bootstrap_pval_types"
	),
	randomization_bootstrap_ci = c(
		"compute_rand_bootstrap_confidence_interval",
		"get_supported_rand_bootstrap_ci_types"
	),
	jackknife = c(
		"approximate_jackknife_distribution_beta_hat_T",
		"compute_jackknife_estimate",
		"compute_jackknife_bias_estimate",
		"compute_jackknife_std_error",
		"compute_jackknife_wald_two_sided_pval",
		"compute_jackknife_wald_confidence_interval"
	),
	wald = c(
		"compute_asymp_confidence_interval",
		"compute_asymp_two_sided_pval",
		"compute_wald_two_sided_pval",
		"compute_wald_confidence_interval"
	),
	likelihood_tests = c(
		"set_testing_type",
		"set_information_preference",
		"get_testing_type",
		"get_information_preference",
		"get_information_source_used",
		"get_supported_testing_types",
		"get_supported_information_preferences",
		"compute_score_two_sided_pval",
		"compute_score_confidence_interval",
		"compute_lik_ratio_two_sided_pval",
		"compute_lik_ratio_confidence_interval",
		"compute_gradient_two_sided_pval",
		"compute_gradient_confidence_interval",
		# 2026-08-19 (inference_suite_inspect.md audit,
		# public_methods_for_capability completeness audit): Bartlett-
		# corrected likelihood-ratio variants, unconditionally defined on
		# InferenceAsympLik (source of this capability) alongside score/
		# lik_ratio/gradient above -- same "likelihood_tests" gate, same
		# accepted imprecision (real per-instance support is checked by the
		# private supports_bartlett_likelihood_ratio_approx()/_exact() guard
		# methods, not a capability flag; see the Bartlett-capability TODO's
		# own "no new capability" decision).
		"compute_lik_ratio_bartlett_two_sided_pval",
		"compute_lik_ratio_bartlett_confidence_interval",
		"compute_lik_ratio_bartlett_approx_two_sided_pval",
		"compute_lik_ratio_bartlett_approx_confidence_interval",
		"compute_lik_ratio_bartlett_exact_two_sided_pval",
		"compute_lik_ratio_bartlett_exact_confidence_interval"
	),
	likelihood_ratio = c(
		"compute_lik_ratio_two_sided_pval",
		"compute_lik_ratio_confidence_interval"
	),
	estimating_equation_likelihood_ratio = c(
		"compute_lik_ratio_two_sided_pval",
		"compute_lik_ratio_confidence_interval"
	),
	parametric_likelihood_bootstrap = c(
		"compute_lik_ratio_bootstrap_two_sided_pval",
		"compute_lik_ratio_bootstrap_confidence_interval",
		"get_last_param_bootstrap_diagnostics",
		# 2026-08-19 (inference_suite_inspect.md audit,
		# public_methods_for_capability completeness audit): genuine public
		# methods on InferenceParamBootstrap, distinct from the
		# compute_lik_ratio_bootstrap_* pair above (a bootstrap-calibrated
		# LR test) -- these are a direct parametric-bootstrap estimate/CI/
		# pval for the treatment coefficient itself, previously never
		# registered under any capability at all.
		"compute_param_bootstrap_confidence_interval",
		"compute_param_bootstrap_pval"
	),
	bayesian_bootstrap = c(
		"approximate_bayesian_bootstrap_distribution_beta_hat_T",
		"compute_bayesian_bootstrap_two_sided_pval",
		"compute_bayesian_bootstrap_confidence_interval",
		"get_supported_bayesian_bootstrap_pval_types",
		"get_supported_bayesian_bootstrap_ci_types"
	),
	nonparametric_bootstrap = c(
		"approximate_bootstrap_distribution_beta_hat_T",
		"compute_bootstrap_two_sided_pval",
		"compute_bootstrap_confidence_interval",
		"get_supported_bootstrap_pval_types",
		"get_supported_bootstrap_ci_types",
		# 2026-08-19 (inference_suite_inspect.md audit,
		# public_methods_for_capability completeness audit): m-out-of-n
		# bootstrap and subsampling are distinct resampling schemes (not
		# `type` variations of compute_bootstrap_*), but both are
		# unconditionally provided by the same NonparametricBootstrap
		# component alongside the canonical bootstrap methods above, so
		# they're folded into the same capability rather than given their
		# own -- no class composes one without the other.
		"compute_m_out_of_n_bootstrap_two_sided_pval",
		"compute_m_out_of_n_bootstrap_confidence_interval",
		"compute_subsampling_two_sided_pval",
		"compute_subsampling_confidence_interval"
	)
)

EDI_COMPONENT_SPECS = list(
	RandomizationTest = list(
		status = "active",
		source_name = "InferenceRand",
		file = "inference_all_abstract_rand.R",
		dependencies = character(),
		owns_state = c(
			"custom_randomization_statistic_function", "compiled_cpp_stat_fn",
			"compiled_cpp_stat_src", "randomization_mc_control"
		),
		provides_capabilities = "randomization_test",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	RandomizationCI = list(
		status = "active",
		source_name = "InferenceRandCI",
		file = "inference_all_abstract_rand_ci.R",
		dependencies = "RandomizationTest",
		provides_capabilities = "randomization_ci",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	NonparametricBootstrap = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceNonParamBootstrap",
		file = "inference_all_abstract_non_param_boot.R",
		dependencies = "RandomizationCI",
		owns_state = c(
			"boot_distr_cache", "jack_distr_cache",
			"bootstrap_extreme_estimate_threshold",
			"bootstrap_extreme_ci_width_threshold",
			"bootstrap_pval_types", "bootstrap_ci_types"
		),
		provides_public_methods = c(
			"approximate_m_out_of_n_bootstrap_distribution_beta_hat_T",
			"compute_m_out_of_n_bootstrap_two_sided_pval",
			"compute_m_out_of_n_bootstrap_confidence_interval",
			"select_optimal_m_out_of_n_bootstrap",
			"approximate_subsampling_distribution_beta_hat_T",
			"compute_subsampling_two_sided_pval",
			"compute_subsampling_confidence_interval",
			"select_optimal_b_subsampling",
			"compute_subsampling_sensitivity",
			"approximate_bootstrap_distribution_beta_hat_T",
			"compute_bootstrap_two_sided_pval",
			"compute_bootstrap_confidence_interval",
			"get_supported_bootstrap_pval_types",
			"get_supported_bootstrap_ci_types"
		),
		provides_private_methods = c(
			"bca_ci_core", "bca_pval_core", "resolve_resampling_unit",
			"get_exchangeable_units", "get_resampling_cluster_ids",
			"get_resampling_strata_ids", "get_resampling_block_ids",
			"resampling_effective_p", "resolve_resampling_size",
			"allocate_resampling_sizes_by_stratum", "sample_exchangeable_unit_ids",
			"build_resampling_draw_from_units", "generate_exchangeable_resampling_draws",
			"compute_resampling_draw_distribution",
			"get_cached_centered_resampling_pivot",
			"set_cached_centered_resampling_pivot",
			"resampling_ci_from_centered_distribution", "resampling_centered_pval",
			"resampling_scaling_factor", "select_optimal_resample_size",
			"approximate_m_out_of_n_bootstrap_distribution_beta_hat_T_impl",
			"compute_m_out_of_n_bootstrap_two_sided_pval_impl",
			"compute_m_out_of_n_bootstrap_confidence_interval_impl",
			"select_optimal_m_out_of_n_bootstrap_impl",
			"m_out_of_n_bootstrap_cache_key", "m_out_of_n_bootstrap_centered_pivot",
			"resampling_scaling_key", "m_out_of_n_bootstrap_sample_indices",
			"load_m_out_of_n_bootstrap_draw_into_worker",
			"evaluate_m_out_of_n_bootstrap_size",
			"approximate_subsampling_distribution_beta_hat_T_impl",
			"compute_subsampling_two_sided_pval_impl",
			"compute_subsampling_confidence_interval_impl",
			"select_optimal_b_subsampling_impl", "compute_subsampling_sensitivity_impl",
			"subsampling_cache_key", "subsampling_centered_pivot",
			"subsampling_sample_indices", "load_subsampling_draw_into_worker",
			"compute_subsampling_worker_estimate", "evaluate_subsampling_size",
			"assert_valid_bootstrap_type", "get_bootstrap_type",
			"resolve_jackknife_unit", "jackknife_block_size_gt_one_unsupported",
			"mark_jackknife_nonestimable_if_block_unsupported",
			"missing_bootstrap_ci", "check_bootstrap_replicate_deadline",
			"is_resampling_control_condition", "resampling_error_to_na",
			"bootstrap_estimates_extreme", "bootstrap_confidence_interval_extreme",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"validate_bootstrap_worker_state", "create_reusable_bootstrap_worker",
			"load_bootstrap_draw_into_worker", "load_non_param_bootstrap_draw_into_worker",
			"estimate_bootstrap_worker", "create_design_backed_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker",
			"load_bootstrap_sample_into_design_backed_worker",
			"compute_bootstrap_worker_estimate",
			"compute_bootstrap_worker_estimate_via_compute_treatment_estimate",
			"compute_reusable_bootstrap_worker_distribution",
			"compute_bootstrap_distribution_with_reused_workers",
			"compute_jackknife_distribution_with_reused_workers",
			"bootstrap_sample_indices", "renumber_match_ids",
			"get_cluster_jackknife_ids", "build_jackknife_deletion_draws",
			"bootstrap_subset_inference", "bootstrap_replication_stats",
			"approximate_bootstrap_statistics_beta_hat_T",
			"approximate_jackknife_distribution_beta_hat_T_private",
			"ci_from_boot_distribution", "studentized_interval_scale_unstable",
			"studentized_bootstrap_pivots", "ci_studentized",
			"ci_symmetric_studentized", "ci_bca", "ci_calibrated_bootstrap",
			"ci_smoothed_bootstrap", "infer_original_se", "pval_bca",
			"boot_distr_cache", "jack_distr_cache",
			"bootstrap_extreme_estimate_threshold",
			"bootstrap_extreme_ci_width_threshold",
			"bootstrap_pval_types", "bootstrap_ci_types"
		),
		provides_capabilities = "nonparametric_bootstrap",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	RandomizationBootstrap = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceRandBootstrap",
		file = "inference_all_abstract_rand_bootstrap.R",
		dependencies = "NonparametricBootstrap",
		owns_state = c("rand_boot_draws_counter", "brt_mc_control", "rand_bootstrap_pval_types"),
		provides_public_methods = c(
			"approximate_rand_bootstrap_distribution_beta_hat_T",
			"compute_rand_bootstrap_two_sided_pval",
			"get_supported_rand_bootstrap_pval_types"
		),
		provides_private_methods = c(
			"rand_bootstrap_transform_code", "rand_bootstrap_draw_matrices",
			"generate_rand_bootstrap_draws", "load_rand_bootstrap_draw_into_worker",
			"load_rand_bootstrap_assignment_into_worker",
			"compute_rand_bootstrap_distribution_with_reused_workers",
			"get_brt_distribution_prefix", "compute_two_sided_brt_pval_with_sequential_mc",
			"run_rand_bootstrap_iteration_with_se",
			"compute_brt_null_statistics_with_reused_workers",
			"compute_brt_null_statistics_with_se", "compute_two_sided_brt_pval_studentized",
			"run_rand_bootstrap_iteration", "rand_boot_draws_counter", "brt_mc_control",
			"rand_bootstrap_pval_types"
		),
		provides_capabilities = "randomization_bootstrap",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	RandomizationBootstrapCI = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceRandBootstrapCI",
		file = "inference_all_abstract_rand_bootstrap_ci.R",
		dependencies = "RandomizationBootstrap",
		owns_state = c("rand_bootstrap_ci_conservative_count", "rand_bootstrap_ci_types"),
		provides_public_methods = c("compute_rand_bootstrap_confidence_interval", "get_supported_rand_bootstrap_ci_types"),
		provides_private_methods = c(
			"rand_bootstrap_ci_conservative_count",
			"rand_bootstrap_ci_timeout_deadline",
			"check_rand_bootstrap_ci_deadline",
			"closed_form_ci_from_affine_null_draws",
			"compute_rand_bootstrap_ci_pval_cached",
			"expand_rand_bootstrap_bound",
			"invert_rand_bootstrap_test_bisection",
			"rand_bootstrap_ci_types"
		),
		# 2026-08-19 (inference_suite_inspect.md audit): gives this
		# component its own distinct capability string, mirroring
		# RandomizationCI's "randomization_ci" precedent, so
		# "randomization_bootstrap_ci" %in% caps precisely implies
		# compute_rand_bootstrap_confidence_interval exists -- before this,
		# the CI side contributed no capability of its own, so nothing
		# distinguished "has the p-value method" (RandomizationBootstrap's
		# "randomization_bootstrap") from "has the p-value *and* CI
		# methods" (concrete classes composing RandomizationBootstrap
		# without RandomizationBootstrapCI exist, e.g.
		# InferenceAllSimpleWilcox/InferenceAllKKWilcoxIVWC).
		provides_capabilities = "randomization_bootstrap_ci",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	BayesianBootstrap = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceBayesianBootstrap",
		file = "inference_all_abstract_bayesian_bootstrap.R",
		dependencies = "RandomizationBootstrapCI",
		owns_state = c(
			"current_bayesian_bootstrap_context",
			"current_bayesian_bootstrap_subject_or_block_weights",
			"bayesian_bootstrap_pval_types", "bayesian_bootstrap_ci_types"
		),
		provides_public_methods = c(
			"compute_estimate_with_bootstrap_weights",
			"approximate_bayesian_bootstrap_distribution_beta_hat_T",
			"compute_bayesian_bootstrap_two_sided_pval",
			"compute_bayesian_bootstrap_confidence_interval",
			"get_supported_bayesian_bootstrap_pval_types",
			"get_supported_bayesian_bootstrap_ci_types"
		),
		provides_private_methods = c(
			"supports_bayesian_bootstrap", "bayesian_bootstrap_cache_key",
			"build_bayesian_bootstrap_context", "bayesian_bootstrap_sample_weights",
			"expand_subject_or_block_weights_to_row_weights",
			"load_bayesian_bootstrap_weights_into_worker",
			"load_bayesian_bootstrap_draw_into_worker",
			"compute_bayesian_bootstrap_worker_estimate",
			"approximate_bayesian_bootstrap_statistics_beta_hat_T",
			"approximate_bayesian_jackknife_distribution_beta_hat_T",
			"ci_bayesian_bca", "pval_bayesian_bca",
			"compute_bayesian_bootstrap_distribution_with_reused_workers",
			"current_bayesian_bootstrap_context",
			"current_bayesian_bootstrap_subject_or_block_weights",
			"bayesian_bootstrap_pval_types", "bayesian_bootstrap_ci_types"
		),
		provides_capabilities = "bayesian_bootstrap",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	Jackknife = list(
		status = "active",
		source_name = "InferenceJackknife",
		file = "inference_all_abstract_jackknife.R",
		dependencies = character(),
		provides_capabilities = "jackknife",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	Wald = list(
		status = "active",
		source_name = "InferenceAsymp",
		file = "inference_all_abstract_asymp.R",
		dependencies = "Jackknife",
		owns_state = "cached_mod",
		provides_capabilities = "wald",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		declare_body_references_optional = TRUE
	),
	SimpleMeanDifference = list(
		status = "active",
		source_name = "SimpleMeanDifferenceSource",
		file = "inference_all_average_diff.R",
		dependencies = character(),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	SimpleMeanDifferencePooledVar = list(
		status = "active",
		source_name = "SimpleMeanDifferencePooledVarSource",
		file = "inference_all_simple_mean_diff_pooled_var.R",
		dependencies = "SimpleMeanDifference",
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKMeanDifferenceIVWC = list(
		status = "active",
		source_name = "KKMeanDifferenceIVWCSource",
		file = "inference_all_KK_mean_diff_IVWC.R",
		dependencies = "KKCompound",
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKWilcoxIVWC = list(
		status = "active",
		source_name = "KKWilcoxIVWCSource",
		file = "inference_all_KK_wilcox_ivwc.R",
		dependencies = character(),
		provides_capabilities = c("kk_passthrough", "kk_compound"),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKNewcombeRiskDiffIVWC = list(
		status = "active",
		source_name = "KKNewcombeRiskDiffIVWCSource",
		file = "inference_incidence_KK_newcombe_ivwc_univ.R",
		dependencies = "KKCompound",
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ContinKKRobustRegrIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "ContinKKRobustRegrIVWCSource",
		file = "inference_continuous_KK_robust_regr_ivwc.R",
		dependencies = "KKCompound",
		owns_state = c(
			"rlm_method", "rlm_maxit", "rlm_acc", "rlm_start_with_ols",
			"use_rcpp", "rlm_force_M"
		),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval", "duplicate"
		),
		provides_private_methods = c(
			"compute_fast_randomization_distr", "resolve_rlm_control",
			"is_rlm_nonconvergence_warning", "shared", "assert_finite_se",
			"fit_rlm_with_treatment", "robust_for_matched_pairs", "robust_for_reservoir",
			"rlm_method", "rlm_maxit", "rlm_acc", "rlm_start_with_ols",
			"use_rcpp", "rlm_force_M"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "quasi",
		declare_body_references_optional = TRUE
	),
	IncidenceKKGComputation = list(
		status = "active",
		load_policy = "lazy",
		source_name = "IncidenceKKGComputationSource",
		file = "inference_incidence_KK_gcomp_abstract.R",
		dependencies = "KKPassThrough",
		owns_state = c("best_X_colnames", "gcomp_boot_beta", "max_abs_reasonable_coef"),
		provides_public_methods = c(
			"initialize",
			"compute_estimate", "get_standard_error", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_wald_two_sided_pval", "compute_wald_confidence_interval",
			"approximate_bootstrap_distribution_beta_hat_T",
			"approximate_bootstrap_distribution_beta_hat_T_generic",
			"compute_rand_two_sided_pval",
			"get_supported_testing_types",
			"compute_bootstrap_confidence_interval", "compute_bootstrap_confidence_interval_generic",
			"compute_bootstrap_two_sided_pval", "compute_bootstrap_two_sided_pval_generic",
			"compute_bayesian_bootstrap_two_sided_pval", "compute_bayesian_bootstrap_two_sided_pval_generic",
			"compute_bayesian_bootstrap_confidence_interval", "compute_bayesian_bootstrap_confidence_interval_generic",
			"compute_jackknife_wald_two_sided_pval", "compute_jackknife_wald_two_sided_pval_generic",
			"compute_jackknife_wald_confidence_interval", "compute_jackknife_wald_confidence_interval_generic"
		),
		provides_private_methods = c(
			"is_a_incid_kk_gcomp", "is_a_kk_marginal_incid", "supports_likelihood_tests",
			"compute_basic_match_data", "compute_treatment_estimate_during_randomization_inference",
			"max_abs_reasonable_coef", "default_null_value",
			"compute_rr_bootstrap_basic_confidence_interval",
			"compute_rr_bayesian_bootstrap_log_confidence_interval",
			"compute_rr_jackknife_log_se", "compute_rr_jackknife_wald_two_sided_pval",
			"compute_rr_jackknife_wald_confidence_interval",
			"compute_weighted_gcomp_estimate", "set_failed_fit_cache", "effects_are_usable",
			"coefficients_are_usable", "fit_logistic_with_sandwich",
			"compute_standardized_effects_r", "compute_standardized_effects",
			"get_effect_estimate", "compute_effect_confidence_interval", "compute_effect_pvalue",
			"shared", "get_covariate_names", "get_cluster_ids",
			"best_X_colnames", "gcomp_boot_beta",
			"build_design_matrix", "get_estimand_type",
			"supports_reusable_bootstrap_worker", "create_bootstrap_worker_state",
			"load_bootstrap_sample_into_worker", "compute_bootstrap_worker_estimate"
		),
		# "wald" -- per user request, 2026-08-23: this component provides
		# `compute_wald_two_sided_pval`/`compute_wald_confidence_interval`
		# and `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`
		# (delta-method Wald CI/pval on the log-RR scale) and they work
		# correctly when called directly, but with no declared "wald"
		# capability `run_all_inference()`'s method fan-out (gated on
		# `"wald" %in% inf_obj$capabilities()`) never offered it, silently
		# hiding a fully working method behind a missing tag.
		provides_capabilities = "wald",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKQuantileRegrIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "KKQuantileRegrIVWCSource",
		file = "inference_all_KK_quantile_regr_ivwc_abstract.R",
		# QuantileRandomizationCI (Zhang combined rand-CI) is a dependency here
		# rather than a separate direct component on each concrete class: both
		# InferenceContinKKQuantileRegrIVWC and InferencePropKKQuantileRegrIVWC
		# need it and neither has any reason to compose it without this
		# component too.
		dependencies = c("KKCompound", "QuantileRandomizationCI"),
		owns_state = c("tau", "transform_y_fn_list"),
		requires_state = "m",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"tau", "transform_y_fn_list",
			"compute_basic_match_data", "matrix_with_n_rows",
			"reduce_full_rank_matrix", "reduce_preserve_cols_matrix",
			"set_colnames_safely", "shared", "quantile_for_matched_pairs",
			"quantile_for_reservoir", "iqr_se", "extract_se_from_rq",
			"compute_rand_pval_matched_pairs", "compute_rand_pval_reservoir",
			"qr_intercept_pairs", "qr_trt_coef_reservoir"
		),
		# 2026-08-19 (fix_inference_hierarchy.md "Static Cleanup", "Ban semantic
		# classification through private method-name sniffing"): replaces the
		# former is_a_kk_quantile_regr_ivwc private-method marker, which existed
		# solely so inference_all_abstract_rand.R's compute_treatment_estimate_
		# during_randomization_inference() could sniff for it via
		# has_private_method(); that call site now checks this capability instead.
		provides_capabilities = "kk_quantile_regr_ivwc",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKQuantileRegrOneLik = list(
		status = "active",
		load_policy = "lazy",
		source_name = "KKQuantileRegrOneLikSource",
		file = "inference_all_KK_quantile_regr_one_lik_abstract.R",
		# 2026-08-18 migration (fix_inference_hierarchy.md "Full-Likelihood
		# Estimators" / "KK And IVWC Estimators"): same reshaping as
		# KKQuantileRegrIVWC above -- QuantileRandomizationCI is a dependency
		# here rather than a separate direct component, shared by both
		# InferenceContinKKQuantileRegrOneLik and
		# InferencePropKKQuantileRegrOneLik. No ParametricLikelihoodBootstrap:
		# despite the "OneLik" naming, this class has no real likelihood-test
		# surface (quantreg::rq() sandwich SEs only).
		dependencies = c("KKCompound", "QuantileRandomizationCI"),
		owns_state = c("tau", "transform_y_fn_list"),
		requires_state = "m",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"tau", "transform_y_fn_list",
			"compute_treatment_estimate_during_randomization_inference",
			"compute_fast_randomization_distr", "compute_basic_match_data",
			"assert_finite_se", "get_standard_error", "shared_combined_likelihood",
			"extract_se_from_rq", "compute_weighted_combined_estimate"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	IncidKKCondLogitIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "IncidKKCondLogitIVWCSource",
		file = "inference_incidence_KK_cond_logit.R",
		dependencies = "KKCompound",
		owns_state = character(),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"compute_basic_match_data", "get_standard_error", "shared",
			"clogit_for_matched_pairs", "logistic_for_reservoir"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	SurvivalKKStratCoxIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "SurvivalKKStratCoxIVWCSource",
		file = "inference_survival_KK_strat_cox.R",
		dependencies = "KKCompound",
		owns_state = "max_abs_reasonable_coef",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"get_standard_error", "compute_basic_match_data",
			"cox_design_candidates", "rcpp_cox_fit_is_usable", "shared",
			"assert_finite_se", "max_abs_reasonable_coef"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	BaiAdjustedT = list(
		status = "active",
		load_policy = "lazy",
		source_name = "BaiAdjustedTSource",
		file = "inference_continuous_KK_bai_abstract.R",
		dependencies = "KKCompound",
		owns_state = "convex_flag",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"is_a_bai_adjusted_t", "get_standard_error",
			"compute_fast_randomization_distr", "shared",
			"compute_bai_variance_for_pairs", "compute_halves",
			"convex_flag"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ContinKKOLSIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "ContinKKOLSIVWCSource",
		file = "inference_continuous_KK_ols_ivwc.R",
		dependencies = "KKCompound",
		owns_state = character(),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"compute_fast_randomization_distr", "shared", "assert_finite_se",
			"satterthwaite_df", "fit_ols_with_treatment", "ols_for_matched_pairs",
			"ols_for_reservoir"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "quasi",
		declare_body_references_optional = TRUE
	),
	CountKKHurdlePoissonIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "CountKKHurdlePoissonIVWCSource",
		file = "inference_count_KK_cond_poisson.R",
		dependencies = "KKPassThrough",
		owns_state = c("use_rcpp", "max_abs_reasonable_coef"),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval", "compute_estimate_with_bootstrap_weights"
		),
		provides_private_methods = c(
			"compute_treatment_estimate_during_randomization_inference",
			"compute_basic_match_data", "compute_fast_randomization_distr",
			"build_model_matrix", "shared", "build_glmm_formula",
			"fit_hurdle_for_matched_pairs", "fit_hurdle_for_matched_pairs_rcpp",
			"fit_hurdle_for_matched_pairs_glmm_tmb", "fit_poisson_for_reservoir",
			"assert_finite_se", "supports_likelihood_tests",
			"use_rcpp", "max_abs_reasonable_coef"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "full",
		declare_body_references_optional = TRUE
	),
	SimpleWilcox = list(
		status = "active",
		source_name = "SimpleWilcoxSource",
		file = "inference_all_simple_wilcox.R",
		dependencies = character(),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ExactTest = list(
		status = "active",
		source_name = "ExactTestSource",
		file = "inference_all_abstract_exact.R",
		dependencies = character(),
		owns_state = "default_exact_type",
		provides_capabilities = "exact_test",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ExactBinomialIncidence = list(
		status = "active",
		source_name = "ExactBinomialIncidenceSource",
		file = "inference_incidence_exact_binomial.R",
		dependencies = "ExactTest",
		requires_capabilities = "exact_test",
		provides_capabilities = "exact_binomial_incidence",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ExactFisherIncidence = list(
		status = "active",
		source_name = "ExactFisherIncidenceSource",
		file = "inference_indicidence_exact_fisher.R",
		dependencies = "ExactTest",
		requires_capabilities = "exact_test",
		provides_capabilities = "exact_fisher_incidence",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	ExactZhangIncidence = list(
		status = "active",
		source_name = "ExactZhangIncidenceSource",
		file = "inference_incidence_exact_zhang.R",
		dependencies = "ExactTest",
		requires_capabilities = "exact_test",
		provides_capabilities = "exact_zhang_incidence",
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	LikelihoodTests = list(
		status = "active",
		source_name = "InferenceAsympLik",
		file = "inference_all_abstract_asymp_lik.R",
		dependencies = "Wald",
		owns_state = c(
			"likelihood_ci_max_abs", "testing_type",
			"information_preference", "information_source_used"
		),
		provides_capabilities = "likelihood_tests",
		allowed_likelihood_tiers = c("quasi", "partial", "full"),
		declare_body_references_optional = TRUE
	),
	MarginalEstimand = list(
		status = "active",
		source_name = "InferenceMarginalEstimand",
		file = "inference_all_abstract_marginal_estimand.R",
		dependencies = character(),
		owns_state = "estimand",
		provides_capabilities = "marginal_estimand",
		allowed_likelihood_tiers = c("partial", "full"),
		declare_body_references_optional = TRUE
	),
	ParametricLikelihoodBootstrap = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceParamBootstrap",
		file = "inference_all_abstract_param_boot.R",
		dependencies = "LikelihoodTests",
		owns_state = c(
			"bartlett_factor_mc_min_usable_fraction",
			"bartlett_factor_mc_max_attempts_per_replicate",
			"param_bootstrap_extreme_lr_threshold",
			"param_bootstrap_extreme_estimate_threshold"
		),
		provides_public_methods = c(
			"get_last_param_bootstrap_diagnostics",
			"compute_lik_ratio_bootstrap_two_sided_pval",
			"compute_lik_ratio_bootstrap_confidence_interval",
			"get_last_param_bootstrap_estimate_diagnostics",
			"compute_param_bootstrap_estimate",
			"compute_param_bootstrap_confidence_interval",
			"compute_param_bootstrap_pval"
		),
		provides_private_methods = c(
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx",
			"extract_param_bootstrap_estimate_coef",
			"param_bootstrap_estimate_threshold",
			"param_bootstrap_estimate_extreme",
			"param_bootstrap_confidence_interval_extreme",
			"run_param_bootstrap_estimate_batch",
			"run_param_bootstrap_estimate_replicates",
			"compute_param_bootstrap_estimate_impl",
			"supports_param_bootstrap_estimate",
			"is_a_param_bootstrap",
			"param_bootstrap_lr_extreme",
			"run_param_bootstrap_replicates",
			"simulate_param_boot_bernoulli_y",
			"simulate_param_boot_poisson_y",
			"simulate_param_boot_gaussian_y",
			"simulate_param_boot_ordinal_y",
			"simulate_param_boot_weibull_observed",
			"supports_reusable_param_bootstrap_worker",
			"use_reusable_param_bootstrap_worker",
			"use_deterministic_param_bootstrap",
			"with_param_bootstrap_thread_budget",
			"with_param_bootstrap_seed",
			"param_boot_failure_result",
			"param_boot_success_result",
			"validate_param_bootstrap_spec",
			"validate_param_bootstrap_worker_data",
			"extract_param_bootstrap_failure_reason",
			"compute_param_bootstrap_lr_from_boot_spec",
			"compute_param_bootstrap_lr_impl",
			"load_param_bootstrap_draw_into_worker",
			"create_param_bootstrap_worker_state",
			"compute_param_bootstrap_worker_lrt",
			"summarize_param_bootstrap_diagnostics",
			"supports_lik_ratio_param_bootstrap",
			"supports_lik_ratio_param_bootstrap_confidence_interval",
			"simulate_under_lik_null",
			"bartlett_factor_mc_min_usable_fraction",
			"bartlett_factor_mc_max_attempts_per_replicate",
			"param_bootstrap_extreme_lr_threshold",
			"param_bootstrap_extreme_estimate_threshold"
		),
		provides_capabilities = "parametric_likelihood_bootstrap",
		allowed_likelihood_tiers = c("partial", "full"),
		declare_body_references_optional = TRUE
	),
		StandardModelCache = list(
			status = "active",
			source_name = "StandardModelCacheSource",
			file = "inference_all_abstract_asymp_lik_std_mod_cache.R",
			dependencies = "LikelihoodTests",
			provides_capabilities = "standard_model_cache",
		allowed_likelihood_tiers = c("quasi", "partial", "full"),
		declare_body_references_optional = TRUE
	),
	CoxPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "CoxPartialLikelihoodSource",
		file = "inference_survival_coxph.R",
		dependencies = "StandardModelCache",
		provides_public_methods = character(),
		provides_private_methods = c(
			"fit_survival_coxph_kernel",
			"fit_survival_coxph_fixed_kernel",
			"cox_neg_loglik_breslow_r",
			"cox_score_breslow_fd_r",
			"cox_information_breslow_fd_r",
			"cox_partial_likelihood_coefficients_extreme"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	StratifiedCoxPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "StratifiedCoxPartialLikelihoodSource",
		file = "inference_survival_strat_cox.R",
		dependencies = "CoxPartialLikelihood",
		provides_public_methods = character(),
		provides_private_methods = c(
			"cox_partial_likelihood_strata_info",
			"cox_partial_likelihood_reduce_covariates",
			"cox_partial_likelihood_informative_rows",
			"cox_partial_likelihood_fit_with_formula",
			"cox_partial_likelihood_fit_estimate_only_fast"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	ConditionalLogitPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "ConditionalLogitPartialLikelihoodSource",
		file = "inference_incidence_KK_cond_logit.R",
		dependencies = character(),
		provides_public_methods = character(),
		provides_private_methods = c(
			"conditional_logit_prepare_combined_design",
			"conditional_logit_weighted_combined_estimate",
			"conditional_logit_neg_loglik",
			"conditional_logit_fit_matched_pairs",
			"conditional_logit_fit_reservoir"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	OrdinalConditionalLogitPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "OrdinalConditionalLogitPartialLikelihoodSource",
		file = "inference_ordinal_KK_cond_logit_abstract.R",
		dependencies = "ConditionalLogitPartialLikelihood",
		provides_public_methods = character(),
		provides_private_methods = c(
			"ordinal_cond_clogit_compute_setup",
			"ordinal_cond_clogit_assert_finite_se",
			"ordinal_cond_clogit_shared_univ",
			"ordinal_cond_clogit_shared_multi"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	KKLWACoxIVWCPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "KKLWACoxIVWCPartialLikelihoodSource",
		file = "inference_survival_KK_lwa_cox_ivwc_abstract.R",
		# 2026-08-18 migration: previously a shim-only component with
		# dependencies = "Wald"; now the real merged abstract+leaf source for
		# InferenceSurvivalKKLWACoxPHIVWC (Wald arrives explicitly in that
		# class's composition vector).
		dependencies = "KKCompound",
		owns_state = "max_abs_reasonable_coef",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"is_a_kk_lwa_cox_ivwc", "get_standard_error",
			"compute_basic_match_data", "shared", "assert_finite_se",
			"cox_design_candidates", "fit_cox_model",
			"lwa_cox_for_matched_pairs", "cox_for_reservoir",
			"max_abs_reasonable_coef",
			"kk_lwa_cox_ivwc_shared",
			"kk_lwa_cox_ivwc_assert_finite_se",
			"kk_lwa_cox_design_candidates",
			"kk_lwa_cox_fit_model",
			"kk_lwa_cox_for_matched_pairs",
			"kk_lwa_cox_for_reservoir"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	KKLWACoxOneLikPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "KKLWACoxOneLikPartialLikelihoodSource",
		file = "inference_survival_KK_lwa_cox_one_lik_abstract.R",
		# 2026-08-18 migration: previously a shim-only component with
		# dependencies = "ParametricLikelihoodBootstrap"; now the real merged
		# abstract+leaf source for InferenceSurvivalKKLWACoxPHOneLik (see the
		# KKLWACoxIVWCPartialLikelihood entry above for the analogous IVWC
		# reshaping earlier this stretch).
		dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap"),
		owns_state = "max_abs_reasonable_coef",
		requires_state = "optimization_alg",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"is_a_kk_lwa_cox_one_lik", "compute_basic_match_data",
			"get_standard_error", "get_degrees_of_freedom", "assert_finite_se",
			"supports_likelihood_tests", "supports_lik_ratio_param_bootstrap",
			"simulate_under_lik_null", "get_likelihood_test_spec",
			"compute_treatment_estimate_during_randomization_inference",
			"design_matrix_candidates", "shared_combined_likelihood",
			"max_abs_reasonable_coef",
			"kk_lwa_cox_one_lik_get_standard_error",
			"kk_lwa_cox_one_lik_get_degrees_of_freedom",
			"kk_lwa_cox_one_lik_assert_finite_se",
			"kk_lwa_cox_one_lik_supports_likelihood_tests",
			"kk_lwa_cox_one_lik_supports_lik_ratio_param_bootstrap",
			"kk_lwa_cox_one_lik_simulate_under_lik_null",
			"kk_lwa_cox_one_lik_get_likelihood_test_spec",
			"kk_lwa_cox_one_lik_compute_treatment_estimate_during_randomization_inference",
			"kk_lwa_cox_one_lik_design_matrix_candidates",
			"kk_lwa_cox_one_lik_shared_combined_likelihood"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	CountKKHurdlePoissonOneLikLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "CountKKHurdlePoissonOneLikLikelihoodSource",
		file = "inference_count_KK_cond_poisson.R",
		# 2026-08-19 migration (fix_inference_hierarchy.md "Full-Likelihood
		# Estimators" / "KK And IVWC Estimators"): formerly a single-layer R6
		# leaf raw-splicing InferenceMixinKKPassThrough$public/private onto
		# InferenceParamBootstrap. No KKCompound dependency: this class's own
		# compute_basic_match_data uses .compute_kk_basic_match_data_cached()
		# directly and its initialize performs its own manual match-structure
		# setup rather than calling init_kk_passthrough() (preserved verbatim,
		# no Lesson-1 fix needed here).
		dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap"),
		owns_state = c("cached_mod", "use_rcpp", "max_abs_reasonable_coef"),
		requires_state = "m",
		provides_public_methods = c(
			"initialize",
			"compute_score_confidence_interval_generic",
			"compute_lik_ratio_confidence_interval_generic",
			"compute_gradient_confidence_interval_generic",
			"compute_score_two_sided_pval_generic",
			"compute_lik_ratio_two_sided_pval_generic",
			"compute_gradient_two_sided_pval_generic",
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_score_confidence_interval",
			"compute_lik_ratio_confidence_interval", "compute_gradient_confidence_interval",
			"compute_asymp_two_sided_pval", "compute_score_two_sided_pval",
			"compute_lik_ratio_two_sided_pval", "compute_gradient_two_sided_pval",
			"compute_wald_confidence_interval", "compute_wald_two_sided_pval"
		),
		provides_private_methods = c(
			"cached_mod", "use_rcpp", "max_abs_reasonable_coef",
			"get_standard_error", "supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap", "get_supported_testing_types_impl",
			"warn_bootstrap_fallback_once", "compute_basic_match_data",
			"build_model_matrix", "build_combined_hurdle_data",
			"build_weighted_combined_hurdle_data", "combined_hurdle_neg_loglik",
			"combined_hurdle_score", "combined_hurdle_hessian",
			"information_inverse_diagonal_entry", "record_combined_hurdle_fit_summary",
			"fit_combined_hurdle", "shared_combined_hurdle",
			"compute_weighted_combined_hurdle_estimate", "shared",
			"simulate_under_lik_null", "get_likelihood_test_spec"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "full",
		declare_body_references_optional = TRUE
	),
	CountKKCondPoissonOneLikLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "CountKKCondPoissonOneLikLikelihoodSource",
		file = "inference_count_KK_cond_poisson.R",
		# 2026-08-19 migration (fix_inference_hierarchy.md "Full-Likelihood
		# Estimators" / "KK And IVWC Estimators"): same shape as
		# CountKKHurdlePoissonOneLikLikelihood above.
		dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap"),
		owns_state = c("cached_mod", "max_abs_reasonable_coef"),
		provides_public_methods = c(
			"initialize",
			"compute_score_confidence_interval_generic",
			"compute_lik_ratio_confidence_interval_generic",
			"compute_gradient_confidence_interval_generic",
			"compute_score_two_sided_pval_generic",
			"compute_lik_ratio_two_sided_pval_generic",
			"compute_gradient_two_sided_pval_generic",
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_wald_confidence_interval", "compute_wald_two_sided_pval",
			"compute_score_confidence_interval", "compute_lik_ratio_confidence_interval",
			"compute_gradient_confidence_interval", "compute_score_two_sided_pval",
			"compute_lik_ratio_two_sided_pval", "compute_gradient_two_sided_pval"
		),
		provides_private_methods = c(
			"cached_mod", "max_abs_reasonable_coef", "get_standard_error",
			"supports_lik_ratio_param_bootstrap", "get_supported_testing_types_impl",
			"compute_basic_match_data", "build_model_matrix",
			"build_combined_cpoisson_data", "reduce_combined_covariates",
			"set_failed_combined_cache", "try_combined_fit", "try_pairs_only",
			"try_reservoir_only", "fit_combined_cpoisson",
			"compute_weighted_combined_estimate", "weighted_cpoisson_neg_loglik",
			"weighted_cpoisson_score",
			"supports_likelihood_tests", "shared_combined_cpoisson", "shared",
			"simulate_under_lik_null", "get_likelihood_test_spec"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "full",
		declare_body_references_optional = TRUE
	),
	IncidKKCondLogitOneLikLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "IncidKKCondLogitOneLikLikelihoodSource",
		file = "inference_incidence_KK_cond_logit.R",
		# 2026-08-19 migration (fix_inference_hierarchy.md "Full-Likelihood
		# Estimators" / "KK And IVWC Estimators"): formerly a single-layer R6
		# leaf raw-splicing InferenceMixinKKPassThrough$public/private onto
		# InferenceParamBootstrap. Fits one joint combined logistic likelihood
		# directly (no KKCompound-style variance-weighted combination).
		dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap"),
		owns_state = c("cached_mod", "max_abs_reasonable_coef"),
		provides_public_methods = c(
			"initialize",
			"compute_asymp_confidence_interval_generic",
			"compute_asymp_two_sided_pval_generic",
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
		),
		# approximate_bootstrap_distribution_beta_hat_T is deliberately NOT in
		# provides_public_methods (this Source no longer defines it -- see the
		# Source's header comment); it is still declared on the class's
		# `overrides$public` so the composed KKPassThrough/BayesianBootstrap
		# chain-vs-chain collision resolves via component order.
		provides_private_methods = c(
			"cached_mod", "max_abs_reasonable_coef", "assess_combined_fit",
			"shared_combined_likelihood",
			"get_standard_error", "supports_likelihood_tests",
			"compute_likelihood_test_two_sided_pval", "get_likelihood_test_spec",
			"supports_lik_ratio_param_bootstrap",
			"compute_weighted_combined_estimate", "simulate_under_lik_null"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "full",
		declare_body_references_optional = TRUE
	),
	SurvivalKKStratCoxOneLikPartialLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "SurvivalKKStratCoxOneLikPartialLikelihoodSource",
		file = "inference_survival_KK_strat_cox.R",
		# 2026-08-18 migration (fix_inference_hierarchy.md "Partial-Likelihood
		# Estimators" / "KK And IVWC Estimators"): formerly
		# `InferenceSurvivalKKStratCoxPHOneLik`, a single-layer R6 leaf
		# inheriting `InferenceParamBootstrap` and raw-splicing
		# `InferenceMixinKKPassThrough$public/private` (`utils::modifyList
		# (as.list(...), ...)`) -- no separate abstract base, unlike the LWA
		# Cox OneLik pair. Same reshaping recipe as
		# `KKLWACoxOneLikPartialLikelihoodSource`: the class's own
		# stratified-Cox combined-likelihood machinery becomes this source,
		# `dependencies` supplies `KKPassThrough` for match-structure setup/
		# `compute_treatment_estimate_during_randomization_inference` (this
		# class never overrode that method itself, unlike LWA, so it is not
		# duplicated here -- it flows through from KKPassThrough) plus
		# `ParametricLikelihoodBootstrap` (already depends on
		# `LikelihoodTests` transitively).
		dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap"),
		owns_state = c("max_abs_reasonable_coef", "best_X_colnames"),
		requires_state = "optimization_alg",
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"compute_basic_match_data",
			"max_abs_reasonable_coef", "best_X_colnames",
			"design_matrix_candidates", "shared_combined_likelihood",
			"supports_likelihood_tests", "get_likelihood_test_spec",
			"get_standard_error", "get_degrees_of_freedom", "assert_finite_se",
			"supports_lik_ratio_param_bootstrap", "simulate_under_lik_null"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "partial",
		declare_body_references_optional = TRUE
	),
	ContinKKOLSOneLikLikelihood = list(
		status = "active",
		load_policy = "lazy",
		source_name = "ContinKKOLSOneLikLikelihoodSource",
		file = "inference_continuous_KK_ols_one_lik.R",
		# 2026-08-18 migration (fix_inference_hierarchy.md "Full-Likelihood
		# Estimators" / "KK And IVWC Estimators"): formerly a plain R6 leaf on
		# the real R6 abstract `InferenceKKPassThroughCompound`. `KKCompound`
		# supplies reduce_design_matrix_once()/compute_basic_match_data()/
		# init_kk_passthrough() (same as every KKCompound-dependent IVWC leaf);
		# ParametricLikelihoodBootstrap already depends on LikelihoodTests
		# transitively.
		dependencies = c("KKCompound", "ParametricLikelihoodBootstrap"),
		owns_state = character(),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"get_likelihood_components"
		),
		provides_private_methods = c(
			"compute_fast_randomization_distr", "get_standard_error",
			"get_degrees_of_freedom", "supports_likelihood_tests",
			"supports_lik_ratio_param_bootstrap",
			"supports_bartlett_likelihood_ratio_exact", "get_bartlett_factor_exact",
			"simulate_under_lik_null", "get_supported_testing_types_impl",
			"get_score_test_information_matrix", "compute_score_two_sided_pval_impl",
			"compute_gradient_two_sided_pval_impl", "compute_lik_ratio_two_sided_pval_impl",
			"get_likelihood_test_spec", "compute_likelihood_test_two_sided_pval",
			"assert_finite_se", "fit_ols", "fit_combined", "fit_weighted_combined"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "full",
		declare_body_references_optional = TRUE
	),
	ContinKKRobustRegrOneLik = list(
		status = "active",
		load_policy = "lazy",
		source_name = "ContinKKRobustRegrOneLikSource",
		file = "inference_continuous_KK_robust_regr_one_lik.R",
		# 2026-08-18 migration (fix_inference_hierarchy.md "Quasi And Robust
		# Estimators" / "KK And IVWC Estimators"): formerly a plain R6 leaf on
		# the real R6 abstract `InferenceKKPassThroughCompoundNoParamBootstrap`.
		# `KKCompound` supplies reduce_design_matrix_once()/
		# compute_basic_match_data()/init_kk_passthrough(); no
		# ParametricLikelihoodBootstrap, same "quasi" tier as the IVWC sibling.
		dependencies = "KKCompound",
		owns_state = c("rlm_method", "rlm_maxit", "rlm_acc", "rlm_start_with_ols", "use_rcpp", "rlm_force_M"),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
			"compute_wald_confidence_interval", "compute_wald_two_sided_pval",
			"duplicate"
		),
		provides_private_methods = c(
			"rlm_method", "rlm_maxit", "rlm_acc", "rlm_start_with_ols", "use_rcpp",
			"compute_fast_randomization_distr", "rlm_force_M",
			"resolve_rlm_control", "is_rlm_nonconvergence_warning", "assert_finite_se",
			"get_standard_error", "get_degrees_of_freedom", "fit_rlm", "fit_combined",
			"fit_weighted_combined"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "quasi",
		declare_body_references_optional = TRUE
	),
	SurvivalKKRankRegrIVWC = list(
		status = "active",
		load_policy = "lazy",
		source_name = "SurvivalKKRankRegrIVWCSource",
		file = "inference_survival_KK_rank_regr_ivwc_abstract.R",
		dependencies = "KKCompound",
		owns_state = c("best_X_colnames_matched", "best_X_colnames_reservoir", "max_abs_reasonable_coef"),
		provides_public_methods = c(
			"initialize", "compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"is_a_kk_survival_rank_regr_ivwc", "build_design_matrix",
			"compute_basic_match_data", "aft_design_candidates",
			"extract_term_estimate", "extract_term_se", "shared",
			"assert_finite_se", "get_standard_error",
			"aftsrr_for_matched_pairs", "aftsrr_for_reservoir",
			"best_X_colnames_matched", "best_X_colnames_reservoir",
			"max_abs_reasonable_coef"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = "none",
		declare_body_references_optional = TRUE
	),
	KKSurvivalRankRegression = list(
		status = "active",
		load_policy = "lazy",
		source_name = "KKSurvivalRankRegressionSource",
		file = "inference_survival_KK_rank_regr_ivwc_abstract.R",
		dependencies = "Wald",
		provides_public_methods = character(),
		provides_private_methods = c(
			"kk_survival_rank_design_candidates",
			"kk_survival_rank_extract_term_estimate",
			"kk_survival_rank_extract_term_se",
			"kk_survival_rank_shared",
			"kk_survival_rank_assert_finite_se",
			"kk_survival_rank_aftsrr_for_matched_pairs",
			"kk_survival_rank_aftsrr_for_reservoir"
		),
		provides_capabilities = character(),
		allowed_likelihood_tiers = c("none", "partial"),
		declare_body_references_optional = TRUE
	),
			CountLikelihoodPlumbing = list(
				status = "active",
				load_policy = "lazy",
				source_name = "CountLikelihoodPlumbingSource",
			file = "inference_all_abstract_count_likelihood.R",
		dependencies = "LikelihoodTests",
		provides_public_methods = c(
			"compute_estimate", "compute_asymp_confidence_interval",
			"compute_asymp_two_sided_pval", "compute_wald_two_sided_pval",
			"compute_wald_confidence_interval", "compute_score_two_sided_pval",
			"compute_score_confidence_interval", "compute_lik_ratio_two_sided_pval",
			"compute_lik_ratio_confidence_interval", "compute_gradient_two_sided_pval",
			"compute_gradient_confidence_interval",
			"compute_lik_ratio_bootstrap_two_sided_pval",
			"compute_lik_ratio_bootstrap_confidence_interval"
		),
		provides_private_methods = c(
			"shared", "get_standard_error", "get_degrees_of_freedom",
			"get_backend_warm_start_args", "supports_lik_ratio_param_bootstrap",
			"supports_likelihood_tests", "get_likelihood_test_spec",
			"compute_score_two_sided_pval_impl", "compute_gradient_two_sided_pval_impl",
			"compute_lik_ratio_two_sided_pval_impl",
			"compute_score_confidence_interval_impl",
			"compute_gradient_confidence_interval_impl",
			"compute_lik_ratio_confidence_interval_impl",
			"count_likelihood_block_asymp_unsupported",
			"mark_count_likelihood_block_asymp_nonestimable",
			"count_likelihood_missing_ci", "is_a_count_likelihood",
			"cl_plumbing_asymp_lik_compute_asymp_confidence_interval",
			"cl_plumbing_asymp_lik_compute_asymp_two_sided_pval",
			"cl_plumbing_param_boot_compute_lik_ratio_bootstrap_two_sided_pval",
			"cl_plumbing_param_boot_compute_lik_ratio_bootstrap_confidence_interval"
		),
		provides_capabilities = "count_likelihood_plumbing",
			allowed_likelihood_tiers = c("quasi", "full"),
			declare_body_references_optional = TRUE
		),
			CountCompositeLikelihood = list(
				status = "active",
				source_name = "CountCompositeLikelihoodSource",
				file = "inference_count_composite_likelihood.R",
				dependencies = character(),
				provides_capabilities = "count_composite_likelihood",
				allowed_likelihood_tiers = "quasi",
				declare_body_references_optional = TRUE
			),
			ZeroAugmentedCountLikelihood = list(
				status = "active",
				# Eager, not lazy (unlike every other per-class *Likelihood
				# component in this migration): this component's own
				# `initialize` is a real, always-bound method here rather than
				# a lazy install-stub because InferenceCountZeroAugmentedPoisson
				# Abstract has real classic-inheritance subclasses
				# (InferenceCountHurdlePoisson/ZeroInflatedNegBin/
				# ZeroInflatedPoisson, the "thin leaf of an already-composed
				# abstract" pattern) whose own initialize() calls
				# super$initialize(...) -- that resolves to whatever's bound as
				# this abstract's own `initialize` method. A lazy stub's
				# install-then-redispatch body (`install_lazy_inference_
				# component(self, private, class(self)[1L], .component_name);
				# self[[.method_name]](...)`) uses class(self)[1L], which for a
				# leaf instance is the LEAF's class name, not the abstract's --
				# install_lazy_inference_component() has no dispatch entry
				# keyed by the leaf, so this either fails outright or
				# recurses (found 2026-08-21 constructing
				# InferenceCountHurdlePoisson: "unused argument" / "infinite
				# recursion" depending on install state). No other component
				# in this migration has real classic-inheritance subclasses
				# below it, so this is the first time the lazy-stub-as-
				# initialize pattern (already used safely by e.g.
				# IncidenceLogisticLikelihood, which has no subclasses) breaks.
				source_name = "ZeroAugmentedCountLikelihoodSource",
				file = "inference_count_zero_augmented_poisson_abstract.R",
				dependencies = "CountLikelihoodPlumbing",
				owns_state = c(
					"cached_mod", "za_X_cov_all", "za_Xzi_cov_all",
					"best_X_colnames", "best_Xzi_colnames", "use_rcpp",
					"model_formula_zero"
				),
				requires_state = "cached_vc_params",
				provides_public_methods = c(
					"initialize",
					"compute_asymp_confidence_interval",
					"compute_asymp_two_sided_pval",
					"compute_estimate_with_bootstrap_weights",
					"compute_jackknife_estimate",
					"compute_jackknife_bias_estimate",
					"compute_jackknife_std_error",
					"compute_jackknife_wald_two_sided_pval",
					"compute_jackknife_wald_confidence_interval",
					"compute_bootstrap_two_sided_pval",
					"compute_bootstrap_confidence_interval",
					"compute_bayesian_bootstrap_two_sided_pval",
					"compute_bayesian_bootstrap_confidence_interval"
				),
				provides_private_methods = c(
					"is_a_count_zero_augmented_poisson",
					"supports_reusable_bootstrap_worker",
					"create_bootstrap_worker_state",
					"load_bootstrap_sample_into_worker",
					"compute_bootstrap_worker_estimate",
					"record_zero_augmented_fit_summary",
					"invalidate_likelihood_fit",
					"get_standard_error",
					"get_degrees_of_freedom",
					"safe_zero_augmented_vcov_se",
					"get_complexity_tier",
					"build_component_matrix",
					"build_component_frame",
					"build_formula_from_matrix",
					"zero_augmented_sandwich_se",
					"zero_augmented_poisson_sandwich_vcov_full",
					"zero_augmented_poisson_mean_from_theta",
					"zero_augmented_poisson_marginal_functional",
					"compute_marginal_estimand_estimate",
					"hurdle_poisson_lambda_mle",
					"hurdle_poisson_neg_loglik",
					"fit_treatment_only_hurdle_poisson_closed_form",
					"compute_treatment_estimate_during_randomization_inference",
					"za_family",
					"za_description",
					"supports_likelihood_tests",
					"get_likelihood_test_spec",
					"predictors_df",
					"fit_zero_augmented_model",
					"generate_mod",
					"assert_finite_se",
					"supports_lik_ratio_param_bootstrap",
					"supports_lik_ratio_param_bootstrap_confidence_interval",
					"simulate_under_lik_null",
					"nonparam_boot_compute_bootstrap_two_sided_pval",
					"nonparam_boot_compute_bootstrap_confidence_interval",
					"bayesian_boot_compute_bayesian_bootstrap_two_sided_pval",
					"bayesian_boot_compute_bayesian_bootstrap_confidence_interval",
					"cached_mod",
					"za_X_cov_all",
					"za_Xzi_cov_all",
					"best_X_colnames",
					"best_Xzi_colnames",
					"use_rcpp",
					"model_formula_zero"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalProportionalOddsLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalProportionalOddsLikelihoodSource",
				file = "inference_ordinal_proportional_odds.R",
				dependencies = "StandardModelCache",
				owns_state = "best_X_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"get_complexity_tier",
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"supports_lik_ratio_param_bootstrap",
					"supports_likelihood_tests",
					"simulate_under_lik_null",
					"get_likelihood_test_spec",
					"generate_mod",
					"build_design_matrix",
					"best_X_colnames"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalAdjacentCategoryLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalAdjacentCategoryLikelihoodSource",
				file = "inference_ordinal_adj_cat_logit.R",
				dependencies = "StandardModelCache",
				# `cached_mod` added 2026-08-21: never declared in the original
				# class's own source (created dynamically on first assignment in
				# generate_mod()), and Wald's own `cached_mod = NULL` declaration
				# never survives component composition (modifyList()-based
				# assembly drops NULL-valued entries for *eager* components).
				# Harmless for real package instances (lock_objects = FALSE) but
				# breaks any locked test/user subclass -- reproduced directly:
				# `private$cached_mod = model_output` in generate_mod() threw
				# "cannot add bindings to a locked environment". Same fix pattern
				# as every other migrated *Likelihood component this session.
				owns_state = c("best_Xmm_colnames", "cached_mod"),
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"supports_likelihood_tests",
					"supports_bayesian_bootstrap",
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"get_bootstrap_worker_spec",
					"generate_mod",
					"get_likelihood_test_spec",
					"supports_lik_ratio_param_bootstrap",
					"simulate_under_lik_null",
					"build_design_matrix",
					"best_Xmm_colnames",
					"cached_mod"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalCloglogLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalCloglogLikelihoodSource",
				file = "inference_ordinal_cloglog.R",
				dependencies = "StandardModelCache",
				owns_state = "best_X_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"supports_lik_ratio_param_bootstrap",
					"supports_likelihood_tests",
					"supports_fisher_information",
					"simulate_under_lik_null",
					"get_likelihood_test_spec",
					"generate_mod",
					"build_design_matrix",
					"best_X_colnames"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalCauchitLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalCauchitLikelihoodSource",
				file = "inference_ordinal_cauchit.R",
				dependencies = "StandardModelCache",
				owns_state = "best_X_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"supports_lik_ratio_param_bootstrap",
					"supports_likelihood_tests",
					"supports_fisher_information",
					"simulate_under_lik_null",
					"get_likelihood_test_spec",
					"generate_mod",
					"build_design_matrix",
					"best_X_colnames"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalStereotypeLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalStereotypeLikelihoodSource",
				file = "inference_ordinal_stereotype_logit.R",
				dependencies = "StandardModelCache",
				owns_state = "best_Xmm_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"supports_likelihood_tests",
					"supports_bayesian_bootstrap",
					"get_complexity_tier",
					"stereotype_treatment_estimate_is_usable",
					"stereotype_fit_is_usable",
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"get_bootstrap_worker_spec",
					"generate_mod",
					"get_likelihood_test_spec",
					"supports_lik_ratio_param_bootstrap",
					"simulate_under_lik_null",
					"build_design_matrix",
					"best_Xmm_colnames"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
			OrdinalContinuationRatioLikelihood = list(
				status = "active",
				load_policy = "lazy",
				source_name = "OrdinalContinuationRatioLikelihoodSource",
				file = "inference_ordinal_stereotype_logit.R",
				dependencies = "StandardModelCache",
				owns_state = "best_Xmm_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"supports_likelihood_tests",
					"get_complexity_tier",
					"compute_treatment_estimate_during_randomization_inference",
					"generate_mod",
					"get_likelihood_test_spec",
					"supports_lik_ratio_param_bootstrap",
					"simulate_under_lik_null",
					"build_design_matrix",
					"best_Xmm_colnames"
				),
				provides_capabilities = character(),
				allowed_likelihood_tiers = "full",
				declare_body_references_optional = TRUE
			),
				OrdinalOrderedProbitLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "OrdinalOrderedProbitLikelihoodSource",
				file = "inference_ordinal_ordered_probit.R",
				dependencies = "StandardModelCache",
				owns_state = "best_X_colnames",
				provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
				provides_private_methods = c(
					"get_complexity_tier",
					"compute_treatment_estimate_during_randomization_inference",
					"supports_reusable_bootstrap_worker",
					"supports_lik_ratio_param_bootstrap",
					"supports_likelihood_tests",
					"supports_fisher_information",
					"simulate_under_lik_null",
					"get_likelihood_test_spec",
					"generate_mod",
					"build_design_matrix",
					"best_X_colnames"
				),
				provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceLogisticLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceLogisticLikelihoodSource",
					file = "inference_incidence_logit.R",
					dependencies = "StandardModelCache",
					owns_state = c(
						"best_X_colnames", "logit_X_full_cache", "logit_w_cache",
						"max_abs_reasonable_coef",
						# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" /
						# per-class migration ladders): re-declared here to survive
						# eager-component NULL-dropping; see the comment on
						# inference_incid_log_regr_private's own cached_mod entry.
						"cached_mod"
					),
					provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
					provides_private_methods = c(
						"is_logistic_fit_reasonable",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker",
						"supports_lik_ratio_param_bootstrap",
						"supports_likelihood_tests",
						"supports_fisher_information",
						"simulate_under_lik_null",
						"get_likelihood_test_spec",
						"generate_mod",
						"build_design_matrix",
						"get_complexity_tier",
						"best_X_colnames",
						"logit_X_full_cache",
						"logit_w_cache",
						"max_abs_reasonable_coef",
						"cached_mod"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceProbitLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceProbitLikelihoodSource",
					file = "inference_incidence_probit.R",
					dependencies = "StandardModelCache",
					owns_state = c("best_X_colnames", "max_abs_reasonable_coef", "cached_mod"),
					provides_public_methods = c("initialize", "compute_estimate_with_bootstrap_weights"),
					provides_private_methods = c(
						"is_probit_fit_reasonable",
						"get_complexity_tier",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker",
						"supports_lik_ratio_param_bootstrap",
						"supports_likelihood_tests",
						"supports_fisher_information",
						"simulate_under_lik_null",
						"get_likelihood_test_spec",
						"generate_mod",
						"build_design_matrix",
						"best_X_colnames",
						"max_abs_reasonable_coef",
						"cached_mod"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceLogBinomialLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceLogBinomialLikelihoodSource",
					file = "inference_incidence_log_binomial.R",
					dependencies = "StandardModelCache",
					owns_state = c(
						"best_X_colnames", "logbin_X_full_cache", "logbin_w_cache",
						"max_abs_reasonable_coef", "cached_mod"
					),
					provides_public_methods = c(
						"initialize",
						"compute_estimate_with_bootstrap_weights",
						"compute_score_confidence_interval",
						"compute_gradient_confidence_interval"
					),
					provides_private_methods = c(
						"is_log_binomial_fit_reasonable",
						"get_complexity_tier",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker",
						"supports_lik_ratio_param_bootstrap",
						"supports_likelihood_tests",
						"compute_gradient_confidence_interval_impl",
						"simulate_under_lik_null",
						"get_likelihood_test_spec",
						"generate_mod",
						"build_design_matrix",
						"best_X_colnames",
						"logbin_X_full_cache",
						"logbin_w_cache",
						"max_abs_reasonable_coef",
						"cached_mod"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceModifiedPoissonLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceModifiedPoissonLikelihoodSource",
					file = "inference_incidence_modified_poisson.R",
					dependencies = "StandardModelCache",
					owns_state = c(
						"best_X_colnames", "cached_mod", "max_abs_reasonable_coef",
						"max_abs_reasonable_linear_predictor"
					),
					provides_public_methods = c(
						"initialize",
						"compute_estimate",
						"compute_asymp_confidence_interval",
						"compute_asymp_two_sided_pval",
						"compute_estimate_with_bootstrap_weights"
					),
					provides_private_methods = c(
						"build_design_matrix",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker",
						"supports_lik_ratio_param_bootstrap",
						"supports_likelihood_tests",
						"get_supported_testing_types_impl",
						"is_modified_poisson_fit_reasonable",
						"simulate_under_lik_null",
						"get_likelihood_test_spec",
						"generate_mod",
						"best_X_colnames",
						"cached_mod",
						"max_abs_reasonable_coef",
						"max_abs_reasonable_linear_predictor"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceBinomialIdentityLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceBinomialIdentityLikelihoodSource",
					file = "inference_incidence_binomial_identity.R",
					dependencies = "StandardModelCache",
					owns_state = c("best_X_colnames", "cached_mod"),
					provides_public_methods = c(
						"initialize",
						"compute_estimate_with_bootstrap_weights",
						"compute_lik_ratio_confidence_interval"
					),
					provides_private_methods = c(
						"build_design_matrix",
						"is_identity_binomial_fit_reasonable",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker",
						"supports_likelihood_tests",
						"get_supported_testing_types_impl",
						"supports_lik_ratio_param_bootstrap",
						"simulate_under_lik_null",
						"get_likelihood_test_spec",
						"generate_mod",
						"best_X_colnames",
						"cached_mod"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				IncidenceGComputation = list(
					status = "active",
					load_policy = "lazy",
					source_name = "IncidenceGComputationSource",
					file = "inference_incidence_gcomp_abstract.R",
					dependencies = character(),
					owns_state = c(
						"best_X_colnames", "gcomp_boot_beta",
						"prob_clip_eps", "max_abs_reasonable_coef"
					),
					provides_public_methods = c(
						"initialize",
						"approximate_bootstrap_distribution_beta_hat_T",
						"compute_estimate",
						"get_standard_error",
						"compute_estimate_with_bootstrap_weights",
						"compute_asymp_confidence_interval",
						"compute_asymp_two_sided_pval",
						"compute_wald_two_sided_pval",
						"compute_wald_confidence_interval",
						"compute_bootstrap_confidence_interval",
						"compute_bootstrap_two_sided_pval",
						"compute_bayesian_bootstrap_two_sided_pval",
						"compute_bayesian_bootstrap_confidence_interval",
						"compute_jackknife_wald_two_sided_pval",
						"compute_jackknife_wald_confidence_interval"
					),
					provides_private_methods = c(
						"is_a_incid_gcomp",
						"compute_treatment_estimate_during_randomization_inference",
						"build_design_matrix",
						"get_estimand_type",
						"get_covariate_names",
						"default_null_value",
						"compute_rr_bootstrap_basic_confidence_interval",
						"compute_rr_bayesian_bootstrap_log_confidence_interval",
						"compute_rr_jackknife_log_se",
						"compute_rr_jackknife_wald_two_sided_pval",
						"compute_rr_jackknife_wald_confidence_interval",
						"set_failed_fit_cache",
						"effects_are_usable",
						"weighted_gcomp_fit",
						"weighted_gcomp_effects_from_row_weights",
						"coefficients_are_usable",
						"fit_logistic_with_sandwich",
						"compute_standardized_effects_r",
						"compute_standardized_effects",
						"get_effect_estimate",
						"compute_effect_confidence_interval",
						"compute_effect_pvalue",
						"shared",
						"best_X_colnames",
						"gcomp_boot_beta",
						"prob_clip_eps",
						"max_abs_reasonable_coef"
					),
					# "wald" -- see the identical fix/rationale on
					# `IncidenceKKGComputation` above (per user request,
					# 2026-08-23): this component's `compute_wald_two_sided_
					# pval`/`compute_wald_confidence_interval`/
					# `compute_asymp_confidence_interval`/`compute_asymp_
					# two_sided_pval` work correctly but had no declared
					# capability, hiding them from `run_all_inference()`.
					provides_capabilities = "wald",
					allowed_likelihood_tiers = "none",
					declare_body_references_optional = TRUE
				),
				SurvivalWeibullLikelihood = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalWeibullLikelihoodSource",
					file = "inference_survival_weibull.R",
					dependencies = "StandardModelCache",
					owns_state = c("best_X_colnames", "cached_mod"),
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
						"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
						"compute_bayesian_bootstrap_two_sided_pval",
						"compute_lik_ratio_bartlett_approx_two_sided_pval",
						"compute_rand_two_sided_pval"
					),
					provides_private_methods = c(
						"bayesian_boot_compute_bayesian_bootstrap_two_sided_pval",
						"rand_compute_rand_two_sided_pval",
						"get_complexity_tier",
						"weibull_kernel_fit", "weibull_kernel_score", "weibull_kernel_hessian",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker", "supports_lik_ratio_param_bootstrap",
						"supports_likelihood_tests", "simulate_under_lik_null", "get_likelihood_test_spec",
						"generate_mod", "build_design_matrix", "best_X_colnames", "cached_mod"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalDepCensTransform = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalDepCensTransformSource",
					file = "inference_survival_dep_cens_transform.R",
					# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
					# migration ladders): was `character()` -- this component's own body
					# calls `private$shared()` (compute_estimate/compute_asymp_
					# confidence_interval/compute_asymp_two_sided_pval/get_likelihood_
					# test_spec all use it), which only exists via StandardModelCache.
					# This spec had never actually been composed by a concrete class
					# before this migration, so the missing dependency was never
					# exercised until now (surfaced as "attempt to apply non-function"
					# calling private$shared() -> NULL).
					dependencies = "StandardModelCache",
					owns_state = c("dep_cens_bootstrap_ci_max_abs", "best_X_colnames", "cached_mod", "max_abs_reasonable_coef"),
					requires_state = "cached_vc_params",
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
						"compute_jackknife_estimate", "compute_jackknife_bias_estimate",
						"compute_jackknife_std_error", "compute_jackknife_wald_two_sided_pval",
						"compute_jackknife_wald_confidence_interval", "compute_rand_two_sided_pval",
						"compute_rand_confidence_interval", "compute_bootstrap_confidence_interval",
						"compute_bootstrap_confidence_interval_basic", "compute_bootstrap_confidence_interval_bca",
						"compute_bootstrap_confidence_interval_studentized",
						"approximate_randomization_distribution_beta_hat_T",
						"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval",
						"compute_score_two_sided_pval", "compute_lik_ratio_confidence_interval"
					),
					provides_private_methods = c(
						"nonparam_boot_compute_bootstrap_confidence_interval",
						"dep_cens_percentile_bootstrap_ci", "dep_cens_ci_excludes_zero",
						"dep_cens_ci_too_wide", "dep_cens_validate_bootstrap_ci",
						"compute_treatment_estimate_during_randomization_inference",
						"supports_reusable_bootstrap_worker", "supports_likelihood_tests",
						"get_likelihood_test_spec", "generate_mod", "supports_lik_ratio_param_bootstrap",
						"simulate_under_lik_null", "build_design_matrix", "dep_cens_bootstrap_ci_max_abs",
						"best_X_colnames", "cached_mod", "max_abs_reasonable_coef"
					),
					provides_capabilities = character(),
					# "full", not "none": InferenceSurvivalDepCensTransformRegr implements
					# a genuine full parametric likelihood (score/information/LR spec,
					# supports_likelihood_tests = TRUE, supports_lik_ratio_param_bootstrap
					# = TRUE, simulate_under_lik_null). It was previously misclassified
					# "none" only because infer_inference_likelihood_tier()'s name regex
					# didn't match "DepCensTransform" -- see fix_inference_hierarchy.md's
					# "Asymptotic (Wald) No-Likelihood Migration" 2026-08-17 tier-fix note.
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				# Leaf-only since the 2026-08-17 migration: the mixin-merged surface it
				# used to carry (harvested from the pre-migration raw-splice class) now
				# arrives through the KKPassThrough dependency; this component holds
				# only the class's own estimator overrides.
				SurvivalKKWeibullMarginal = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalKKWeibullMarginalSource",
					file = "inference_survival_KK_weibull_marginal.R",
					dependencies = "KKPassThrough",
					owns_state = "max_abs_reasonable_coef",
					requires_state = "cached_vc_params",
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
						"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval", "duplicate"
					),
					provides_private_methods = c(
						"compute_basic_match_data", "supports_likelihood_tests", "get_cluster_ids",
						"fit_weibull_marginal_cpp", "fit_weibull_marginal_survreg", "shared",
						"assert_finite_se", "get_standard_error", "get_degrees_of_freedom",
						"compute_treatment_estimate_during_randomization_inference",
						"compute_fast_rand_bootstrap_distr",
						"max_abs_reasonable_coef"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalGLMMWeibullFrailtyLoggammaIVWC = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalGLMMWeibullFrailtyLoggammaIVWCSource",
					file = "inference_survival_GLMM_weibull_frailty_loggamma.R",
					# Leaf-only since the 2026-08-17 migration: the KK compound layer
					# arrives through the KKCompound dependency.
					dependencies = "KKCompound",
					owns_state = c(
						"best_par", "best_X_colnames", "cached_mod",
						"best_X_colnames_matched", "best_X_colnames_reservoir",
						"cached_vc_params_matched", "cached_vc_params_reservoir",
						"max_abs_reasonable_coef"
					),
					requires_state = "optimization_alg",
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_estimate_with_bootstrap_weights",
						"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
					),
					provides_private_methods = c(
						"compute_basic_match_data", "compute_treatment_estimate_during_randomization_inference",
						"assert_finite_se", "filtered_covariate_candidates", "design_matrix_candidates",
						"shared", "clayton_copula_for_matched_pairs", "weibull_for_reservoir",
						"best_par", "best_X_colnames", "cached_mod",
						"best_X_colnames_matched", "best_X_colnames_reservoir",
						"cached_vc_params_matched", "cached_vc_params_reservoir", "max_abs_reasonable_coef"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalGLMMWeibullFrailtyLoggammaOneLik = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalGLMMWeibullFrailtyLoggammaOneLikSource",
					file = "inference_survival_GLMM_weibull_frailty_loggamma.R",
					# 2026-08-23 (fix_inference_hierarchy.md "Static Cleanup" / "Ban
					# raw component splicing"): the source is now leaf-only and the
					# KK pass-through surface arrives through this dependency, like
					# every other OneLik component; root-owned state is required,
					# never redeclared (Source Invariant 15).
					dependencies = "KKPassThrough",
					owns_state = "max_abs_reasonable_coef",
					requires_state = c(
						"m", "y_temp", "dead", "w", "X", "any_censoring", "optimization_alg"
					),
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_asymp_confidence_interval",
						"compute_asymp_two_sided_pval", "duplicate"
					),
					provides_private_methods = c(
						"compute_treatment_estimate_during_randomization_inference", "get_standard_error",
						"get_degrees_of_freedom", "assert_finite_se", "supports_likelihood_tests",
						"get_likelihood_test_spec", "filtered_covariate_candidates", "shared",
						"supports_lik_ratio_param_bootstrap", "simulate_under_lik_null",
						"max_abs_reasonable_coef"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalGLMMWeibullFrailtyNormalIVWC = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalGLMMWeibullFrailtyNormalIVWCSource",
					file = "inference_survival_GLMM_weibull_frailty_normal.R",
					# 2026-08-18 migration (same reshaping as SurvivalGLMMWeibullFrailtyLoggammaIVWC):
					# previously a self-harvested abstract component paired with a
					# separate ...IVWCLeaf component (now deleted); this is the merged
					# abstract+leaf static source, on the KKCompound dependency chain.
					dependencies = "KKCompound",
					owns_state = c(
						"best_par", "best_X_colnames",
						"cached_mod", "best_X_colnames_matched",
						"best_X_colnames_reservoir", "max_abs_reasonable_coef",
						"cached_vc_params_matched", "cached_vc_params_reservoir"
					),
					requires_state = c("optimization_alg", "any_censoring", "m"),
					provides_public_methods = c(
						"initialize", "compute_estimate", "compute_asymp_confidence_interval",
						"compute_asymp_two_sided_pval"
					),
					provides_private_methods = c(
						"is_a_kk_weibull_frailty_ivwc", "get_standard_error",
						"compute_basic_match_data",
						"supports_lik_ratio_param_bootstrap",
						"compute_treatment_estimate_during_randomization_inference",
						"frailty_for_matched_pairs", "weibull_for_reservoir", "shared",
						"assert_finite_se", "best_par", "best_X_colnames",
						"cached_mod", "best_X_colnames_matched",
						"best_X_colnames_reservoir", "max_abs_reasonable_coef",
						"cached_vc_params_matched", "cached_vc_params_reservoir"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalGLMMWeibullFrailtyNormalOneLik = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalGLMMWeibullFrailtyNormalOneLikSource",
					file = "inference_survival_GLMM_weibull_frailty_normal.R",
					# 2026-08-23 (fix_inference_hierarchy.md "Static Cleanup" / "Ban
					# raw component splicing"): leaf-only source; the KK pass-through
					# surface arrives through this dependency and root-owned state
					# is required, never redeclared (Source Invariant 15).
					dependencies = "KKPassThrough",
					owns_state = c("use_rcpp", "max_abs_reasonable_coef"),
					requires_state = c(
						"m", "y_temp", "dead", "w", "X", "any_censoring",
						"optimization_alg", "cached_vc_params"
					),
					provides_public_methods = c(
						"compute_estimate_with_bootstrap_weights",
						"initialize", "compute_estimate", "compute_asymp_confidence_interval",
						"compute_asymp_two_sided_pval",
						# Added 2026-08-19 migration: generic-`self$`-aliased overrides
						# (see the source file's header comment).
						"compute_asymp_confidence_interval_generic", "compute_asymp_two_sided_pval_generic"
					),
					provides_private_methods = c(
						"is_a_kk_weibull_frailty_one_lik", "shared_combined_likelihood",
						"supports_likelihood_tests", "get_likelihood_test_spec", "get_standard_error",
						"get_degrees_of_freedom", "assert_finite_se", "supports_lik_ratio_param_bootstrap",
						"simulate_under_lik_null", "compute_treatment_estimate_during_randomization_inference",
						"use_rcpp", "max_abs_reasonable_coef"
					),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				SurvivalGLMMWeibullFrailtyNormalOneLikLeaf = list(
					status = "active",
					load_policy = "lazy",
					source_name = "SurvivalGLMMWeibullFrailtyNormalOneLikLeafSource",
					file = "inference_survival_GLMM_weibull_frailty_normal.R",
					dependencies = character(),
					provides_public_methods = "initialize",
					provides_private_methods = character(),
					provides_capabilities = character(),
					allowed_likelihood_tiers = "full",
					declare_body_references_optional = TRUE
				),
				KKGEE = list(
					status = "active",
					source_name = "InferenceMixinKKGEEShared",
		file = "inference_mixin_kk_gee_shared.R",
		dependencies = c("BayesianBootstrap", "Wald"),
		owns_state = c("use_rcpp", "max_abs_reasonable_coef", "kk_gee_engine"),
		# des_obj_priv_int added 2026-08-19 (fix_inference_hierarchy.md "KK And
		# IVWC Estimators", "finish declaring every KKPassThrough/KKCompound/
		# KKGEE/KKGLMM host requirement"): compute_rand_two_sided_pval()
		# (below) reads it unconditionally, and it's a root Inference field
		# (set directly in Inference$initialize(), not owned by any component)
		# so it's always present regardless of composition -- confirmed via
		# complete_component_reference_contract()'s reference scan
		# (EDI_VALIDATE_INFERENCE_CONTRACTS=true), which previously found this
		# as an undeclared reference. custom_randomization_statistic_function/
		# randomization_mc_control (RandomizationTest's owns_state) were
		# DELIBERATELY left undeclared here despite also being referenced:
		# they're read defensively (`is.null(private$x)`, always safe even if
		# the binding was never materialized) and, for
		# custom_randomization_statistic_function specifically, never exist as
		# a static private-list entry at all -- it's created dynamically the
		# first time `set_custom_randomization_statistic_function()` runs
		# (`private[["custom_randomization_statistic_function"]] = ...`), so
		# declaring it in requires_state made define_inference_class()'s
		# static private-name check fail even though the resolved component
		# chain genuinely includes RandomizationTest (verified: adding both
		# here broke `InferenceCountPoissonKKGEE`'s load with "missing private
		# state required by KKGEE"). Left as an accepted gap in the static
		# contract rather than force-declared.
		requires_state = c(
			"any_censoring", "cached_values", "harden", "n", "y",
			"des_obj_priv_int", "m"
		),
		requires_public_methods = c(
			# is_nonestimable is guarded with is.function(self$is_nonestimable)
			# in compute_rand_two_sided_pval(), so it's declared required (always
			# present on the root chain) rather than merely optional -- the
			# is.function() guard there is defensive, not a sign of absence.
			"is_nonestimable"
		),
		requires_private_methods = c(
			"cache_nonestimable_estimate", "cache_nonestimable_se", "clear_nonestimable_state",
			"compute_z_or_t_ci_from_s_and_df", "compute_z_or_t_two_sided_pval_from_s_and_df",
			"create_design_matrix", "expand_subject_or_block_weights_to_row_weights",
			"fit_with_hardened_qr_column_dropping", "gee_family", "gee_response_type",
			"get_fit_warm_start_fisher", "get_fit_warm_start_for_length",
			"get_fit_warm_start_weights", "set_fit_warm_start", "shared_gee_dispatch",
			# The following 13 are the compute_rand_two_sided_pval()
			# randomization-test path's dependencies on the always-composed
			# RandomizationTest/RandomizationCI/InferenceAll base chain --
			# same discovery/rationale as requires_state above.
			"assert_design_supports_randomization_draw",
			"assert_no_incidence_only_randomization_args",
			"build_randomization_distribution_cache_key",
			"compute_exact_two_sided_pval_rand",
			"compute_two_sided_pval_with_sequential_mc",
			"compute_two_sided_randomization_pval_from_t0s",
			"ensure_resampling_distribution_cache",
			"generate_permutations",
			"get_randomization_distribution_prefix",
			"normalize_exact_inference_args",
			"sequential_mc_control_enabled",
			"should_use_design_randomization_for_incidence",
			"should_use_zhang_incidence_randomization"
		),
		optional_public_methods = c(
			"compute_jackknife_wald_confidence_interval",
			"compute_jackknife_wald_two_sided_pval"
		),
		optional_private_methods = character(),
		provides_capabilities = c("kk_gee", "wald"),
		allowed_likelihood_tiers = c("quasi"),
		conflicts = character(),
		declare_body_references_optional = TRUE
	),
	RobustSandwich = list(
		status = "active",
		source_name = "RobustSandwichSource",
		file = "helper_robust_sandwich.R",
		dependencies = character(),
		provides_capabilities = "robust_sandwich",
		allowed_likelihood_tiers = "quasi",
		declare_body_references_optional = TRUE
	),
	KKGLMM = list(
		status = "active",
		load_policy = "lazy",
		# `declare_body_references_optional = TRUE` is deliberately NOT set
		# here: register_inference_component_from_spec() skips the reference-
		# completeness scan entirely for `load_policy = "lazy"` components
		# (their `public`/`private` are left empty at registration time, so
		# the auto-scan would be vacuous). Verified 2026-08-19 (fix_inference_
		# hierarchy.md "KK And IVWC Estimators", "finish declaring every
		# KKPassThrough/KKCompound/KKGEE/KKGLMM host requirement") by manually
		# harvesting the real source (InferenceMixinKKGLMMShared) and running
		# component_body_references()/component_declared_reference_names()
		# against it directly: zero undeclared private/self/super references.
		source_name = "InferenceMixinKKGLMMShared",
		file = "inference_mixin_kk_glmm_shared.R",
		dependencies = character(),
		owns_state = c(
			"skip_glmm_pkg_check",
			"max_abs_reasonable_coef", "kk_glmm_engine"
		),
		provides_public_methods = c(
			"compute_estimate", "compute_estimate_with_bootstrap_weights",
			"compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"
		),
		provides_private_methods = c(
			"skip_glmm_pkg_check",
			"max_abs_reasonable_coef", "kk_glmm_engine",
			"is_a_glmm_family", "init_kk_glmm_shared", "glmm_predictors_df",
			"glmm_predictors_df_candidates", "get_standard_error",
			"get_degrees_of_freedom", "shared_glmm_tmb", "assert_finite_se",
			"fit_glmm_on_data", "fit_weighted_glmm_on_data", "fit_glmm",
			"compute_weighted_glmm_bootstrap_estimate", ".is_usable_glmm_fit"
		),
		requires_state = c("any_censoring", "cached_values", "harden", "n", "y", "m", "optimization_alg"),
		requires_public_methods = c("get_testing_type", "num_cores"),
		requires_private_methods = c(
			"cache_nonestimable_estimate", "clear_nonestimable_state",
			"compute_standard_error_from_information_matrix",
			"compute_z_or_t_ci_from_s_and_df", "compute_z_or_t_two_sided_pval_from_s_and_df",
			"create_design_matrix", "expand_subject_or_block_weights_to_row_weights",
			"fit_with_hardened_qr_column_dropping", "glmm_family", "glmm_response_type",
			"shared"
		),
		optional_public_methods = character(),
		optional_private_methods = character(),
		requires_super_methods = c("compute_asymp_confidence_interval", "compute_asymp_two_sided_pval"),
		provides_capabilities = c("kk_glmm", "wald"),
		allowed_likelihood_tiers = c("partial", "full"),
		conflicts = character()
	),
	KKPassThrough = list(
		status = "active",
		source_name = "InferenceMixinKKPassThrough",
		file = "inference_mixin_kk_passthrough.R",
		dependencies = character(),
		# Root-owned state (m, y_temp, dead, w, X, any_censoring, optimization_alg)
		# is no longer redeclared here (fix_inference_hierarchy.md, Source
		# Invariant 15, closed 2026-08-23): it is required from the root, and
		# the historical "lbfgs" optimizer default is established through the
		# root setter in init_kk_passthrough().
		owns_state = c(
			"kk_passthrough", "best_par", "cached_mod",
			"best_X_colnames", "best_Xmm_colnames"
		),
		requires_state = c(
			"cached_values", "des_obj_priv_int", "has_match_structure", "n", "y",
			"m", "y_temp", "dead", "w", "X", "any_censoring", "optimization_alg"
		),
		requires_public_methods = c("duplicate", "num_cores"),
		requires_private_methods = c(
			"assert_valid_bootstrap_type", "cache_nonestimable_estimate",
			"effective_parallel_cores",
			"expand_subject_or_block_weights_to_row_weights", "get_X", "has_private_method",
			"object_has_private_method", "par_lapply", "supports_likelihood_tests"
		),
		optional_public_methods = character(),
		optional_private_methods = c("compute_fast_bootstrap_distr", "compute_weighted_estimate_ivwc"),
		requires_super_methods = "approximate_bootstrap_distribution_beta_hat_T",
		provides_capabilities = c("kk_passthrough", "nonparametric_bootstrap"),
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		conflicts = character(),
		# Enabled 2026-08-19 (fix_inference_hierarchy.md "KK And IVWC
		# Estimators", "finish declaring every KKPassThrough/KKCompound/
		# KKGEE/KKGLMM host requirement"): verified complete via
		# complete_component_reference_contract() (EDI_VALIDATE_INFERENCE_
		# CONTRACTS=true) -- zero undeclared private/self/super references
		# found. Enabling the check here (rather than leaving it off) makes
		# that completeness a standing guarantee instead of a one-time audit.
		declare_body_references_optional = TRUE
	),
	KKCompound = list(
		status = "active",
		source_name = "InferenceMixinKKPassThroughCompound",
		file = "inference_mixin_kk_passthrough_compound.R",
		dependencies = "KKPassThrough",
		owns_state = "kk_passthrough_compound",
		requires_state = c("cached_values", "has_match_structure"),
		requires_public_methods = character(),
		requires_private_methods = c("cache_nonestimable_estimate", "compute_basic_kk_match_data_impl"),
		optional_public_methods = character(),
		optional_private_methods = character(),
		provides_capabilities = "kk_compound",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		conflicts = character(),
		# Enabled 2026-08-19, same rationale as KKPassThrough above: verified
		# complete via complete_component_reference_contract().
		declare_body_references_optional = TRUE
	),
	OffOptimumLikelihoodEval = list(
		status = "active",
		source_name = "InferenceMixinOffOptimumLikelihoodEval",
		file = "inference_mixin_off_optimum_likelihood_eval.R",
		dependencies = character(),
		owns_state = character(),
		requires_state = character(),
		requires_public_methods = character(),
		requires_private_methods = c("get_default_information_source", "get_likelihood_test_spec"),
		optional_public_methods = character(),
		optional_private_methods = character(),
		provides_capabilities = "off_optimum_likelihood_eval",
		allowed_likelihood_tiers = c("partial", "full"),
		conflicts = character()
	),
	QuantileRandomizationCI = list(
		status = "active",
		source_name = "InferenceExtQuantileRandCI",
		file = "inference_ext_quantile_rand_ci.R",
		dependencies = character(),
		owns_state = c("quantile_rand_ci", "nsim_rand"),
		# State used by the CI implementation is supplied through the unresolved
		# randomization chain or by concrete estimator descendants.
		requires_state = character(),
		requires_public_methods = c(
			"compute_estimate", "compute_asymp_confidence_interval"
		),
		requires_private_methods = character(),
		optional_public_methods = character(),
		# These hooks arrive through the lazily resolved randomization ancestor
		# chain and are exercised only by concrete quantile-regression hosts.
		optional_private_methods = c(
			"compute_rand_pval_matched_pairs", "compute_rand_pval_reservoir"
		),
		provides_capabilities = "quantile_randomization_ci",
		allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
		conflicts = character(),
		declare_body_references_optional = TRUE
	),
	BartlettApproximation = list(
		status = "active",
		load_policy = "lazy",
		source_name = "InferenceExtBartlettApprox",
		file = "inference_ext_bartlett_approx.R",
		dependencies = "ParametricLikelihoodBootstrap",
		owns_state = c(
			"bartlett_factor_mc_min_usable_fraction",
			"bartlett_factor_mc_max_attempts_per_replicate"
		),
		provides_public_methods = character(),
		provides_private_methods = c(
			"bartlett_factor_mc_min_usable_fraction",
			"bartlett_factor_mc_max_attempts_per_replicate",
			"supports_bartlett_likelihood_ratio_approx",
			"get_bartlett_factor_approx"
		),
		requires_state = "active_resampling_operation",
		requires_public_methods = character(),
		requires_private_methods = c(
			"supports_lik_ratio_param_bootstrap",
			"run_param_bootstrap_replicates",
			"param_bootstrap_lr_extreme"
		),
		optional_public_methods = character(),
		optional_private_methods = character(),
		requires_super_methods = character(),
		requires_capabilities = "parametric_likelihood_bootstrap",
		provides_capabilities = "bartlett_approximation",
		allowed_likelihood_tiers = c("partial", "full"),
		conflicts = character()
	)
)

InferenceComponent = function(
	name,
	status = c("active", "scaffold"),
	source_name = name,
	file,
	public = list(),
	private = list(),
	component_loader = list(load_policy = "eager"),
	dependencies = character(),
	provides_public_methods = names(public) %||% character(),
	provides_private_methods = names(private) %||% character(),
	owns_state = character(),
	requires_state = character(),
	requires_public_methods = character(),
	requires_private_methods = character(),
	optional_public_methods = character(),
	optional_private_methods = character(),
	requires_super_methods = character(),
	requires_capabilities = character(),
	provides_capabilities = character(),
	allowed_likelihood_tiers = EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS,
	conflicts = character(),
	allowed_host_overrides = list(public = character(), private = character()),
	forbidden_refs = list(private = character(), self = character(), super = character())
) {
	status = match.arg(status)
	component = list(
		name = name,
		status = status,
		source_name = source_name,
		file = file,
		public = public,
		private = private,
		component_loader = component_loader,
		dependencies = dependencies,
		provides_public_methods = provides_public_methods,
		provides_private_methods = provides_private_methods,
		owns_state = owns_state,
		requires_state = requires_state,
		requires_public_methods = requires_public_methods,
		requires_private_methods = requires_private_methods,
		optional_public_methods = optional_public_methods,
		optional_private_methods = optional_private_methods,
		requires_super_methods = requires_super_methods,
		requires_capabilities = requires_capabilities,
		provides_capabilities = provides_capabilities,
		allowed_likelihood_tiers = allowed_likelihood_tiers,
		conflicts = conflicts,
		allowed_host_overrides = allowed_host_overrides,
		forbidden_refs = forbidden_refs
	)
	validate_inference_component(component)
	component
}

validate_inference_component = function(component) {
	required = c(
		"name", "status", "source_name", "file", "public", "private",
		"component_loader", "dependencies", "provides_public_methods", "provides_private_methods",
		"owns_state", "requires_state", "requires_public_methods",
		"requires_private_methods", "optional_public_methods",
		"optional_private_methods", "requires_super_methods",
		"requires_capabilities", "provides_capabilities",
		"allowed_likelihood_tiers", "conflicts", "allowed_host_overrides",
		"forbidden_refs"
	)
	missing = setdiff(required, names(component))
	if (length(missing) > 0L) {
		stop(sprintf(
			"Inference component %s is missing required field(s): %s",
			component$name %||% "<unknown>",
			paste(missing, collapse = ", ")
		), call. = FALSE)
	}
	if (!is.character(component$name) || length(component$name) != 1L || !nzchar(component$name)) {
		stop("Inference component field `name` must be a non-empty character scalar.", call. = FALSE)
	}
	if (!(component$status %in% EDI_COMPONENT_ALLOWED_STATUSES)) {
		stop(sprintf("Inference component %s has invalid status.", component$name), call. = FALSE)
	}
	if (!is.list(component$public) || !is.list(component$private)) {
		stop(sprintf("Inference component %s must provide public/private lists.", component$name), call. = FALSE)
	}
	if (!is.list(component$component_loader)) {
		stop(sprintf("Inference component %s must provide `component_loader` metadata.", component$name), call. = FALSE)
	}
	load_policy = component$component_loader$load_policy %||% "eager"
	if (!identical(load_policy, "eager") && !identical(load_policy, "lazy")) {
		stop(sprintf("Inference component %s has invalid load policy.", component$name), call. = FALSE)
	}
	for (field in setdiff(required, c("public", "private", "component_loader", "allowed_host_overrides", "forbidden_refs"))) {
		if (!is.character(component[[field]])) {
			stop(sprintf("Inference component %s has non-character `%s`.", component$name, field), call. = FALSE)
		}
	}
	if (!all(component$allowed_likelihood_tiers %in% EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS)) {
		stop(sprintf("Inference component %s has invalid likelihood tier.", component$name), call. = FALSE)
	}
	if (!isTRUE(is_lazy_inference_component(component)) &&
			!identical(sort(component$provides_public_methods), sort(component_public_names(component)))) {
		stop(sprintf("Inference component %s has stale public method metadata.", component$name), call. = FALSE)
	}
	if (!isTRUE(is_lazy_inference_component(component)) &&
			!identical(sort(component$provides_private_methods), sort(component_private_names(component)))) {
		stop(sprintf("Inference component %s has stale private method metadata.", component$name), call. = FALSE)
	}
	invisible(TRUE)
}

register_inference_component = function(component) {
	validate_inference_component(component)
	if (exists(component$name, envir = EDI_INFERENCE_COMPONENTS, inherits = FALSE)) {
		stop(sprintf("Inference component already registered for %s.", component$name), call. = FALSE)
	}
	assign(component$name, component, envir = EDI_INFERENCE_COMPONENTS)
	invisible(component)
}

clear_inference_component_registry = function() {
	rm(list = ls(EDI_INFERENCE_COMPONENTS), envir = EDI_INFERENCE_COMPONENTS)
	clear_inference_component_implementation_cache()
	invisible(TRUE)
}

inference_component_registry_as_list = function() {
	mget(ls(EDI_INFERENCE_COMPONENTS), envir = EDI_INFERENCE_COMPONENTS, inherits = FALSE)
}

get_inference_component = function(name) {
	if (!exists(name, envir = EDI_INFERENCE_COMPONENTS, inherits = FALSE)) {
		stop(sprintf("No inference component registered for %s.", name), call. = FALSE)
	}
	get(name, envir = EDI_INFERENCE_COMPONENTS, inherits = FALSE)
}

EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE = new.env(parent = emptyenv())
EDI_INFERENCE_LAZY_DISPATCH_CACHE = new.env(parent = emptyenv())
EDI_INFERENCE_COMPONENT_LOAD_TRACE = new.env(parent = emptyenv())
EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE = new.env(parent = emptyenv())

is_lazy_inference_component = function(component) {
	identical(component$component_loader$load_policy %||% "eager", "lazy")
}

should_run_expensive_inference_contract_validation = function() {
	isTRUE(getOption("EDI.validate_inference_contracts", FALSE)) ||
		identical(Sys.getenv("EDI_VALIDATE_INFERENCE_CONTRACTS"), "true")
}

optional_package_available = function(pkg) {
	if (exists(pkg, envir = EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE, inherits = FALSE)) {
		return(get(pkg, envir = EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE, inherits = FALSE))
	}
	available = requireNamespace(pkg, quietly = TRUE)
	assign(pkg, available, envir = EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE)
	available
}

clear_inference_component_implementation_cache = function() {
	rm(list = ls(EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE), envir = EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE)
	rm(list = ls(EDI_INFERENCE_LAZY_DISPATCH_CACHE), envir = EDI_INFERENCE_LAZY_DISPATCH_CACHE)
	rm(list = ls(EDI_INFERENCE_COMPONENT_LOAD_TRACE), envir = EDI_INFERENCE_COMPONENT_LOAD_TRACE)
	rm(list = ls(EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE), envir = EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE)
	invisible(TRUE)
}

inference_component_load_trace = function(class_name = NULL) {
	if (is.null(class_name)) {
		return(mget(ls(EDI_INFERENCE_COMPONENT_LOAD_TRACE), envir = EDI_INFERENCE_COMPONENT_LOAD_TRACE, inherits = FALSE))
	}
	get0(class_name, envir = EDI_INFERENCE_COMPONENT_LOAD_TRACE, inherits = FALSE, ifnotfound = character())
}

component_public_names = function(component) {
	if (isTRUE(is_lazy_inference_component(component))) {
		return(component$provides_public_methods %||% character())
	}
	names(component$public) %||% character()
}

component_private_names = function(component) {
	if (isTRUE(is_lazy_inference_component(component))) {
		return(component$provides_private_methods %||% character())
	}
	names(component$private) %||% character()
}

inference_component_source_parts = function(source) {
	if (inherits(source, "R6ClassGenerator")) {
		public = as.list(source$public_methods)
		public$clone = NULL
		private = c(as.list(source$private_methods), as.list(source$private_fields))
		return(list(public = public, private = private))
	}
	if (is.list(source) && all(c("public", "private") %in% names(source))) {
		return(list(
			public = as.list(source$public),
			private = as.list(source$private)
		))
	}
	stop("Inference component source must be an R6 generator or public/private list.", call. = FALSE)
}

find_inference_component_source_file = function(file) {
	if (file.exists(file)) {
		return(normalizePath(file, mustWork = FALSE))
	}
	candidates = c(
		file.path("R", file),
		file.path("EDI", "R", file),
		file.path("R", "EDI", "R", file),
		system.file("R", file, package = "EDI")
	)
	candidates = candidates[nzchar(candidates)]
	hits = candidates[file.exists(candidates)]
	if (length(hits) == 0L) return(NA_character_)
	normalizePath(hits[[1L]], mustWork = FALSE)
}

get_inference_component_cache_env = function(class_name) {
	class_name = class_name %||% "<global>"
	if (!exists(class_name, envir = EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE, inherits = FALSE)) {
		assign(class_name, new.env(parent = emptyenv()), envir = EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE)
	}
	get(class_name, envir = EDI_INFERENCE_COMPONENT_IMPLEMENTATION_CACHE, inherits = FALSE)
}

get_inference_component_dispatch_cache_env = function(class_name) {
	class_name = class_name %||% "<global>"
	if (!exists(class_name, envir = EDI_INFERENCE_LAZY_DISPATCH_CACHE, inherits = FALSE)) {
		assign(class_name, new.env(parent = emptyenv()), envir = EDI_INFERENCE_LAZY_DISPATCH_CACHE)
	}
	get(class_name, envir = EDI_INFERENCE_LAZY_DISPATCH_CACHE, inherits = FALSE)
}

get_lazy_component_dispatch = function(component_name, class_name) {
	cache = get_inference_component_dispatch_cache_env(class_name)
	if (exists(component_name, envir = cache, inherits = FALSE)) {
		return(get(component_name, envir = cache, inherits = FALSE))
	}
	component = load_inference_component(component_name, class_name = class_name)
	dispatch = list(
		public = component$public,
		private = component$private
	)
	assign(component_name, dispatch, envir = cache)
	dispatch
}

load_inference_component = function(component_name, class_name = "<global>", ns = environment(populate_inference_component_registry)) {
	component = get_inference_component(component_name)
	cache = get_inference_component_cache_env(class_name)
	if (exists(component_name, envir = cache, inherits = FALSE)) {
		return(get(component_name, envir = cache, inherits = FALSE))
	}
	component_order = tryCatch(
		resolve_component_dependencies(component_name),
		error = function(e) {
			stop(sprintf("Cannot load inference component %s: %s", component_name, conditionMessage(e)), call. = FALSE)
		}
	)
	for (name in component_order) {
		if (exists(name, envir = cache, inherits = FALSE)) next
		meta = get_inference_component(name)
		for (pkg in meta$component_loader$optional_packages %||% character()) {
			if (!optional_package_available(pkg)) {
				stop(sprintf(
					"Cannot load inference component %s: optional package `%s` is not installed.",
					name,
					pkg
				), call. = FALSE)
			}
		}
		source_name = meta$source_name
		source = get0(source_name, envir = ns, inherits = TRUE, ifnotfound = NULL)
		if (is.null(source)) {
			source_file = find_inference_component_source_file(meta$file)
			if (is.na(source_file)) {
				stop(sprintf(
					"Cannot load inference component %s: source file `%s` was not found.",
					name,
					meta$file
				), call. = FALSE)
			}
			load_env = new.env(parent = ns)
			sys.source(source_file, envir = load_env)
			source = get0(source_name, envir = load_env, inherits = TRUE, ifnotfound = NULL)
			if (is.null(source)) {
				stop(sprintf(
					"Cannot load inference component %s: source object `%s` was not created by `%s`.",
					name,
					source_name,
					meta$file
				), call. = FALSE)
			}
		}
		parts = tryCatch(
			inference_component_source_parts(source),
			error = function(e) {
				stop(sprintf("Cannot load inference component %s: %s", name, conditionMessage(e)), call. = FALSE)
			}
		)
		loaded = meta
		loaded$public = parts$public
		loaded$private = parts$private
		loaded$component_loader$load_policy = "eager"
		if (!identical(sort(meta$provides_public_methods), sort(names(parts$public) %||% character()))) {
			stop(sprintf("Cannot load inference component %s: public method contract mismatch after load.", name), call. = FALSE)
		}
		if (!identical(sort(meta$provides_private_methods), sort(names(parts$private) %||% character()))) {
			stop(sprintf("Cannot load inference component %s: private method contract mismatch after load.", name), call. = FALSE)
		}
		validate_inference_component(loaded)
		assign(name, loaded, envir = cache)
		assign(class_name, c(get0(class_name, envir = EDI_INFERENCE_COMPONENT_LOAD_TRACE, inherits = FALSE, ifnotfound = character()), name),
			envir = EDI_INFERENCE_COMPONENT_LOAD_TRACE)
	}
	get(component_name, envir = cache, inherits = FALSE)
}

#' Re-bind already-installed lazy-component methods on a freshly cloned
#' \code{Inference} object to that clone's own \code{self}/\code{private}.
#'
#' \code{install_lazy_inference_component()} permanently binds each real
#' (non-stub) implementation it installs to whichever object triggered the
#' install, via \code{environment(value) = parent.frame()}. R6's
#' \code{clone()} correctly rebinds every method present in the class
#' generator's original method list, but a lazily-installed method is
#' injected into \code{private}/\code{self} at runtime and is invisible to
#' that bookkeeping, so a clone keeps calling back into the ORIGINAL
#' object's data (e.g. a Bayesian-bootstrap worker clone silently reading
#' the pre-clone object's \code{current_bayesian_bootstrap_context}, always
#' \code{NULL}, instead of its own). Call this right after \code{self$clone()}
#' to repoint every already-installed lazy-component method (public and
#' private) at the clone's own enclosing environment; state fields
#' (\code{owns_state}) are left untouched since \code{clone()} already
#' copies their current values correctly.
#'
#' @param i The freshly cloned \code{Inference} object.
#' @param source_private The pre-clone source object's own \code{private}
#'   environment, if available (\code{NULL} if not). \code{clone()} does not
#'   preserve environment-level attributes, so the "already installed"
#'   marker for a lazy component installed while the private environment was
#'   locked cannot be read from the clone's own private environment; when
#'   supplied, it is also read from \code{source_private} so those
#'   attribute-only markers are not missed. See the implementation comment
#'   below for the full mechanism.
edi_rebind_lazy_components_after_clone = function(i, source_private = NULL) {
	i_priv = i$.__enclos_env__$private
	loaded_marker_name = ".__loaded_lazy_components"
	read_marker = function(env) {
		unique(c(
			get0(loaded_marker_name, envir = env, inherits = FALSE, ifnotfound = character()),
			attr(env, loaded_marker_name, exact = TRUE) %||% character()
		))
	}
	# 2026-08-20 (fix_inference_hierarchy.md "Base Deletion" / per-class
	# migration ladders): two compounding bugs, both found via
	# `test-incidence-logit-bootstrap-fast-path.R` (a `Slow*` bootstrap test
	# subclass's row-resampled clones, from bootstrap_subset_inference() /
	# duplicate() / clone(), all returned the same constant estimate
	# regardless of the resampled data) and confirmed to reproduce
	# identically on the already-migrated `InferenceOrdinalPropOddsRegr` --
	# a pre-existing gap in the lazy-component/clone interaction, not
	# something specific to one migrated class:
	# (1) install_lazy_inference_component() stores the "already installed"
	#     marker as an ENVIRONMENT ATTRIBUTE (not a binding) whenever the
	#     private environment is already LOCKED at install time -- true for
	#     any R6 subclass that doesn't itself pass `lock_objects = FALSE`
	#     (every migrated class does; a plain `R6::R6Class(inherit =
	#     <migrated class>, ...)` test/user subclass does NOT by default),
	#     since `assign()`-ing a brand-new marker NAME would otherwise fail.
	#     This function's read used to check only the binding.
	# (2) `self$clone()` copies environment BINDINGS but does not preserve
	#     environment-level ATTRIBUTES, so even with (1) fixed, an
	#     attribute-stored marker never survives the clone at all -- there
	#     is nothing on the clone's own private env to read, regardless of
	#     how it's read. The marker (and hence which components need
	#     rebinding) must instead be read from the SOURCE instance's private
	#     environment, captured before/at the point of cloning -- `source_
	#     private` is threaded through from duplicate(), the only caller,
	#     whose own `private` is exactly that source, still valid at the
	#     call site regardless of what clone() did or didn't preserve.
	loaded = read_marker(i_priv)
	if (!is.null(source_private)) loaded = unique(c(loaded, read_marker(source_private)))
	if (!length(loaded)) return(invisible(i))
	new_env = i$.__enclos_env__
	rebind_fn_env = function(env, name) {
		if (!exists(name, envir = env, inherits = FALSE)) return(invisible(NULL))
		val = get(name, envir = env, inherits = FALSE)
		if (!is.function(val)) return(invisible(NULL))
		environment(val) = new_env
		# unlockBinding()/lockBinding(): flagged by R CMD check as a "possibly
		# unsafe call" NOTE, but genuinely required here, not a workaround to
		# remove -- R6 locks method bindings on any subclass built without
		# `lock_objects = FALSE`, and re-pointing a rebound method's closure
		# environment after clone() (this function's whole purpose) requires
		# reassigning that binding. Scope is minimal and always restored: only
		# this one already-existing binding is ever unlocked, and only for the
		# duration of the single `assign()` immediately below, re-locked
		# unconditionally afterward. Justified in cran-comments.md.
		was_locked = bindingIsLocked(name, env)
		if (isTRUE(was_locked)) unlockBinding(name, env)
		assign(name, val, envir = env)
		if (isTRUE(was_locked)) lockBinding(name, env)
		invisible(NULL)
	}
	for (component_name in loaded) {
		spec = EDI_COMPONENT_SPECS[[component_name]]
		if (is.null(spec)) next
		for (name in spec$provides_public_methods %||% character()) {
			rebind_fn_env(i, name)
		}
		for (name in spec$provides_private_methods %||% character()) {
			rebind_fn_env(i_priv, name)
		}
	}
	# Re-record the marker on the clone itself (as a binding if its private
	# env isn't locked, else as the same attribute fallback
	# install_lazy_inference_component() uses) so a clone-of-this-clone
	# also has something to read.
	if (!environmentIsLocked(i_priv)) {
		assign(loaded_marker_name, loaded, envir = i_priv)
	} else {
		attr(i_priv, loaded_marker_name) = loaded
	}
	invisible(i)
}

install_lazy_inference_component = function(self, private, class_name, component_name) {
	loaded_marker_name = ".__loaded_lazy_components"
	loaded = unique(c(
		get0(loaded_marker_name, envir = private, inherits = FALSE, ifnotfound = character()),
		attr(private, loaded_marker_name, exact = TRUE) %||% character()
	))
	if (component_name %in% loaded) {
		return(invisible(get_lazy_component_dispatch(component_name, class_name)))
	}
	dispatch = get_lazy_component_dispatch(component_name, class_name)
	method_env = parent.frame()
	assign_method = function(env, name, value) {
		if (is.function(value)) environment(value) = method_env
		if (exists(name, envir = env, inherits = FALSE)) {
			current = get(name, envir = env, inherits = FALSE)
			if (!is.function(value) && !is.null(current)) {
				return(invisible(current))
			}
			if (is.function(current) &&
					!identical(attr(current, "inference_lazy_component_stub", exact = TRUE), component_name)) {
				return(invisible(current))
			}
		}
		# unlockBinding()/lockBinding(): same justification as edi_rebind_
		# lazy_components_after_clone() above -- required to install a lazy
		# component's method onto a locked R6 public/private environment,
		# minimally scoped, always re-locked. See cran-comments.md.
		was_locked = exists(name, envir = env, inherits = FALSE) && bindingIsLocked(name, env)
		if (isTRUE(was_locked)) unlockBinding(name, env)
		env[[name]] = value
		if (isTRUE(was_locked)) lockBinding(name, env)
		invisible(value)
	}
	for (name in names(dispatch$private) %||% character()) {
		assign_method(private, name, dispatch$private[[name]])
	}
	for (name in names(dispatch$public) %||% character()) {
		assign_method(self, name, dispatch$public[[name]])
	}
	loaded = unique(c(loaded, component_name))
	if (exists(loaded_marker_name, envir = private, inherits = FALSE)) {
		# Direct write, bypassing assign_method()'s NULL-protection: that
		# protection exists to stop a second component's install from
		# clobbering a *state field* it doesn't itself own back to NULL, but
		# the marker is internal bookkeeping that must always grow to record
		# every component installed on this object -- applying the same
		# protection here silently truncated it to just the first-installed
		# component whenever a second, different component (e.g.
		# `BayesianBootstrap` after a lazy `initialize` already installed
		# some other component) was later installed on the same object,
		# which meant edi_rebind_lazy_components_after_clone() never saw
		# that second component and left its methods stale after clone().
		# unlockBinding()/lockBinding(): same justification as the two sites
		# above -- required to grow the lazy-component-install marker on a
		# locked private environment. See cran-comments.md.
		was_locked = bindingIsLocked(loaded_marker_name, private)
		if (isTRUE(was_locked)) unlockBinding(loaded_marker_name, private)
		assign(loaded_marker_name, loaded, envir = private)
		if (isTRUE(was_locked)) lockBinding(loaded_marker_name, private)
	} else if (!environmentIsLocked(private)) {
		assign(loaded_marker_name, loaded, envir = private)
	} else {
		attr(private, loaded_marker_name) = loaded
	}
	invisible(dispatch)
}

lazy_component_public_stub = function(component_name, method_name) {
	fn = function(...) NULL
	body(fn) = substitute({
		install_lazy_inference_component(self, private, class(self)[1L], .component_name)
		self[[.method_name]](...)
	}, list(.component_name = component_name, .method_name = method_name))
	attr(fn, "inference_lazy_component_stub") = component_name
	fn
}

lazy_component_private_stub = function(component_name, method_name) {
	fn = function(...) NULL
	body(fn) = substitute({
		install_lazy_inference_component(self, private, class(self)[1L], .component_name)
		private[[.method_name]](...)
	}, list(.component_name = component_name, .method_name = method_name))
	attr(fn, "inference_lazy_component_stub") = component_name
	fn
}

lazy_component_entries = function(component, slot) {
	if (identical(slot, "public")) {
		return(stats::setNames(
			lapply(component$provides_public_methods, function(method_name) {
				lazy_component_public_stub(component$name, method_name)
			}),
			component$provides_public_methods
		))
	}
	private_names = component$provides_private_methods
	private_state = intersect(private_names, component$owns_state)
	private_methods = setdiff(private_names, private_state)
	c(
		stats::setNames(vector("list", length(private_state)), private_state),
		stats::setNames(
			lapply(private_methods, function(method_name) {
				lazy_component_private_stub(component$name, method_name)
			}),
			private_methods
		)
	)
}

complete_component_reference_contract = function(component) {
	refs = component_body_references(component)
	declared = component_declared_reference_names(component)
	missing_private = setdiff(refs$private, declared$private)
	missing_self = setdiff(refs$self, declared$self)
	missing_super = setdiff(refs$super, declared$super)
	component$optional_private_methods = sort(unique(c(
		component$optional_private_methods,
		missing_private
	)))
	component$optional_public_methods = sort(unique(c(
		component$optional_public_methods,
		missing_self
	)))
	component$requires_super_methods = sort(unique(c(
		component$requires_super_methods,
		missing_super
	)))
	validate_inference_component(component)
	component
}

populate_inference_component_registry = function(
	ns = environment(populate_inference_component_registry),
	component_names = names(EDI_COMPONENT_SPECS)
) {
	clear_inference_component_registry()
	for (name in component_names) {
		register_inference_component_from_spec(name, ns = ns)
	}
	invisible(EDI_INFERENCE_COMPONENTS)
}

register_inference_component_from_spec = function(name, ns = environment(populate_inference_component_registry)) {
	if (exists(name, envir = EDI_INFERENCE_COMPONENTS, inherits = FALSE)) {
		return(invisible(get_inference_component(name)))
	}
	if (!(name %in% names(EDI_COMPONENT_SPECS))) {
		stop(sprintf("No inference component spec registered for %s.", name), call. = FALSE)
	}
	spec = EDI_COMPONENT_SPECS[[name]]
	for (dependency in spec$dependencies %||% character()) {
		register_inference_component_from_spec(dependency, ns = ns)
	}
	source_name = spec$source_name %||% name
	declare_body_references_optional = isTRUE(spec$declare_body_references_optional)
	load_policy = spec$load_policy %||% "eager"
	optional_packages = spec$optional_packages %||% character()
	spec$source_name = NULL
	spec$declare_body_references_optional = NULL
	spec$load_policy = NULL
	spec$optional_packages = NULL
	if (identical(load_policy, "lazy") &&
			!is.null(spec$provides_public_methods) &&
			!is.null(spec$provides_private_methods)) {
		parts = list(public = list(), private = list())
	} else {
		source = get(source_name, envir = ns, inherits = TRUE)
		parts = inference_component_source_parts(source)
	}
	component_args = list(
		name = name,
		source_name = source_name,
		public = parts$public,
		private = parts$private,
		component_loader = list(
			load_policy = load_policy,
			optional_packages = optional_packages
		)
	)
	if (is.null(spec$provides_public_methods)) {
		component_args$provides_public_methods = names(parts$public) %||% character()
	}
	if (is.null(spec$provides_private_methods)) {
		component_args$provides_private_methods = names(parts$private) %||% character()
	}
	component = do.call(InferenceComponent, c(component_args, spec))
	if (declare_body_references_optional &&
			!isTRUE(is_lazy_inference_component(component)) &&
			should_run_expensive_inference_contract_validation()) {
		component = complete_component_reference_contract(component)
	}
	register_inference_component(component)
	invisible(component)
}

ensure_inference_components_registered = function(component_names, ns = parent.frame()) {
	for (name in unique(component_names)) {
		register_inference_component_from_spec(name, ns = ns)
	}
	invisible(EDI_INFERENCE_COMPONENTS)
}

component_body_references = function(component) {
	refs = list(private = character(), self = character(), super = character())
	collect_from_expr = function(expr) {
		if (!is.call(expr) && !is.expression(expr)) return(invisible(NULL))
		if (is.call(expr) &&
				identical(as.character(expr[[1L]]), "$") &&
				length(expr) >= 3L &&
				is.symbol(expr[[2L]])) {
			lhs = as.character(expr[[2L]])
			if (lhs %in% names(refs)) {
				refs[[lhs]] <<- c(refs[[lhs]], as.character(expr[[3L]])[1L])
			}
		}
		for (i in seq_along(expr)) {
			collect_from_expr(expr[[i]])
		}
		invisible(NULL)
	}
	for (slot in c("public", "private")) {
		for (fn in component[[slot]]) {
			if (is.function(fn)) collect_from_expr(body(fn))
		}
	}
	lapply(refs, function(x) sort(unique(x)))
}

component_declared_reference_names = function(component) {
	list(
		private = sort(unique(c(
			component$provides_private_methods,
			component$owns_state,
			component$requires_state,
			component$requires_private_methods,
			component$optional_private_methods,
			component$forbidden_refs$private %||% character()
		))),
		self = sort(unique(c(
			component$provides_public_methods,
			component$requires_public_methods,
			component$optional_public_methods,
			component$forbidden_refs$self %||% character()
		))),
		super = sort(unique(c(
			component$requires_super_methods,
			component$forbidden_refs$super %||% character()
		)))
	)
}

validate_component_body_references = function(component) {
	if (!isTRUE(is_lazy_inference_component(component))) {
		component = complete_component_reference_contract(component)
	}
	refs = component_body_references(component)
	declared = component_declared_reference_names(component)
	offenders = character()
	for (receiver in names(refs)) {
		missing = setdiff(refs[[receiver]], declared[[receiver]])
		if (length(missing) > 0L) {
			offenders = c(offenders, sprintf(
				"%s has undeclared %s reference(s): %s",
				component$name,
				receiver,
				paste(missing, collapse = ", ")
			))
		}
	}
	if (length(offenders) > 0L) {
		stop(paste(offenders, collapse = "\n"), call. = FALSE)
	}
	invisible(TRUE)
}

validate_no_scaffold_effective_components = function(class_names = ls(EDI_INFERENCE_CLASS_REGISTRY)) {
	scaffold_components = names(Filter(function(component) {
		identical(component$status, "scaffold")
	}, inference_component_registry_as_list()))
	for (class_name in class_names) {
		components = get_effective_components(class_name)
		used_scaffolds = intersect(components, scaffold_components)
		if (length(used_scaffolds) > 0L) {
			stop(sprintf(
				"%s uses scaffold component(s): %s",
				class_name,
				paste(used_scaffolds, collapse = ", ")
			), call. = FALSE)
		}
	}
	invisible(TRUE)
}

resolve_component_dependencies = function(component_names, satisfied_components = character()) {
	duplicated_direct = sort(unique(component_names[duplicated(component_names)]))
	if (length(duplicated_direct) > 0L) {
		stop(sprintf(
			"Duplicate direct component(s): %s",
			paste(duplicated_direct, collapse = ", ")
		), call. = FALSE)
	}
	component_registry_names = ls(EDI_INFERENCE_COMPONENTS)
	unknown_components = setdiff(component_names, component_registry_names)
	if (length(unknown_components) > 0L) {
		stop(sprintf(
			"Unknown component(s): %s",
			paste(unknown_components, collapse = ", ")
		), call. = FALSE)
	}
	scaffold_components = component_names[vapply(component_names, function(component_name) {
		identical(get_inference_component(component_name)$status, "scaffold")
	}, logical(1L))]
	if (length(scaffold_components) > 0L) {
		stop(sprintf(
			"Scaffold component(s) cannot be resolved: %s",
			paste(scaffold_components, collapse = ", ")
		), call. = FALSE)
	}

	direct_dependency_hits = character()
	for (component_name in component_names) {
		deps = get_inference_component(component_name)$dependencies
		direct_dependency_hits = c(direct_dependency_hits, intersect(component_names, deps))
	}
	if (length(direct_dependency_hits) > 0L) {
		stop(sprintf(
			"Direct component list duplicates transitive dependency component(s): %s",
			paste(sort(unique(direct_dependency_hits)), collapse = ", ")
		), call. = FALSE)
	}

	resolved = character()
	visiting = character()
	expanded_dependencies = character()

	visit = function(component_name, path = character()) {
		if (component_name %in% satisfied_components) return(invisible(NULL))
		if (component_name %in% resolved) return(invisible(NULL))
		if (component_name %in% visiting) {
			cycle = c(path, component_name)
			stop(sprintf(
				"Component dependency cycle detected: %s",
				paste(cycle, collapse = " -> ")
			), call. = FALSE)
		}
		if (!(component_name %in% component_registry_names)) {
			stop(sprintf("Unknown component(s): %s", component_name), call. = FALSE)
		}
		component = get_inference_component(component_name)
		if (identical(component$status, "scaffold")) {
			stop(sprintf(
				"Scaffold component(s) cannot be resolved: %s",
				component_name
			), call. = FALSE)
		}
		visiting <<- c(visiting, component_name)
		for (dep in component$dependencies) {
			expanded_dependencies <<- c(expanded_dependencies, dep)
			visit(dep, c(path, component_name))
		}
		visiting <<- setdiff(visiting, component_name)
		resolved <<- c(resolved, component_name)
		invisible(NULL)
	}

	for (component_name in component_names) {
		visit(component_name)
	}

	resolved
}

normalise_inference_overrides = function(overrides = list()) {
	if (is.null(overrides)) overrides = list()
	utils::modifyList(
		list(public = character(), private = character(), state = character(), public_private = character()),
		overrides
	)
}

entry_kinds = function(entries) {
	if (length(entries) == 0L) return(character())
	stats::setNames(
		ifelse(vapply(entries, is.function, logical(1L)), "method", "state"),
		names(entries)
	)
}

combine_component_slot = function(target_name, component_names, slot, host_entries = list(), overrides = list(), resolve = TRUE) {
	overrides = normalise_inference_overrides(overrides)
	if (isTRUE(resolve)) {
		component_names = resolve_component_dependencies(component_names)
	}
	allowed = unique(c(overrides[[slot]], overrides$state))
	combined = list()
	combined_kinds = character()
	for (component_name in component_names) {
		component = get_inference_component(component_name)
		lazy_component = isTRUE(is_lazy_inference_component(component))
		component_entries = if (lazy_component) {
			lazy_component_entries(component, slot)
		} else {
			as.list(component[[slot]])
		}
		incoming_names = names(component_entries) %||% character()
		incoming_kinds = entry_kinds(component_entries)
		collisions = intersect(names(combined), incoming_names)
		kind_collisions = collisions[combined_kinds[collisions] != incoming_kinds[collisions]]
		undeclared_kind_collisions = setdiff(kind_collisions, allowed)
		if (length(undeclared_kind_collisions) > 0L) {
			stop(sprintf(
				"%s has undeclared %s method/state collision(s): %s",
				target_name,
				slot,
				paste(undeclared_kind_collisions, collapse = ", ")
			), call. = FALSE)
		}
		undeclared = setdiff(collisions, allowed)
		if (length(undeclared) > 0L) {
			stop(sprintf(
				"%s has undeclared %s component collision(s): %s",
				target_name,
				slot,
				paste(undeclared, collapse = ", ")
			), call. = FALSE)
		}
		# Lazy NULL entries are declared owned state and must survive assembly.
		# Eager legacy sources can still contain inherited NULL root fields that are
		# intentionally omitted until those sources are fully contract-trimmed.
		combined = utils::modifyList(combined, component_entries, keep.null = lazy_component)
		combined_kinds = entry_kinds(combined)
	}
	host_names = names(host_entries) %||% character()
	host_collisions = intersect(names(combined), host_names)
	undeclared_host_collisions = setdiff(host_collisions, allowed)
	if (length(undeclared_host_collisions) > 0L) {
		stop(sprintf(
			"%s overrides component %s member(s) without declaration: %s",
			target_name,
			slot,
			paste(undeclared_host_collisions, collapse = ", ")
		), call. = FALSE)
	}
	host_kinds = entry_kinds(host_entries)
	kind_collisions = host_collisions[combined_kinds[host_collisions] != host_kinds[host_collisions]]
	undeclared_kind_collisions = setdiff(kind_collisions, allowed)
	if (length(undeclared_kind_collisions) > 0L) {
		stop(sprintf(
			"%s overrides component %s method/state member(s) without declaration: %s",
			target_name,
			slot,
			paste(undeclared_kind_collisions, collapse = ", ")
		), call. = FALSE)
	}
	utils::modifyList(combined, host_entries, keep.null = TRUE)
}

assemble_public = function(target_name, component_names = character(), public = list(), overrides = list(), resolve = TRUE) {
	combine_component_slot(
		target_name = target_name,
		component_names = component_names,
		slot = "public",
		host_entries = public,
		overrides = overrides,
		resolve = resolve
	)
}

assemble_private = function(target_name, component_names = character(), private = list(), overrides = list(), resolve = TRUE) {
	combine_component_slot(
		target_name = target_name,
		component_names = component_names,
		slot = "private",
		host_entries = private,
		overrides = overrides,
		resolve = resolve
	)
}

r6_inherited_public_names = function(inherit) {
	collected = character()
	gen = inherit
	while (!is.null(gen)) {
		collected = c(
			collected,
			names(gen$public_methods) %||% character(),
			names(gen$active) %||% character()
		)
		# R6 permits a generator's parent to be resolved lazily. During package
		# loading that parent may legitimately be defined by a later Collate entry.
		gen = tryCatch(gen$get_inherit(), error = function(e) NULL)
	}
	unique(collected)
}

r6_inherited_private_names = function(inherit) {
	collected = character()
	gen = inherit
	while (!is.null(gen)) {
		collected = c(
			collected,
			names(gen$private_methods) %||% character(),
			names(gen$private_fields) %||% character()
		)
		# See r6_inherited_public_names(): an unresolved lazy ancestor is not a
		# reason to make factory validation fail while the namespace is loading.
		gen = tryCatch(gen$get_inherit(), error = function(e) NULL)
	}
	unique(collected)
}

#' Private state fields declared by the root of an R6 inheritance chain
#'
#' Walks `inherit` up through `get_inherit()` to the root generator and returns
#' the names of that root's non-function private entries (its state fields).
#' Used by \code{validate_inference_class_definition()} to enforce that no
#' component redeclares root-owned state (fix_inference_hierarchy.md, Source
#' Invariant 15). Returns \code{character()} when there is no parent.
#' @noRd
r6_root_private_state_names = function(inherit) {
	if (is.null(inherit)) return(character())
	# The legacy ladder's R6 `inherit =` expressions resolve lazily, so a
	# class defined before its deepest ancestors are sourced cannot walk the
	# chain yet; every inference generator roots at `Inference`, so fall back
	# to it by name in that case.
	root = tryCatch({
		generator = inherit
		while (!is.null(generator$get_inherit())) {
			generator = generator$get_inherit()
		}
		generator
	}, error = function(e) NULL)
	if (is.null(root)) {
		root = get0("Inference", envir = parent.env(environment()), inherits = FALSE)
	}
	if (is.null(root)) return(character())
	names(root$private_fields) %||% character()
}

validate_inference_class_definition = function(
	classname,
	inherit = NULL,
	component_names = character(),
	public = list(),
	private = list(),
	active = NULL,
	metadata = list(),
	overrides = list(),
	public_methods_for_capability = NULL,
	capability_requires = NULL,
	resolve_components = TRUE
) {
	overrides = normalise_inference_overrides(overrides)
	if (is.null(public_methods_for_capability)) {
		public_methods_for_capability = get("public_methods_for_capability", envir = parent.env(environment()))
	}
	if (is.null(capability_requires)) {
		capability_requires = get("capability_requires", envir = parent.env(environment()))
	}
	if (isTRUE(resolve_components)) {
		component_names = resolve_component_dependencies(component_names)
	}
	components = lapply(component_names, get_inference_component)
	# Source Invariant 15 (fix_inference_hierarchy.md): no component redeclares
	# root-owned state. Every private field the root generator declares has
	# exactly one owner -- the root -- so a component that touches it must list
	# it under `requires_state`, never `owns_state`. Enforced here (class
	# definition time, when the root generator is guaranteed to exist) in
	# addition to the static guardrail in test-static-cleanup-guardrails.R.
	root_state = r6_root_private_state_names(inherit)
	if (length(root_state) > 0L) {
		for (component in components) {
			redeclared = intersect(component$owns_state %||% character(), root_state)
			if (length(redeclared) > 0L) {
				stop(sprintf(
					"%s composes component %s, which redeclares root-owned state: %s. Root-owned state must be declared in `requires_state`, never `owns_state`.",
					classname,
					component$name,
					paste(redeclared, collapse = ", ")
				), call. = FALSE)
			}
		}
	}
	likelihood_tier = metadata$likelihood_tier %||% "none"
	capabilities = unique(c(
		as.character(unlist(lapply(components, `[[`, "provides_capabilities"), use.names = FALSE)),
		metadata$capabilities %||% character()
	))
	public_names = unique(c(r6_inherited_public_names(inherit), names(public) %||% character(), names(active) %||% character()))
	private_names = unique(c(r6_inherited_private_names(inherit), names(private) %||% character()))

	public_private_overlap = intersect(public_names, private_names)
	undeclared_public_private_overlap = setdiff(public_private_overlap, overrides$public_private)
	if (length(undeclared_public_private_overlap) > 0L) {
		stop(sprintf(
			"%s has undeclared public/private name duplication: %s",
			classname,
			paste(undeclared_public_private_overlap, collapse = ", ")
		), call. = FALSE)
	}

	for (capability in intersect(capabilities, names(capability_requires))) {
		requirements = capability_requires[[capability]]
		allowed_tiers = requirements$likelihood_tier %||% EDI_COMPONENT_ALLOWED_LIKELIHOOD_TIERS
		if (!(likelihood_tier %in% allowed_tiers)) {
			stop(sprintf(
				"%s advertises capability %s with disallowed likelihood tier `%s`.",
				classname,
				capability,
				likelihood_tier
			), call. = FALSE)
		}
		missing_public = setdiff(requirements$public_methods %||% character(), public_names)
		if (length(missing_public) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without required public method(s): %s",
				classname,
				capability,
				paste(missing_public, collapse = ", ")
			), call. = FALSE)
		}
		missing_private = setdiff(requirements$private_methods %||% character(), private_names)
		if (length(missing_private) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without required private method(s): %s",
				classname,
				capability,
				paste(missing_private, collapse = ", ")
			), call. = FALSE)
		}
		missing_state = setdiff(requirements$private_state %||% character(), private_names)
		if (length(missing_state) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without required private state: %s",
				classname,
				capability,
				paste(missing_state, collapse = ", ")
			), call. = FALSE)
		}
		missing_capabilities = setdiff(requirements$capabilities %||% character(), capabilities)
		if (length(missing_capabilities) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without required capability/capabilities: %s",
				classname,
				capability,
				paste(missing_capabilities, collapse = ", ")
			), call. = FALSE)
		}
		missing_metadata = setdiff(requirements$metadata %||% character(), names(metadata))
		if (length(missing_metadata) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without required metadata field(s): %s",
				classname,
				capability,
				paste(missing_metadata, collapse = ", ")
			), call. = FALSE)
		}
	}

	for (component in components) {
		if (!(likelihood_tier %in% component$allowed_likelihood_tiers)) {
			stop(sprintf(
				"%s uses component %s with disallowed likelihood tier `%s`.",
				classname,
				component$name,
				likelihood_tier
			), call. = FALSE)
		}
		missing_public = setdiff(component$requires_public_methods, public_names)
		if (length(missing_public) > 0L) {
			stop(sprintf(
				"%s is missing public method(s) required by %s: %s",
				classname,
				component$name,
				paste(missing_public, collapse = ", ")
			), call. = FALSE)
		}
		missing_private = setdiff(component$requires_private_methods, private_names)
		if (length(missing_private) > 0L) {
			stop(sprintf(
				"%s is missing private method(s) required by %s: %s",
				classname,
				component$name,
				paste(missing_private, collapse = ", ")
			), call. = FALSE)
		}
		missing_state = setdiff(component$requires_state, private_names)
		if (length(missing_state) > 0L) {
			stop(sprintf(
				"%s is missing private state required by %s: %s",
				classname,
				component$name,
				paste(missing_state, collapse = ", ")
			), call. = FALSE)
		}
		missing_capabilities = setdiff(component$requires_capabilities, capabilities)
		if (length(missing_capabilities) > 0L) {
			stop(sprintf(
				"%s is missing capability required by %s: %s",
				classname,
				component$name,
				paste(missing_capabilities, collapse = ", ")
			), call. = FALSE)
		}
	}

	for (capability in intersect(names(public_methods_for_capability), capabilities)) {
		missing_methods = setdiff(public_methods_for_capability[[capability]], public_names)
		if (length(missing_methods) > 0L) {
			stop(sprintf(
				"%s advertises capability %s without public method(s): %s",
				classname,
				capability,
				paste(missing_methods, collapse = ", ")
			), call. = FALSE)
		}
	}
	invisible(TRUE)
}

define_inference_class = function(
	classname,
	inherit = NULL,
	components = character(),
	public = list(),
	private = list(),
	active = NULL,
	metadata = list(),
	overrides = list(),
	public_methods_for_capability = NULL,
	lock_objects = FALSE,
	...
) {
	if (!identical(lock_objects, FALSE)) {
		stop("define_inference_class() must keep `lock_objects = FALSE` until the R6 tree is stable.", call. = FALSE)
	}
	if (length(components) > 0L) {
		ensure_inference_components_registered(
			ns = parent.frame(),
			component_names = unique(components)
		)
	}
	component_names = resolve_component_dependencies(components)
	assembled_public = assemble_public(classname, component_names, public, overrides, resolve = FALSE)
	assembled_private = assemble_private(classname, component_names, private, overrides, resolve = FALSE)
	validate_inference_class_definition(
		classname = classname,
		inherit = inherit,
		component_names = component_names,
		public = assembled_public,
		private = assembled_private,
		active = active,
		metadata = metadata,
		overrides = overrides,
		public_methods_for_capability = public_methods_for_capability,
		resolve_components = FALSE
	)
	R6::R6Class(
		classname = classname,
		lock_objects = FALSE,
		inherit = inherit,
		public = assembled_public,
		private = assembled_private,
		active = active,
		...
	)
}

assert_valid_mixin_composition = function(target_name, mixin_names, public_overrides = character(), private_overrides = character()) {
	duplicated_mixins = sort(unique(mixin_names[duplicated(mixin_names)]))
	if (length(duplicated_mixins) > 0L) {
		stop(sprintf(
			"%s composes duplicate mixin component(s): %s",
			target_name,
			paste(duplicated_mixins, collapse = ", ")
		), call. = FALSE)
	}
	for (mixin_name in mixin_names) {
		deps = EDI_MIXIN_DEPENDENCIES[[mixin_name]]
		missing_deps = setdiff(deps, mixin_names)
		if (length(missing_deps) > 0L) {
			stop(sprintf(
				"%s composes %s without required component(s): %s",
				target_name,
				mixin_name,
				paste(missing_deps, collapse = ", ")
			), call. = FALSE)
		}
	}
	for (slot in c("public", "private")) {
		slot_names = as.character(unlist(lapply(mixin_names, function(mixin_name) {
			mixin = get(mixin_name, envir = parent.frame(2L), inherits = TRUE)
			names(mixin[[slot]])
		}), use.names = FALSE))
		collisions = sort(unique(slot_names[duplicated(slot_names)]))
		allowed = EDI_MIXIN_ALLOWED_COLLISIONS[[target_name]][[slot]]
		undeclared = setdiff(collisions, allowed)
		if (length(undeclared) > 0L) {
			stop(sprintf(
				"%s has undeclared %s mixin collision(s): %s",
				target_name,
				slot,
				paste(undeclared, collapse = ", ")
			), call. = FALSE)
		}
		override_names = if (slot == "public") public_overrides else private_overrides
		override_collisions = intersect(slot_names, override_names)
		allowed_overrides = EDI_MIXIN_ALLOWED_OVERRIDES[[target_name]][[slot]]
		undeclared_overrides = setdiff(override_collisions, allowed_overrides)
		if (length(undeclared_overrides) > 0L) {
			stop(sprintf(
				"%s overrides inherited %s method(s) without declaration: %s",
				target_name,
				slot,
				paste(undeclared_overrides, collapse = ", ")
			), call. = FALSE)
		}
	}
	invisible(TRUE)
}

compose_inference_mixins = function(target_name, mixin_names, public = list(), private = list()) {
	assert_valid_mixin_composition(
		target_name = target_name,
		mixin_names = mixin_names,
		public_overrides = names(public),
		private_overrides = names(private)
	)
	component_names = unname(EDI_LEGACY_MIXIN_COMPONENT_NAMES[mixin_names])
	missing_component_names = mixin_names[is.na(component_names)]
	if (length(missing_component_names) > 0L) {
		stop(sprintf(
			"%s uses mixin(s) without canonical component mapping: %s",
			target_name,
			paste(missing_component_names, collapse = ", ")
		), call. = FALSE)
	}
	if (length(ls(EDI_INFERENCE_COMPONENTS)) == 0L) {
		populate_inference_component_registry(ns = parent.frame(), component_names = component_names)
	}
	allowed_collisions = EDI_MIXIN_ALLOWED_COLLISIONS[[target_name]] %||% list(public = character(), private = character())
	allowed_overrides = EDI_MIXIN_ALLOWED_OVERRIDES[[target_name]] %||% list(public = character(), private = character())
	overrides = list(
		public = unique(c(allowed_collisions$public, allowed_overrides$public, names(public))),
		private = unique(c(allowed_collisions$private, allowed_overrides$private, names(private)))
	)
	list(
		public = assemble_public(target_name, component_names, public, overrides = overrides, resolve = FALSE),
		private = assemble_private(target_name, component_names, private, overrides = overrides, resolve = FALSE)
	)
}
