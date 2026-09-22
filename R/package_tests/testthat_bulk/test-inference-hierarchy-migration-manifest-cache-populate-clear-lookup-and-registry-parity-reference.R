library(testthat)
library(EDI)

# The inference-hierarchy migration manifest cache (EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST, an environment) sits alongside the per-call
# build_inference_hierarchy_migration_record() and is never populated automatically at load: clear_inference_hierarchy_migration_manifest() empties it,
# populate_inference_hierarchy_migration_manifest() fills it with one record per name in EDI_INFERENCE_CLASS_REGISTRY (returning the manifest environment
# itself), get_inference_hierarchy_migration_record() looks up a cached record (erroring by name when absent), inference_hierarchy_migration_manifest_as_list()
# snapshots the whole cache as a named list. The cached record for a class is identical to a fresh build_inference_hierarchy_migration_record() call.
# The manifest is cleared and left empty at the end regardless of outcome, so this file cannot affect later tests that share the namespace-level cache.

ns <- asNamespace("EDI")
clear <- get("clear_inference_hierarchy_migration_manifest", envir = ns)
populate <- get("populate_inference_hierarchy_migration_manifest", envir = ns)
as_list <- get("inference_hierarchy_migration_manifest_as_list", envir = ns)
get_record <- get("get_inference_hierarchy_migration_record", envir = ns)
build_record <- get("build_inference_hierarchy_migration_record", envir = ns)
manifest_env <- get("EDI_INFERENCE_HIERARCHY_MIGRATION_MANIFEST", envir = ns)
registry_names <- ls(get("EDI_INFERENCE_CLASS_REGISTRY", envir = ns))
withr::defer(clear())

test_that("clear() empties the manifest; a lookup on the empty manifest errors by class name", {
	clear()
	expect_length(ls(manifest_env), 0L)
	expect_error(get_record("InferenceContinOLS"), "No inference hierarchy migration record registered for InferenceContinOLS", fixed = TRUE)
	expect_length(as_list(), 0L)
})

test_that("populate() fills exactly one record per registered class name and returns the manifest environment itself", {
	clear()
	r <- populate()
	expect_identical(r, manifest_env)
	expect_setequal(ls(manifest_env), registry_names)
	expect_length(as_list(), length(registry_names))
	expect_setequal(names(as_list()), registry_names)
})

test_that("the cached record for a class equals a fresh build_inference_hierarchy_migration_record() call, field for field", {
	populate()
	for (nm in c("InferenceContinOLS", "InferenceIncidLogRegr", "InferenceCountPoisson")) {
		expect_identical(get_record(nm), build_record(nm), info = nm)
	}
	rec <- get_record("InferenceContinOLS")
	expect_true(all(c("name", "current_parent", "target_components", "target_capabilities", "migration_status") %in% names(rec)))
	expect_identical(rec$name, "InferenceContinOLS")
})

test_that("populate() is idempotent (re-running gives the same class set) and clear() after populate() empties it again", {
	populate(); first <- sort(ls(manifest_env))
	populate(); expect_identical(sort(ls(manifest_env)), first)
	clear(); expect_length(ls(manifest_env), 0L)
	expect_error(get_record("InferenceContinOLS"), "No inference hierarchy migration record registered")
})
