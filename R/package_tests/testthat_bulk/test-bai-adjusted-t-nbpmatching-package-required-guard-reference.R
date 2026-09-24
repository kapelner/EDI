library(testthat)
library(EDI)

# InferenceBaiAdjustedTKK14/InferenceBaiAdjustedTKK21's shared initialize() (the BaiAdjustedT
# component source in inference_continuous_KK_bai_abstract.R) guards on `check_package_installed(
# "nbpMatching")` before proceeding, stopping with "Package 'nbpMatching' is required for
# InferenceBaiAdjustedT. Please install it." A codebase-wide grep confirmed this exact message had no
# test reference anywhere, despite both concrete classes being otherwise extensively tested elsewhere
# (compute_halves()/compute_bai_variance_for_pairs()/migration-golden files) -- every existing
# reference runs with the real nbpMatching package actually installed (guarded by
# skip_if_not_installed("nbpMatching")), so the "package unavailable" branch itself was never
# exercised. Reached the same way the hurdle-Poisson/glmmTMB "package unavailable" guards elsewhere in
# this suite are tested: mocking check_package_installed() to return FALSE via
# local_mocked_bindings()/with_mocked_bindings(), independent of whether nbpMatching is actually
# installed on the machine running the test.

kk_design_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x <- data.frame(x1 = rnorm(1))
		w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 0.4 * w + rnorm(1))
	}
	des
}

test_that("InferenceBaiAdjustedTKK14 errors with the documented message when nbpMatching is (mocked as) unavailable", {
	des <- kk_design_fixture(1L)
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceBaiAdjustedTKK14$new(des, verbose = FALSE),
				"Package 'nbpMatching' is required for InferenceBaiAdjustedT. Please install it.",
				fixed = TRUE
			)
		}
	)
})

test_that("InferenceBaiAdjustedTKK21 errors with the same documented message when nbpMatching is (mocked as) unavailable", {
	set.seed(2L)
	n <- 20L
	des <- DesignSeqOneByOneKK21$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x <- data.frame(x1 = rnorm(1))
		w <- des$add_one_subject_to_experiment_and_assign(x)
		des$add_one_subject_response(i, 0.4 * w + rnorm(1))
	}
	with_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			expect_error(
				InferenceBaiAdjustedTKK21$new(des, verbose = FALSE),
				"Package 'nbpMatching' is required for InferenceBaiAdjustedT. Please install it.",
				fixed = TRUE
			)
		}
	)
})

test_that("construction succeeds normally when nbpMatching is not mocked as unavailable", {
	skip_if_not_installed("nbpMatching")
	des <- kk_design_fixture(3L)
	expect_no_error(InferenceBaiAdjustedTKK14$new(des, verbose = FALSE))
})
