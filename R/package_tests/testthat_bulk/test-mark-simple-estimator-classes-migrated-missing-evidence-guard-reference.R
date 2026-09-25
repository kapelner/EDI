library(testthat)
library(EDI)

# mark_simple_estimator_classes_migrated() (inference_class_registry.R:2169-2183) checks that a
# target already at migration_status = "migrated" has all of EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_
# EVIDENCE recorded in its migration_evidence -- "<name> cannot be marked migrated: missing
# no-likelihood migration evidence: <missing>." Every real entry in the static EDI_SIMPLE_ESTIMATOR_
# TARGETS table is auto-defaulted (via the lapply directly below its literal definition) to a fully
# populated migration_evidence, so this branch is not reachable via any currently-registered target
# without directly mutating the table -- the same "defensive check on an always-currently-valid
# invariant" shape as several other guards closed this session, except here the mutation target is a
# package-namespace binding rather than a private R6 field. A codebase-wide grep confirmed the exact
# message had zero test references anywhere. Reached via unlockBinding()/assign() on the EDI
# namespace's EDI_SIMPLE_ESTIMATOR_TARGETS binding, restored via on.exit before the test completes
# (never left mutated for any other test in the suite).

test_that("a simple-estimator target at migration_status = 'migrated' but missing required evidence is rejected", {
	ns <- asNamespace("EDI")
	orig <- ns$EDI_SIMPLE_ESTIMATOR_TARGETS
	on.exit({
		unlockBinding("EDI_SIMPLE_ESTIMATOR_TARGETS", ns)
		assign("EDI_SIMPLE_ESTIMATOR_TARGETS", orig, envir = ns)
		lockBinding("EDI_SIMPLE_ESTIMATOR_TARGETS", ns)
	}, add = TRUE)

	mutated <- orig
	mutated$InferenceAllSimpleAverageDiff$migration_evidence <- "before_after_manifest_counts"
	unlockBinding("EDI_SIMPLE_ESTIMATOR_TARGETS", ns)
	assign("EDI_SIMPLE_ESTIMATOR_TARGETS", mutated, envir = ns)

	expect_error(
		EDI:::mark_simple_estimator_classes_migrated("InferenceAllSimpleAverageDiff"),
		"InferenceAllSimpleAverageDiff cannot be marked migrated: missing no-likelihood migration evidence: kept_dropped_optional_methods, mark_inference_class_migrated, golden_outputs, method_availability_snapshot, private_state_owner_snapshot",
		fixed = TRUE
	)
})

test_that("every real entry in EDI_SIMPLE_ESTIMATOR_TARGETS already has full migration_evidence (confirms the guard is otherwise unreachable)", {
	targets <- EDI:::EDI_SIMPLE_ESTIMATOR_TARGETS
	required <- EDI:::EDI_NO_LIKELIHOOD_MIGRATION_REQUIRED_EVIDENCE
	for (nm in names(targets)) {
		expect_true(all(required %in% (targets[[nm]]$migration_evidence %||% character())), info = nm)
	}
	expect_no_error(EDI:::mark_simple_estimator_classes_migrated())
})
