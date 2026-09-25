library(testthat)
library(EDI)

# set_num_cores(num_cores, force_mirai) (globals.R:570-585), when force_mirai = TRUE (or on a
# non-Unix platform), requires the 'mirai' package before attempting to launch any daemon: "The
# 'mirai' package is required for parallelization on this system or when force_mirai = TRUE. Please
# install it." Every existing set_num_cores(force_mirai = TRUE) call in the suite (test-parametric-
# bootstrap-lr.R, test-bayesian-bootstrap.R, test-simulation-framework-parallel-cleanup.R, test-
# simulation-framework-extended.R) exercises the success path with mirai genuinely installed and a
# real daemon pool spun up -- none exercise this package-unavailable guard, confirmed via a
# codebase-wide grep for the exact message (zero hits). Reached via the established with_mocked_
# bindings(check_package_installed = ..., .package = "EDI") technique; the guard fires before any
# real daemon is ever launched, and unset_num_cores() is called both before (inside set_num_cores
# itself) and after (cleanup) to guarantee no lingering cluster state.

test_that("set_num_cores(force_mirai = TRUE) errors with the documented message when 'mirai' is (mocked as) unavailable, without launching any daemon", {
	on.exit(unset_num_cores(), add = TRUE)
	res <- with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		tryCatch(set_num_cores(2L, force_mirai = TRUE), error = function(e) conditionMessage(e))
	)
	expect_identical(
		res,
		"The 'mirai' package is required for parallelization on this system or when force_mirai = TRUE. Please install it."
	)
})

test_that("num_cores <= 1 never reaches the guard, even with force_mirai = TRUE and mirai (mocked as) unavailable", {
	on.exit(unset_num_cores(), add = TRUE)
	res <- with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		tryCatch(set_num_cores(1L, force_mirai = TRUE), error = function(e) conditionMessage(e))
	)
	expect_null(res)
})
