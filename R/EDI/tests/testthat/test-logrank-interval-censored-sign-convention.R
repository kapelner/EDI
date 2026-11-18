library(testthat)
library(EDI)

# v1.0.6-TODO-117: interval::ictest() orders a two-level group by first
# appearance, so its estimate/Z are "arm in row 1 minus the other arm". On
# interval-censored data InferenceSurvivalLogRank used them unoriented, so the
# point estimate's sign depended on which arm subject 1 was in, and bootstrap
# draws (which reshuffle row 1) had an essentially random sign.

make_icen_logrank_design = function(seed, n = 120L, g = 0.5, first_arm = 0L){
	# draw until subject 1 is in the requested arm, so the test exercises the
	# ordering that used to flip the sign
	repeat {
		set.seed(seed)
		X = data.frame(x1 = rnorm(n))
		des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w = des$get_w()
		if (w[1L] == first_arm) break
		seed = seed + 1L
	}
	true_time = rexp(n, rate = 0.15 * exp(1.2 * w))
	y_L = floor(true_time / g) * g
	y_R = y_L + g
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	list(des = des, w = w, y_L = y_L, y_R = y_R)
}

test_that("ictest_treatment_minus_control_sign orients by arm, not by row order", {
	expect_identical(EDI:::ictest_treatment_minus_control_sign(list(U = c(`1` = 2, `0` = -2))), 1)
	expect_identical(EDI:::ictest_treatment_minus_control_sign(list(U = c(`0` = -2, `1` = 2))), -1)
	expect_identical(EDI:::ictest_treatment_minus_control_sign(list(U = c(a = 1, b = 2, c = 3))), NA_real_)
})

test_that("InferenceSurvivalLogRank interval-censored estimate is treatment minus control whichever arm comes first", {
	skip_if_not_installed("interval")
	for (first_arm in c(0L, 1L)) {
		setup = make_icen_logrank_design(seed = 11700L, first_arm = first_arm)
		inf = InferenceSurvivalLogRank$new(setup$des, verbose = FALSE)
		expect_true(isTRUE(inf$.__enclos_env__$private$has_general_censoring))
		est = inf$compute_estimate()
		fit = interval::ictest(setup$y_L, setup$y_R, setup$w, scores = "logrank1")
		t_minus_c = mean(fit$scores[setup$w == 1]) - mean(fit$scores[setup$w == 0])
		expect_equal(est, t_minus_c, tolerance = 1e-10)
		# treated have the higher hazard, so they score higher (earlier events)
		expect_gt(est, 0)
		expect_equal(
			inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(),
			as.numeric(fit$p.value)
		)
	}
})

test_that("InferenceSurvivalLogRank interval-censored bootstrap draws keep the estimate's sign under a strong effect", {
	skip_if_not_installed("interval")
	setup = make_icen_logrank_design(seed = 11710L, first_arm = 0L)
	inf = InferenceSurvivalLogRank$new(setup$des, verbose = FALSE)
	est = inf$compute_estimate()
	set.seed(1)
	bd = inf$approximate_bootstrap_distribution_beta_hat_T(B = 60)
	bd = bd[is.finite(bd)]
	expect_gt(length(bd), 50L)
	# before the fix about half the draws had the wrong sign
	expect_gt(mean(sign(bd) == sign(est)), 0.95)
})
