# v1.0.6-TODO-234 (owner decision 2026-11-19): DesignFixedRerandomization's prop_acceptable path
# at prob_T = 0.5 drew every candidate from complete_randomization_forced_balanced_cpp(), which
# treats floor(n / 2). For n = 3 mod 4 that is one fewer than round(n * prob_T), the count every
# other path (and the documentation) uses. The forced-balanced kernel is now used only for even n.

library(testthat)
library(EDI)

rerand_prop = function(n, prob_T = 0.5, seed = 1L) {
	set.seed(seed)
	des = DesignFixedRerandomization$new(n = n, prob_T = prob_T, response_type = "continuous",
		prop_acceptable = 0.2, seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	des
}

test_that("prop_acceptable at prob_T = 0.5 treats round(n / 2) for odd and even n", {
	for (n in c(7L, 8L, 9L, 11L, 21L, 22L, 23L)) {
		des = rerand_prop(n)
		des$assign_w_to_all_subjects()
		n_T = round(n * 0.5)
		expect_equal(sum(des$get_w()), n_T, info = paste("n =", n))
		ws = des$draw_ws_according_to_design(30)
		expect_identical(dim(ws), c(n, 30L))
		expect_true(all(colSums(ws) == n_T), info = paste("n =", n))
	}
	# The cases that changed: n = 3 mod 4 rounds 11.5 / 5.5 up to even.
	expect_equal(round(23 * 0.5), 12)
	expect_equal(round(11 * 0.5), 6)
})

test_that("prop_acceptable agrees with the obj_val_cutoff path on the treated count at odd n", {
	n = 23L
	set.seed(3L)
	X = data.frame(x1 = rnorm(n), x2 = runif(n))
	cut = DesignFixedRerandomization$new(n = n, prob_T = 0.5, response_type = "continuous",
		obj_val_cutoff = Inf, seed = 3L)
	cut$add_all_subjects_to_experiment(X)
	prop = DesignFixedRerandomization$new(n = n, prob_T = 0.5, response_type = "continuous",
		prop_acceptable = 0.5, seed = 3L)
	prop$add_all_subjects_to_experiment(X)
	expect_true(all(colSums(cut$draw_ws_according_to_design(10)) == 12))
	expect_true(all(colSums(prop$draw_ws_according_to_design(10)) == 12))
})

test_that("prop_acceptable keeps the lowest-objective candidates at odd n", {
	des = rerand_prop(23L, seed = 5L)
	ws = des$draw_ws_according_to_design(20)
	# Every kept allocation is one of the 12-treated draws; with prop_acceptable = 0.2 the kept
	# set is the best fifth, so its mean Mahalanobis objective is below that of fresh 12-treated draws.
	X = as.matrix(des$get_X())
	S_inv = solve(var(X))
	mahal = function(w) { d = colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE]); drop(d %*% S_inv %*% d) }
	kept = apply(ws, 2L, mahal)
	set.seed(6L)
	fresh = replicate(200, mahal(sample(c(rep(1, 12), rep(0, 11)))))
	expect_lt(mean(kept), mean(fresh))
})
