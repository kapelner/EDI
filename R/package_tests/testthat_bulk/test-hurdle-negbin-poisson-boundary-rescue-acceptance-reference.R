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
	# 2026-09-25: the exact maxit at which the raw optimizer's own convergence
	# criterion is NOT yet satisfied (so accept_negbin_poisson_boundary_convergence()'s
	# override is what actually fires) is a hard cliff, not a margin -- the original
	# seed=4 fixture only ever triggered the rescue at a single maxit value (a lone spike,
	# not a band), and that single point is BLAS/compiler-path dependent enough to drift
	# clean out of any nearby scan window (confirmed live: maxit=8 locally, FALSE across
	# 6:12 on CI run 36101666047 shard 37, and FALSE again across 6:12 on CI run
	# 36257223738 shard 1 after the window was already widened once).
	#
	# 2026-09-27: replaced the seed with one found by scanning seeds 1:300 (maxit 5:40)
	# for a fixture with multiple, spread-out maxit values that trigger the rescue rather
	# than a single spike -- seed=245 hits at maxit in {17, 19, 21, 22, 23} (5 hits, not
	# monotonic -- 16, 18, 20 do NOT hit -- so this is still chaotic optimizer-path
	# territory, not a stable plateau, but 5 independent trigger points spread across a
	# 7-wide window is far less likely to vanish under a BLAS-driven shift than a single
	# point was. Scanning a wide band (10:30) and requiring the rescue to fire for at
	# least one maxit in it tests the same real mechanism without pinning an exact
	# transition point.
	f <- get("fast_hurdle_negbin_cpp", envir = asNamespace("EDI"))
	set.seed(245L); n <- 50L
	X <- matrix(1, n, 1)
	y <- rpois(n, 10)

	r <- NULL
	for (m in 10L:30L) {
		candidate <- f(X, y, X_hurdle_r = X, maxit = m)
		if (isTRUE(candidate$dispersion_at_poisson_boundary)) { r <- candidate; maxit_used <- m; break }
	}
	expect_false(is.null(r), info = "no maxit in 10:30 triggered the Poisson-boundary rescue")
	expect_true(r$converged)
	expect_gt(log(r$theta_hat), log(1e4))   # kNegBinPoissonBoundaryLogTheta
	expect_true(is.finite(r$b))

	# the boundary rescue is deterministic given the same warm start / data, not RNG-driven
	r2 <- f(X, y, X_hurdle_r = X, maxit = maxit_used)
	expect_identical(r$theta_hat, r2$theta_hat)
	expect_identical(r$b, r2$b)
})

test_that("the same data under an unconstrained maxit converges normally without needing the rescue (dispersion_at_poisson_boundary stays FALSE), confirming the capped-maxit fixture above is genuinely exercising the rescue path, not just always-TRUE behavior", {
	f <- get("fast_hurdle_negbin_cpp", envir = asNamespace("EDI"))
	set.seed(245L); n <- 50L
	X <- matrix(1, n, 1)
	y <- rpois(n, 10)

	r <- f(X, y, X_hurdle_r = X, maxit = 100000L)
	expect_true(r$converged)
	expect_false(isTRUE(r$dispersion_at_poisson_boundary))
})
