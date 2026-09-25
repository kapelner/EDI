library(testthat)
library(EDI)

# mark_inference_class_migrated() (inference_class_registry.R:1847-1852) has a first guard, before
# any structural-consistency check: a class whose migration record status is "root"/"infrastructure"
# (or whose own metadata is abstract) cannot be marked migrated at all -- "<name> is not a concrete
# inference class and cannot be marked migrated." test-inference-class-registry.R exercises this
# function's OTHER guards extensively (current-parent mismatch, effective-components mismatch,
# effective-capabilities mismatch, missing public methods -- all via temporarily-registered
# "InferenceTemporary*" fixture classes), but never this first one. A codebase-wide grep confirmed
# the exact message had zero test references anywhere. Exercised directly against a real, already-
# registered abstract/infrastructure class (InferenceAsymp), no temporary registration needed.

test_that("a non-concrete (root/infrastructure/abstract) class cannot be marked migrated", {
	expect_error(
		EDI:::mark_inference_class_migrated("InferenceAsymp"),
		"InferenceAsymp is not a concrete inference class and cannot be marked migrated\\.",
	)
	# Confirms this really is the abstract/infrastructure branch and not some other failure:
	rec <- EDI:::get_inference_hierarchy_migration_record("InferenceAsymp")
	expect_true(rec$migration_status %in% c("root", "infrastructure"))
})
