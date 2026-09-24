library(testthat)
library(EDI)

# rerandomization_search_cpp (rerandomization_helpers.cpp) is DesignFixedRerandomization's actual
# draw-generating search kernel (design_fixed_rerandomization.R): it repeatedly draws balanced
# (n/2-treated) allocations, recomputes the objective in-line (abs_sum_diff or mahal_dist, matching
# compute_objective_vals_cpp's own formulas but computed directly on standardized/whitened columns
# rather than via a separate call), and keeps only draws whose objective is <= cutoff, until r are
# found or max_draws is exhausted (returning an n x k matrix with k <= r). A codebase-wide grep
# across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms ZERO test
# references of any kind for this exported kernel, despite it being the single production
# call site for the whole rerandomization design's draw mechanism.
#
# This test suite runs single-threaded (the sequential code path, nthreads <= 1, in effect whenever
# OpenMP isn't configured for multiple threads in this environment), which is fully deterministic
# under set.seed() -- confirmed directly below. Every returned column's exact balance (n/2 treated)
# and objective-vs-cutoff invariant is checked against an independent from-scratch R computation
# using compute_objective_vals_cpp() itself (an independently-tested kernel) as the objective
# reference, rather than re-deriving the standardization formula by hand.

f <- get("rerandomization_search_cpp", envir = asNamespace("EDI"))
obj_ref <- get("compute_objective_vals_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 41L, n = 20L, p = 2L) {
	set.seed(seed)
	X <- matrix(rnorm(n * p), n, p)
	X
}

test_that("abs_sum_diff: every returned draw is exactly balanced (n/2 treated) and has objective <= cutoff (verified against compute_objective_vals_cpp)", {
	X <- fx()
	n <- nrow(X)
	set.seed(51)
	out <- f(X, 5L, "abs_sum_diff", 100, 2000L)
	expect_equal(nrow(out), n)
	expect_lte(ncol(out), 5L)
	expect_true(all(colSums(out) == n %/% 2L))

	indicTs <- t(out)
	objs <- as.numeric(obj_ref(X, indicTs, "abs_sum_diff"))
	expect_true(all(objs <= 100 + 1e-6))
})

test_that("mahal_dist: every returned draw is balanced and has objective <= cutoff (verified against compute_objective_vals_cpp)", {
	X <- fx(seed = 52L)
	n <- nrow(X)
	S_inv <- solve(cov(X))
	set.seed(53)
	out <- f(X, 5L, "mahal_dist", 5, 2000L)
	expect_true(all(colSums(out) == n %/% 2L))

	indicTs <- t(out)
	objs <- as.numeric(obj_ref(X, indicTs, "mahal_dist", S_inv))
	expect_true(all(objs <= 5 + 1e-6))
})

test_that("an unreachable cutoff exhausts max_draws and returns a trimmed (fewer than r) result", {
	X <- fx(seed = 54L)
	set.seed(55)
	out <- f(X, 5L, "abs_sum_diff", -1, 50L)
	expect_equal(nrow(out), nrow(X))
	expect_equal(ncol(out), 0L)
})

test_that("draws are reproducible under an identical set.seed() (sequential/single-thread code path)", {
	X <- fx(seed = 56L)
	set.seed(61); a <- f(X, 3L, "abs_sum_diff", 1000, 500L)
	set.seed(61); b <- f(X, 3L, "abs_sum_diff", 1000, 500L)
	expect_identical(a, b)
})
