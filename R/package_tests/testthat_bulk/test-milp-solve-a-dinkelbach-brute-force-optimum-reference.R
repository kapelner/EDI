library(testthat)
library(EDI)

# helper_optimal_milp_solvers.R's milp_solve_A_dinkelbach() -- the Dinkelbach fractional-programming
# solver for the A-optimality ratio g(w)/s(w) = (w'Hw + 1) / (n_T - w'Pw) -- had never been verified
# against an independent ground truth. The only two existing references to it
# (test-milp-solve-a-dinkelbach-degenerate-ratio-guard-reference.R and this session's own
# test-optimal-solve-auto-dinkelbach-exhausted-annealing-fallback-reference.R, which mocks it out
# entirely) exercise its stop() guard and its CALLER's downstream dispatch, never the actual iterative
# algorithm's correctness. test-design-fixed-optimal.R's "routes through Dinkelbach to a global
# certificate" test only checks converged == TRUE via the DesignFixedOptimal class, not the numeric
# result against ground truth. Verified here via brute-force enumeration over all n-choose-n_T binary
# allocations for a small n -- Dinkelbach's algorithm is guaranteed to reach the GLOBAL optimum of this
# concave-fractional program on convergence, so an exact match against the brute-force minimum is the
# correct independent reference (the same "match an independent brute-force search" technique already
# established for the optimal-blocks "ompr" method in this suite).
#   1. The converged solution's objective_value and w exactly match an independently brute-forced
#      global minimum, across two different (P, H, n_T) configurations.
#   2. The returned w always has exactly n_T ones (a valid allocation).

dinkelbach_brute_force_reference <- function(P, H, n_T) {
	n <- nrow(P)
	combn_idx <- combn(n, n_T)
	best <- Inf; best_w <- NULL
	for (k in seq_len(ncol(combn_idx))) {
		w <- rep(0, n); w[combn_idx[, k]] <- 1
		s <- n_T - drop(t(w) %*% P %*% w)
		if (s <= 0) next                                                           # degenerate, excluded exactly as the solver itself excludes it
		g <- drop(t(w) %*% H %*% w) + 1
		r <- g / s
		if (r < best) { best <- r; best_w <- w }
	}
	list(objective_value = best, w = best_w)
}

test_that("the converged solution exactly matches an independent brute-force global minimum, across two configurations", {
	f <- getFromNamespace("milp_solve_A_dinkelbach", "EDI")

	set.seed(1L); n <- 6L
	X <- matrix(rnorm(n * 2), n, 2)
	P1 <- X %*% solve(t(X) %*% X + diag(0.1, 2)) %*% t(X)
	H1 <- diag(n) * 0.5
	res1 <- f(P1, H1, n_T = 3L, roi_solver = "glpk")
	ref1 <- dinkelbach_brute_force_reference(P1, H1, n_T = 3L)
	expect_true(res1$converged)
	expect_equal(res1$objective_value, ref1$objective_value, tolerance = 1e-8)
	expect_equal(as.numeric(res1$w), as.numeric(ref1$w))

	set.seed(2L)
	X2 <- matrix(rnorm(n * 2), n, 2)
	P2 <- X2 %*% solve(t(X2) %*% X2 + diag(0.1, 2)) %*% t(X2)
	H2 <- diag(runif(n, 0.2, 1))
	res2 <- f(P2, H2, n_T = 3L, roi_solver = "glpk")
	ref2 <- dinkelbach_brute_force_reference(P2, H2, n_T = 3L)
	expect_true(res2$converged)
	expect_equal(res2$objective_value, ref2$objective_value, tolerance = 1e-8)
	expect_equal(as.numeric(res2$w), as.numeric(ref2$w))
})

test_that("the returned w always has exactly n_T ones (a valid allocation)", {
	f <- getFromNamespace("milp_solve_A_dinkelbach", "EDI")
	set.seed(3L); n <- 6L
	X <- matrix(rnorm(n * 2), n, 2)
	P <- X %*% solve(t(X) %*% X + diag(0.1, 2)) %*% t(X)
	H <- diag(n)
	res <- f(P, H, n_T = 2L, roi_solver = "glpk")
	expect_equal(sum(res$w), 2)
	expect_true(all(res$w %in% c(0, 1)))
})
