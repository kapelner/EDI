library(testthat)
library(EDI)

# mark_custom_randomization_classes_migrated() (inference_class_registry.R:2561-2572), the custom-
# randomization-host sibling of mark_simple_estimator_classes_migrated() (closed the previous
# iteration in test-mark-simple-estimator-classes-migrated-missing-evidence-guard-reference.R),
# checks that a target already at migration_status = "migrated" has both required evidence entries
# ("method_snapshot", "golden_randomization") recorded -- "<name> cannot be marked migrated:
# missing custom-randomization migration evidence: <missing>." The one real entry in the static
# EDI_CUSTOM_RANDOMIZATION_TARGETS table (InferenceCustomRand) is already fully evidenced in its
# literal definition, so this branch is likewise unreachable without directly mutating the table --
# reached via the same scoped unlockBinding()/assign() technique on the EDI namespace binding,
# restored via on.exit before the test completes. A codebase-wide grep confirmed the exact message
# had zero test references anywhere.

test_that("the custom-randomization host at migration_status = 'migrated' but missing required evidence is rejected", {
	ns <- asNamespace("EDI")
	orig <- ns$EDI_CUSTOM_RANDOMIZATION_TARGETS
	on.exit({
		unlockBinding("EDI_CUSTOM_RANDOMIZATION_TARGETS", ns)
		assign("EDI_CUSTOM_RANDOMIZATION_TARGETS", orig, envir = ns)
		lockBinding("EDI_CUSTOM_RANDOMIZATION_TARGETS", ns)
	}, add = TRUE)

	mutated <- orig
	mutated$InferenceCustomRand$migration_evidence <- "method_snapshot"
	unlockBinding("EDI_CUSTOM_RANDOMIZATION_TARGETS", ns)
	assign("EDI_CUSTOM_RANDOMIZATION_TARGETS", mutated, envir = ns)

	expect_error(
		EDI:::mark_custom_randomization_classes_migrated("InferenceCustomRand"),
		"InferenceCustomRand cannot be marked migrated: missing custom-randomization migration evidence: golden_randomization",
		fixed = TRUE
	)
})

test_that("the one real custom-randomization target already has full migration_evidence (confirms the guard is otherwise unreachable)", {
	targets <- EDI:::EDI_CUSTOM_RANDOMIZATION_TARGETS
	required <- c("method_snapshot", "golden_randomization")
	for (nm in names(targets)) {
		expect_true(all(required %in% (targets[[nm]]$migration_evidence %||% character())), info = nm)
	}
	expect_no_error(EDI:::mark_custom_randomization_classes_migrated())
})
