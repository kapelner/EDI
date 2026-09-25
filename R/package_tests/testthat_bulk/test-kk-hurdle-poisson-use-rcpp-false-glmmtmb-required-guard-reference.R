library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC and InferenceCountKKHurdlePoissonOneLik (both in
# inference_count_KK_cond_poisson.R) each have their own copy of a constructor-time guard:
# "Package 'glmmTMB' is required for <class> when use_rcpp = FALSE. Please install it." Distinct
# from the already-covered weighted-bootstrap-refit glmmTMB requirement ("weighted bootstrap
# estimation requires package 'glmmTMB'", test-hurdle-poisson-glmmtmb-weighted-bootstrap.R) -- this
# is the SEPARATE, earlier construction-time check triggered by use_rcpp = FALSE regardless of
# whether a weighted refit is ever attempted. A codebase-wide grep confirmed the only two references
# to either class in test-proportion-count-family-contracts.R/test-parametric-bootstrap-lr-all-
# capable-classes.R always construct with use_rcpp = TRUE (or the default), so this guard had zero
# test references anywhere for either class. Reached via with_mocked_bindings(check_package_installed
# = function(pkg) FALSE, .package = "EDI") on a real KK14 count-response design, the established
# pattern for exercising a package-unavailable branch without actually uninstalling glmmTMB.

mk_des <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rpois(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	des
}

test_that("InferenceCountKKHurdlePoissonIVWC(use_rcpp = FALSE) requires glmmTMB at construction time", {
	des <- mk_des(1L)
	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		code = expect_error(
			InferenceCountKKHurdlePoissonIVWC$new(des, use_rcpp = FALSE, verbose = FALSE),
			"Package 'glmmTMB' is required for InferenceCountKKHurdlePoissonIVWC when use_rcpp = FALSE",
			fixed = TRUE
		)
	)
	# the real package IS installed in this test environment, so the same call succeeds unmocked
	expect_silent(InferenceCountKKHurdlePoissonIVWC$new(des, use_rcpp = FALSE, verbose = FALSE))
})

test_that("InferenceCountKKHurdlePoissonOneLik(use_rcpp = FALSE) requires glmmTMB at construction time", {
	des <- mk_des(2L)
	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		code = expect_error(
			InferenceCountKKHurdlePoissonOneLik$new(des, use_rcpp = FALSE, verbose = FALSE),
			"Package 'glmmTMB' is required for InferenceCountKKHurdlePoissonOneLik when use_rcpp = FALSE",
			fixed = TRUE
		)
	)
	expect_silent(InferenceCountKKHurdlePoissonOneLik$new(des, use_rcpp = FALSE, verbose = FALSE))
})

test_that("use_rcpp = TRUE (the default) never triggers the guard, even when glmmTMB is mocked unavailable", {
	des <- mk_des(3L)
	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		code = {
			expect_silent(InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE))
			expect_silent(InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE))
		}
	)
})
