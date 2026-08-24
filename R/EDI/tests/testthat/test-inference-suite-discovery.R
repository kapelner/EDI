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

	# Design$applicable_inference_class_names()/
	# unavailable_inference_classes_due_to_missing_packages() are the single
	# shared implementation InferenceSuite discovery now delegates to (see
	# fix_inference_hierarchy.md's "Design-Side Discovery API" section) -- must
	# agree exactly, for every design, with what the suite stores.
	expect_identical(sort(des$applicable_inference_class_names()), sort(classes))
	expect_identical(
		des$unavailable_inference_classes_due_to_missing_packages(),
		suite$unavailable_due_to_missing_packages
	)

	expect_true("InferenceAllSimpleAverageDiff" %in% classes)
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

test_that("InferenceSuite's requires_blocking gate actually rejects non-blocking designs (fix_design_hierarchy.md, Class-Identity Dispatch Replacement)", {
	# Regression test for a real bug: .design_metadata()'s `is_blocking` used to be
	# computed via concrete class identity checks. Because the old blocking base was a
	# mandatory ancestor of every current DesignFixed/DesignSeqOneByOne subclass, the
	# first inherits() check was TRUE for literally every design, making the
	# `requires_blocking` gate for classes that actually require blocking a permanent
	# no-op -- these would appear "applicable" even for a plain Bernoulli design with
	# no actual block structure. Fixed by switching to `des_obj$supports("blocking")`,
	# which reads the real `blocking_capable` flag via `is_blocking_design()` instead
	# of class identity.
	#
	# InferenceIncidExtendedRobins is used as the requires-blocking marker class here
	# (not InferenceIncidCMH): CMH has a fully-working non-blocking code path (a
	# different standard-error estimator via draw_ws_according_to_design()) and is
	# NOT excluded from non-blocking designs -- see
	# fix_inference_hierarchy.md's Discovery section, "Add compatibility predicates
	# for ... blocked ... designs" entry.
	set.seed(20260813)
	n = 12L
	des_bernoulli = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des_bernoulli$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_bernoulli$assign_w_to_all_subjects()
	des_bernoulli$add_all_subject_responses(rbinom(n, 1, 0.3))
	expect_false(des_bernoulli$supports("blocking"))
	classes_bernoulli = InferenceSuite$new(des_bernoulli)$applicable_design_classes
	expect_false("InferenceIncidExtendedRobins" %in% classes_bernoulli)
	expect_true("InferenceIncidCMH" %in% classes_bernoulli)

	# `equal_block_sizes = TRUE` (not `FALSE` as originally written here):
	# InferenceIncidCMH requires equal block sizes for blocking designs
	# (its own initialize()-time stop(), now also a registered
	# design_compatibility_reason() predicate -- see
	# fix_inference_hierarchy.md's "Discovery-time applicability" entry).
	# The original `equal_block_sizes = FALSE` + `sample(..., n, TRUE)`
	# fixture relied on the random strata draw happening to land on equal
	# group sizes; found stale 2026-08-22 when RNG-stream drift from the
	# des_bernoulli block above (consuming draws before this point) shifted
	# the draw to an unequal 7/5 split, correctly excluding CMH and failing
	# this assertion -- not a discovery bug, the fixture's own assumption
	# was never guaranteed.
	des_blocking = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2))  # deterministic, guarantees equal block sizes
	des_blocking$add_all_subjects_to_experiment(X)
	des_blocking$assign_w_to_all_subjects()
	des_blocking$add_all_subject_responses(rbinom(n, 1, 0.3))
	expect_true(des_blocking$supports("blocking"))
	classes_blocking = InferenceSuite$new(des_blocking)$applicable_design_classes
	expect_true("InferenceIncidCMH" %in% classes_blocking)
})

test_that("InferenceSuite discovery is unaffected by a class whose constructor always fails", {
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260816)
	n = 8L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))

	# A generator that is fully metadata-compatible but whose constructor
	# unconditionally throws -- stands in for any real class with a broken
	# constructor (e.g. an optional-package load failure, a malformed design, a
	# bug). Discovery (.discover_applicable_design_classes()) reads only
	# inference_class_registry_as_list() and never calls get()/new() on any
	# candidate, so a guaranteed-to-fail constructor must have zero effect on
	# whether the class is reported as applicable.
	InferenceTemporaryAlwaysThrows = R6::R6Class("InferenceTemporaryAlwaysThrows",
		inherit = EDI:::Inference,
		public = list(
			initialize = function(des_obj, ...) {
				stop("InferenceTemporaryAlwaysThrows: constructor always fails (test double).")
			}
		)
	)

	EDI:::register_inference_class(
		name = "InferenceTemporaryAlwaysThrows",
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
	expect_true("InferenceTemporaryAlwaysThrows" %in% classes)
	expect_error(InferenceTemporaryAlwaysThrows$new(des), "constructor always fails")
})

test_that("InferenceSuite reports missing optional packages separately from design incompatibility", {
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260817)
	n = 8L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))

	# Design-compatible (response type matches; no KK/blocking/censoring
	# requirement) but declares a required package that cannot possibly be
	# installed -- must be excluded from applicable_design_classes and
	# reported, by name, in unavailable_due_to_missing_packages, not silently
	# lumped in with ordinary incompatibility (fix_inference_hierarchy.md's
	# Discovery section: "Unavailable packages should be reported separately
	# from design incompatibility").
	EDI:::register_inference_class(
		name = "InferenceTemporaryMissingPackage",
		parent = "Inference",
		metadata = list(
			abstract = FALSE,
			exported = TRUE,
			response_types = "continuous",
			design_families = "all",
			compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none",
			required_packages = "zzzNotARealPackageXYZ123",
			capabilities = character()
		),
		direct_components = character()
	)
	# A second, ordinarily-incompatible class (wrong response type) with no
	# package requirement, registered alongside, to prove the two exclusion
	# reasons stay distinct rather than collapsing into one "not applicable"
	# bucket.
	EDI:::register_inference_class(
		name = "InferenceTemporaryWrongResponseType",
		parent = "Inference",
		metadata = list(
			abstract = FALSE,
			exported = TRUE,
			response_types = "count",
			design_families = "all",
			compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none",
			required_packages = character(),
			capabilities = character()
		),
		direct_components = character()
	)

	suite = InferenceSuite$new(des)
	expect_false("InferenceTemporaryMissingPackage" %in% suite$applicable_design_classes)
	expect_true("InferenceTemporaryMissingPackage" %in% names(suite$unavailable_due_to_missing_packages))
	expect_identical(
		suite$unavailable_due_to_missing_packages[["InferenceTemporaryMissingPackage"]],
		"zzzNotARealPackageXYZ123"
	)

	expect_false("InferenceTemporaryWrongResponseType" %in% suite$applicable_design_classes)
	expect_false("InferenceTemporaryWrongResponseType" %in% names(suite$unavailable_due_to_missing_packages))
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
	expect_identical(sort(des$applicable_inference_class_names()), sort(classes))

	# `InferenceAllKKMeanDiffIVWC`/`InferenceContinKKOLSIVWC` are correctly
	# ABSENT here, not present: `is_inference_class_compatible_with_design_
	# metadata()` unconditionally excludes any class whose name contains
	# "IVWC" from discovery (inference_suite.R's own docstring: "the legacy
	# inverse-variance-weighted-combination KK estimators are deprecated in
	# favor of the OneLik joint-likelihood variants and are never surfaced
	# by InferenceSuite discovery, even though they remain independently
	# constructible/exported for backwards compatibility") -- this
	# assertion predated that deliberate exclusion and was never updated
	# (found stale 2026-08-22). The OneLik sibling is the one actually
	# discoverable for a KK-capable design.
	expect_false("InferenceAllKKMeanDiffIVWC" %in% classes)
	expect_false("InferenceContinKKOLSIVWC" %in% classes)
	# The OneLik sibling is the one actually discoverable for a KK-capable
	# design, preserving this test's original "KK compatibility surfaces
	# something" intent.
	expect_true("InferenceContinKKOLSOneLik" %in% classes)
	expect_false("InferenceRandBootstrap" %in% classes)
	expect_false("InferenceRandBootstrapCI" %in% classes)
})

test_that("Design$applicable_inference_class_names() matches InferenceSuite for the blocking-axis regression designs", {
	set.seed(20260816)
	n = 12L
	des_bernoulli = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des_bernoulli$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_bernoulli$assign_w_to_all_subjects()
	des_bernoulli$add_all_subject_responses(rbinom(n, 1, 0.3))
	expect_identical(
		sort(des_bernoulli$applicable_inference_class_names()),
		sort(InferenceSuite$new(des_bernoulli)$applicable_design_classes)
	)

	# equal_block_sizes = TRUE: see the identical fixture fix/rationale in
	# the "Design$applicable_inference_class_names() matches design metadata
	# for KK compatibility" test above (InferenceIncidCMH requires equal
	# block sizes; found stale 2026-08-22).
	des_blocking = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2))  # deterministic, guarantees equal block sizes
	des_blocking$add_all_subjects_to_experiment(X)
	des_blocking$assign_w_to_all_subjects()
	des_blocking$add_all_subject_responses(rbinom(n, 1, 0.3))
	expect_identical(
		sort(des_blocking$applicable_inference_class_names()),
		sort(InferenceSuite$new(des_blocking)$applicable_design_classes)
	)
	expect_true("InferenceIncidCMH" %in% des_blocking$applicable_inference_class_names())
})
