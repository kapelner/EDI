library(testthat)
library(EDI)

# TODO-118: DesignFixedRerandomization's unbalanced / odd-n fallback draws candidates in
# vectorized batches (generate_rerandomized_w_batch) instead of one R loop iteration per draw.
# Skipped when the installed EDI predates the batched method.

mk_rerand = function(n, prob_T, cutoff, objective = "mahal_dist") {
	set.seed(4)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedRerandomization$new(response_type = "continuous", n = n, prob_T = prob_T,
		obj_val_cutoff = cutoff, objective = objective, seed = 1, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	skip_if(is.null(des$.__enclos_env__$private$generate_rerandomized_w_batch),
		"installed EDI predates generate_rerandomized_w_batch")
	list(des = des, X = as.matrix(X))
}
ref_mahal = function(X, w) {
	d = colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])
	as.numeric(t(d) %*% solve(var(X)) %*% d)
}
ref_abs = function(X, w) sum(abs(colMeans(X[w == 1, , drop = FALSE]) - colMeans(X[w == 0, , drop = FALSE])))

test_that("batched fallback meets the cutoff for unbalanced prob_T and odd n", {
	skip_on_cran()
	for (cfg in list(c(20, 0.3), c(25, 0.7), c(21, 0.5))) {
		f = mk_rerand(cfg[1], cfg[2], 0.5)
		W = f$des$draw_ws_according_to_design(r = 60)
		expect_equal(dim(W), c(cfg[1], 60L))
		expect_true(all(W %in% c(0, 1)))
		expect_true(all(apply(W, 2, function(w) ref_mahal(f$X, w)) <= 0.5 + 1e-9))
		if (cfg[2] == 0.5) expect_true(all(colSums(W) == round(cfg[1] / 2)))
	}
	f = mk_rerand(20, 0.3, 0.8, "abs_sum_diff")
	W = f$des$draw_ws_according_to_design(r = 40)
	expect_true(all(apply(W, 2, function(w) ref_abs(f$X, w)) <= 0.8 + 1e-9))
})

test_that("batched fallback keeps the Bernoulli(prob_T) law without a cutoff and errors on an impossible cutoff", {
	skip_on_cran()
	f = mk_rerand(20, 0.3, NULL)
	W = f$des$draw_ws_according_to_design(r = 3000)
	expect_equal(mean(W), 0.3, tolerance = 0.02)
	g = mk_rerand(20, 0.3, 1e-12)
	expect_error(g$des$draw_ws_according_to_design(r = 3), "could not find 3 acceptable allocation")
})

test_that("batched fallback is reproducible under a seed", {
	skip_on_cran()
	a = mk_rerand(20, 0.3, 0.5)$des$draw_ws_according_to_design(r = 20)
	b = mk_rerand(20, 0.3, 0.5)$des$draw_ws_according_to_design(r = 20)
	expect_identical(a, b)
})
