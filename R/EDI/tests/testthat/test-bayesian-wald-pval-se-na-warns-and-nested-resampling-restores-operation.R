library(testthat)
library(EDI)

# v1.0.6-TODO-185 (follow-up of v1.0.6-TODO-165):
# (1) The Bayesian-bootstrap p-value's normal-approximation branch (type = "wald") returned a silent
#     NA when the draws have no spread (bayesian_bootstrap_standard_error_unavailable). It now warns
#     once with an edi_procedure_na_warning, and stays silent while a resampling operation is active.
# (2) Every resampling entry point (null draws, bootstrap / Bayesian / jackknife distributions, ...)
#     reset private$active_resampling_operation to NULL on exit instead of restoring the caller's
#     value, so an outer operation lost its flag after a nested call and later procedure-NA
#     warnings fired where they should be silent. They now restore the previous value.

make_cont_design = function(y_fun = function(w, n) rnorm(n) + w, n = 40){
	set.seed(3)
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(y_fun(des$get_w(), n))
	des
}

stub_method = function(env, name, f){
	unlockBinding(name, env)
	assign(name, f, envir = env)
	lockBinding(name, env)
}

collect_na_warnings = function(expr){
	warns = list()
	val = suppressMessages(withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	}))
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

bayes_wald_pval = function(inf) inf$compute_bayesian_bootstrap_two_sided_pval(B = 21, type = "wald", show_progress = FALSE)

test_that("Bayesian wald p-value with zero-spread draws warns once (stubbed draws)", {
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rep(0.5, B))
	res = collect_na_warnings(bayes_wald_pval(inf))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "Bayesian bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "bayesian_bootstrap_standard_error_unavailable")
})

test_that("Bayesian wald p-value with zero-spread draws warns once (real draws, y equal to w)", {
	# y = w exactly: every Dirichlet-weighted mean difference is 1, so the draws have sd 0.
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design(y_fun = function(w, n) as.numeric(w)))
	res = collect_na_warnings(bayes_wald_pval(inf))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "bayesian_bootstrap_standard_error_unavailable")
})

test_that("Bayesian wald p-value NA is silent inside a resampling operation", {
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rep(0.5, B))
	inf$.__enclos_env__$private$active_resampling_operation = "outer_operation"
	res = collect_na_warnings(bayes_wald_pval(inf))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
})

test_that("Bayesian wald p-value is unchanged when the draws have spread", {
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	inf$set_seed(11)
	res = collect_na_warnings(bayes_wald_pval(inf))
	expect_true(is.finite(res$value))
	expect_length(res$na, 0L)
})

test_that("resampling entry points restore the caller's active_resampling_operation", {
	des = make_cont_design()
	calls = list(
		rand_null_draws = function(inf) inf$approximate_randomization_distribution_beta_hat_T(r = 21, show_progress = FALSE),
		rand_bootstrap_null_draws = function(inf) inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE),
		bayesian_bootstrap = function(inf) inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE),
		nonparametric_bootstrap = function(inf) inf$approximate_bootstrap_distribution_beta_hat_T(B = 21, show_progress = FALSE),
		bootstrap_statistics = function(inf) inf$.__enclos_env__$private$approximate_bootstrap_statistics_beta_hat_T(B = 21, show_progress = FALSE),
		bayesian_statistics = function(inf) inf$.__enclos_env__$private$approximate_bayesian_bootstrap_statistics_beta_hat_T(B = 21, show_progress = FALSE),
		bayesian_jackknife = function(inf) inf$.__enclos_env__$private$approximate_bayesian_jackknife_distribution_beta_hat_T()
	)
	for (nm in names(calls)) {
		for (outer in list(NULL, "outer_operation")) {
			inf = InferenceAllSimpleAverageDiff$new(des)
			priv = inf$.__enclos_env__$private
			priv$active_resampling_operation = outer
			suppressWarnings(suppressMessages(calls[[nm]](inf)))
			expect_identical(priv$active_resampling_operation, outer, info = paste(nm, "outer =", format(outer)))
		}
	}
})

test_that("an outer operation stays silent after nested null draws", {
	# The rand-bootstrap p-value warns from compute_two_sided_randomization_pval_from_t0s() after
	# computing its null draws. With an outer operation active, that warning must stay silent; before
	# v1.0.6-TODO-185 the null draws cleared the flag and the warning fired.
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	priv = inf$.__enclos_env__$private
	stub_method(priv, "compute_two_sided_randomization_pval_from_t0s", function(t0s, t, ...){
		EDI:::edi_warn_procedure_na(inf, priv, procedure = "randomization-bootstrap p-value",
			reason = "randomization_too_few_finite_estimates")
		NA_real_
	})
	priv$active_resampling_operation = "outer_operation"
	res = collect_na_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = 21, show_progress = FALSE))
	expect_length(res$na, 0L)
	expect_identical(priv$active_resampling_operation, "outer_operation")
	# Top level (no outer operation) still warns.
	priv$active_resampling_operation = NULL
	res = collect_na_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = 21, show_progress = FALSE))
	expect_length(res$na, 1L)
})
