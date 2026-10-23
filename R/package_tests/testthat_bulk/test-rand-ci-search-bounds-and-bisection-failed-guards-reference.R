library(testthat)
library(EDI)

# InferenceRandCI's compute_rand_confidence_interval() (inference_all_abstract_rand_ci.R) has two
# distinct nonestimable guards, neither of which had a test reference anywhere:
#   1. "rand_ci_search_bounds_failed": build_randomization_ci_search_bounds() fails to bracket the
#      target p-value (non-finite l/u) and there's no usable fallback CI (either ci_search_control$
#      fallback = "na", or the fallback CI itself is invalid).
#   2. "rand_ci_bisection_failed": the bounds ARE finite, but both bisection-search calls to
#      compute_ci_by_inverting_the_randomization_test_iteratively() return non-finite results, and
#      again no usable fallback CI is available.
# Both reached via InferenceAllSimpleAverageDiff, mocking the exact private helper each site calls
# (unlockBinding) -- bypassing the real permutation/bisection machinery entirely, the same technique
# already used elsewhere in this suite for analogous unreachable-in-practice failure paths.
#
# 2026-10-22 (TODO-116): both guards now go through edi_record_procedure_failure() (procedure
# "rand_ci"). With a valid Wald fit they no longer flip the object to nonestimable: the Wald
# estimate/SE are kept, is_nonestimable() stays FALSE, get_nonestimable_reason() stays NULL, and
# the reason is recorded under cached_values$procedure_failure_reason$rand_ci instead.

expect_rand_ci_procedure_failure <- function(f, reason) {
	expect_false(f$inf$is_nonestimable())
	expect_null(f$inf$get_nonestimable_reason())
	expect_true(is.finite(f$inf$compute_estimate()))
	se <- f$priv$cached_values$s_beta_hat_T
	expect_true(is.null(se) || is.finite(se))
	expect_identical(f$priv$cached_values$procedure_failure_reason$rand_ci, reason)
}

smd_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("'rand_ci_search_bounds_failed' fires when the search fails to bracket and fallback = 'na'", {
	f <- smd_fixture()
	unlockBinding("build_randomization_ci_search_bounds", f$priv)
	f$priv$build_randomization_ci_search_bounds <- function(...) {
		list(l = NA_real_, u = NA_real_, est = 0.3, fallback_ci = NULL)
	}

	ci <- f$inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE, ci_search_control = list(fallback = "na"))
	expect_true(all(is.na(ci)))
	expect_rand_ci_procedure_failure(f, "rand_ci_search_bounds_failed")
})

test_that("'rand_ci_bisection_failed' fires when both bounds are finite but both bisection calls fail with no fallback", {
	f <- smd_fixture(seed = 2L)
	unlockBinding("build_randomization_ci_search_bounds", f$priv)
	f$priv$build_randomization_ci_search_bounds <- function(...) {
		list(l = -1, u = 1, est = 0.3, fallback_ci = NULL)
	}
	unlockBinding("compute_ci_by_inverting_the_randomization_test_iteratively", f$priv)
	f$priv$compute_ci_by_inverting_the_randomization_test_iteratively <- function(...) NA_real_

	ci <- f$inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_rand_ci_procedure_failure(f, "rand_ci_bisection_failed")
})
