library(testthat)
library(EDI)

# annealing_design_search_cpp (design_optimal_annealing_search.cpp) is the native simulated-annealing
# solver DesignFixedOptimal's solver dispatch falls back to beyond the exact-MILP linearization
# cutoff (helper_optimal_annealing.R's annealing_solve_kernel()). A codebase-wide grep across
# testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms ZERO test references
# of any kind for this exported kernel by name.
#   1. `objective_kind` must be one of "quadratic"/"l1"/"ratio"/"custom", else throws.
#   2. `objective_kind = "custom"` requires a non-NULL custom_objective XPtr, else throws.
# For "quadratic" (M1 is n x n; objective = w'M1w) and "l1" (M1 is p x n; objective =
# sum(abs(M1 %*% w))), the returned objective_value is pinned against an independent from-scratch
# R computation on the returned allocation w, and against min(chain_values) (the best of n_chains
# independent annealing runs). n_T treated subjects and reproducibility under set.seed() (the
# solver consumes R's own RNG stream via GetRNGstate()/PutRNGstate(), one seed per chain) are also
# checked.

f <- get("annealing_design_search_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 41L, n = 12L, p = 3L) {
	set.seed(seed)
	X <- matrix(rnorm(n * p), n, p)
	list(X = X, n = n, n_T = n %/% 2L, M2 = matrix(0, 0, 0))
}

test_that("an unrecognized objective_kind throws the objective-name error", {
	d <- fx()
	M1 <- d$X %*% t(d$X)
	expect_error(f("bogus", M1, d$M2, d$n_T, 2L, 50L, 1.0, 0.95, NULL), "objective_kind must be 'quadratic', 'l1', 'ratio', or 'custom'")
})

test_that("objective_kind = 'custom' without a custom_objective XPtr throws the missing-XPtr error", {
	d <- fx(seed = 42L)
	M1 <- d$X %*% t(d$X)
	expect_error(f("custom", M1, d$M2, d$n_T, 2L, 50L, 1.0, 0.95, NULL), "objective_kind 'custom' requires a custom_objective XPtr")
})

test_that("quadratic objective: the returned allocation has exactly n_T treated, objective_value equals w'M1w and equals the best of the n_chains, and the search is reproducible under set.seed()", {
	d <- fx(seed = 43L)
	M1 <- d$X %*% t(d$X)   # n x n quadratic imbalance form

	set.seed(51)
	r <- f("quadratic", M1, d$M2, d$n_T, 4L, 200L, 1.0, 0.95, NULL)
	w <- as.numeric(r$w)
	expect_length(w, d$n)
	expect_equal(sum(w), d$n_T)
	expect_equal(r$objective_value, as.numeric(t(w) %*% M1 %*% w), tolerance = 1e-10)
	expect_equal(r$objective_value, min(r$chain_values), tolerance = 1e-10)

	set.seed(51)
	r2 <- f("quadratic", M1, d$M2, d$n_T, 4L, 200L, 1.0, 0.95, NULL)
	expect_identical(w, as.numeric(r2$w))
})

test_that("l1 objective: the returned allocation's objective_value equals sum(abs(M1 %*% w)) (M1 here is p x n, not n x n)", {
	d <- fx(seed = 44L)
	A <- t(d$X)   # p x n, the l1 kernel's own shape convention (distinct from quadratic/ratio's n x n)

	set.seed(52)
	r <- f("l1", A, d$M2, d$n_T, 3L, 150L, 1.0, 0.95, NULL)
	w <- as.numeric(r$w)
	expect_equal(sum(w), d$n_T)
	expect_equal(r$objective_value, sum(abs(as.numeric(A %*% w))), tolerance = 1e-10)
})
