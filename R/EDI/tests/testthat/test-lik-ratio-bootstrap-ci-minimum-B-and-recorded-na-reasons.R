library(testthat)
library(EDI)

# v1.0.6-TODO-210 (owner decisions 2026-11-19):
# (1) the three LR-bootstrap CI NA reasons are recorded in procedure_failure_reason (under
#     "lik_ratio_bootstrap_ci", like "rand_bootstrap_ci"), still with exactly one warning;
# (2) the CI errors up front when B < 2 / alpha - 1: the bootstrap p-value it inverts is at
#     least 2 / (B + 1), so a smaller B can never reject at level alpha.

lin_fixture_210 = function(seed = 1L, n = 40L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf = InferenceContinLin$new(des, verbose = FALSE)
	inf$set_seed(7)
	inf
}

stub_lr_boot_pval_210 = function(inf, f){
	if (bindingIsLocked("compute_lik_ratio_bootstrap_two_sided_pval", inf)) unlockBinding("compute_lik_ratio_bootstrap_two_sided_pval", inf)
	inf$compute_lik_ratio_bootstrap_two_sided_pval = f
	invisible(inf)
}

collect_na_warnings_210 = function(expr){
	warns = list()
	val = suppressMessages(withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	}))
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

test_that("the minimum B is the smallest B with 2 / (B + 1) <= alpha", {
	min_B = getFromNamespace("edi_lik_ratio_bootstrap_ci_min_B", "EDI")
	for (alpha in c(0.01, 0.05, 0.1, 0.2, 0.3, 0.5, 0.9)) {
		b = min_B(alpha)
		expect_true(2 / (b + 1) <= alpha + 1e-12, info = alpha)
		if (b > 1L) expect_true(2 / b > alpha, info = alpha)
	}
	expect_identical(min_B(0.05), 39L)
	expect_identical(min_B(0.01), 199L)
	expect_identical(min_B(0.1), 19L)
	expect_identical(min_B(0.2), 9L)
})

test_that("B below the minimum errors up front, naming the minimum; B at the minimum runs", {
	inf = lin_fixture_210()
	expect_error(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 38, max_root_iterations = 0L),
		"B must be at least 39 for alpha = 0.05", fixed = TRUE)
	expect_error(inf$compute_lik_ratio_bootstrap_confidence_interval(alpha = 0.2, B = 8L, max_root_iterations = 0L),
		"B must be at least 9 for alpha = 0.2", fixed = TRUE)
	# The error comes before any bootstrap work.
	expect_null(inf$get_last_param_bootstrap_diagnostics())

	res = collect_na_warnings_210(inf$compute_lik_ratio_bootstrap_confidence_interval(alpha = 0.2, B = 9L, max_root_iterations = 0L))
	expect_length(res$value, 2L)
	expect_true(all(is.finite(res$value)))
	expect_lte(res$value[[1L]], res$value[[2L]])

	inf = lin_fixture_210()
	res = collect_na_warnings_210(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 39L, max_root_iterations = 0L))
	expect_length(res$value, 2L)
	expect_false(is.null(inf$get_last_param_bootstrap_diagnostics()))
})

test_that("the p-value has no alpha and keeps accepting small B", {
	inf = lin_fixture_210()
	p = suppressMessages(inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9L))
	expect_true(is.finite(p))
	expect_gte(p, 2 / 10)
})

test_that("the count-likelihood wrappers error up front too, before their nonestimable short-circuit", {
	set.seed(11)
	n = 40L
	des = DesignFixedBernoulli$new(response_type = "count", n = n, seed = 11L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.3 * des$get_w())))
	pois = InferenceCountPoisson$new(des, verbose = FALSE)
	expect_error(pois$compute_lik_ratio_bootstrap_confidence_interval(B = 29L),
		"B must be at least 39 for alpha = 0.05", fixed = TRUE)
	nb = InferenceCountNegBin$new(des, verbose = FALSE)
	expect_error(nb$compute_lik_ratio_bootstrap_confidence_interval(B = 29L),
		"B must be at least 39 for alpha = 0.05", fixed = TRUE)
})

expect_recorded_ci_reason_210 = function(inf, res, reason){
	expect_true(all(is.na(res$value)))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "parametric-bootstrap likelihood-ratio confidence interval")
	expect_identical(res$na[[1L]]$reason, reason)
	pf = inf$.__enclos_env__$private$cached_values$procedure_failure_reason
	expect_identical(pf[["lik_ratio_bootstrap_ci"]], reason)
	# A procedure failure, not a primary-fit failure: the Wald state is kept.
	expect_false(isTRUE(inf$is_nonestimable("estimate")))
	expect_true(is.finite(inf$compute_estimate()))
	expect_false(isTRUE(inf$is_nonestimable("se")))
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
}

test_that("the three LR-bootstrap CI NA reasons are recorded and warned once", {
	inf = lin_fixture_210()
	suppressWarnings(inf$compute_estimate())
	stub_lr_boot_pval_210(inf, function(...) NA_real_)
	res = collect_na_warnings_210(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 39L))
	expect_recorded_ci_reason_210(inf, res, "lik_ratio_bootstrap_ci_pval_at_estimate_unavailable")

	inf = lin_fixture_210()
	suppressWarnings(inf$compute_estimate())
	stub_lr_boot_pval_210(inf, function(...) 0.001)
	res = collect_na_warnings_210(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 39L))
	expect_recorded_ci_reason_210(inf, res, "lik_ratio_bootstrap_ci_rejects_at_estimate")

	# Never rejects anywhere: no outer bracket, so no bound.
	inf = lin_fixture_210()
	suppressWarnings(inf$compute_estimate())
	stub_lr_boot_pval_210(inf, function(...) 1)
	res = collect_na_warnings_210(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 39L))
	expect_recorded_ci_reason_210(inf, res, "lik_ratio_bootstrap_ci_bound_not_found")

	# A later successful run clears the stale reason.
	est = inf$compute_estimate()
	stub_lr_boot_pval_210(inf, function(delta, ...) if (abs(delta - est) < 1e-12) 1 else 0.01)
	ci = suppressWarnings(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 39L, max_root_iterations = 0L))
	expect_true(all(is.finite(ci)))
	pf = inf$.__enclos_env__$private$cached_values$procedure_failure_reason
	expect_null(pf[["lik_ratio_bootstrap_ci"]])
})

test_that("CI reasons map to their own procedure, p-value reasons keep theirs", {
	f = getFromNamespace("edi_resampling_procedure_for_reason", "EDI")
	expect_identical(f("lik_ratio_bootstrap_ci_bound_not_found"), "lik_ratio_bootstrap_ci")
	expect_identical(f("lik_ratio_bootstrap_ci_rejects_at_estimate"), "lik_ratio_bootstrap_ci")
	expect_identical(f("lik_ratio_bootstrap_ci_pval_at_estimate_unavailable"), "lik_ratio_bootstrap_ci")
	expect_identical(f("lik_ratio_bootstrap_too_few_converged_samples"), "lik_ratio_bootstrap")
})
