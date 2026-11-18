# v1.0.6-TODO-129: a reusable bootstrap worker sets the worker design's private$X to NULL
# (model_matrix_stale = TRUE) on a rank-deficient resample. Design redraws that read
# private$X directly must rebuild it from Ximp rather than erroring (Atkinson) or
# replaying covariate-blind (KK21stepwise with condition_on_ws_for_rand_tests = FALSE).

make_seq_design_for_replay_test = function(gen, n, X, y, ...) {
	d = gen$new(n = n, response_type = "continuous", verbose = FALSE, ...)
	for (i in seq_len(n)) {
		d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y[i])
	}
	d
}

replay_draws_with_and_without_cleared_X = function(d, r = 10L) {
	intact = d$duplicate(verbose = FALSE)
	set.seed(7)
	w_intact = intact$draw_ws_according_to_design(r)
	cleared = d$duplicate(verbose = FALSE)
	cleared_priv = cleared$.__enclos_env__$private
	cleared_priv$X = NULL
	cleared_priv$model_matrix_stale = TRUE
	set.seed(7)
	w_cleared = cleared$draw_ws_according_to_design(r)
	list(intact = w_intact, cleared = w_cleared)
}

test_that("Atkinson redraw rebuilds a model matrix cleared by the bootstrap worker", {
	set.seed(1)
	n = 30
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	y = X$x1 + rnorm(n)
	d = make_seq_design_for_replay_test(DesignSeqOneByOneAtkinson, n, X, y)
	draws = replay_draws_with_and_without_cleared_X(d)
	expect_identical(draws$cleared, draws$intact)
})

test_that("KK21stepwise exact replay rebuilds a model matrix cleared by the bootstrap worker", {
	set.seed(1)
	n = 30
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	y = X$x1 + rnorm(n)
	d = make_seq_design_for_replay_test(DesignSeqOneByOneKK21stepwise, n, X, y,
		condition_on_ws_for_rand_tests = FALSE)
	draws = replay_draws_with_and_without_cleared_X(d, r = 5L)
	expect_identical(draws$cleared, draws$intact)
})
