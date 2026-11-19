library(testthat)
library(EDI)

# v1.0.6-TODO-207 (found by the v1.0.6-TODO-185 agent): the parametric-bootstrap methods, the
# Monte-Carlo Bartlett factor and the m-out-of-n / subsampling distributions set
# private$active_resampling_operation at their own top level, so a procedure-NA warning raised in
# their own top-level code was silenced even when a user called them directly. The flag now covers
# only the replicate loop (run_param_bootstrap_replicates(), run_param_bootstrap_estimate_replicates(),
# compute_resampling_draw_distribution()), restoring the caller's value afterwards
# (v1.0.6-TODO-185). Top-level NA results warn; replicates stay silent.

lin_fixture = function(seed = 1L, n = 40L){
	set.seed(seed)
	des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf = InferenceContinLin$new(des, verbose = FALSE)
	inf$set_seed(7)
	inf
}

stub_private = function(inf, name, f){
	priv = inf$.__enclos_env__$private
	# Bind to the object's enclosing env so self / private resolve, also in R6 clones.
	environment(f) = inf$.__enclos_env__
	if (bindingIsLocked(name, priv)) unlockBinding(name, priv)
	assign(name, f, envir = priv)
}

collect_na_warnings = function(expr){
	warns = list()
	val = suppressMessages(withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	}))
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns))
}

test_that("parametric-bootstrap, Bartlett, m-out-of-n and subsampling sites restore the caller's operation", {
	calls = list(
		lik_ratio_bootstrap_pval = function(inf) inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9),
		lik_ratio_bootstrap_ci = function(inf) inf$compute_lik_ratio_bootstrap_confidence_interval(alpha = 0.2, B = 9, max_root_iterations = 0L),
		param_bootstrap_estimate = function(inf) inf$compute_param_bootstrap_estimate(B = 9),
		param_bootstrap_ci = function(inf) inf$compute_param_bootstrap_confidence_interval(B = 9),
		param_bootstrap_pval = function(inf) inf$compute_param_bootstrap_pval(delta = 0, B = 9),
		bartlett_factor = function(inf){
			priv = inf$.__enclos_env__$private
			spec = priv$get_likelihood_test_spec()
			priv$get_bartlett_factor_approx(spec = spec, delta = 0, full_fit = spec$full_fit, null_fit = spec$fit_null(0), B = 9)
		},
		bartlett_pval = function(inf) inf$compute_lik_ratio_bartlett_approx_two_sided_pval(B = 9),
		m_out_of_n_distribution = function(inf) inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 9, m = 10, show_progress = FALSE),
		subsampling_distribution = function(inf) inf$approximate_subsampling_distribution_beta_hat_T(B = 9, b = 10, show_progress = FALSE)
	)
	for (nm in names(calls)) {
		for (outer in list(NULL, "outer_operation")) {
			inf = lin_fixture()
			priv = inf$.__enclos_env__$private
			priv$active_resampling_operation = outer
			suppressWarnings(suppressMessages(calls[[nm]](inf)))
			expect_identical(priv$active_resampling_operation, outer, info = paste(nm, "outer =", format(outer)))
		}
	}
})

test_that("the flag is set inside the replicate loop and not at the methods' top level", {
	options(edi_todo207_seen = NULL)
	on.exit(options(edi_todo207_seen = NULL), add = TRUE)
	inf = lin_fixture(seed = 2L)
	priv = inf$.__enclos_env__$private
	priv$todo207_orig_spec = priv$get_likelihood_test_spec
	priv$todo207_orig_sim = priv$simulate_under_lik_null
	stub_private(inf, "get_likelihood_test_spec", function(...){
		options(edi_todo207_seen = c(getOption("edi_todo207_seen"), paste0("top:", format(private$active_resampling_operation))))
		private$todo207_orig_spec(...)
	})
	stub_private(inf, "simulate_under_lik_null", function(spec, delta, null_fit){
		options(edi_todo207_seen = c(getOption("edi_todo207_seen"), paste0("rep:", format(private$active_resampling_operation))))
		private$todo207_orig_sim(spec, delta, null_fit)
	})
	p = inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9)
	expect_true(is.finite(p))
	seen = getOption("edi_todo207_seen")
	# The first spec lookup is the method's own top-level one (replicate refits may look it up again).
	expect_identical(seen[[1L]], "top:NULL")
	expect_true(any(seen == "rep:param_boot"))
	expect_false(any(seen == "rep:NULL"))
	expect_null(priv$active_resampling_operation)
})

test_that("a direct top-level parametric-bootstrap NA warns while its replicates stay silent", {
	inf = lin_fixture(seed = 3L)
	priv = inf$.__enclos_env__$private
	# Every replicate raises a procedure-NA warning; it must stay silent inside the loop.
	priv$todo207_orig_sim = priv$simulate_under_lik_null
	stub_private(inf, "simulate_under_lik_null", function(spec, delta, null_fit){
		EDI:::edi_warn_procedure_na(self, private, procedure = "replicate", reason = "replicate_reason")
		private$todo207_orig_sim(spec, delta, null_fit)
	})
	res = collect_na_warnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9))
	expect_true(is.finite(res$value))
	expect_length(res$na, 0L)

	# Top-level failure: every LR flagged extreme, so the observed LR is rejected before any replicate.
	stub_private(inf, "param_bootstrap_lr_extreme", function(lr, max_abs = NULL) rep(TRUE, length(lr)))
	res = collect_na_warnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "parametric-bootstrap likelihood-ratio p-value")
	expect_identical(res$na[[1L]]$reason, "lik_ratio_bootstrap_observed_lr_extreme")

	# Same call inside an outer resampling operation: silent, and the flag is kept.
	priv$active_resampling_operation = "outer_operation"
	res = collect_na_warnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
	expect_identical(priv$active_resampling_operation, "outer_operation")
})

test_that("too few usable LR replicates warns once at top level", {
	inf = lin_fixture(seed = 4L)
	stub_private(inf, "simulate_under_lik_null", function(spec, delta, null_fit) NULL)
	res = collect_na_warnings(inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 9))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "lik_ratio_bootstrap_too_few_converged_samples")
})

test_that("parametric-bootstrap estimate / CI / p-value warn on their recorded NA reasons", {
	too_few = function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))
	cases = list(
		list(call = function(inf) inf$compute_param_bootstrap_estimate(B = 20L), procedure = "parametric-bootstrap estimate"),
		list(call = function(inf) inf$compute_param_bootstrap_confidence_interval(B = 20L), procedure = "parametric-bootstrap confidence interval"),
		list(call = function(inf) inf$compute_param_bootstrap_pval(delta = 0, B = 20L), procedure = "parametric-bootstrap p-value")
	)
	for (cs in cases) {
		inf = lin_fixture(seed = 5L)
		stub_private(inf, "run_param_bootstrap_estimate_batch", too_few)
		res = collect_na_warnings(cs$call(inf))
		expect_true(all(is.na(res$value)), info = cs$procedure)
		expect_length(res$na, 1L)
		expect_identical(res$na[[1L]]$procedure, cs$procedure)
		expect_identical(res$na[[1L]]$reason, "param_bootstrap_estimate_too_few_usable_replicates")
	}
	# The batch helper's own preflight NA (raw estimate flagged extreme) names the calling procedure.
	inf = lin_fixture(seed = 6L)
	stub_private(inf, "param_bootstrap_estimate_extreme", function(...) TRUE)
	res = collect_na_warnings(inf$compute_param_bootstrap_pval(delta = 0, B = 20L))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "parametric-bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "param_bootstrap_estimate_raw_estimate_extreme")
})

test_that("an LR-bootstrap CI whose B cannot reach alpha errors up front instead of a warned NA", {
	# v1.0.6-TODO-210: B = 29 < 2 / 0.05 - 1 = 39 used to search and then warn
	# lik_ratio_bootstrap_ci_bound_not_found; it now errors before any bootstrap work.
	inf = lin_fixture()
	expect_error(inf$compute_lik_ratio_bootstrap_confidence_interval(B = 29, max_root_iterations = 2L),
		"B must be at least 39 for alpha = 0.05", fixed = TRUE)
	expect_null(inf$get_last_param_bootstrap_diagnostics())
})

test_that("m-out-of-n and subsampling p-value failures warn like their CIs", {
	inf = lin_fixture()
	res = collect_na_warnings(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 9, m = 10, show_progress = FALSE, min_number_usable_samples = 50L))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "m-out-of-n bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "m_out_of_n_too_few_finite_estimates")
	inf = lin_fixture()
	res = collect_na_warnings(inf$compute_subsampling_two_sided_pval(B = 9, b = 10, show_progress = FALSE, min_number_usable_samples = 50L))
	expect_true(is.na(res$value))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "subsampling p-value")
})
