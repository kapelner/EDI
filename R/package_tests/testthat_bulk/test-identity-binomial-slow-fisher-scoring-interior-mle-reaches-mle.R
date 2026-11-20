library(testthat)
library(EDI)

# v1.0.6-TODO-267: on randomization draw 27 of the v1.0.6-TODO-205 fixture (Bernoulli design, n = 20, seed 1;
# draws seed 5) InferenceIncidBinomialIdentityRiskDiff returned 0.0833, half the MLE 0.1666. The MLE is interior,
# but one y = 1 row sits at mu = 0.9996, where the expected information (working weight ~2300) overstates the
# observed curvature (~1) by three orders of magnitude. Fisher scoring then crawls (2817 iterations at tol 1e-12),
# the kernel hit maxit = 100 with converged = FALSE, and the class dropped x1 and reported the unadjusted difference.
# The constrained binomial kernels (fast_log_binomial_regression.cpp) now switch to observed-information Newton steps
# after kObservedNewtonStartIter iterations when no row is held on a bound and the full step stays in the support.
# Needs the owner's build (the installed kernel fails these tests until then).

slow_fisher_fixture <- function() {
	set.seed(1L)
	list(
		x1 = rnorm(20L),
		w = c(0, 1, 1, 1, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 0),
		y = c(1, 1, 1, 1, 1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 0, 1)
	)
}

test_that("identity-binomial kernel reaches an interior MLE next to mu = 1 within the default maxit", {
	f <- slow_fisher_fixture()
	X <- cbind(1, f$w, f$x1)
	tight <- fast_identity_binomial_regression_cpp(X = X, y = f$y, tol = 1e-12, maxit = 5000L)
	expect_true(isTRUE(tight$converged))
	expect_identical(as.integer(tight$n_active_bounds), 0L)  # the MLE is interior
	expect_gt(max(X %*% tight$b), 0.999)                    # ... with one row next to mu = 1
	fit <- fast_identity_binomial_regression_cpp(X = X, y = f$y)
	expect_true(isTRUE(fit$converged))
	expect_false(isTRUE(fit$hit_iteration_cap))
	expect_lt(fit$num_iter, 100L)
	expect_equal(fit$b, tight$b, tolerance = 1e-6)
	expect_equal(fit$b[2], 0.1666128, tolerance = 1e-5)
	wfit <- fast_identity_binomial_regression_weighted_cpp(X = X, y = f$y, weights = rep(1, 20L))
	expect_true(isTRUE(wfit$converged))
	expect_equal(wfit$b, tight$b, tolerance = 1e-6)
})

test_that("InferenceIncidBinomialIdentityRiskDiff keeps x1 and returns the MLE on that draw", {
	f <- slow_fisher_fixture()
	set.seed(1L)
	des <- DesignFixedBernoulli$new(n = 20L, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = f$x1))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(f$y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$w <- f$w
	reset_reused_worker_private_caches(priv, changed = "assignment")
	priv$cached_values <- list()
	expect_no_warning(est <- inf$compute_estimate(estimate_only = TRUE), class = "edi_covariate_dropped_warning")
	expect_equal(est, 0.1666128, tolerance = 1e-5)
})
