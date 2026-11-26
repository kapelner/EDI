# v1.0.7-TODO-190: nonparametric bootstrap resamples with missing covariate values.
# reimpute_missing_vals_each_resample = FALSE (default) keeps every resample on the rows of
# the design's original imputation, including a resample whose model matrix has to be
# rebuilt (a rare covariate level goes constant); TRUE re-runs the imputation per resample.
# Without missing covariates the flag changes nothing.

make_reimpute_case = function(with_missing = TRUE, seed = 1L) {
	set.seed(seed)
	n = 60L
	X = data.frame(
		x1 = rnorm(n),
		x2 = rnorm(n),
		# One 1 in 60 rows: about a third of the resamples leave it out, the column is then
		# constant, and that resample's model matrix is rebuilt.
		x_rare = c(1, rep(0, n - 1L))
	)
	if (with_missing) X$x1[c(5, 11, 17, 23, 29, 35, 41, 47)] = NA
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 7L)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = 1 + 0.5 * w + X$x2 + rnorm(n)
	des$add_all_subject_responses(ys = y)
	InferenceContinOLS$new(des)
}

count_missranger_calls = function(expr) {
	calls = 0L
	real = getFromNamespace("missRanger", "missRanger")
	testthat::local_mocked_bindings(
		missRanger = function(...) { calls <<- calls + 1L; real(...) },
		.package = "EDI"
	)
	force(expr)
	calls
}

test_that("default bootstrap never re-imputes, even on rank-deficient resamples", {
	inf = make_reimpute_case()
	invisible(inf$compute_estimate())
	calls = count_missranger_calls(
		ci <- inf$compute_bootstrap_confidence_interval(B = 30, type = "percentile", show_progress = FALSE)
	)
	expect_identical(calls, 0L)
	expect_true(all(is.finite(ci)))
})

test_that("reimpute_missing_vals_each_resample = TRUE imputes every resample", {
	inf = make_reimpute_case()
	invisible(inf$compute_estimate())
	B = 12L
	calls = count_missranger_calls(
		ci <- inf$compute_bootstrap_confidence_interval(B = B, type = "percentile", show_progress = FALSE,
			reimpute_missing_vals_each_resample = TRUE)
	)
	expect_gte(calls, B)
	expect_true(all(is.finite(ci)))
})

test_that("the two settings give different draws with missing covariates, cached apart", {
	inf = make_reimpute_case()
	d_false = inf$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE)
	d_true = inf$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE,
		reimpute_missing_vals_each_resample = TRUE)
	expect_length(d_true, 15L)
	expect_false(identical(d_false, d_true))
	# The FALSE distribution is still the cached one for a default call.
	expect_identical(inf$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE), d_false)
})

test_that("without missing covariates both settings are identical", {
	ci_default = make_reimpute_case(with_missing = FALSE)$compute_bootstrap_confidence_interval(
		B = 25, type = "percentile", show_progress = FALSE)
	ci_false = make_reimpute_case(with_missing = FALSE)$compute_bootstrap_confidence_interval(
		B = 25, type = "percentile", show_progress = FALSE, reimpute_missing_vals_each_resample = FALSE)
	ci_true = make_reimpute_case(with_missing = FALSE)$compute_bootstrap_confidence_interval(
		B = 25, type = "percentile", show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE)
	expect_identical(ci_false, ci_default)
	expect_identical(ci_true, ci_default)
	p_false = make_reimpute_case(with_missing = FALSE)$compute_bootstrap_two_sided_pval(B = 25, type = "percentile",
		show_progress = FALSE)
	p_true = make_reimpute_case(with_missing = FALSE)$compute_bootstrap_two_sided_pval(B = 25, type = "percentile",
		show_progress = FALSE, reimpute_missing_vals_each_resample = TRUE)
	expect_identical(p_true, p_false)
})

test_that("TRUE refuses when the inference's matrix is not the design's", {
	set.seed(3)
	n = 60L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	X$x1[c(3, 9, 15, 21)] = NA
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 7L)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = rnorm(n) + des$get_w())
	inf = InferenceContinOLS$new(des, model_formula = ~ x2)
	expect_error(
		inf$compute_bootstrap_confidence_interval(B = 10, type = "percentile", show_progress = FALSE,
			reimpute_missing_vals_each_resample = TRUE),
		"reimpute_missing_vals_each_resample = TRUE needs"
	)
	expect_true(all(is.finite(inf$compute_bootstrap_confidence_interval(B = 10, type = "percentile", show_progress = FALSE))))
})

test_that("reimpute_missing_vals_each_resample must be a flag", {
	inf = make_reimpute_case()
	expect_error(inf$compute_bootstrap_two_sided_pval(B = 10, show_progress = FALSE, reimpute_missing_vals_each_resample = NA))
})
