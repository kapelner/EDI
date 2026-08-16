library(testthat)
library(EDI)

# interval_censored_survival_response.md TODO-8: interval::icfit() (Turnbull
# NPMLE) dispatch for InferenceSurvivalKMDiff (median contrast) and
# InferenceSurvivalRestrictedMeanDiff (restricted-mean contrast). Neither
# icfit() nor the derived median/RMST statistics have a closed-form variance,
# so the variance/CI strategy is the nonparametric bootstrap fallback this
# package already has (s_beta_hat_T left NA under general censoring, which
# compute_asymp_confidence_interval()/compute_asymp_two_sided_pval() already
# route to compute_bootstrap_confidence_interval()/
# compute_bootstrap_two_sided_pval() whenever the SE is unavailable).

make_right_censored_design = function(seed, n = 150L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.5 * exp(0.4 * w))
	dead = rbinom(n, 1, 0.75)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	des
}

make_interval_censored_design = function(seed, n = 400L, g = 0.5){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	true_time = rexp(n, rate = 0.5 * exp(-0.6 * w))  # treatment prolongs survival
	y_L = floor(true_time / g) * g
	y_R = y_L + g
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	list(des = des, w = w, y_L = y_L, y_R = y_R)
}

test_that("InferenceSurvivalKMDiff is unaffected by the general-censoring dispatch on exact/right-censored data", {
	des = make_right_censored_design(seed = 4001L)
	inf = InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_false(isTRUE(priv$has_general_censoring))
	est = inf$compute_estimate()
	pv = inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(est))
	expect_true(is.finite(pv))
})

test_that("InferenceSurvivalRestrictedMeanDiff is unaffected by the general-censoring dispatch on exact/right-censored data", {
	des = make_right_censored_design(seed = 4002L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_false(isTRUE(priv$has_general_censoring))
	est = inf$compute_estimate()
	pv = inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(est))
	expect_true(is.finite(pv))
})

test_that("InferenceSurvivalKMDiff matches a direct interval::icfit()-based median contrast under interval censoring", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 4003L)
	inf = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(isTRUE(priv$has_general_censoring))

	est = inf$compute_estimate()
	expect_true(is.finite(est))
	expect_gt(est, 0)  # treatment prolongs survival in this simulation

	med_of = function(y_L, y_R) {
		fit = interval::icfit(y_L, y_R)
		surv_after = 1 - cumsum(fit$pf)
		idx = which(surv_after <= 0.5 + sqrt(.Machine$double.eps))[1L]
		(fit$intmap[1, idx] + fit$intmap[2, idx]) / 2
	}
	idx_t = setup$w == 1
	idx_c = setup$w == 0
	direct = med_of(setup$y_L[idx_t], setup$y_R[idx_t]) - med_of(setup$y_L[idx_c], setup$y_R[idx_c])
	expect_equal(est, direct)

	ci = inf$compute_bootstrap_confidence_interval(type = "percentile")
	expect_true(all(is.finite(ci)))
})

test_that("InferenceSurvivalRestrictedMeanDiff estimate is finite and sensible under interval censoring", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 4004L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(isTRUE(priv$has_general_censoring))

	est = inf$compute_estimate()
	expect_true(is.finite(est))
	expect_gt(est, 0)

	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
})

test_that("guards fire under general censoring for KMDiff and RestrictedMeanDiff", {
	skip_if_not_installed("interval")
	setup = make_interval_censored_design(seed = 4005L, n = 100L)
	inf_km = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	inf_rm = InferenceSurvivalRestrictedMeanDiff$new(setup$des, verbose = FALSE)

	expect_error(inf_km$compute_estimate_with_bootstrap_weights(rep(1, 100L)), "not yet supported")
	expect_error(inf_rm$compute_estimate_with_bootstrap_weights(rep(1, 100L)), "not yet supported")
	expect_error(inf_km$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(), "not supported")
})
