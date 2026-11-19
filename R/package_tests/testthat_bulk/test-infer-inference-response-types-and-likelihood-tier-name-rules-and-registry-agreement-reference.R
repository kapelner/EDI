library(testthat)
library(EDI)

# infer_inference_response_types(name) and infer_inference_likelihood_tier(name): name-pattern classifiers used to
# populate the inference class registry. Hand-listed names pin each branch (including precedence quasi > partial >
# full > none and the per-class response-type exclusions). The registry takes a class's declared metadata first and
# uses these classifiers only where nothing is declared.

Z <- function(x) get(x, envir = asNamespace("EDI"))
`%||%` <- function(a, b) if (is.null(a)) b else a
rt <- Z("infer_inference_response_types"); lt <- Z("infer_inference_likelihood_tier")
all_types <- c("continuous", "incidence", "count", "proportion", "survival", "ordinal")

test_that("response types by name prefix", {
	expect_identical(rt("Inference"), all_types)
	expect_identical(rt("InferenceAllKKMeanDiffIVWC"), all_types)
	expect_identical(rt("InferenceAllSimpleAverageDiff"), all_types)
	expect_identical(rt("InferenceContinOLS"), "continuous")
	expect_identical(rt("InferenceBaiAdjustedTKK14"), "continuous")
	expect_identical(rt("InferenceCountPoisson"), "count")
	expect_identical(rt("InferenceIncidLogRegr"), "incidence")
	expect_identical(rt("InferenceIncidenceSomething"), "incidence")
	expect_identical(rt("InferenceOrdinalRidit"), "ordinal")
	expect_identical(rt("InferencePropBetaRegr"), "proportion")
	expect_identical(rt("InferenceSurvivalCoxPHRegr"), "survival")
})

test_that("unrecognised names give no response types; matching is anchored at the start", {
	expect_identical(rt("InferenceFooBar"), character())
	expect_identical(rt("MyInferenceContinOLS"), character())
	expect_identical(rt("SomethingCountPoisson"), character())
})

test_that("the per-class exclusion table removes types from an otherwise all-types class", {
	ex <- Z("EDI_INFERENCE_RESPONSE_TYPE_EXCLUSIONS")
	expect_true("InferenceAllSimpleWilcox" %in% names(ex))
	expect_identical(rt("InferenceAllSimpleWilcox"), setdiff(all_types, ex$InferenceAllSimpleWilcox))
	expect_false("incidence" %in% rt("InferenceAllSimpleWilcox"))
	for (nm in names(ex)) expect_length(intersect(rt(nm), ex[[nm]]), 0L)
})

test_that("likelihood tier: quasi > partial > full > none by pattern precedence", {
	expect_identical(lt("InferenceCountQuasiPoisson"), "quasi")           # Quasi beats Poisson (full)
	expect_identical(lt("InferenceContinRobustRegr"), "quasi")
	expect_identical(lt("InferenceContinKKGEE"), "quasi")
	expect_identical(lt("InferenceCountCompositeLikelihood"), "quasi")
	expect_identical(lt("InferenceSurvivalCoxPHRegr"), "partial")
	expect_identical(lt("InferenceIncidKKCondLogit"), "partial")
	expect_identical(lt("InferenceOrdinalKKCondAdjCat"), "partial")
	expect_identical(lt("InferenceSurvivalKKLWA"), "partial")
	expect_identical(lt("InferenceContinOLS"), "full")
	expect_identical(lt("InferenceIncidLogRegr"), "full")
	expect_identical(lt("InferenceCountZeroInflatedPoisson"), "full")
	expect_identical(lt("InferenceSurvivalDepCensTransformRegr"), "full")
	expect_identical(lt("InferenceOrdinalPropOddsRegr"), "full")
	expect_identical(lt("InferenceAllSimpleAverageDiff"), "none")
	expect_identical(lt("InferenceOrdinalRidit"), "none")
	expect_identical(lt("InferenceFooBar"), "none")
})

test_that("Robust/Quasi shadow Cox and full-likelihood tokens (quasi wins even inside a partial-looking name)", {
	expect_identical(lt("InferenceSurvivalRobustCox"), "quasi")
	expect_identical(lt("InferenceCountRobustPoisson"), "quasi")
})

test_that("every live registry record agrees with its declaration, else with the classifiers", {
	# Since 2026-11-18 the metadata a class declares to define_inference_class() wins; the name
	# classifiers are the fallback for classes built without the factory (and for fields a
	# declaration leaves out).
	reg <- Z("inference_class_registry_as_list")()
	decl_of <- Z("inference_class_declaration")
	expect_gt(length(reg), 100L)
	for (nm in names(reg)) {
		declared <- decl_of(get0(nm, envir = asNamespace("EDI")))$metadata %||% list()
		expect_setequal(declared$response_types %||% rt(nm), reg[[nm]]$response_types)
		expect_identical(declared$likelihood_tier %||% lt(nm), reg[[nm]]$likelihood_tier, info = nm)
	}
	expect_true(all(vapply(reg, function(r) r$likelihood_tier %in% Z("EDI_INFERENCE_ALLOWED_LIKELIHOOD_TIERS"), NA)))
})

# docs-claims audit, finding docs-claims-dfa95cecb: InferenceIncidKKGCompRiskRatio declares
# likelihood_tier = "none", so no score or likelihood-ratio testing is offered.
test_that("InferenceIncidKKGCompRiskRatio is pinned to likelihood_tier 'none' and offers no score/LR tests", {
	expect_identical(Z("get_inference_class_metadata")("InferenceIncidKKGCompRiskRatio")$likelihood_tier, "none")
	set.seed(4)
	des <- DesignSeqOneByOneKK14$new(n = 30L, response_type = "incidence", verbose = FALSE)
	for (i in 1:30) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(30, 1, 0.5))
	inf <- InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	types <- inf$get_supported_testing_types()
	expect_false(any(c("score", "lik_ratio", "gradient") %in% types))
	expect_null(inf$compute_lik_ratio_bootstrap_two_sided_pval)
})
