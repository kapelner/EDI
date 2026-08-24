#' Comprehensive-test slow-path registry
#'
#' Performance-based exclusions used by EDI's comprehensive test harness.
#' These rules describe paths that are implemented but intentionally omitted
#' from routine exhaustive execution because their observed runtime is too
#' high. They do not change an inference class's public capabilities and must
#' not be interpreted as "not implemented" declarations.
#'
#' @details Rule-name prefixes use the harness vocabulary: `boot` is ordinary
#'   nonparametric bootstrap, `bbt` is Bayesian bootstrap, `brt` is bootstrap
#'   randomization, `pboot`/`param_bootstrap` are parametric bootstrap, and
#'   `rand` is randomization inference. Suffixes identify the affected CI,
#'   p-value, or typed variant. A class can appear in more than one category.
#'
#' `InferenceSuite$run_all_inference()` also omits matching class/method/type
#' combinations when its `methods` argument is left at the default `NULL`.
#' Supplying `methods` explicitly opts into the requested paths even when they
#' appear in this registry.
#'
#' @format A named list. `exact_operations` contains keys of the form
#'   `response_type||InferenceClass||operation`; every other element contains
#'   formula-, dataset-, and design-independent concrete inference-class names
#'   for the named slow-path family.
#' @seealso [InferenceSuite]
#' @export
EDI_COMPREHENSIVE_SLOW_PATHS = list(
	exact_operations = c(
		"count||InferenceCountHurdleNegBin||compute_rand_two_sided_pval",
		"proportion||InferenceAllSimpleWilcox||compute_rand_confidence_interval",
		"incidence||InferenceIncidKKCondLogitGLMMOneLik||compute_bayesian_bootstrap_two_sided_pval_bca",
		"count||InferenceCountHurdleNegBin||compute_rand_two_sided_pval(delta=0.5)",
		"ordinal||InferenceOrdinalKKGEE||compute_bootstrap_confidence_interval",
		"ordinal||InferenceOrdinalKKGLMM||compute_lik_ratio_bartlett_two_sided_pval",
		"survival||InferenceSurvivalWeibullRegr||compute_rand_two_sided_pval(delta=0.5)",
		"survival||InferenceSurvivalCoxPHRegr||compute_estimate"
	),
	bootstrap = c(
		"InferenceContinRobustRegr",
		"InferenceContinKKGLMM",
		"InferenceOrdinalStereotypeLogitRegr"
	),
	rand = c(
		"InferenceContinKKGLMM",
		"InferenceOrdinalStereotypeLogitRegr"
	),
	rand_ci = c("InferenceSurvivalWeibullRegr", "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceSurvivalGLMMWeibullFrailtyNormalOneLik", "InferenceSurvivalKKWeibullMarginal", "InferencePropQuantileRegr", "InferencePropKKGEE", "InferencePropBetaRegr"),
	score_ci = c("InferenceSurvivalGLMMWeibullFrailtyNormalOneLik"),
	lik_ratio_ci = c("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceSurvivalDepCensTransformRegr"),
	bbt_pval = c("InferenceIncidKKCondLogitGLMMOneLik"),
	bbt_pval_symmetric = c("InferenceIncidKKCondLogitGLMMOneLik"),
	bbt_pval_wald = c("InferenceIncidKKCondLogitGLMMOneLik"),
	bbt_pval_studentized = c("InferenceIncidKKCondLogitGLMMOneLik"),
	bbt_ci = c("InferenceIncidKKCondLogitGLMMOneLik"),
	bbt_ci_default = character(),
	boot_ci_default = c("InferenceIncidRiskDiff", "InferenceContinKKQuantileRegrOneLik", "InferenceSurvivalDepCensTransformRegr"),
	boot_ci_basic = character(),
	boot_ci_bca = c("InferenceIncidKKGCompRiskDiff"),
	boot_stud = c("InferenceIncidRiskDiff", "InferenceSurvivalGehanWilcox", "InferenceSurvivalDepCensTransformRegr", "InferenceOrdinalKKGEE", "InferenceIncidModifiedPoisson"),
	boot_pval_stud = c("InferenceAllSimpleAverageDiff", "InferenceSurvivalGehanWilcox", "InferenceOrdinalKKGEE"),
	boot_pval_symmetric = c("InferenceIncidKKGCompRiskRatio"),
	boot_ci = character(),
	jack = c("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceContinKKGLMM"),
	pboot_ci = c("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik"),
	lik_ratio_bootstrap_pval = c("InferenceSurvivalStratCoxPHRegr"),
	param_bootstrap_estimate = c("InferenceSurvivalStratCoxPHRegr"),
	param_bootstrap_pval = c("InferenceSurvivalStratCoxPHRegr"),
	param_bootstrap_ci = c("InferenceSurvivalStratCoxPHRegr"),
	# The 7 non-KK ordinal classes added 2026-08-24 (per user investigation:
	# "ordinal iBCRD" ran ~13 minutes) each recompute the Bartlett-approx
	# correction factor -- a fresh B=99-replicate parametric bootstrap (each
	# replicate a full ordinal MLE refit) -- at EVERY delta candidate the CI
	# root-finder tries (~15-40 evaluations per bound, ~30-80 per class), an
	# already-deliberate tradeoff (see `get_bartlett_factor_approx()`'s own
	# comment: worker-reuse across delta values was tried and found ~5x
	# slower, not faster). None of the 7 support the "exact" Bartlett
	# variant (`inference_class_supports_bartlett_exact()` is FALSE for all
	# of them), so this bucket -- which gates both "approx" and "exact" --
	# only ever suppresses "approx" here.
	bartlett_pval = c(
		"InferenceSurvivalStratCoxPHRegr",
		"InferenceOrdinalAdjCatLogitRegr", "InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr",
		"InferenceOrdinalContRatioRegr", "InferenceOrdinalOrderedProbitRegr", "InferenceOrdinalPropOddsRegr",
		"InferenceOrdinalStereotypeLogitRegr"
	),
	rand_delta_pval = c("InferenceIncidKKCondLogitGLMMOneLik", "InferenceOrdinalKKGEE"),
	brt_pval_smoothed = c("InferenceOrdinalKKGLMM", "InferenceOrdinalContRatioRegr", "InferenceOrdinalStereotypeLogitRegr", "InferenceOrdinalAdjCatLogitRegr", "InferenceSurvivalDepCensTransformRegr"),
	brt_pval_typed = c("InferenceCountKKHurdlePoissonOneLik", "InferenceCountKKCondPoissonOneLik"),
	brt_ci_all = c("InferenceSurvivalGehanWilcox", "InferenceSurvivalWeibullRegr", "InferencePropBetaRegr", "InferencePropKKGEE"),
	brt_ci_smoothed = c("InferenceAllSimpleWilcox", "InferencePropKKQuantileRegrOneLik"),
	brt_ci_typed = c("InferencePropKKQuantileRegrOneLik"),
	m_out_of_n = c("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferencePropZeroOneInflatedBetaRegr", "InferenceSurvivalWeibullRegr", "InferenceSurvivalStratCoxPHRegr", "InferenceSurvivalCoxPHRegr", "InferencePropQuantileRegr", "InferencePropBetaRegr", "InferencePropFractionalLogit", "InferenceCountHurdleNegBin", "InferenceCountPoissonKKGEE", "InferencePropKKGEE"),
	m_out_of_n_ci = c("InferenceCountPoissonKKGEE", "InferencePropKKGEE"),
	subsampling = c("InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceCountHurdleNegBin", "InferenceCountPoissonKKGEE")
)

EDI_COMPREHENSIVE_SLOW_PATH_RULE_NAMES = names(EDI_COMPREHENSIVE_SLOW_PATHS)

validate_comprehensive_slow_path_rules = function(rules = EDI_COMPREHENSIVE_SLOW_PATHS){
	if (!is.list(rules) || is.null(names(rules)) || any(!nzchar(names(rules))) || anyDuplicated(names(rules))) {
		stop("Comprehensive slow-path rules must be a uniquely named list.", call. = FALSE)
	}
	missing_rules = setdiff(EDI_COMPREHENSIVE_SLOW_PATH_RULE_NAMES, names(rules))
	unexpected_rules = setdiff(names(rules), EDI_COMPREHENSIVE_SLOW_PATH_RULE_NAMES)
	if (length(missing_rules) || length(unexpected_rules)) {
		stop(
			"Comprehensive slow-path rule schema mismatch; missing: ",
			paste(missing_rules, collapse = ", "),
			"; unexpected: ", paste(unexpected_rules, collapse = ", "),
			call. = FALSE
		)
	}
	for (rule_name in names(rules)) {
		values = rules[[rule_name]]
		if (!is.character(values) || anyNA(values) || any(!nzchar(values)) || anyDuplicated(values)) {
			stop("Comprehensive slow-path rule `", rule_name, "` must contain unique nonempty strings.", call. = FALSE)
		}
	}

	exact_parts = strsplit(rules$exact_operations, "||", fixed = TRUE)
	valid_responses = c("continuous", "incidence", "proportion", "count", "survival", "ordinal")
	bad_exact = vapply(
		exact_parts,
		function(parts) length(parts) != 3L || !(parts[[1L]] %in% valid_responses) ||
			!grepl("^Inference[A-Za-z0-9]+$", parts[[2L]]) || !nzchar(parts[[3L]]),
		logical(1L)
	)
	if (any(bad_exact)) {
		stop("Invalid comprehensive exact-operation key(s): ", paste(rules$exact_operations[bad_exact], collapse = ", "), call. = FALSE)
	}

	class_names = unique(c(
		vapply(exact_parts, `[[`, character(1L), 2L),
		unlist(rules[setdiff(names(rules), "exact_operations")], use.names = FALSE)
	))
	registry = inference_class_registry_as_list()
	missing_classes = setdiff(class_names, names(registry))
	if (length(missing_classes)) {
		stop("Comprehensive slow-path rules name unknown inference class(es): ", paste(missing_classes, collapse = ", "), call. = FALSE)
	}
	abstract_classes = class_names[vapply(class_names, function(class_name) {
		isTRUE(registry[[class_name]]$abstract)
	}, logical(1L))]
	if (length(abstract_classes)) {
		stop("Comprehensive slow-path rules must name concrete classes, not abstract classes: ", paste(abstract_classes, collapse = ", "), call. = FALSE)
	}
	invisible(TRUE)
}
