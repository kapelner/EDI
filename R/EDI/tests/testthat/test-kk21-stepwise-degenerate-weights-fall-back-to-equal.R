# v1.0.6-TODO-74 (and v1.0.6-TODO-27, same root cause): the KK21stepwise weight kernels leave every
# covariate's weight NA (or 0) when the residual variance is 0 for every candidate, i.e. when the
# responses so far are constant or fit exactly by [1, w, x]. na0() turned that into all-zero raw
# weights and assign_wt() normalized them as 0/0 = NaN, so the next assignment crashed in
# stats::quantile(). assign_wt() now falls back to equal weights when the raw weights sum to 0.

run_kk21_stepwise_sequence = function(response_type, y_fun, n = 20, ...){
	set.seed(1)
	X = data.frame(x1 = rnorm(n))
	d = DesignSeqOneByOneKK21stepwise$new(response_type = response_type, n = n, seed = 1L, ...)
	y = y_fun(X$x1)
	for (i in seq_len(n)){
		d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y[i])
	}
	d
}

test_that("KK21stepwise with one covariate and an exact-fit continuous response keeps assigning (TODO repro)", {
	set.seed(1); X = data.frame(x1 = rnorm(20))
	d = DesignSeqOneByOneKK21stepwise$new(response_type = "continuous", n = 20, seed = 1L)
	set.seed(1L); y = rnorm(20) # identical to x1: an exact fit
	expect_no_error(for (i in 1:20) {
		d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y[i])
	})
	expect_true(all(d$get_w() %in% c(0, 1)))
	expect_equal(unname(d$get_covariate_weights()), 1)
	for (wts in Filter(Negate(is.null), d$get_iteration_weights())){
		expect_true(all(is.finite(wts)))
		expect_equal(sum(wts), 1)
	}
})

test_that("KK21stepwise degenerate weights fall back to equal weights for every response type", {
	cases = list(
		list("continuous", function(x) rep(3, length(x))),
		list("continuous", function(x) 2 * x + 1),
		list("count", function(x) rep(2, length(x))),
		list("proportion", function(x) plogis(x)),
		list("survival", function(x) exp(x)),
		list("ordinal", function(x) rep(2, length(x))),
		list("ordinal", function(x) rep(2, length(x)), ordinal_use_speedup = FALSE)
	)
	for (cs in cases){
		args = c(list(cs[[1]], cs[[2]]), cs[-(1:2)])
		d = expect_no_error(do.call(run_kk21_stepwise_sequence, args))
		cw = d$get_covariate_weights()
		expect_true(all(is.finite(cw)), info = cs[[1]])
		expect_equal(sum(cw), 1, info = cs[[1]])
	}
})

test_that("KK21stepwise with two covariates and all-zero count responses gets equal finite weights", {
	set.seed(11)
	d = DesignSeqOneByOneKK21stepwise$new(n = 30, response_type = "count", seed = 1L)
	for (i in 1:30){
		d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
		d$add_one_subject_response(i, 0)
	}
	expect_equal(unname(d$get_covariate_weights()), c(0.5, 0.5))
})
