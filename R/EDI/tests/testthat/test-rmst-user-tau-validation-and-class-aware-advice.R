# v1.0.6-TODO-79: RMST leftovers from v1.0.6-TODO-69.
# (1) A user tau is validated against the same horizon rule as the default (under general censoring,
#     exact-event y values folded in as [y, y] count toward an arm's largest observed time), so a valid
#     tau is no longer rejected when an arm's largest time is an exact event.
# (2) Warnings that suggest other procedures name only procedures the class supports: RMST refuses
#     compute_rand_confidence_interval(), so neither the bootstrap "extreme interval" warning nor the
#     cluster-independence warning may suggest it for RMST.

interval_with_exact_max_design = function(){
	set.seed(2)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y_L = ifelse(w == 1, runif(n, 5, 30), runif(n, 1, 5))
	y_R = y_L + 5
	ys = rep(NA_real_, n)
	# One control's largest time is an exact event far beyond the control intervals.
	ic = which(w == 0)[1L]
	ys[ic] = 50
	y_L[ic] = NA_real_
	y_R[ic] = NA_real_
	des$add_all_subject_responses(ys, y_L, y_R)
	des
}

test_that("user tau validation counts exact-event y under general censoring", {
	skip_if_not_installed("interval")
	des = interval_with_exact_max_design()
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf0$.__enclos_env__$private
	expect_true(isTRUE(p$has_general_censoring))
	tau_default = p$rmst_observed_tau
	# The interval-only rule (exact y ignored) is far below the default horizon.
	expect_lt(min(p$rmst_arm_max_time(p$w == 1), p$rmst_arm_max_time(p$w == 0)), 10)
	expect_gt(tau_default, 30)
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 30)
	expect_equal(inf$.__enclos_env__$private$rmst_horizon(), 30)
	expect_true(is.finite(inf$compute_estimate()))
	# A user tau equal to the default horizon is accepted; past it is still refused.
	expect_no_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau_default))
	expect_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = tau_default + 1),
		"exceeds the smaller of the two arms")
})

test_that("user tau validation is unchanged under right censoring", {
	set.seed(5)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rexp(n, 0.2))
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p = inf0$.__enclos_env__$private
	arm_max = min(max(p$y[p$w == 1]), max(p$y[p$w == 0]))
	expect_no_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = arm_max))
	expect_error(InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = arm_max * 1.01),
		"exceeds the smaller of the two arms")
})

capture_procedure_na_message = function(inf){
	msg = NULL
	withCallingHandlers(
		inf$.__enclos_env__$private$missing_bootstrap_ci(0.05, "bootstrap_extreme_confidence_interval"),
		edi_procedure_na_warning = function(cond){ msg <<- conditionMessage(cond); invokeRestart("muffleWarning") }
	)
	msg
}

right_censored_survival_design = function(){
	set.seed(7)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rexp(n, 0.2))
	des
}

test_that("the extreme-interval warning suggests the randomization CI only when the class supports it", {
	des = right_censored_survival_design()
	rmst = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	expect_false(rmst$supports("randomization_ci")[[1L]])
	msg = capture_procedure_na_message(rmst)
	expect_match(msg, "stability cap", fixed = TRUE)
	expect_false(grepl("compute_rand_confidence_interval", msg, fixed = TRUE))

	set.seed(8)
	n = 30L
	des_c = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des_c$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_c$assign_w_to_all_subjects()
	des_c$add_all_subject_responses(rnorm(n))
	ols = InferenceContinOLS$new(des_c, verbose = FALSE)
	expect_true(ols$supports("randomization_ci")[[1L]])
	expect_match(capture_procedure_na_message(ols), "compute_rand_confidence_interval()", fixed = TRUE)
})

test_that("the cluster-independence warning names only procedures the class supports", {
	fake_cluster_private = function(){
		pv = new.env()
		pv$active_resampling_operation = NULL
		pv$des_obj = list(is_a_cluster_capable = function() TRUE)
		pv$cached_values = list()
		pv$cluster_independence_warned = character()
		pv
	}
	cluster_msg = function(inf){
		msg = NULL
		withCallingHandlers(
			edi_warn_cluster_independence_once(inf, fake_cluster_private(), "wald"),
			edi_cluster_independence_warning = function(cond){ msg <<- conditionMessage(cond); invokeRestart("muffleWarning") }
		)
		msg
	}
	rmst = InferenceSurvivalRestrictedMeanDiff$new(right_censored_survival_design(), verbose = FALSE)
	msg = cluster_msg(rmst)
	expect_match(msg, "compute_rand_two_sided_pval()", fixed = TRUE)
	expect_match(msg, "compute_bootstrap_confidence_interval()", fixed = TRUE)
	expect_match(msg, "unit = \"cluster\"", fixed = TRUE)
	expect_false(grepl("compute_rand_confidence_interval", msg, fixed = TRUE))

	set.seed(9)
	n = 30L
	des_c = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des_c$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_c$assign_w_to_all_subjects()
	des_c$add_all_subject_responses(rnorm(n))
	msg_ols = cluster_msg(InferenceContinOLS$new(des_c, verbose = FALSE))
	expect_match(msg_ols, "compute_rand_two_sided_pval() / compute_rand_confidence_interval()", fixed = TRUE)
	expect_match(msg_ols, ", or compute_jackknife_wald_two_sided_pval()", fixed = TRUE)
})
