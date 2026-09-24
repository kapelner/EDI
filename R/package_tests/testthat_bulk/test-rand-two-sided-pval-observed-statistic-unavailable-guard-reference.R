library(testthat)
library(EDI)

# InferenceRand's private compute_rand_two_sided_pval() (inference_all_abstract_rand.R) -- the
# shared randomization-inference p-value machinery composed into every class supporting
# response_type-appropriate randomization tests -- has a guard, checked right after computing the
# observed treatment statistic: `if (length(t) != 1 || !is.finite(t)) { if (isTRUE(private$harden))
# private$cache_nonestimable_estimate("randomization_observed_statistic_unavailable"); return(NA_real_) }`.
# This fires at TWO separate call sites within the same function (the t0s_rand cache-reuse fast path,
# and the general path), and is gated on private$harden: with harden = FALSE, the guard is skipped
# entirely (no nonestimable state is cached, even though the p-value is still NA). A codebase-wide
# grep confirms the base "randomization_observed_statistic_unavailable" reason string (as opposed to
# class-specific variants like "kk_clogit_combined_randomization_observed_statistic_unavailable",
# already covered elsewhere) had no test reference anywhere. Reached by unlockBinding-replacing
# compute_treatment_estimate_during_randomization_inference() with a stub that returns a non-finite
# observed statistic, on InferenceContinLin (a simple, harden-capable continuous class), independent
# of the real treatment-estimate machinery (already tested elsewhere).

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnorm(n) + 0.5 * w + 0.3 * X$x1
	des$add_all_subject_responses(y)
	des
}

test_that("harden = TRUE: a non-finite observed treatment statistic caches the documented nonestimable reason and returns NA", {
	des <- fx(1L)
	inf <- InferenceContinLin$new(des, harden = TRUE, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("compute_treatment_estimate_during_randomization_inference", priv)
	priv$compute_treatment_estimate_during_randomization_inference <- function(estimate_only = TRUE) NA_real_

	pval <- inf$compute_rand_two_sided_pval(r = 20L)
	expect_true(is.na(pval))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "randomization_observed_statistic_unavailable")
})

test_that("harden = FALSE: the same non-finite observed statistic returns NA but does NOT cache any nonestimable reason", {
	des <- fx(2L)
	inf <- InferenceContinLin$new(des, harden = FALSE, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("compute_treatment_estimate_during_randomization_inference", priv)
	priv$compute_treatment_estimate_during_randomization_inference <- function(estimate_only = TRUE) NA_real_

	pval <- inf$compute_rand_two_sided_pval(r = 20L)
	expect_true(is.na(pval))
	expect_false(inf$is_nonestimable("estimate"))
	expect_null(inf$get_nonestimable_reason())
})

test_that("a wrong-length (not length-1) observed statistic also triggers the guard under harden = TRUE", {
	des <- fx(3L)
	inf <- InferenceContinLin$new(des, harden = TRUE, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("compute_treatment_estimate_during_randomization_inference", priv)
	priv$compute_treatment_estimate_during_randomization_inference <- function(estimate_only = TRUE) c(0.1, 0.2)

	pval <- inf$compute_rand_two_sided_pval(r = 20L)
	expect_true(is.na(pval))
	expect_equal(inf$get_nonestimable_reason(), "randomization_observed_statistic_unavailable")
})

test_that("a well-formed finite observed statistic does not trigger the guard", {
	des <- fx(4L)
	inf <- InferenceContinLin$new(des, harden = TRUE, verbose = FALSE)
	pval <- inf$compute_rand_two_sided_pval(r = 50L)
	expect_true(is.finite(pval))
	expect_false(inf$is_nonestimable("estimate"))
})
