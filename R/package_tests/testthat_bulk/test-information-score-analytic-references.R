library(testthat)
library(EDI)

test_that("information variances and correlated score tests agree with Schur complements", {
	set.seed(1210)
	d = DesignFixedBernoulli$new(n = 16L, response_type = "continuous", seed = 1210L)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(16)))
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(16))
	p = InferenceContinOLS$new(d)$.__enclos_env__$private
	M = matrix(c(2, .4, .2, .4, 3, .5, .2, .5, 4), 3)
	score = c(.7, -1.2, 2)
	for (j in 1:3) {
		nuisance = setdiff(1:3, j)
		efficient = M[j, j] - M[j, nuisance, drop = FALSE] %*%
			solve(M[nuisance, nuisance, drop = FALSE], M[nuisance, j, drop = FALSE])
		expect_equal(p$compute_variance_from_information_matrix(M, j), 1 / as.numeric(efficient))
		expected = pchisq(score[j]^2 / as.numeric(efficient), 1, lower.tail = FALSE)
		expect_equal(p$score_test_with_ridge_fallback(score, M, j), expected, tolerance = 1e-7)
	}
	perm = c(3, 1, 2)
	expect_equal(p$score_test_with_ridge_fallback(score[perm], M[perm, perm], 1L),
		p$score_test_with_ridge_fallback(score, M, 3L))
	expect_equal(p$score_test_with_ridge_fallback(-score, M, 2L),
		p$score_test_with_ridge_fallback(score, M, 2L))
	expect_equal(p$score_test_with_ridge_fallback(2 * score, 4 * M, 2L),
		p$score_test_with_ridge_fallback(score, M, 2L))
	expect_equal(p$score_test_with_ridge_fallback(2, matrix(4), 1L), pchisq(1, 1, lower.tail = FALSE))
	expect_true(is.na(p$score_test_with_ridge_fallback(2, matrix(-1), 1L)))
})

test_that("likelihood-ratio and restricted-gradient statistics match scalar analytic references", {
	for (increase in c(0, .1, 2, 10)) {
		lr = EDI:::likelihood_ratio_test_from_negloglik_cpp(5, 5 + increase, 1L)
		expect_equal(lr$statistic, 2 * increase)
		expect_equal(lr$p_value, pchisq(2 * increase, 1, lower.tail = FALSE))
	}
	for (delta in c(-1, 0, 1)) {
		# Quadratic NLL (theta - 2)^2 / 2 has restricted likelihood score 2 - delta.
		res = EDI:::gradient_test_from_restricted_score_cpp(c(0, 2 - delta), 2, delta, 2L)
		expect_equal(res$statistic, (2 - delta)^2)
		expect_equal(res$p_value, pchisq((2 - delta)^2, 1, lower.tail = FALSE))
	}
})
