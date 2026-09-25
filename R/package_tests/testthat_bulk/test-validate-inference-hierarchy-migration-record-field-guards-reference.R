library(testthat)
library(EDI)

# validate_inference_hierarchy_migration_record() (inference_class_registry.R:1707-1742) is called
# on every registered class's migration record, but its own structural-validity guards --
# distinct from the higher-level "mark migrated" consistency checks extensively exercised
# elsewhere in test-inference-class-registry.R -- had zero test references anywhere (confirmed via
# codebase-wide grep):
#   1. migration_status must be one of "root"/"infrastructure"/"pending"/"migrated".
#   2. target_likelihood_tier must be one of the allowed likelihood tiers.
#   3. required fields (e.g. `name`) must all be present.
# A fourth guard on this function -- rejecting target_components with a legacy "InferenceMixin*"
# name -- is confirmed structurally dead: EDI_INFERENCE_COMPONENTS has zero registered components
# whose name starts with "InferenceMixin" today, so the earlier "unknown target component(s)" check
# always fires first for any such name; not exercised here for that reason. Exercised via direct
# mutation of a real, valid migration record (EDI:::get_inference_hierarchy_migration_record()),
# no synthetic fixture needed.

test_that("an invalid migration_status value is rejected with the documented message", {
	rec <- EDI:::get_inference_hierarchy_migration_record("InferenceCustomRand")
	rec$migration_status <- "bogus_status"
	expect_error(
		EDI:::validate_inference_hierarchy_migration_record(rec),
		"Invalid migration status for InferenceCustomRand\\.",
	)
})

test_that("an invalid target_likelihood_tier value is rejected with the documented message", {
	rec <- EDI:::get_inference_hierarchy_migration_record("InferenceCustomRand")
	rec$target_likelihood_tier <- "bogus_tier"
	expect_error(
		EDI:::validate_inference_hierarchy_migration_record(rec),
		"Invalid target likelihood tier for InferenceCustomRand\\.",
	)
})

test_that("a record missing a required field is rejected with the documented message naming the field", {
	rec <- EDI:::get_inference_hierarchy_migration_record("InferenceCustomRand")
	rec$name <- NULL
	expect_error(
		EDI:::validate_inference_hierarchy_migration_record(rec),
		"is missing field\\(s\\): name",
	)
})

test_that("a genuinely valid, unmodified migration record passes silently", {
	rec <- EDI:::get_inference_hierarchy_migration_record("InferenceCustomRand")
	expect_true(EDI:::validate_inference_hierarchy_migration_record(rec))
})
