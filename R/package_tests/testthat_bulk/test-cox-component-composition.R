library(testthat)
library(EDI)

# interval_censored_survival_response.md TODO-13: InferenceSurvivalCoxPHRegr's
# migration to define_inference_class() only ever composed "CoxPartialLikelihood",
# leaving compute_rand_two_sided_pval, approximate_bootstrap_distribution_beta_hat_T,
# compute_bootstrap_two_sided_pval, approximate_bayesian_bootstrap_distribution_beta_hat_T,
# compute_bayesian_bootstrap_two_sided_pval, and compute_bayesian_bootstrap_confidence_interval
# entirely absent (is.function() FALSE). Fixed by composing
# components = c("BayesianBootstrap", "CoxPartialLikelihood") -- in that
# order, since resolve_component_dependencies() does a post-order DFS and
# combine_component_slot() merges resolved components via utils::modifyList(),
# so whichever subtree resolves LAST wins any name collision; CoxPartialLikelihood
# must resolve last so its own StandardModelCache-provided
# compute_treatment_estimate_during_randomization_inference() (which correctly
# threads through Cox's own generate_mod()) wins over the generic
# InferenceRand version. An earlier attempt at this fix got that ordering
# backwards and was reverted (see TODO-13's "Attempted fix, reverted" note);
# this test file exists so a repeat doesn't go unnoticed.

make_right_censored_design = function(seed, n = 90L){
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

test_that("InferenceSurvivalCoxPHRegr's randomization/bootstrap/jackknife family is present and functional", {
	des = make_right_censored_design(seed = 5001L)
	inf = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(5001L)
	expect_true(is.function(inf$compute_rand_two_sided_pval))
	rand_pv = inf$compute_rand_two_sided_pval(r = 31, show_progress = FALSE)
	expect_true(is.finite(rand_pv) && rand_pv >= 0 && rand_pv <= 1)

	boot_distr = inf$approximate_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE)
	expect_gt(mean(is.finite(boot_distr)), 0.8)
	expect_gt(sd(boot_distr[is.finite(boot_distr)]), 0)

	bboot_distr = inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE)
	expect_gt(mean(is.finite(bboot_distr)), 0.8)
	expect_gt(sd(bboot_distr[is.finite(bboot_distr)]), 0)
	bboot_pv = inf$compute_bayesian_bootstrap_two_sided_pval(B = 31, type = "percentile", show_progress = FALSE)
	expect_true(is.finite(bboot_pv))
	fresh_bboot = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	fresh_bboot$num_cores = 1L
	fresh_bboot$set_seed(5001L)
	expect_equal(bboot_distr, fresh_bboot$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE))
	expect_equal(bboot_pv, fresh_bboot$compute_bayesian_bootstrap_two_sided_pval(B = 31, type = "percentile", show_progress = FALSE))

	brt_pv = inf$compute_rand_bootstrap_two_sided_pval(B = 31, show_progress = FALSE)
	expect_true(is.finite(brt_pv))

	jack_est = as.numeric(inf$compute_jackknife_estimate())[1L]
	expect_true(is.finite(jack_est))
})

test_that("InferenceSurvivalKMDiff Bayesian bootstrap is unchanged after randomization and nonparametric bootstrap on the same object", {
	# TODO-42's alleged stale-worker failure was specifically reported for this
	# class as well as Cox.  Keep the fixture fully observed so this checks object
	# reuse rather than TODO-54's separate non-estimable-median behavior under
	# heavy censoring.
	set.seed(5042L)
	n = 90L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.15 * exp(0.4 * w))
	des$add_all_subject_responses(y)

	fresh = InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	fresh$num_cores = 1L
	fresh$set_seed(5042L)
	expected_distr = fresh$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE)
	expected_pval = fresh$compute_bayesian_bootstrap_two_sided_pval(B = 31, type = "percentile", show_progress = FALSE)

	reused = InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	reused$num_cores = 1L
	reused$set_seed(5042L)
	expect_true(is.finite(reused$compute_rand_two_sided_pval(r = 31, show_progress = FALSE)))
	boot_distr = reused$approximate_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE)
	expect_gt(mean(is.finite(boot_distr)), 0.8)
	observed_distr = reused$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 31, show_progress = FALSE)
	observed_pval = reused$compute_bayesian_bootstrap_two_sided_pval(B = 31, type = "percentile", show_progress = FALSE)

	expect_identical(observed_distr, expected_distr)
	expect_identical(observed_pval, expected_pval)
})

test_that("Cox's TODO-6 icenReg dispatch is unaffected by the component-composition fix", {
	skip_if_not_installed("icenReg")
	set.seed(5002L)
	n = 100L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	true_time = rexp(n, rate = 0.5 * exp(-0.6 * w))
	g = 0.5
	y_L = floor(true_time / g) * g
	y_R = y_L + g
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)

	inf = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	est = as.numeric(inf$compute_estimate())[1L]

	dat = data.frame(.icen_L = y_L, .icen_R = y_R, treatment = w, x1 = X$x1)
	fit_direct = icenReg::ic_sp(cbind(.icen_L, .icen_R) ~ treatment + x1, data = dat, model = "ph", bs_samples = 0)
	expect_equal(est, as.numeric(fit_direct$coefficients["treatment"]))
})

test_that("weighted_cox_bootstrap_surrogate_fit handles a NULL warm start (survival::coxph rejects init = NULL explicitly)", {
	set.seed(5003L)
	n = 100L
	time = rexp(n)
	dead = rbinom(n, 1, 0.7)
	X = matrix(rbinom(n, 1, 0.5), ncol = 1, dimnames = list(NULL, "treatment"))
	row_weights = rexp(n); row_weights = row_weights / mean(row_weights)
	fit = EDI:::weighted_cox_bootstrap_surrogate_fit(time, dead, X, row_weights, warm_start_beta = NULL)
	expect_false(is.null(fit))
	expect_true(is.finite(fit$beta_hat))
})
