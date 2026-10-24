# TODO-31 (release_v1_0_5.md): non-regression bound for the shipped default-node
# Gauss-Hermite Poisson GLMM against its own 320-node optimum. The 1e-4 exact-NLL
# rule applies at 320 nodes; at the default fixed nodes the gap is quadrature
# error, not optimizer error. Revisit after adaptive quadrature
# (performance_profiling_and_upgrades.md TODO-153).
# History: the default was 20 nodes and this test checked n = 200 (40 groups of 5),
# sigma 0.9, where 20 nodes passed narrowly. The G4-C R8 grid (2026-10-23) found 20
# nodes out of bound at n = 120 (24 groups of 5): |log sigma diff| up to 0.171 at
# sigma 0.9. The node-count scan (2026-10-24) passed at 40, 60 and 80 nodes (30 was
# worse than 20: fixed-node GH error is not monotone in the node count), and the
# default became 60. This test now checks the failing cell, n = 120, sigma 0.9, at
# the wrapper's default node count (no n_gh passed), so it pins whatever ships.
# Measured at 60 nodes on these 10 seeds: 10 of 10 usable, max |log sigma diff|
# 0.064, max |coef diff| 0.14 SE. A seed enters the bound only when both fits are
# finite and converged (the R callers treat a non-converged kernel fit as a failure
# and fall back to glmmTMB); at least 5 of the 10 must be usable so the test cannot
# pass vacuously. Do not extend the seed range without re-measuring.
test_that("default-node Poisson GLMM stays within the recorded bound of the 320-node optimum at n = 120, sigma 0.9", {
	K <- function(x) get(x, envir = asNamespace("EDI"))
	fit <- K("fast_poisson_glmm_cpp")
	usable <- 0L
	skipped <- integer(0)
	for (seed in 41001:41010) {
		set.seed(seed)
		n <- 120L; G <- 24L
		g <- rep(seq_len(G), each = 5L)
		x <- rnorm(n)
		u <- rnorm(G, sd = 0.9)[g]
		X <- cbind(1, x)
		y <- as.numeric(rpois(n, exp(0.4 + 0.3 * x + u)))
		g <- as.integer(g)
		r320 <- fit(X, y, g, 1L, n_gh = 320L, optimization_alg = "newton")
		rdef <- fit(X, y, g, 1L, optimization_alg = "newton")
		ok <- function(r) isTRUE(r$converged) && all(is.finite(c(r$b, r$log_sigma)))
		if (!ok(r320) || !ok(rdef) || !all(is.finite(diag(as.matrix(r320$vcov))[1:2]))) {
			skipped <- c(skipped, seed)
			next
		}
		usable <- usable + 1L
		se <- sqrt(diag(as.matrix(r320$vcov)))[1:2]
		d_se <- abs(as.numeric(rdef$b) - as.numeric(r320$b)) / se
		d_ls <- abs(as.numeric(rdef$log_sigma) - as.numeric(r320$log_sigma))
		expect_lte(max(d_se), 0.75, label = paste("max |coef diff| in SE, seed", seed))
		expect_lte(d_ls, 0.10, label = paste("|log sigma diff|, seed", seed))
	}
	expect_gte(usable, 5L, label = paste0("usable seeds (skipped: ", paste(skipped, collapse = ", "), ")"))
})
