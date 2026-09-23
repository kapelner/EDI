library(testthat)
library(EDI)

# InferenceContinRobustRegr$shared() (inference_continuous_robust_regr.R) has two distinct fit-
# failure sites: the FIRST call (private$best_X_colnames is still NULL) runs the hardened
# column-dropping search and calls set_failed_fit_cache() if hardening never finds a usable fit --
# already covered elsewhere. A SUBSEQUENT call (best_X_colnames already cached from a successful
# first fit) takes the "reuse structure" branch instead: it refits directly with the previously
# selected columns via fit_rlm_model(), and calls the SAME set_failed_fit_cache() if that refit
# returns NULL -- a structurally distinct call site inside shared()'s else-branch, never reached by
# calling fit_rlm_model()/set_failed_fit_cache() directly in isolation (as the existing private-
# helper reference test does) or by the first-call hardening-failure path. Reached here by mocking
# the instance's own fit_rlm_model to fail only on the second call.

test_that("a fit_rlm_model failure on the 'reuse structure' (already-selected-columns) path also fails via set_failed_fit_cache", {
	set.seed(2); n <- 60L
	X <- data.frame(x1 = rnorm(n), x2 = runif(n))
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(n) + d$get_w() + X$x1)

	inf <- InferenceContinRobustRegr$new(d, verbose = FALSE)
	p <- inf$.__enclos_env__$private

	# first call succeeds and populates best_X_colnames (entering the reuse branch on any later call)
	est1 <- inf$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(est1))
	expect_true(length(p$best_X_colnames) > 0L)

	# force the reuse-path refit to fail
	unlockBinding("fit_rlm_model", p)
	p$fit_rlm_model <- function(...) NULL
	p$cached_values$s_beta_hat_T <- NULL  # forces shared(estimate_only = FALSE) to actually run again

	est2 <- inf$compute_estimate(estimate_only = FALSE)
	expect_true(is.na(est2))
	expect_true(is.na(p$cached_values$beta_hat_T))  # even the previously-good point estimate is overwritten
	expect_true(is.na(p$cached_values$s_beta_hat_T))
	expect_true(is.na(p$cached_values$df))
})
