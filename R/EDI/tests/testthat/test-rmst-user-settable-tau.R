library(testthat)
library(EDI)

# TODO-108: InferenceSurvivalRestrictedMeanDiff(tau =) user-settable horizon.

make_rmst_design = function(seed, n = 120L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.15 * exp(0.4 * w))
	dead = rbinom(n, 1, 0.75)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), ifelse(dead == 1, NA_real_, y), ifelse(dead == 1, NA_real_, Inf))
	des
}

# Independent reference: area under the survfit step curve up to tau.
ref_rmst = function(y, dead, tau){
	fit = survival::survfit(survival::Surv(y, dead) ~ 1)
	tt = c(0, fit$time); ss = c(1, fit$surv)
	area = 0
	for (i in seq_along(tt)) {
		if (tt[i] >= tau) break
		end = if (i < length(tt)) min(tt[i + 1L], tau) else tau
		area = area + ss[i] * (end - tt[i])
	}
	area
}
ref_diff = function(inf, tau){
	p = inf$.__enclos_env__$private
	ref_rmst(p$y[p$w == 1], p$dead[p$w == 1], tau) - ref_rmst(p$y[p$w == 0], p$dead[p$w == 0], tau)
}

test_that("default (tau unset) is unchanged: shared min-of-arm-maxima horizon", {
	des = make_rmst_design(1L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	expect_null(p$rmst_tau)
	tau_def = min(max(p$y[p$w == 1]), max(p$y[p$w == 0]))
	expect_equal(inf$compute_estimate(), ref_diff(inf, tau_def), tolerance = 1e-10)
	expect_equal(inf$compute_estimate(),
		get_survival_stat_diff(p$y, p$dead, p$w, "restricted_mean"), tolerance = 1e-12)
})

test_that("tau is honored: estimate equals an independent survfit RMST at tau", {
	des = make_rmst_design(2L)
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p0 = inf0$.__enclos_env__$private
	tau_max = min(max(p0$y[p0$w == 1]), max(p0$y[p0$w == 0]))
	for (tau in c(2, 5, 0.5 * tau_max, tau_max)) {
		inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau)
		expect_equal(inf$compute_estimate(), ref_diff(inf, tau), tolerance = 1e-10)
	}
	inf5 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 5)
	expect_false(isTRUE(all.equal(inf5$compute_estimate(), inf0$compute_estimate())))
	# tau == default maximum reproduces the default exactly
	inf_max = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau_max)
	expect_equal(inf_max$compute_estimate(), inf0$compute_estimate(), tolerance = 1e-12)
})

test_that("Greenwood SE honors tau and matches the native kernel on pre-truncated data", {
	des = make_rmst_design(3L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 4)
	inf$compute_estimate()
	se = inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	p = inf$.__enclos_env__$private
	over = p$y > 4
	se_ref = get_restricted_mean_se_diff(pmin(p$y, 4), ifelse(over, 0L, p$dead), p$w)
	expect_equal(se, se_ref, tolerance = 1e-12)
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	inf0$compute_estimate()
	expect_false(isTRUE(all.equal(se, inf0$.__enclos_env__$private$cached_values$s_beta_hat_T)))
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	ci = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci)))
})

test_that("Bayesian-bootstrap weighted path honors tau (unit weights reproduce the point estimate)", {
	des = make_rmst_design(4L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 4)
	p = inf$.__enclos_env__$private
	est = inf$compute_estimate()
	wt = p$weighted_survival_stat_diff(rep(1, length(p$y)), "restricted_mean")
	expect_equal(wt, est, tolerance = 1e-8)
})

test_that("randomization p-value uses tau through the generic path", {
	des = make_rmst_design(5L, n = 60L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 3)
	pv = suppressWarnings(inf$compute_rand_two_sided_pval(r = 49L, show_progress = FALSE))
	expect_true(is.finite(pv) && pv > 0 && pv <= 1)
	p = inf$.__enclos_env__$private
	expect_null(p$compute_fast_rand_bootstrap_distr(p$y, list(), 0, "none"))
})

test_that("invalid tau errors", {
	des = make_rmst_design(6L)
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p0 = inf0$.__enclos_env__$private
	tau_max = min(max(p0$y[p0$w == 1]), max(p0$y[p0$w == 0]))
	for (bad in list(0, -1, NA_real_, Inf, c(1, 2), "a", NaN)) {
		expect_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = bad), "tau")
	}
	expect_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau_max * 1.01), "exceeds")
})

test_that("Turnbull path integrates exactly to tau", {
	skip_if_not_installed("interval")
	set.seed(7)
	n = 200L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	tt = rexp(n, rate = 0.15 * exp(0.4 * w))
	y_L = floor(tt / 0.5) * 0.5
	y_R = y_L + 0.5
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 3)
	est = inf$compute_estimate()
	ref_arm = function(idx){
		fit = interval::icfit(y_L[idx], y_R[idx])
		o = order(fit$intmap[1, ]); L = fit$intmap[1, o]; s = 1 - cumsum(fit$pf[o])
		t_ = c(0, L); s_ = c(1, s); k = t_ < 3
		sum(s_[k] * (c(t_[k][-1L], 3) - t_[k]))
	}
	expect_equal(est, ref_arm(w == 1) - ref_arm(w == 0), tolerance = 1e-10)
	expect_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 1e6), "exceeds")
})
