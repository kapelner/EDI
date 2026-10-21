# TODO-31 (release_v1_0_5.md): non-regression bound for the shipped 20-node
# Gauss-Hermite Poisson GLMM against its own 320-node optimum. The 1e-4 exact-NLL
# rule applies at 320 nodes; at 20 fixed nodes the gap is quadrature error, not
# optimizer error. Bound = measured level (2026-10-21) plus a thin margin; revisit
# after adaptive quadrature (performance_profiling_and_upgrades.md TODO-153).
test_that("20-node Poisson GLMM stays within the recorded bound of the 320-node optimum", {
	K <- function(x) get(x, envir = asNamespace("EDI"))
	fit <- K("fast_poisson_glmm_cpp")
	for (seed in 41001:41010) {
		set.seed(seed)
		n <- 200L; G <- 40L
		g <- rep(seq_len(G), each = 5L)
		x <- rnorm(n)
		u <- rnorm(G, sd = 0.9)[g]
		X <- cbind(1, x)
		y <- as.numeric(rpois(n, exp(0.4 + 0.3 * x + u)))
		g <- as.integer(g)
		r320 <- fit(X, y, g, 1L, n_gh = 320L, optimization_alg = "newton")
		r20  <- fit(X, y, g, 1L, n_gh = 20L,  optimization_alg = "newton")
		se <- sqrt(diag(as.matrix(r320$vcov)))[1:2]
		d_se <- abs(as.numeric(r20$b) - as.numeric(r320$b)) / se
		d_ls <- abs(as.numeric(r20$log_sigma) - as.numeric(r320$log_sigma))
		expect_lte(max(d_se), 0.75, label = paste("max |coef diff| in SE, seed", seed))
		expect_lte(d_ls, 0.10, label = paste("|log sigma diff|, seed", seed))
	}
})
