library(testthat)
library(EDI)

# _negbin_boundary_convergence.h's accept_negbin_poisson_boundary_convergence() is shared by three
# kernels (per its own finished-features writeup, negbin_dispersion_boundary_acceptance.md, and the
# fast_neg_bin_with_var_cpp reference test's own comment): fast_neg_bin_with_var_cpp,
# fast_hurdle_negbin_cpp, and fast_zinb_cpp. That writeup explicitly requires "regression coverage
# ... [for] all three affected kernel families", but a codebase-wide grep confirmed only fast_neg_
# bin_with_var_cpp's ACCEPT path (dispersion_at_poisson_boundary = TRUE) has ever been tested
# (test-negbin-poisson-boundary-rescue-acceptance-reference.R) -- fast_hurdle_negbin_cpp's copy of
# this same rescue mechanism had zero test references anywhere. This is inherently narrow, seed-
# dependent numerical territory (not a source bug -- the accept function's own conditions are working
# as designed), found here by the same kind of automated seed/n/maxit sweep the existing negbin test's
# own comment describes, not analytically constructible by hand; the exact fixture is pinned as a
# regression fixture. (The count submodel's dispersion rescue and the separate hurdle/zero submodel's
# own convergence are independent concerns in this kernel -- the fixture below happens to leave the
# hurdle submodel unconverged, which is irrelevant to what's being tested here, so assertions are
# scoped to the count-side rescue fields only, not the hurdle-side ones.)

test_that("a deliberately capped maxit on near-Poisson intercept-only count data triggers the count-side Poisson-boundary rescue: converged is forced TRUE, dispersion_at_poisson_boundary is TRUE, and log(theta_hat) exceeds the boundary constant", {
	f <- get("fast_hurdle_negbin_cpp", envir = asNamespace("EDI"))
	set.seed(4L); n <- 50L
	X <- matrix(1, n, 1)
	y <- rpois(n, 10)

	r <- f(X, y, X_hurdle_r = X, maxit = 8L)

	expect_true(isTRUE(r$dispersion_at_poisson_boundary))
	expect_true(r$converged)
	expect_gt(log(r$theta_hat), log(1e4))   # kNegBinPoissonBoundaryLogTheta
	expect_true(is.finite(r$b))

	# the boundary rescue is deterministic given the same warm start / data, not RNG-driven
	r2 <- f(X, y, X_hurdle_r = X, maxit = 8L)
	expect_identical(r$theta_hat, r2$theta_hat)
	expect_identical(r$b, r2$b)
})

test_that("the same data under an unconstrained maxit converges normally without needing the rescue (dispersion_at_poisson_boundary stays FALSE), confirming the capped-maxit fixture above is genuinely exercising the rescue path, not just always-TRUE behavior", {
	f <- get("fast_hurdle_negbin_cpp", envir = asNamespace("EDI"))
	set.seed(4L); n <- 50L
	X <- matrix(1, n, 1)
	y <- rpois(n, 10)

	r <- f(X, y, X_hurdle_r = X, maxit = 100000L)
	expect_true(r$converged)
	expect_false(isTRUE(r$dispersion_at_poisson_boundary))
})
