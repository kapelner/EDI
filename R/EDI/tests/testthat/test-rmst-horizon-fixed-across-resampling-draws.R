library(testthat)
library(EDI)

# v1.0.6-TODO-69: the default RMST horizon (min of the arms' max follow-up) was
# recomputed in every randomization draw, so the null draws integrated to a different,
# assignment-dependent tau than the observed statistic (fixture: observed 39 vs null
# 162-180) and the randomization test had power below alpha at a strong effect. The
# default horizon is now fixed from the observed data and carried into every draw.

make_rc_design = function(seed, n = 60L, effect = 0.8){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.15 * exp(-effect * w))
	dead = rbinom(n, 1, 0.75)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), ifelse(dead == 1, NA_real_, y), ifelse(dead == 1, NA_real_, Inf))
	des
}

test_that("default horizon is fixed from the observed data; observed estimate and SE unchanged", {
	des = make_rc_design(11L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	expect_null(p$rmst_tau)
	tau_obs = min(max(p$y[p$w == 1]), max(p$y[p$w == 0]))
	expect_equal(p$rmst_observed_tau, tau_obs)
	expect_identical(inf$compute_estimate(), get_survival_stat_diff(p$y, p$dead, p$w, "restricted_mean"))
	expect_identical(p$cached_values$s_beta_hat_T, get_restricted_mean_se_diff(p$y, p$dead, p$w))
	# a user tau takes precedence and leaves the observed default unset
	inf_u = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 0.5 * tau_obs)
	expect_null(inf_u$.__enclos_env__$private$rmst_observed_tau)
	expect_equal(inf_u$.__enclos_env__$private$rmst_horizon(), 0.5 * tau_obs)
})

test_that("randomization draws use the observed horizon, not each draw's arms", {
	des = make_rc_design(12L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	tau_obs = p$rmst_observed_tau
	set.seed(3)
	perms = p$generate_permutations(30L)
	got = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 30L, permutations = perms, show_progress = FALSE))
	ref = vapply(seq_len(ncol(perms$w_mat)), function(b){
		wb = perms$w_mat[, b]
		over = p$y > tau_obs
		get_survival_stat_diff(pmin(p$y, tau_obs), ifelse(over, 0L, p$dead), wb, "restricted_mean")
	}, numeric(1))
	expect_equal(got, ref, tolerance = 1e-10)
	# and differs from the old per-draw horizon for at least some draws
	old = vapply(seq_len(ncol(perms$w_mat)), function(b) get_survival_stat_diff(p$y, p$dead, perms$w_mat[, b], "restricted_mean"), numeric(1))
	expect_false(isTRUE(all.equal(got, old)))
})

test_that("bootstrap and jackknife draws hold the observed horizon (worker clones carry it)", {
	des = make_rc_design(13L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	tau_obs = p$rmst_observed_tau
	worker = inf$duplicate()
	expect_equal(worker$.__enclos_env__$private$rmst_horizon(), tau_obs)
	set.seed(4)
	bd = suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = 25L, show_progress = FALSE))
	expect_true(mean(is.finite(bd)) > 0.8)
	# no bootstrap estimate can exceed the horizon in magnitude
	expect_true(all(abs(bd[is.finite(bd)]) <= tau_obs + 1e-8))
})

test_that("interval-censored: fixed observed horizon in randomization draws restores the p-value", {
	skip_if_not_installed("interval")
	set.seed(21)
	n = 40L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	tt = rexp(n, rate = ifelse(w == 1, 0.02, 0.2))
	y_L = floor(tt)
	y_R = ifelse(tt > 25 & w == 1, Inf, y_L + 1)
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	iv = turnbull_effective_interval(p$y_L, p$y_R, p$y)
	tau_obs = min(turnbull_arm_horizon(iv$y_L[w == 1], iv$y_R[w == 1]), turnbull_arm_horizon(iv$y_L[w == 0], iv$y_R[w == 0]))
	expect_equal(p$rmst_observed_tau, tau_obs)
	expect_identical(inf$compute_estimate(), turnbull_npmle_stat_diff(p$y_L, p$y_R, w, "restricted_mean", y = p$y))
	set.seed(5)
	pv = suppressWarnings(inf$compute_rand_two_sided_pval(r = 99L, show_progress = FALSE))
	expect_lt(pv, 0.05)
})
