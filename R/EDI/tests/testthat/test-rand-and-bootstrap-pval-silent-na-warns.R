library(testthat)
library(EDI)

# v1.0.6-TODO-136 and v1.0.6-TODO-145: p-values that returned a silent NA now warn once
# (edi_procedure_na_warning, with the recorded reason), values unchanged:
#  - randomization p-value with too few finite null draws (randomization_too_few_finite_estimates),
#    also via the randomization-bootstrap p-value that shares the helper;
#  - bootstrap p-value: bootstrap_too_few_finite_estimates (na.rm = TRUE),
#    bootstrap_extreme_finite_estimates, bootstrap_pvalue_unavailable (BCa);
#  - Bayesian-bootstrap p-value: ..._too_few_finite_estimates, ..._extreme_finite_estimates.
# The randomization CI searches evaluate the p-value once per delta: those per-evaluation
# warnings are muffled and the CI warns once itself when it ends NA. Draws are stubbed.

make_cont_design = function(){
	set.seed(3); n = 60
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	des
}

stub_method = function(env, name, f){
	unlockBinding(name, env)
	assign(name, f, envir = env)
	lockBinding(name, env)
}

collect_na_warnings = function(expr){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

expect_one_na_warning = function(res, procedure, reason){
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, procedure)
	expect_identical(res$na[[1L]]$reason, reason)
	expect_true(is.na(res$value))
}

test_that("randomization p-value with too few finite draws warns once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_randomization_distribution_beta_hat_T",
		function(r = 501, ...) c(rnorm(5), rep(NA_real_, r - 5)))
	res = collect_na_warnings(inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE))
	expect_one_na_warning(res, "randomization p-value", "randomization_too_few_finite_estimates")
	# enough finite draws: finite and silent
	inf2 = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf2, "approximate_randomization_distribution_beta_hat_T",
		function(r = 501, ...) c(rnorm(20), rep(NA_real_, r - 20)))
	res2 = collect_na_warnings(inf2$compute_rand_two_sided_pval(r = 101, show_progress = FALSE))
	expect_length(res2$na, 0L)
	expect_true(is.finite(res2$value))
})

test_that("the p-value helper is silent while a resampling operation is active", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "rand"
	res = collect_na_warnings(priv$compute_two_sided_randomization_pval_from_t0s(c(1, 2, rep(NA_real_, 99)), 0.5))
	expect_length(res$na, 0L)
	expect_true(is.na(res$value))
})

test_that("randomization CI search does not warn per p-value evaluation; an NA CI warns once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_randomization_distribution_beta_hat_T",
		function(r = 501, ...) c(rnorm(5), rep(NA_real_, r - 5)))
	# count p-value evaluations (the null draws may be computed once and shifted per delta)
	priv = inf$.__enclos_env__$private
	orig_helper = priv$compute_two_sided_randomization_pval_from_t0s
	n_calls = 0L
	stub_method(priv, "compute_two_sided_randomization_pval_from_t0s", function(...){
		n_calls <<- n_calls + 1L
		orig_helper(...)
	})
	res = collect_na_warnings(inf$compute_rand_confidence_interval(r = 101, show_progress = FALSE,
		ci_search_control = list(fallback = "na", pval_cache_enable = FALSE)))
	expect_gt(n_calls, 1L) # the search really evaluated the p-value several times
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "randomization confidence interval")
	expect_true(all(is.na(res$value)))
})

test_that("randomization CI that succeeds is silent even when some deltas give NA p-values", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_randomization_distribution_beta_hat_T", function(r = 501, delta = 0, ...){
		if (abs(delta) > 0.3) c(rnorm(5), rep(NA_real_, r - 5)) else rnorm(r, delta)
	})
	res = collect_na_warnings(inf$compute_rand_confidence_interval(r = 101, show_progress = FALSE))
	expect_length(res$na, 0L)
})

test_that("bootstrap p-value: too few finite (na.rm = TRUE) and extreme estimates warn once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_bootstrap_distribution_beta_hat_T",
		function(B = 501, ...) c(rnorm(3), rep(NA_real_, B - 3)))
	res = collect_na_warnings(inf$compute_bootstrap_two_sided_pval(B = 51, na.rm = TRUE, show_progress = FALSE))
	expect_one_na_warning(res, "bootstrap p-value", "bootstrap_too_few_finite_estimates")
	for (type in c("percentile", "symmetric")) {
		stub_method(inf, "approximate_bootstrap_distribution_beta_hat_T",
			function(B = 501, ...) c(1e12, rnorm(B - 1)))
		res = collect_na_warnings(inf$compute_bootstrap_two_sided_pval(B = 51, type = type, show_progress = FALSE))
		expect_one_na_warning(res, "bootstrap p-value", "bootstrap_extreme_finite_estimates")
	}
	# ordinary draws: finite and silent
	stub_method(inf, "approximate_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rnorm(B, 1))
	res = collect_na_warnings(inf$compute_bootstrap_two_sided_pval(B = 51, type = "percentile", show_progress = FALSE))
	expect_length(res$na, 0L)
	expect_true(is.finite(res$value))
})

test_that("BCa bootstrap p-value that is unavailable warns once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	stub_method(inf, "approximate_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rnorm(B, 1))
	stub_method(priv, "pval_bca", function(boot_distr, est, delta) stop("stub failure"))
	res = collect_na_warnings(inf$compute_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE))
	expect_one_na_warning(res, "bootstrap p-value", "bootstrap_pvalue_unavailable")
	stub_method(priv, "pval_bca", function(boot_distr, est, delta) NA_real_)
	res = collect_na_warnings(inf$compute_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE))
	expect_one_na_warning(res, "bootstrap p-value", "bootstrap_pvalue_unavailable")
})

test_that("Bayesian-bootstrap p-value: too few finite and extreme estimates warn once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T",
		function(B = 501, ...) c(rnorm(3), rep(NA_real_, B - 3)))
	res = collect_na_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, na.rm = TRUE, show_progress = FALSE))
	expect_one_na_warning(res, "Bayesian bootstrap p-value", "bayesian_bootstrap_too_few_finite_estimates")
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T",
		function(B = 501, ...) c(1e12, rnorm(B - 1)))
	res = collect_na_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, show_progress = FALSE))
	expect_one_na_warning(res, "Bayesian bootstrap p-value", "bayesian_bootstrap_extreme_finite_estimates")
})
