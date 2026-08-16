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

test_that("InferenceSurvivalCoxPHRegr's randomization/bootstrap/jackknife family is present and functional", {
	des = make_right_censored_design(seed = 5001L)

	# Each capability tested on its own fresh object: a separate, pre-existing
	# bug in the shared reusable-worker infrastructure (reproduces identically
	# on InferenceSurvivalKMDiff, confirmed unrelated to this fix -- tracked
	# separately, not fixed here) leaves a stale Bayesian-bootstrap worker
	# context after a randomization or nonparametric-bootstrap call on the
	# *same* object, which is a distinct, out-of-scope issue from what this
	# test verifies (that the methods exist and work in isolation).
	inf_rand = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf_rand$num_cores = 1L
	expect_true(is.function(inf_rand$compute_rand_two_sided_pval))
	rand_pv = inf_rand$compute_rand_two_sided_pval(r = 51, show_progress = FALSE)
	expect_true(is.finite(rand_pv) && rand_pv >= 0 && rand_pv <= 1)

	inf_boot = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf_boot$num_cores = 1L
	boot_distr = inf_boot$approximate_bootstrap_distribution_beta_hat_T(B = 51, show_progress = FALSE)
	expect_gt(mean(is.finite(boot_distr)), 0.8)
	expect_gt(sd(boot_distr[is.finite(boot_distr)]), 0)

	inf_bboot = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf_bboot$num_cores = 1L
	bboot_distr = inf_bboot$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 51, show_progress = FALSE)
	expect_gt(mean(is.finite(bboot_distr)), 0.8)
	expect_gt(sd(bboot_distr[is.finite(bboot_distr)]), 0)
	bboot_pv = inf_bboot$compute_bayesian_bootstrap_two_sided_pval(B = 51, type = "percentile", show_progress = FALSE)
	expect_true(is.finite(bboot_pv))

	inf_brt = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf_brt$num_cores = 1L
	brt_pv = inf_brt$compute_rand_bootstrap_two_sided_pval(B = 51, show_progress = FALSE)
	expect_true(is.finite(brt_pv))

	inf_jack = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	inf_jack$num_cores = 1L
	jack_est = as.numeric(inf_jack$compute_jackknife_estimate())[1L]
	expect_true(is.finite(jack_est))
})

test_that("Cox's TODO-6 icenReg dispatch is unaffected by the component-composition fix", {
	skip_if_not_installed("icenReg")
	set.seed(5002L)
	n = 300L
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
