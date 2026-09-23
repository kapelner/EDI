library(testthat)
library(EDI)

# InferenceCountHurdleNegBin (inference_count_hurdle.R) has 4 distinct nonestimable guards around
# its unweighted generate_mod() and weighted compute_estimate_with_bootstrap_weights(), none of
# which had a test reference anywhere:
#   1. "hurdle_negbin_design_unusable": generate_mod()'s main (count-submodel) design reduction is
#      unusable (NULL X or non-finite j_treat, or nrow(X) <= ncol(X)).
#   2. "hurdle_negbin_fit_unavailable": try_hurdle_negbin_fit() itself returns NULL (even after the
#      harden = TRUE treatment-only fallback).
#   3. "hurdle_negbin_weighted_design_unusable": the weighted-refit path's count-submodel or
#      hurdle-submodel design matrix is NULL.
#   4. "hurdle_negbin_weighted_fit_unavailable": glmmTMB::glmmTMB() itself errors on the weighted
#      refit.
# Reached by mocking the exact private method / package function each site calls -- the same
# techniques already used elsewhere in this suite for analogous unreachable-in-practice failure
# paths. The public compute_estimate_with_bootstrap_weights() method runs isolated (the isolation-
# wrapper mechanism documented in inference_all_abstract.R and already used by several of this
# session's other weighted-refit reference tests), so private$weighted_refit_impl() -- the pre-wrap
# implementation -- is called directly to inspect the cache it fills.

hurdle_negbin_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.3 * X$x1 + 0.5 * des$get_w() + 1)))
	des
}

test_that("generate_mod()'s own guard fires with 'hurdle_negbin_design_unusable' when the main design reduction is unusable", {
	des <- hurdle_negbin_fixture()
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("reduce_design_matrix_preserving_treatment", p)
	p$reduce_design_matrix_preserving_treatment <- function(...) list(X = NULL, j_treat = NA_real_)

	res <- p$generate_mod(estimate_only = TRUE)
	expect_null(res)
	expect_identical(inf$get_nonestimable_reason(), "hurdle_negbin_design_unusable")
})

test_that("generate_mod()'s own guard fires with 'hurdle_negbin_fit_unavailable' when try_hurdle_negbin_fit() fails", {
	des <- hurdle_negbin_fixture(seed = 2L)
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("try_hurdle_negbin_fit", p)
	p$try_hurdle_negbin_fit <- function(...) NULL

	res <- p$generate_mod(estimate_only = TRUE)
	expect_null(res)
	expect_identical(inf$get_nonestimable_reason(), "hurdle_negbin_fit_unavailable")
})

test_that("the weighted-refit guard fires with 'hurdle_negbin_weighted_design_unusable' when the design can't be built", {
	des <- hurdle_negbin_fixture(seed = 3L)
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	unlockBinding("build_component_matrix", p)
	p$build_component_matrix <- function(...) NULL

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "hurdle_negbin_weighted_design_unusable")
})

test_that("the weighted-refit guard fires with 'hurdle_negbin_weighted_fit_unavailable' when glmmTMB() errors", {
	skip_if_not_installed("glmmTMB")
	des <- hurdle_negbin_fixture(seed = 4L)
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	local_mocked_bindings(glmmTMB = function(...) stop("forced failure"), .package = "glmmTMB")

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "hurdle_negbin_weighted_fit_unavailable")
})
