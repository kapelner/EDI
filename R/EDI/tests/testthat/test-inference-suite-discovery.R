library(testthat)
library(EDI)

test_that("InferenceSuite discovers only exported concrete classes from metadata", {
	set.seed(20260802)
	n = 12L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))

	suite = InferenceSuite$new(des)
	classes = suite$applicable_design_classes

	expect_true("InferenceAllSimpleMeanDiff" %in% classes)
	expect_true("InferenceContinOLS" %in% classes)
	expect_false("InferenceRandBootstrap" %in% classes)
	expect_false("InferenceRandBootstrapCI" %in% classes)
	expect_false("InferenceAsymp" %in% classes)
	expect_false("InferenceNonParamBootstrap" %in% classes)
	expect_false(any(grepl("Abstract", classes, fixed = TRUE)))
	expect_false("InferenceAllKKCompoundMeanDiff" %in% classes)
	expect_false(any(grepl("^InferenceCount", classes)))
	expect_false(any(grepl("^InferenceIncid", classes)))
	expect_false(any(grepl("^InferenceOrdinal", classes)))
	expect_false(any(grepl("^InferenceSurvival", classes)))

	exported = getNamespaceExports("EDI")
	expect_true(all(classes %in% exported))
	for (class_name in classes) {
		gen = get(class_name, envir = getNamespace("EDI"))
		expect_identical(gen$classname, class_name)
	}
})

test_that("InferenceSuite discovery is registry metadata-only", {
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260804)
	n = 8L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))

	EDI:::register_inference_class(
		name = "InferenceTemporaryMetadataOnlySuite",
		parent = "Inference",
		metadata = list(
			abstract = FALSE,
			exported = TRUE,
			response_types = "continuous",
			design_families = "all",
			compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none",
			required_packages = character(),
			capabilities = character()
		),
		direct_components = character()
	)

	classes = InferenceSuite$new(des)$applicable_design_classes
	expect_true("InferenceTemporaryMetadataOnlySuite" %in% classes)
	expect_false(exists("InferenceTemporaryMetadataOnlySuite", envir = getNamespace("EDI"), inherits = FALSE))
})

test_that("InferenceSuite uses design metadata for KK compatibility", {
	set.seed(20260803)
	n = 12L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))

	classes = InferenceSuite$new(des)$applicable_design_classes

	expect_true("InferenceAllKKMeanDiffIVWC" %in% classes)
	expect_true("InferenceContinKKOLSIVWC" %in% classes)
	expect_false("InferenceRandBootstrap" %in% classes)
	expect_false("InferenceRandBootstrapCI" %in% classes)
})
