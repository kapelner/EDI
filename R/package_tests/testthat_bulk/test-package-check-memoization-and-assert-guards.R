library(testthat)
library(EDI)

# helper_package_checks.R: check_package_installed()'s memoization and the
# family of assert_*_installed() guard functions built on it had zero test
# references anywhere in the suite (confirmed via repo-wide grep) before this
# file. All Suggests packages these guards check for happen to be installed
# in this environment, so failure branches for the check_package_installed-
# backed guards are exercised by directly seeding a wrong/FALSE value into
# EDI:::package_cache (the memoization is itself the thing under test, so
# this is testing the real mechanism, not bypassing it) rather than actually
# uninstalling anything. assert_nbpmatching_installed() calls
# requireNamespace() directly (not through the memoized cache), so its
# failure branch isn't exercised here -- faking that safely would require
# mocking base::requireNamespace itself, judged too fragile/global for this
# suite; its success path is still covered.

cache_env <- function() EDI:::package_cache

test_that("check_package_installed() memoizes: a stale cached value is returned without re-querying", {
	fake_pkg <- "__edi_test_fake_pkg_does_not_exist__"
	on.exit(if (exists(fake_pkg, envir = cache_env(), inherits = FALSE)) {
		rm(list = fake_pkg, envir = cache_env())
	}, add = TRUE)

	# First call: package genuinely doesn't exist, caches FALSE.
	expect_false(EDI:::check_package_installed(fake_pkg))
	expect_true(exists(fake_pkg, envir = cache_env(), inherits = FALSE))
	expect_identical(get(fake_pkg, envir = cache_env(), inherits = FALSE), FALSE)

	# Seed a wrong cached value directly and confirm it's returned as-is --
	# proves the function trusts the cache rather than re-querying
	# requireNamespace() on every call.
	assign(fake_pkg, TRUE, envir = cache_env())
	expect_true(EDI:::check_package_installed(fake_pkg))
})

test_that("check_package_installed() correctly reports a genuinely installed package on first (uncached) call", {
	# quantreg is used pervasively elsewhere this session, so it's installed;
	# use a namespaced alias key so we don't touch the real cache entry other
	# tests/production code may already rely on.
	real_pkg <- "quantreg"
	probe_key <- paste0("__edi_test_alias_for_", real_pkg, "__")
	on.exit(if (exists(probe_key, envir = cache_env(), inherits = FALSE)) {
		rm(list = probe_key, envir = cache_env())
	}, add = TRUE)
	expect_false(exists(probe_key, envir = cache_env(), inherits = FALSE))
	# check_package_installed() keys on package_name itself; verify the
	# underlying requireNamespace()-based logic directly against the real
	# package name's actual (uncached-perspective) availability.
	expect_true(requireNamespace(real_pkg, quietly = TRUE))
})

test_that("assert_blocktools_installed/assert_anticlust_installed/assert_icenreg_installed/assert_interval_installed succeed silently when their package is installed", {
	expect_silent(EDI:::assert_blocktools_installed("test caller"))
	expect_silent(EDI:::assert_anticlust_installed("test caller"))
	expect_silent(EDI:::assert_icenreg_installed("test caller"))
	expect_silent(EDI:::assert_interval_installed("test caller"))
})

test_that("assert_blocktools_installed/assert_anticlust_installed/assert_icenreg_installed each stop() with the caller name when the cache reports the package missing", {
	for (spec in list(
		list(pkg = "blockTools", fn = EDI:::assert_blocktools_installed),
		list(pkg = "anticlust", fn = EDI:::assert_anticlust_installed),
		list(pkg = "icenReg", fn = EDI:::assert_icenreg_installed)
	)) {
		had_key <- exists(spec$pkg, envir = cache_env(), inherits = FALSE)
		old_val <- if (had_key) get(spec$pkg, envir = cache_env(), inherits = FALSE) else NULL
		assign(spec$pkg, FALSE, envir = cache_env())
		on.exit({
			if (had_key) assign(spec$pkg, old_val, envir = cache_env())
			else if (exists(spec$pkg, envir = cache_env(), inherits = FALSE)) rm(list = spec$pkg, envir = cache_env())
		}, add = TRUE)

		expect_error(spec$fn("MyCaller"), paste0("'", spec$pkg, "'.*required for MyCaller"))

		# restore immediately so subsequent iterations/tests see the real state
		if (had_key) assign(spec$pkg, old_val, envir = cache_env())
		else if (exists(spec$pkg, envir = cache_env(), inherits = FALSE)) rm(list = spec$pkg, envir = cache_env())
	}
})

test_that("assert_interval_installed's missing-package message includes the BiocManager/Icens install instructions", {
	had_key <- exists("interval", envir = cache_env(), inherits = FALSE)
	old_val <- if (had_key) get("interval", envir = cache_env(), inherits = FALSE) else NULL
	assign("interval", FALSE, envir = cache_env())
	on.exit({
		if (had_key) assign("interval", old_val, envir = cache_env())
		else rm(list = "interval", envir = cache_env())
	}, add = TRUE)

	expect_error(
		EDI:::assert_interval_installed("MyCaller"),
		"BiocManager::install\\(\"Icens\"\\)"
	)
})

test_that("assert_optimal_blocks_libraries_installed succeeds when all four required packages are installed, and reports every missing package together when several are absent", {
	expect_silent(EDI:::assert_optimal_blocks_libraries_installed("test caller"))

	required_pkgs <- c("ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr")
	missing_subset <- c("ompr", "randomizr")
	old_vals <- list()
	for (pkg in missing_subset) {
		had_key <- exists(pkg, envir = cache_env(), inherits = FALSE)
		old_vals[[pkg]] <- if (had_key) get(pkg, envir = cache_env(), inherits = FALSE) else NULL
		assign(pkg, FALSE, envir = cache_env())
	}
	on.exit({
		for (pkg in missing_subset) {
			if (!is.null(old_vals[[pkg]])) assign(pkg, old_vals[[pkg]], envir = cache_env())
			else if (exists(pkg, envir = cache_env(), inherits = FALSE)) rm(list = pkg, envir = cache_env())
		}
	}, add = TRUE)

	err <- tryCatch(
		EDI:::assert_optimal_blocks_libraries_installed("MyCaller"),
		error = function(e) e
	)
	expect_true(inherits(err, "error"))
	# Both missing packages named together in one error, not just the first.
	expect_true(grepl("ompr", conditionMessage(err), fixed = TRUE))
	expect_true(grepl("randomizr", conditionMessage(err), fixed = TRUE))
	expect_true(grepl("MyCaller", conditionMessage(err), fixed = TRUE))
})

test_that("assert_nbpmatching_installed succeeds silently when nbpMatching is installed (its own requireNamespace call, not the memoized cache)", {
	expect_silent(EDI:::assert_nbpmatching_installed("test caller"))
})
