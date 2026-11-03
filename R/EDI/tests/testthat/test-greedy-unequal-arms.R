# DesignFixedGreedy with unequal arms (prob_T != 0.5) and odd n.
#
# The kernel centres X, so M * (2w - 1) = 2 * M * w: a fixed positive multiple
# of the half treated-minus-control mean difference at every treated count.
# The swap update therefore needs no change for unequal arms; only the treated
# and control counts do. Draws at prob_T = 0.5 are pinned separately by the
# seed-reproducibility fixtures (fixtures/openmp_design_seed_draws_v1_0_5.csv).

greedy_unequal_X = function(n = 30L) {
	set.seed(42)
	data.frame(x1 = rnorm(n), x2 = rexp(n), x3 = rbinom(n, 1, 0.4))
}

draw_greedy_unequal = function(prob_T, objective, n_iter = Inf, seed = 11L, X = greedy_unequal_X(), r = 10L) {
	des = DesignFixedGreedy$new(response_type = "continuous", prob_T = prob_T, objective = objective,
		n_iter = n_iter, n = nrow(X), verbose = FALSE, seed = seed)
	des$add_all_subjects_to_experiment(X)
	des$draw_ws_according_to_design(r = r)
}

test_that("unequal prob_T fixes the treated count at round(n * prob_T) and is seed-reproducible", {
	n = 30L
	for (prob_T in c(0.2, 0.3, 2 / 3, 0.8)) {
		for (objective in c("mahal_dist", "abs_sum_diff")) {
			for (n_iter in c(Inf, 300)) {
				W1 = draw_greedy_unequal(prob_T, objective, n_iter)
				W2 = draw_greedy_unequal(prob_T, objective, n_iter)
				expect_equal(dim(W1), c(n, 10L))
				expect_true(all(colSums(W1) == round(n * prob_T)))
				expect_identical(W1, W2)
			}
		}
	}
})

test_that("odd n is supported", {
	W = draw_greedy_unequal(0.5, "abs_sum_diff", X = greedy_unequal_X(29L))
	expect_true(all(colSums(W) == round(29 * 0.5)))
})

test_that("mahal_dist matches DesignFixedGreedyDOptimal's draws at unequal prob_T", {
	X = greedy_unequal_X()
	for (prob_T in c(0.3, 0.7)) {
		dopt = DesignFixedGreedyDOptimal$new(response_type = "continuous", prob_T = prob_T,
			n = nrow(X), verbose = FALSE, seed = 11L)
		dopt$add_all_subjects_to_experiment(X)
		expect_identical(draw_greedy_unequal(prob_T, "mahal_dist"), dopt$draw_ws_according_to_design(r = 10L))
	}
})

test_that("exhaustive abs_sum_diff reaches a local optimum of the true mean-difference criterion", {
	X = greedy_unequal_X()
	Xs = scale(as.matrix(X))
	f = function(w) sum(abs(colMeans(Xs[w == 1, , drop = FALSE]) - colMeans(Xs[w == 0, , drop = FALSE])))
	for (prob_T in c(0.3, 0.8)) {
		W = draw_greedy_unequal(prob_T, "abs_sum_diff", r = 3L)
		for (k in seq_len(ncol(W))) {
			w = W[, k]
			fw = f(w)
			best_gain = -Inf
			for (i in which(w == 1)) for (j in which(w == 0)) {
				v = w; v[i] = 0; v[j] = 1
				best_gain = max(best_gain, fw - f(v))
			}
			expect_lte(best_gain, 1e-12)
		}
	}
})

test_that("treated counts outside (1, n - 1) and prob_T outside (0, 1) error", {
	expect_error(draw_greedy_unequal(0.01, "mahal_dist"), "treated count")
	expect_error(DesignFixedGreedy$new(response_type = "continuous", prob_T = 1, n = 30L), "prob_T")
	expect_error(DesignFixedGreedy$new(response_type = "continuous", prob_T = 0, n = 30L), "prob_T")
})

test_that("pair-constrained kernel mode rejects a treated count other than the number of pairs", {
	X = as.matrix(greedy_unequal_X())
	pairs = matrix(seq_len(nrow(X)), ncol = 2L, byrow = TRUE)
	expect_error(greedy_design_search_cpp(X, 2L, "mahal_dist", -1L, pairs, n_T = 10L), "number of pairs")
})

test_that("DesignFixedMatchingGreedyPairSwitching has no prob_T argument (always 1:1)", {
	expect_error(DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", prob_T = 0.3, n = 32L),
		"unused argument")
	expect_equal(DesignFixedMatchingGreedyPairSwitching$new(response_type = "continuous", n = 32L)$get_prob_T(), 0.5)
})
