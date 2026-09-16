library(testthat)
library(EDI)

make_numerical_resampling_probe = function() {
	set.seed(1201)
	d = DesignFixedBernoulli$new(n = 20L, response_type = "continuous", seed = 1201L)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(20)))
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(20))
	InferenceAllSimpleAverageDiff$new(d)$.__enclos_env__$private
}

test_that("affine-null inversion agrees with exact tail-count order statistics", {
	p = make_numerical_resampling_probe()
	A = seq(-5, 5, length.out = 100)
	ci = p$closed_form_ci_from_affine_null_draws(A, rep(1, 100), 0, .2)
	expect_equal(ci, sort(-A)[c(5, 96)])
	# Translation of the observed statistic translates every breakpoint.
	expect_equal(p$closed_form_ci_from_affine_null_draws(A, rep(1, 100), 2, .2), ci + 2)
	# Positive common slope rescales the inversion without changing tail counts.
	expect_equal(p$closed_form_ci_from_affine_null_draws(A, rep(2, 100), 0, .2), ci / 2)
	expect_null(p$closed_form_ci_from_affine_null_draws(A[1:10], rep(1, 10), 0, .2))
	expect_null(p$closed_form_ci_from_affine_null_draws(A, rep(0, 100), 0, .2))
	expect_null(p$closed_form_ci_from_affine_null_draws(rep(1, 100), rep(1, 100), 0, .2))
})

test_that("centered resampling intervals reflect empirical quantiles on the full-sample scale", {
	p = make_numerical_resampling_probe()
	v = c(-4, -2, -1, 0, 1, 3, 5, NA, Inf)
	finite = v[is.finite(v)]
	q = quantile(finite, c(.1, .9), type = 8, names = FALSE)
	ci = p$resampling_ci_from_centered_distribution(v, .2, est = 2, n_units = 25)
	expect_equal(as.numeric(ci), c(2 - q[2] / 5, 2 - q[1] / 5))
	expect_identical(names(ci), c("10%", "90%"))
	custom = p$resampling_ci_from_centered_distribution(v, .2, 2, 25, list(rate_exponent = 1))
	expect_equal(as.numeric(custom), c(2 - q[2] / 25, 2 - q[1] / 25))
	expect_equal(as.numeric(p$resampling_ci_from_centered_distribution(v + 3, .2, 2, 25)), as.numeric(ci) - .6)
})

test_that("centered resampling p-values count both tails and enforce Monte Carlo resolution", {
	p = make_numerical_resampling_probe()
	v = c(-3, -2, -1, 0, 1, 2, 3, NA, Inf)
	# est - delta = 0 implies observed centered pivot zero.
	expect_equal(p$resampling_centered_pval(v, 2, 2, 25), 1)
	# Observed pivot 2 has two of seven values in its upper tail.
	expect_equal(p$resampling_centered_pval(v, .4, 0, 25), 4 / 7)
	# Outside the empirical support the nonzero floor is 2 / B_finite.
	expect_equal(p$resampling_centered_pval(v, 100, 0, 25), 2 / 7)
	expect_equal(p$resampling_centered_pval(-v, -.4, 0, 25), 4 / 7)
})

test_that("bootstrap bound expansion brackets monotone tails and returns conservative radius", {
	p = make_numerical_resampling_probe()
	f = function(delta) exp(-abs(delta))
	expect_equal(p$expand_rand_bootstrap_bound(-1, 0, .1, TRUE, 10, 5L, f), -4)
	expect_equal(p$expand_rand_bootstrap_bound(1, 0, .1, FALSE, 10, 5L, f), 4)
	expect_equal(p$expand_rand_bootstrap_bound(-1, 0, .1, TRUE, 3, 5L, function(delta) 1), -3)
	expect_true(is.na(p$expand_rand_bootstrap_bound(NA, 0, .1, TRUE, 3, 5L, f)))
})
