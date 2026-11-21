library(testthat)
library(EDI)

# v1.0.6-TODO-295 (docs-scenarios fixed-designs F3): DesignFixedGreedy (mahal_dist) and
# DesignFixedGreedyDOptimal (objective "D") rank allocations the same way, so at the defaults they give
# the same draws for the same seed. The two C++ searches compute the criterion differently in floating
# point, so with tied covariates (several swaps improving it by the same amount) they can break ties
# differently and stop at different, near-equally balanced allocations; the docs now say so.

greedy_pair_draws = function(X, r = 20L, seed = 7L) {
	n = nrow(X)
	g = DesignFixedGreedy$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	g$add_all_subjects_to_experiment(X)
	gd = DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	gd$add_all_subjects_to_experiment(X)
	list(g = g$draw_ws_according_to_design(r), d = gd$draw_ws_according_to_design(r))
}

mahal_imbalance = function(X, w) {
	dm = colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])
	drop(t(dm) %*% solve(stats::cov(X)) %*% dm)
}

test_that("without ties the default Greedy and GreedyDOptimal draws are identical", {
	set.seed(20261118)
	X = data.frame(weight = rnorm(40, 25, 3), age = runif(40, 6, 12))
	W = greedy_pair_draws(X)
	expect_identical(sum(colSums(W$g != W$d) == 0), 20L)
})

test_that("with tied covariates the two searches may differ but reach near-equal balance", {
	set.seed(20261118)
	X = data.frame(weight = round(rnorm(40, 25, 3), 1), age = sample(6:12, 40, replace = TRUE))
	W = greedy_pair_draws(X)
	for (j in seq_len(ncol(W$g))) {
		expect_equal(sum(W$g[, j]), sum(W$d[, j]))
		expect_lt(abs(mahal_imbalance(X, W$g[, j]) - mahal_imbalance(X, W$d[, j])), 1e-3)
	}
})
