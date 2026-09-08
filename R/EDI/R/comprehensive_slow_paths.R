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
#' appear in this registry. Because of that coupling, an `exact_operations`
#' entry must never name the base `compute_estimate` operation itself (only a
#' CI/p-value sub-method, e.g. `compute_rand_two_sided_pval`) -- doing so
#' doesn't just skip one slow sub-computation, it silently drops the whole
#' class from `run_all_inference()`'s default output (found 2026-08-26: a
#' pre-existing `"survival||InferenceSurvivalCoxPHRegr||compute_estimate"`
#' entry, harmless while this registry was internal-only, started doing
#' exactly that the moment `run_all_inference()` began consulting it --
#' `compute_estimate()` for that class takes ~0.09s, nowhere near "too slow";
#' removed).
#'
#' @format A named list. `exact_operations` contains keys of the form
#'   `response_type||InferenceClass||operation`, optionally suffixed with
#'   `||model_formula` (e.g. `||~1`) to restrict the entry to that one
#'   formula -- an operation with no formula suffix is skipped for every
#'   formula, matching the pre-2026-09-08 behavior. `model_formula` is
#'   matched as the deparsed formula text (`"~1"`, `"~."`, ...). Every other
#'   element contains formula-, dataset-, and design-independent concrete
#'   inference-class names for the named slow-path family.
#' @seealso [InferenceSuite]
#' @export
EDI_COMPREHENSIVE_SLOW_PATHS = list(
	exact_operations = c(
		"incidence||InferenceIncidKKCondLogitGLMMOneLik||compute_bayesian_bootstrap_two_sided_pval_bca",
		"ordinal||InferenceOrdinalKKGEE||compute_bootstrap_confidence_interval",
		"ordinal||InferenceOrdinalKKGLMM||compute_lik_ratio_bartlett_two_sided_pval",
		# Observed mean runtime >30 seconds in the 2026-09-02 comprehensive
		# results. Exact entries intentionally collapse across design and formula.
		"ordinal||InferenceOrdinalStereotypeLogitRegr||compute_rand_two_sided_pval(delta=0.5)",
		"ordinal||InferenceOrdinalStereotypeLogitRegr||compute_bootstrap_confidence_interval",
		"ordinal||InferenceOrdinalStereotypeLogitRegr||compute_bootstrap_confidence_interval_studentized",
		"ordinal||InferenceOrdinalStereotypeLogitRegr||compute_rand_two_sided_pval",
		"survival||InferenceSurvivalGLMMWeibullFrailtyNormalOneLik||compute_rand_confidence_interval(custom)",
		"ordinal||InferenceOrdinalKKGLMM||compute_m_out_of_n_bootstrap_confidence_interval",
		"proportion||InferencePropKKGLMM||compute_bayesian_bootstrap_confidence_interval_bca||~1",
		"ordinal||InferenceOrdinalStereotypeLogitRegr||compute_jackknife_estimate",
		# Observed mean runtime >30 seconds in the 2026-09-05 comprehensive
		# results (PropKKGLMM BCa Bayesian-bootstrap p-value: mean 35s, 80th
		# pct 49s, max 82s over 46 runs). Formula-restricted to ~1 as of
		# 2026-09-08 -- the ~. formula is fast (<0.15s) and was removed.
		"proportion||InferencePropKKGLMM||compute_bayesian_bootstrap_two_sided_pval_bca||~1"
		# 2026-09-08 recheck (COMPREHENSIVE_FORCE_SLOW_PATHS, 10 reps/design,
		# all designs+formulas): removed 11 entries confirmed fast now --
		# proportion/InferenceAllSimpleWilcox rand CI (max ~8.0s over 408
		# runs), count/InferenceCountHurdleNegBin rand (both pval variants, max
		# ~28s), survival/InferenceSurvivalWeibullRegr rand delta=0.5 (max
		# ~4.6s), ordinal/InferenceOrdinalKKCLMMCauchit bootstrap CI
		# studentized (max ~24s), survival/InferenceSurvivalLogRank rand
		# delta=0.5 (max ~4.3s, was hours pre-optimization),
		# continuous/InferenceAllSimpleAverageDiff m_out_of_n bootstrap CI
		# (max ~2.8s), survival/InferenceSurvivalGLMMWeibullFrailtyNormalOneLik
		# rand (both pval variants, max ~12.4s -- but the ...(custom) CI
		# variant above is untouched, no fresh data for it). Two removals
		# are weaker evidence, flagged at removal time and worth revisiting
		# if they reappear as slow: ordinal/InferenceOrdinalGCompMeanDiff
		# asymp pval collapses design/formula, and its SPBR-only mean was
		# ~31s/max ~71s across 33 runs (fast on all 6 other designs, which
		# diluted the pooled average -- may deserve a design-scoped skip
		# instead of blanket removal); survival/InferenceSurvivalKKStratCoxPHOneLik
		# rand CI produced zero matching calls in the recheck (method/label
		# appears to no longer be invoked on this path) so its removal is
		# unverified, not confirmed-fast. Same recheck also added the
		# `||model_formula` exact_operations suffix (see @format above) so
		# an entry can target one formula instead of collapsing both --
		# used above to narrow the two PropKKGLMM entries to ~1 only.
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
	rand_ci = c("InferenceSurvivalWeibullRegr", "InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik", "InferenceSurvivalGLMMWeibullFrailtyNormalOneLik", "InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKWeibullMarginal", "InferencePropQuantileRegr", "InferencePropKKGEE", "InferencePropBetaRegr"),
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
	boot_ci = c("InferenceOrdinalKKGLMM"),
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
		function(parts) !(length(parts) %in% c(3L, 4L)) || !(parts[[1L]] %in% valid_responses) ||
			!grepl("^Inference[A-Za-z0-9]+$", parts[[2L]]) || !nzchar(parts[[3L]]) ||
			(length(parts) == 4L && !grepl("^~", parts[[4L]])),
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
