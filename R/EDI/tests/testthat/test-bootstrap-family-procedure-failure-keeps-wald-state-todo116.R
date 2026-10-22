context("TODO-116: bootstrap-family procedure failures keep the Wald state")

# A failing resampling procedure (nonparametric / Bayesian / parametric / LR
# bootstrap, randomization bootstrap and its CI) returns NA but must not wipe
# the valid Wald estimate/SE or flip is_nonestimable(); the reason is recorded
# in cached_values$procedure_failure_reason[[procedure]]. A real primary-fit
# failure must still mark the object nonestimable.

fx_bf_116 = function(seed = 1L, n = 30L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n, sd = 0.5))
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores = 1L
	list(inf = inf, p = inf$.__enclos_env__$private)
}

fx_lin_116 = function(seed = 1L, n = 40L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf = InferenceContinLin$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

wald_bf_116 = function(f){
	list(
		ci = unname(f$inf$compute_asymp_confidence_interval()),
		pval = f$inf$compute_asymp_two_sided_pval(),
		se = f$p$cached_values$s_beta_hat_T,
		est = f$p$cached_values$beta_hat_T
	)
}

expect_wald_intact_bf_116 = function(f, before, procedure, reason = NULL){
	expect_false(f$inf$is_nonestimable("any"))
	expect_null(f$inf$get_nonestimable_reason())
	pf = f$p$cached_values$procedure_failure_reason[[procedure]]
	expect_true(is.character(pf) && nzchar(pf))
	if (!is.null(reason)) expect_identical(pf, reason)
	expect_identical(wald_bf_116(f), before)
}

test_that("nonparametric bootstrap p-value failure leaves the Wald state intact", {
	f = fx_bf_116()
	before = wald_bf_116(f)
	expect_true(is.finite(before$se))
	unlockBinding("bootstrap_estimates_extreme", f$p)
	f$p$bootstrap_estimates_extreme = function(...) TRUE
	expect_true(is.na(f$inf$compute_bootstrap_two_sided_pval(B = 21L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "bootstrap", "bootstrap_extreme_finite_estimates")
})

test_that("nonparametric bootstrap CI failure (missing_bootstrap_ci) leaves the Wald state intact", {
	f = fx_bf_116(seed = 2L)
	before = wald_bf_116(f)
	ci = f$p$missing_bootstrap_ci(0.05, "bootstrap_too_few_finite_estimates", stage = "estimate")
	expect_true(all(is.na(ci)))
	expect_wald_intact_bf_116(f, before, "bootstrap", "bootstrap_too_few_finite_estimates")
	ci2 = f$p$missing_bootstrap_ci(0.05, "bootstrap_unstable_studentized_interval", stage = "se")
	expect_true(all(is.na(ci2)))
	expect_wald_intact_bf_116(f, before, "bootstrap", "bootstrap_unstable_studentized_interval")
})

test_that("BCa (non-block) failures leave the Wald state intact", {
	f = fx_bf_116(seed = 3L)
	before = wald_bf_116(f)
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", f$p)
	f$p$approximate_jackknife_distribution_beta_hat_T_private = function(unit = "auto") 1
	boot = rnorm(100, 0.5, 0.3)
	expect_true(all(is.na(f$p$ci_bca(boot, 0.05, 0.5))))
	expect_wald_intact_bf_116(f, before, "bootstrap", "bootstrap_bca_jackknife_unavailable")
	expect_true(is.na(f$p$pval_bca(boot, 0.5, 0.2)))
	expect_wald_intact_bf_116(f, before, "bootstrap", "bootstrap_bca_jackknife_unavailable")
})

test_that("Bayesian bootstrap p-value failure leaves the Wald state intact", {
	f = fx_bf_116(seed = 4L)
	before = wald_bf_116(f)
	unlockBinding("bootstrap_estimates_extreme", f$p)
	f$p$bootstrap_estimates_extreme = function(...) TRUE
	expect_true(is.na(f$inf$compute_bayesian_bootstrap_two_sided_pval(B = 21L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "bayesian_bootstrap", "bayesian_bootstrap_extreme_finite_estimates")
})

test_that("Bayesian bootstrap CI failure leaves the Wald state intact", {
	f = fx_bf_116(seed = 5L)
	before = wald_bf_116(f)
	expect_true(all(is.na(f$p$missing_bootstrap_ci(0.05, "bayesian_bootstrap_extreme_confidence_interval", stage = "se"))))
	expect_wald_intact_bf_116(f, before, "bayesian_bootstrap", "bayesian_bootstrap_extreme_confidence_interval")
})

test_that("parametric bootstrap estimate / CI / p-value failures leave the Wald state intact", {
	f = fx_lin_116()
	before = wald_bf_116(f)
	unlockBinding("run_param_bootstrap_estimate_batch", f$p)
	f$p$run_param_bootstrap_estimate_batch = function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))
	expect_true(is.na(f$inf$compute_param_bootstrap_estimate(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "param_bootstrap", "param_bootstrap_estimate_too_few_usable_replicates")
	expect_true(all(is.na(f$inf$compute_param_bootstrap_confidence_interval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE))))
	expect_wald_intact_bf_116(f, before, "param_bootstrap", "param_bootstrap_estimate_too_few_usable_replicates")
	expect_true(is.na(f$inf$compute_param_bootstrap_pval(delta = 0, B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "param_bootstrap", "param_bootstrap_estimate_too_few_usable_replicates")
})

test_that("LR-calibrated bootstrap p-value failure leaves the Wald state intact", {
	f = fx_lin_116(seed = 2L)
	before = wald_bf_116(f)
	unlockBinding("get_likelihood_test_spec", f$p)
	f$p$get_likelihood_test_spec = function(...) NULL
	expect_true(is.na(f$inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "lik_ratio_bootstrap", "lik_ratio_bootstrap_spec_unavailable")
})

test_that("randomization-bootstrap p-value failure leaves the Wald state intact", {
	f = fx_bf_116(seed = 6L)
	before = wald_bf_116(f)
	unlockBinding("compute_treatment_estimate_during_randomization_inference", f$p)
	f$p$compute_treatment_estimate_during_randomization_inference = function(...) NA_real_
	expect_true(is.na(f$inf$compute_rand_bootstrap_two_sided_pval(B = 25L, show_progress = FALSE)))
	expect_wald_intact_bf_116(f, before, "rand_bootstrap", "rand_bootstrap_observed_statistic_unavailable")
})

test_that("a primary-fit failure still marks the object nonestimable (not masked)", {
	# Wald estimate is invalid: the reason must go to the nonestimable state.
	f = fx_bf_116(seed = 7L)
	f$p$cached_values$beta_hat_T = NA_real_
	ci = f$p$missing_bootstrap_ci(0.05, "bootstrap_too_few_finite_estimates", stage = "estimate")
	expect_true(all(is.na(ci)))
	expect_true(f$inf$is_nonestimable("any"))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_too_few_finite_estimates")
	# Wald SE invalid (NA) with a finite estimate: also still primary.
	g = fx_bf_116(seed = 8L)
	g$p$cached_values$beta_hat_T = 0.3
	g$p$cached_values$s_beta_hat_T = NA_real_
	edi_record_procedure_failure = getFromNamespace("edi_record_procedure_failure", "EDI")
	edi_record_procedure_failure(g$inf, g$p, "bayesian_bootstrap_extreme_confidence_interval", "se")
	expect_true(g$inf$is_nonestimable("any"))
	expect_identical(g$inf$get_nonestimable_reason(), "bayesian_bootstrap_extreme_confidence_interval")
	# Already nonestimable beforehand: stays so.
	h = fx_bf_116(seed = 9L)
	h$p$cached_values$beta_hat_T = 0.3
	h$p$cached_values$s_beta_hat_T = 0.1
	h$p$cache_nonestimable_se("some_primary_failure")
	edi_record_procedure_failure(h$inf, h$p, "param_bootstrap_estimate_too_few_usable_replicates", "se")
	expect_true(h$inf$is_nonestimable("any"))
	# Primary-fit reasons are never reclassified, even with a valid Wald state.
	k = fx_bf_116(seed = 10L)
	wald_bf_116(k)
	k$p$missing_bootstrap_ci(0.05, "bayesian_bootstrap_original_estimate_unavailable", stage = "estimate")
	expect_true(k$inf$is_nonestimable("any"))
})

test_that("reason-to-procedure routing keeps primary-fit and out-of-scope reasons unmapped", {
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("subsampling_too_few_finite_estimates"), "subsampling")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("m_out_of_n_high_replicate_failure_rate"), "m_out_of_n")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("kk_count_gee_jackknife_wald_calibration_unavailable"), "jackknife")
	expect_null(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("subsampling_original_estimate_unavailable"))
	expect_null(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("jackknife_original_risk_ratio_unavailable"))
	# 2026-10-22 (TODO-116 lik-test stage): likelihood-test failures now map to the testing type;
	# a failed Wald test stays primary.
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("gradient_test_unavailable"), "gradient")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("lik_ratio_bartlett_exact_test_unavailable"), "lik_ratio_bartlett_exact")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("lik_ratio_confidence_interval_unavailable"), "lik_ratio")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("dep_cens_transform_score_pvalue_unstable"), "score")
	expect_null(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("wald_test_unavailable"))
	expect_null(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("test_inversion_confidence_interval_unavailable"))
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("rand_bootstrap_ci_bisection_failed"), "rand_bootstrap_ci")
	expect_identical(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("bootstrap_bca_unstable_bias"), "bootstrap")
	expect_null(getFromNamespace("edi_resampling_procedure_for_reason", "EDI")("bootstrap_original_standard_error_unavailable"))
})

test_that("randomization-bootstrap CI failures leave the Wald state intact", {
	f = fx_bf_116(seed = 11L)
	before = wald_bf_116(f)
	unlockBinding("closed_form_ci_from_affine_null_draws", f$p)
	f$p$closed_form_ci_from_affine_null_draws = function(...) numeric(1)
	expect_true(all(is.na(f$inf$compute_rand_bootstrap_confidence_interval(B = 25L, show_progress = FALSE, type = "percentile"))))
	expect_wald_intact_bf_116(f, before, "rand_bootstrap_ci", "rand_bootstrap_ci_closed_form_unavailable")

	g = fx_bf_116(seed = 12L)
	beforeg = wald_bf_116(g)
	unlockBinding("compute_rand_bootstrap_ci_affine_coefs", g$p)
	g$p$compute_rand_bootstrap_ci_affine_coefs = function(...) NULL
	unlockBinding("expand_rand_bootstrap_bound", g$p)
	g$p$expand_rand_bootstrap_bound = function(bound, est, ...) bound
	unlockBinding("invert_rand_bootstrap_test_bisection", g$p)
	g$p$invert_rand_bootstrap_test_bisection = function(...) NA_real_
	expect_true(all(is.na(g$inf$compute_rand_bootstrap_confidence_interval(B = 25L, show_progress = FALSE, type = "percentile"))))
	expect_wald_intact_bf_116(g, beforeg, "rand_bootstrap_ci", "rand_bootstrap_ci_bisection_failed")
})

test_that("a procedure failure on a fresh object (Wald not yet computed) still does not flag it nonestimable", {
	f = fx_lin_116(seed = 3L)
	unlockBinding("run_param_bootstrap_estimate_batch", f$p)
	f$p$run_param_bootstrap_estimate_batch = function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))
	expect_true(is.na(f$inf$compute_param_bootstrap_estimate(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)))
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(f$p$cached_values$procedure_failure_reason$param_bootstrap,
		"param_bootstrap_estimate_too_few_usable_replicates")
	expect_true(is.finite(f$inf$compute_asymp_confidence_interval()[1L]))
})

test_that("randomization-CI procedure failures (rand_ci_*) keep the Wald state", {
	f = fx_bf_116(seed = 3L)
	before = wald_bf_116(f)
	expect_identical(EDI:::edi_resampling_procedure_for_reason("rand_ci_search_bounds_failed"), "rand_ci")
	expect_identical(EDI:::edi_resampling_procedure_for_reason("rand_ci_bisection_failed"), "rand_ci")
	EDI:::edi_record_procedure_failure(f$inf, f$p, "rand_ci_bisection_failed", "se")
	expect_wald_intact_bf_116(f, before, "rand_ci", "rand_ci_bisection_failed")
})
