# Enables the strict shallow-hierarchy gate for every normal test run
# (fix_inference_hierarchy.md "Base Deletion", 2026-08-21: "Enable
# EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY in normal tests once all concrete
# classes are migrated" -- all concrete classes are migrated as of the
# InferenceOrdinalPairedSignTest migration). With the env var set,
# populate_inference_class_registry() calls
# assert_shallow_inference_hierarchy_complete() at every registry
# (re)population, erroring immediately if any concrete class descends through
# an EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES member -- so a regression
# that re-introduces a deep algorithmic ladder fails loudly in whichever test
# file first touches the registry, not just in test-inference-class-registry.R.
#
# testthat sources setup-*.R files before running tests (and, unlike
# helper-*.R, never re-sources them into interactive sessions), so this is
# scoped to test runs only; plain library(EDI)/load_all() sessions are
# unaffected unless the user exports the variable themselves.
#
# The design-side twin (EDI_REQUIRE_SHALLOW_DESIGN_HIERARCHY, see
# design_class_registry.R) is enabled here too for the same reason -- its
# migration finished earlier (fix_design_hierarchy.md TODO-39) and its gate
# was documented as "opt in via the env var, e.g. in CI".
Sys.setenv(EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY = "true")
Sys.setenv(EDI_REQUIRE_SHALLOW_DESIGN_HIERARCHY = "true")

# Fail fast at setup time (not just lazily on the next repopulation) so a
# violated invariant aborts the run before any test output can bury it.
EDI:::assert_shallow_inference_hierarchy_complete()
EDI:::assert_shallow_design_hierarchy_complete()
