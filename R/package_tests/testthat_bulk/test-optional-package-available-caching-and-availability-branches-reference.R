library(testthat)
library(EDI)

# contracts_mixins.R's optional_package_available() -- a memoized requireNamespace() wrapper backing
# lazy inference-component loading (parallel to the already-well-tested check_package_installed() in
# helper_package_checks.R, but a SEPARATE cache -- EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE, not
# package_cache) -- had only its "genuinely unavailable package, first call" branch exercised
# (test-mixin-contracts.R). Two branches had no test reference anywhere: (1) a genuinely AVAILABLE
# package returns TRUE and is cached; (2) on a SECOND call for the same package name, the cached value
# is returned WITHOUT re-invoking requireNamespace() -- confirmed via a call-count probe on a mocked
# requireNamespace().
#   1. A real, always-installed package ("stats") is reported available and cached as TRUE.
#   2. A mocked-unavailable package's second call for the same name does not re-invoke
#      requireNamespace() at all (the cached FALSE is returned directly).
#   3. Two DIFFERENT package names are cached independently (a cache hit for one does not affect a
#      fresh lookup for the other).

clear_optional_pkg_cache_entries <- function(names) {
	cache_env <- EDI:::EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE
	for (nm in names) if (exists(nm, envir = cache_env, inherits = FALSE)) rm(list = nm, envir = cache_env)
}

test_that("a genuinely available package ('stats') is reported TRUE and cached", {
	clear_optional_pkg_cache_entries("stats")
	cache_env <- EDI:::EDI_OPTIONAL_PACKAGE_AVAILABILITY_CACHE
	expect_false(exists("stats", envir = cache_env, inherits = FALSE))
	res <- EDI:::optional_package_available("stats")
	expect_true(res)
	expect_true(exists("stats", envir = cache_env, inherits = FALSE))
	expect_true(get("stats", envir = cache_env, inherits = FALSE))
})

test_that("a second call for the same (mocked-unavailable) package name does not re-invoke requireNamespace()", {
	clear_optional_pkg_cache_entries("zzz_edi_fake_pkg_for_caching_test")
	calls <- 0L
	local_mocked_bindings(requireNamespace = function(...) { calls <<- calls + 1L; FALSE }, .package = "base")
	r1 <- EDI:::optional_package_available("zzz_edi_fake_pkg_for_caching_test")
	r2 <- EDI:::optional_package_available("zzz_edi_fake_pkg_for_caching_test")
	expect_false(r1)
	expect_false(r2)
	expect_equal(calls, 1L)
})

test_that("two different package names are cached independently", {
	clear_optional_pkg_cache_entries(c("zzz_edi_fake_pkg_a", "zzz_edi_fake_pkg_b"))
	results <- c(zzz_edi_fake_pkg_a = TRUE, zzz_edi_fake_pkg_b = FALSE)
	local_mocked_bindings(requireNamespace = function(package, ...) unname(results[package]), .package = "base")
	expect_true(EDI:::optional_package_available("zzz_edi_fake_pkg_a"))
	expect_false(EDI:::optional_package_available("zzz_edi_fake_pkg_b"))
	expect_true(EDI:::optional_package_available("zzz_edi_fake_pkg_a"))                      # cache hit, still TRUE
})
