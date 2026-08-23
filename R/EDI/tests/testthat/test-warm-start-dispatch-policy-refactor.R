# Golden test for local_machine_optimization.md TODO-2: the sample-size-conditioned
# warm-start disable rules were lifted out of edi_warm_start_dispatch_policy()'s hardcoded
# `if` cascade into get_warm_start_dispatch_policy()'s per-operation `n_conditioned_overrides`
# table. This file freezes the pre-refactor decision function (verbatim, as it stood before
# the refactor) and asserts the live dispatcher returns identical decisions for every
# (inference_class, operation, n) combination below.

frozen_pre_refactor_dispatch = function(inference_class, operation, n = NULL) {
	inference_class = as.character(inference_class[[1]])
	operation = as.character(operation[[1]])
	n_val = suppressWarnings(as.integer(n))
	default_val = TRUE

	if (identical(operation, "bayesian_boot") &&
			(grepl("^InferenceContinKKGLMM$", inference_class, perl = TRUE) ||
			 grepl("^InferenceSurvivalDepCensTransformRegr$", inference_class, perl = TRUE) ||
			 grepl("^InferenceOrdinalCloglogRegr$", inference_class, perl = TRUE) ||
			 grepl("^InferenceCountPoisson$", inference_class, perl = TRUE) ||
			 grepl("^InferenceOrdinalPropOddsRegr$", inference_class, perl = TRUE) ||
			 grepl("^InferenceIncidKKNewcombeRiskDiff$", inference_class, perl = TRUE) ||
			 grepl("^InferenceOrdinalJonckheereTerpstraTest$", inference_class, perl = TRUE) ||
			 grepl("^InferenceOrdinalKKCLMMProbit$", inference_class, perl = TRUE) ||
			 grepl("^InferencePropFractionalLogit$", inference_class, perl = TRUE) ||
			 grepl("^InferencePropGCompMeanDiff$", inference_class, perl = TRUE) ||
			 grepl("^InferenceSurvivalWeibullRegr$", inference_class, perl = TRUE))) {
		return(FALSE)
	}
	if (identical(operation, "bayesian_boot") &&
			grepl("^InferenceIncidBinomialIdentityRiskDiff$", inference_class, perl = TRUE)) return(FALSE)
	if (identical(operation, "jackknife") &&
			(grepl("^InferenceOrdinalContRatioRegr$", inference_class, perl = TRUE) ||
			 grepl("^InferenceOrdinalAdjCatLogitRegr$", inference_class, perl = TRUE) ||
			 grepl("^InferenceSurvivalRestrictedMeanDiff$", inference_class, perl = TRUE))) return(FALSE)
	if (identical(operation, "non_param_boot") &&
			grepl("^InferencePropZeroOneInflatedBetaRegr$", inference_class, perl = TRUE)) return(FALSE)
	if (identical(operation, "rand") &&
			grepl("^InferenceSurvivalKKLWACoxPHIVWC$", inference_class, perl = TRUE)) return(FALSE)

	if (!is.na(n_val) && n_val < 200L) {
		if (identical(operation, "non_param_boot") &&
				(grepl("^InferenceOrdinalContRatioRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCLMMCauchit$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropKKGEE$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCondAdjCatLogitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountQuasiPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropKKQuantileRegrOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountHurdlePoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountZeroInflatedPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidBinomialIdentityRiskDiff$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidGCompRiskRatio$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKGEE$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropBetaRegr$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "rand") &&
				(grepl("^InferencePropBetaRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCondAdjCatLogitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalKKWeibullFrailtyLoggammaOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalKKStratCoxPHOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalKKWeibullFrailtyNormalIVWC$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "jackknife") &&
				grepl("^InferenceSurvivalGehanWilcox$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "bayesian_boot") &&
				grepl("^InferenceContinQuantileRegr$", inference_class, perl = TRUE)) return(FALSE)
	}

	if (!is.na(n_val) && n_val < 500L) {
		if (identical(operation, "rand") &&
				(grepl("^InferenceContinKKOLSIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceContinKKRobustRegrIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropKKQuantileRegrIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalContRatioRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalCoxPHRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKGEE$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "non_param_boot") &&
				(grepl("^InferenceCountZeroInflatedNegBin$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidLogBinomial$", inference_class, perl = TRUE) ||
				 grepl("^InferenceAllSimpleWilcox$", inference_class, perl = TRUE) ||
				 grepl("^InferenceContinKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalContRatioRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalDepCensTransformRegr$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "rand") &&
				grepl("^InferenceIncidLogBinomial$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "bayesian_boot") &&
				(grepl("^InferenceOrdinalKKCondAdjCatLogitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalGehanWilcox$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountHurdleNegBin$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalContRatioRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalKKStratCoxPHOneLik$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "jackknife") &&
				(grepl("^InferenceSurvivalLogRank$", inference_class, perl = TRUE) ||
				 grepl("^InferenceContinKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalCauchitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropBetaRegr$", inference_class, perl = TRUE))) return(FALSE)
	}

	if (!is.na(n_val) && n_val >= 200L && n_val < 500L) {
		if (identical(operation, "rand") &&
				grepl("^InferenceContinKKQuantileRegrOneLik$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "jackknife") &&
				grepl("^InferenceIncidKKCondLogitGLMMIVWC$", inference_class, perl = TRUE)) return(FALSE)
	}

	if (!is.na(n_val) && n_val < 1000L) {
		if (identical(operation, "rand") &&
				(grepl("^InferenceContinKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceContinQuantileRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKModifiedPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropGCompMeanDiff$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "bayesian_boot") &&
				grepl("^InferenceOrdinalKKCLMMCauchit$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "jackknife") &&
				grepl("^InferenceCountNegBin$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "non_param_boot") &&
				grepl("^InferenceCountHurdleNegBin$", inference_class, perl = TRUE)) return(FALSE)
	}

	if (!is.na(n_val) && n_val >= 200L) {
		if (identical(operation, "rand") &&
				grepl("^InferenceCountKKHurdlePoissonOneLik$", inference_class, perl = TRUE)) return(FALSE)
	}

	if (!is.na(n_val) && n_val >= 500L) {
		if (identical(operation, "bayesian_boot") &&
				(grepl("^InferenceSurvivalKKWeibullFrailtyLoggammaOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKCondLogitGLMMOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidModifiedPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropZeroOneInflatedBetaRegr$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "rand") &&
				(grepl("^InferenceContinRobustRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidBinomialIdentityRiskDiff$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKCondLogitGLMMOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKCondLogitGLMMIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidGCompRiskRatio$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCLMM$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "non_param_boot") &&
				(grepl("^InferenceAllKKWilcoxIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalCloglogRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropFractionalLogit$", inference_class, perl = TRUE) ||
				 grepl("^InferencePropKKQuantileRegrIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalKMDiff$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "jackknife") &&
				(grepl("^InferenceContinQuantileRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalGCompMeanDiff$", inference_class, perl = TRUE))) return(FALSE)
	}

	if (!is.na(n_val) && n_val >= 1000L) {
		if (identical(operation, "rand") &&
				grepl("^InferenceCountPoisson$", inference_class, perl = TRUE)) return(FALSE)
		if (identical(operation, "jackknife") &&
				(grepl("^InferenceSurvivalKKWeibullFrailtyLoggammaIVWC$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalOrderedProbitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalDepCensTransformRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalGehanWilcox$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalWeibullRegr$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "bayesian_boot") &&
				(grepl("^InferenceIncidGCompRiskRatio$", inference_class, perl = TRUE) ||
				 grepl("^InferenceContinQuantileRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidRiskDiff$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountQuasiPoisson$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKGCompRiskRatio$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountKKCondPoissonOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceCountKKHurdlePoissonOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidExactBinomial$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidProbitRegr$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidExactZhang$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKGLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalOrderedProbitRegr$", inference_class, perl = TRUE))) return(FALSE)
		if (identical(operation, "non_param_boot") &&
				(grepl("^InferenceIncidKKCondLogitGLMMOneLik$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidKKGCompRiskDiff$", inference_class, perl = TRUE) ||
				 grepl("^InferenceIncidRiskDiff$", inference_class, perl = TRUE) ||
				 grepl("^InferenceOrdinalKKCLMM$", inference_class, perl = TRUE) ||
				 grepl("^InferenceSurvivalRestrictedMeanDiff$", inference_class, perl = TRUE))) return(FALSE)
	}

	base_overrides = switch(operation,
		jackknife = c(
			"^InferenceSurvivalKKLWACoxPHIVWC$" = FALSE,
			"^InferenceSurvivalCoxPHRegr$" = FALSE,
			"^InferenceSurvivalStratCoxPHRegr$" = FALSE
		),
		non_param_boot = c(
			"^InferenceCountNegBin$" = FALSE,
			"^InferenceSurvivalCoxPHRegr$" = FALSE,
			"^InferenceSurvivalStratCoxPHRegr$" = FALSE
		),
		bayesian_boot = c(
			"^InferenceCountNegBin$" = FALSE,
			"^InferenceSurvivalCoxPHRegr$" = FALSE,
			"^InferenceSurvivalStratCoxPHRegr$" = FALSE
		),
		param_boot = character(0),
		rand = c(
			"^InferenceIncidKKCondLogitOneLik$" = FALSE,
			"^InferenceAllSimpleWilcox$" = FALSE
		),
		character(0)
	)
	for (pattern in names(base_overrides)) {
		if (grepl(pattern, inference_class, perl = TRUE)) return(isTRUE(base_overrides[[pattern]]))
	}
	default_val
}

golden_classes = c(
	"InferenceContinKKGLMM", "InferenceSurvivalDepCensTransformRegr", "InferenceOrdinalCloglogRegr",
	"InferenceCountPoisson", "InferenceOrdinalPropOddsRegr", "InferenceIncidKKNewcombeRiskDiff",
	"InferenceOrdinalJonckheereTerpstraTest", "InferenceOrdinalKKCLMMProbit", "InferencePropFractionalLogit",
	"InferencePropGCompMeanDiff", "InferenceSurvivalWeibullRegr", "InferenceIncidBinomialIdentityRiskDiff",
	"InferenceOrdinalContRatioRegr", "InferenceOrdinalAdjCatLogitRegr", "InferenceSurvivalRestrictedMeanDiff",
	"InferencePropZeroOneInflatedBetaRegr", "InferenceSurvivalKKLWACoxPHIVWC", "InferenceOrdinalKKCLMMCauchit",
	"InferencePropKKGEE", "InferenceOrdinalKKCondAdjCatLogitRegr", "InferenceCountQuasiPoisson",
	"InferencePropKKQuantileRegrOneLik", "InferenceCountHurdlePoisson", "InferenceCountZeroInflatedPoisson",
	"InferenceIncidGCompRiskRatio", "InferenceIncidKKGEE", "InferencePropBetaRegr",
	"InferenceSurvivalKKWeibullFrailtyLoggammaOneLik", "InferenceSurvivalKKStratCoxPHOneLik",
	"InferenceSurvivalKKWeibullFrailtyNormalIVWC", "InferenceSurvivalGehanWilcox", "InferenceContinQuantileRegr",
	"InferenceContinKKOLSIVWC", "InferenceContinKKRobustRegrIVWC", "InferencePropKKQuantileRegrIVWC",
	"InferenceSurvivalCoxPHRegr", "InferenceCountZeroInflatedNegBin", "InferenceIncidLogBinomial",
	"InferenceAllSimpleWilcox", "InferenceSurvivalDepCensTransformRegr", "InferenceCountKKGLMM",
	"InferenceCountHurdleNegBin", "InferenceSurvivalLogRank", "InferenceOrdinalCauchitRegr",
	"InferenceContinKKQuantileRegrOneLik", "InferenceIncidKKCondLogitGLMMIVWC", "InferenceIncidKKModifiedPoisson",
	"InferenceCountNegBin", "InferenceCountKKHurdlePoissonOneLik", "InferenceIncidKKCondLogitGLMMOneLik",
	"InferenceIncidModifiedPoisson", "InferenceOrdinalKKCLMM", "InferenceContinRobustRegr",
	"InferenceAllKKWilcoxIVWC", "InferenceOrdinalKKGLMM", "InferenceSurvivalKMDiff", "InferenceOrdinalGCompMeanDiff",
	"InferenceSurvivalKKWeibullFrailtyLoggammaIVWC", "InferenceOrdinalOrderedProbitRegr", "InferenceIncidRiskDiff",
	"InferenceIncidKKGCompRiskRatio", "InferenceCountKKCondPoissonOneLik", "InferenceIncidExactBinomial",
	"InferenceIncidProbitRegr", "InferenceIncidExactZhang", "InferenceIncidKKGCompRiskDiff",
	"InferenceIncidKKCondLogitOneLik", "InferenceCountBinomial", "InferenceNonExistentClass"
)
golden_operations = c("jackknife", "non_param_boot", "bayesian_boot", "param_boot", "rand")
golden_ns = c(NA, 0L, 1L, 199L, 200L, 201L, 499L, 500L, 501L, 999L, 1000L, 1001L, 5000L)

test_that("refactored warm-start dispatcher matches the frozen pre-refactor decision function for every (class, operation, n)", {
	mismatches = character(0)
	for (cl in golden_classes) {
		for (op in golden_operations) {
			for (n in golden_ns) {
				expected = frozen_pre_refactor_dispatch(cl, op, n)
				actual = EDI:::edi_warm_start_dispatch_policy(cl, op, n)
				if (!identical(expected, actual)) {
					mismatches = c(mismatches, sprintf("%s/%s/n=%s: expected %s, got %s", cl, op, n, expected, actual))
				}
			}
		}
	}
	expect_equal(mismatches, character(0))
})

test_that("set_warm_start_dispatch_policy() can now override the sample-size-conditioned layer", {
	on.exit(set_warm_start_dispatch_policy(reset = TRUE))
	# n=300 falls outside every built-in n-conditioned rule for this class/operation, so the
	# built-in policy is the TRUE default here -- the pre-refactor setter could not touch this.
	expect_true(EDI:::edi_warm_start_dispatch_policy("InferenceSurvivalGehanWilcox", "jackknife", 300L))
	set_warm_start_dispatch_policy(list(
		jackknife = list(n_conditioned_overrides = list(
			list(pattern = "^InferenceSurvivalGehanWilcox$", value = FALSE, n_min = -Inf, n_max = Inf)
		))
	))
	expect_false(EDI:::edi_warm_start_dispatch_policy("InferenceSurvivalGehanWilcox", "jackknife", 300L))
	expect_false(EDI:::edi_warm_start_dispatch_policy("InferenceSurvivalGehanWilcox", "jackknife", 5000L))
})
