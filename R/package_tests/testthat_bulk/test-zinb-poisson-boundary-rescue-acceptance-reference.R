library(testthat)
library(EDI)

# _negbin_boundary_convergence.h's accept_negbin_poisson_boundary_convergence() is shared by three
# kernels (negbin_dispersion_boundary_acceptance.md's own finished-features writeup): fast_neg_bin_
# with_var_cpp (already tested), fast_hurdle_negbin_cpp (closed last iteration), and fast_zinb_cpp.
# That writeup explicitly requires regression coverage for "all three affected kernel families", but a
# codebase-wide grep confirmed fast_zinb_cpp's copy of this rescue mechanism (dispersion_at_poisson_
# boundary field) had zero test references anywhere -- completing the sweep of all three kernels.
# Unlike its two siblings, this fixture needed no capped-maxit trick at all: genuinely Poisson-
# distributed count data (no true overdispersion, no true zero-inflation) with an UNCONSTRAINED maxit
# already converges with theta pinned exactly at the Poisson-boundary constant log(1e4) -- the natural,
# organic outcome of fitting a negative-binomial/zero-inflation model to data that has neither property,
# not a special narrow numerical window like the sibling kernels needed. Contrasted against genuinely
# overdispersed negative-binomial data, which converges normally without needing the rescue.

test_that("genuinely Poisson-distributed data (no true overdispersion or zero-inflation) converges with dispersion pinned exactly at the Poisson-boundary constant log(1e4), deterministically", {
	f <- get("fast_zinb_cpp", envir = asNamespace("EDI"))
	set.seed(1L); n <- 50L
	X <- matrix(1, n, 1)
	y <- rpois(n, 10)

	r <- f(X, X, y, maxit = 100000L)

	expect_true(r$converged)
	expect_true(isTRUE(r$dispersion_at_poisson_boundary))
	log_theta <- r$params[3L]  # params = c(count intercept, zero-inflation intercept, log(theta))
	expect_equal(log_theta, log(1e4), tolerance = 1e-6)   # kNegBinPoissonBoundaryLogTheta
	expect_identical(r$covariance_type, "observed_conditional_on_poisson_boundary")

	# the boundary rescue is deterministic given the same data, not RNG-driven
	r2 <- f(X, X, y, maxit = 100000L)
	expect_identical(r$params, r2$params)
})

test_that("genuinely overdispersed negative-binomial data converges normally without needing the rescue (dispersion_at_poisson_boundary stays FALSE), confirming the fixture above is exercising a real boundary condition, not just always-TRUE behavior", {
	f <- get("fast_zinb_cpp", envir = asNamespace("EDI"))
	set.seed(2L); n <- 200L
	X <- matrix(1, n, 1)
	y <- rnbinom(n, size = 2, mu = 10)

	r <- f(X, X, y, maxit = 1000L)

	expect_true(r$converged)
	expect_false(isTRUE(r$dispersion_at_poisson_boundary))
	expect_lt(r$params[3L], log(1e4))  # theta stays well below the Poisson limit
})
