# Classes backed by a Suggests package (quantreg for the quantile regressions,
# multgee/geepack for InferenceOrdinalKKGEE, aftgee for the KK rank regression,
# nbpMatching for the Bai adjusted t) stop in their constructor when it is
# absent, as on the R-devel valgrind and ASAN/UBSAN runners, which install only
# EDI's hard dependencies (v1.0.6-TODO-127). The source of truth is the
# inference registry's required_packages field (EDI_INFERENCE_REQUIRED_PACKAGES),
# read through missing_required_packages_for_inference_class(), the same check
# InferenceSuite discovery uses. test-inference-required-packages-registry.R
# keeps that field in step with the classes' own guards.
#
# inference_fixture_missing_packages(cn, designs) returns the required packages
# of `cn` that are not installed (character(0) when none are, so a class that
# has no fixture while its packages are present still fails the caller's
# expect_false(is.null(inf))). `designs` is accepted for the callers' existing
# signature and not used. Callers only reach it after their own build returned
# NULL.
inference_fixture_missing_packages = function(cn, designs = NULL) {
	EDI:::missing_required_packages_for_inference_class(cn)
}

# Called at the end of a test_that() that skipped classes in its loop (named
# character vector: class -> missing packages), after its other expectations,
# so the skipped classes are reported as a skip rather than silently passing.
skip_inference_fixtures_missing_packages = function(skipped) {
	if (length(skipped) == 0L) return(invisible())
	testthat::skip(paste0("Suggests packages not installed: ",
		paste0(names(skipped), " (", skipped, ")", collapse = "; ")))
}
