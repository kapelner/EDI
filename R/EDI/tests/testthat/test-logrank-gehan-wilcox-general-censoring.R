library(testthat)
library(EDI)

# interval_censored_survival_response.md TODO-7: interval::ictest() dispatch
# for InferenceSurvivalLogRank (scores = "logrank1") and
# InferenceSurvivalGehanWilcox (scores = "wmw"). Both are pure two-sample
# tests (no covariate adjustment), which is exactly what ictest() supports --
# confirmed against ictest()'s formula/default method signatures before
# writing this dispatch (same check TODO-6 did for icenReg).

make_right_censored_design = function(seed, n = 150L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.15 * exp(0.4 * w))
	dead = rbinom(n, 1, 0.75)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	des
}

make_interval_censored_design = function(seed, n = 300L, g = 0.5){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	true_time = rexp(n, rate = 0.15 * exp(0.4 * w))
	y_L = floor(true_time / g) * g
	y_R = y_L + g
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	list(des = des, w = w, y_L = y_L, y_R = y_R)
}

test_that("InferenceSurvivalLogRank is unaffected by the general-censoring dispatch on exact/right-censored data", {
	des = make_right_censored_design(seed = 3001L)
	inf = InferenceSurvivalLogRank$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_false(isTRUE(priv$has_general_censoring))
	est = inf$compute_estimate()
	pv = inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()
	expect_true(is.finite(est))
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("InferenceSurvivalGehanWilcox is unaffected by the general-censoring dispatch on exact/right-censored data", {
	des = make_right_censored_design(seed = 3002L)
	inf = InferenceSurvivalGehanWilcox$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_false(isTRUE(priv$has_general_censoring))
	est = inf$compute_estimate()
	pv = inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(est))
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("InferenceSurvivalLogRank matches direct interval::ictest() under interval censoring", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 3003L)
	inf = InferenceSurvivalLogRank$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(isTRUE(priv$has_general_censoring))

	est = inf$compute_estimate()
	pv = inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()
	ci = inf$compute_asymp_confidence_interval()

	fit_direct = interval::ictest(setup$y_L, setup$y_R, setup$w, scores = "logrank1")
	expect_equal(est, as.numeric(fit_direct$estimate))
	expect_equal(pv, as.numeric(fit_direct$p.value))
	expect_true(all(is.finite(ci)))
})

test_that("InferenceSurvivalGehanWilcox matches direct interval::ictest() under interval censoring", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 3004L)
	inf = InferenceSurvivalGehanWilcox$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(isTRUE(priv$has_general_censoring))

	est = inf$compute_estimate()
	pv = inf$compute_asymp_two_sided_pval()
	ci = inf$compute_asymp_confidence_interval()

	fit_direct = interval::ictest(setup$y_L, setup$y_R, setup$w, scores = "wmw")
	expect_equal(est, as.numeric(fit_direct$estimate))
	expect_equal(pv, as.numeric(fit_direct$p.value))
	expect_true(all(is.finite(ci)))
})

test_that("guards fire under general censoring for LogRank and GehanWilcox", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 3005L, n = 100L)
	inf_lr = InferenceSurvivalLogRank$new(setup$des, verbose = FALSE)
	inf_gw = InferenceSurvivalGehanWilcox$new(setup$des, verbose = FALSE)

	expect_error(inf_lr$compute_estimate_with_bootstrap_weights(rep(1, 100L)), "not yet supported")
	expect_error(inf_gw$compute_estimate_with_bootstrap_weights(rep(1, 100L)), "not yet supported")
	expect_error(inf_lr$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.1), "not yet implemented")
	expect_error(inf_gw$compute_asymp_two_sided_pval(delta = 0.1), "not yet implemented")
})

test_that("InferenceSurvivalKMDiff now accepts interval-censored data (TODO-7 predates, TODO-8 supersedes)", {
	skip_if_not_installed("interval")
	# At the time TODO-7 landed, InferenceSurvivalKMDiff had no interval-censoring
	# support at all and this test correctly expected construction to error. TODO-8
	# later gave it a real interval::icfit()-based dispatch (supports_interval_or_
	# left_censored_data() = TRUE) -- construction now succeeds by design; full
	# coverage of that dispatch lives in test-km-rmst-general-censoring.R.
	setup = make_interval_censored_design(seed = 3006L, n = 80L)
	inf = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
})
