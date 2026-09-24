library(testthat)
library(EDI)

# _negbin_boundary_convergence.h's accept_negbin_poisson_boundary_convergence() -- shared by
# fast_neg_bin_with_var_cpp, fast_hurdle_negbin_cpp and fast_zinb_cpp -- rescues a non-converged fit
# whose log(theta) has drifted past the Poisson-limit boundary constant (log(1e4) ~ 9.2103) as
# "converged" when the non-dispersion (coefficient) gradient is already essentially zero and a
# forward probe further along log(theta) keeps improving toward the Poisson limit. The existing
# reference test (test-negbin-regression-kernel-glm-nb-coefficients-theta-loglik-fixed-and-poisson-
# boundary-reference.R) only ever asserts this rescue flag stays FALSE (Poisson-distributed data with
# an unconstrained maxit that converges normally, well before theta needs rescuing) -- the actual
# ACCEPT path (dispersion_at_poisson_boundary = TRUE) had no test reference anywhere, per the
# coverage registry's own note that this is reached only under a narrow combination of conditions
# (a genuinely tight numerical window, confirmed by direct probing: found by an automated seed/maxit
# sweep over small intercept-only Poisson-generated datasets, not analytically constructible by hand).
#
# This is inherently narrow, seed-dependent numerical territory (not a source bug -- the accept
# function's own conditions are working as designed), so the exact seed/maxit combination below is
# pinned as a fixed regression fixture rather than re-derived from first principles.

test_that("a deliberately capped maxit on near-Poisson intercept-only data triggers the Poisson-boundary rescue: converged is forced TRUE, dispersion_at_poisson_boundary is TRUE, and log(theta_hat) exceeds the boundary constant", {
	f <- get("fast_neg_bin_with_var_cpp", envir = asNamespace("EDI"))
	set.seed(1); n <- 300L
	X <- cbind(1)
	y <- rpois(n, sample(c(2, 5, 10, 20, 50), 1))

	r <- f(X, y, maxit = 15L, eps_g = 1e-9)

	expect_true(isTRUE(r$dispersion_at_poisson_boundary))
	expect_true(r$converged)
	expect_gt(log(r$theta_hat), log(1e4))   # kNegBinPoissonBoundaryLogTheta
	expect_true(is.finite(r$logLik))

	# the boundary rescue is deterministic given the same warm start / data, not RNG-driven
	r2 <- f(X, y, maxit = 15L, eps_g = 1e-9)
	expect_identical(r$theta_hat, r2$theta_hat)
	expect_identical(r$b, r2$b)
})

test_that("the rescued fit's vcov excludes the boundary-hit dispersion parameter from inversion (its row/column are NA), while the coefficient's own variance stays available", {
	f <- get("fast_neg_bin_with_var_cpp", envir = asNamespace("EDI"))
	set.seed(1); n <- 300L
	X <- cbind(1)
	y <- rpois(n, sample(c(2, 5, 10, 20, 50), 1))

	r <- f(X, y, maxit = 15L, eps_g = 1e-9)
	expect_true(isTRUE(r$dispersion_at_poisson_boundary))
	expect_true(is.finite(r$vcov[1, 1]))
	expect_true(is.na(r$vcov[1, 2]))
	expect_true(is.na(r$vcov[2, 1]))
	expect_true(is.na(r$vcov[2, 2]))
})
