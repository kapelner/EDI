# v1.0.6-TODO-116: a BCa interval or p-value that is NA because the adjustment is on the boundary
# or the bias correction / acceleration is unstable raises exactly one warning: the specific
# edi_bootstrap_bca_boundary_warning / edi_bootstrap_bca_unstable_warning. The Bayesian BCa
# interval used to raise the generic edi_procedure_na_warning from missing_bootstrap_ci() as well
# (and again on every repeated call). Checked for the plain and Bayesian bootstrap, CI and p-value.

fx_bca_once = function(){
	set.seed(1); n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(as.numeric(des$get_w()) * 0.5 + X$x1 + rnorm(n))
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(3)
	inf
}

# "unstable": every draw above the estimate, so z0 = qnorm(~0) and |z0| > 2.5.
# "boundary": two draws below the estimate, so z0 ~ -2.3 (stable) but the adjusted lower tail
# lands on the first order statistics (adjustment_on_boundary).
stub_bca_draws = function(inf, nm, kind){
	est = as.numeric(inf$compute_estimate())
	stub = if (identical(kind, "unstable")) {
		function(B = 201, ...) est + 1 + seq_len(B) / B
	} else {
		function(B = 201, ...) est + c(-0.02, -0.01, seq_len(B - 2) / B)
	}
	if (bindingIsLocked(nm, inf)) unlockBinding(nm, inf)
	assign(nm, stub, envir = inf)
}

collect_all_warnings = function(expr_fn){
	got = list()
	val = withCallingHandlers(expr_fn(), warning = function(w){
		got[[length(got) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, classes = vapply(got, function(w) class(w)[1L], character(1)), warnings = got)
}

for (kind in c("unstable", "boundary")) for (bayes in c(FALSE, TRUE)) {
	test_that(sprintf("%s BCa NA (%s) warns exactly once, CI and p-value", if (bayes) "Bayesian bootstrap" else "bootstrap", kind), {
		inf = fx_bca_once()
		stub_bca_draws(inf, if (bayes) "approximate_bayesian_bootstrap_distribution_beta_hat_T" else "approximate_bootstrap_distribution_beta_hat_T", kind)
		ci_fn = if (bayes) {
			function() inf$compute_bayesian_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE)
		} else {
			function() inf$compute_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE)
		}
		pv_fn = if (bayes) {
			function() inf$compute_bayesian_bootstrap_two_sided_pval(B = 201, type = "bca", show_progress = FALSE)
		} else {
			function() inf$compute_bootstrap_two_sided_pval(B = 201, type = "bca", show_progress = FALSE)
		}
		want = if (identical(kind, "unstable")) "edi_bootstrap_bca_unstable_warning" else "edi_bootstrap_bca_boundary_warning"
		reason_end = if (identical(kind, "unstable")) "unstable_bias_or_acceleration$" else "adjustment_on_boundary$"

		r = collect_all_warnings(ci_fn)
		expect_true(all(is.na(r$value)))
		expect_identical(r$classes, want)
		expect_identical(r$warnings[[1]]$what, "interval")
		expect_match(r$warnings[[1]]$reason, reason_end)

		r = collect_all_warnings(pv_fn)
		expect_true(is.na(r$value))
		expect_identical(r$classes, want)
		expect_identical(r$warnings[[1]]$what, "p-value")

		# repeating either call adds no warning at all (no generic procedure-NA warning either)
		r = collect_all_warnings(ci_fn)
		expect_true(all(is.na(r$value)))
		expect_length(r$classes, 0L)
		r = collect_all_warnings(pv_fn)
		expect_true(is.na(r$value))
		expect_length(r$classes, 0L)
	})
}

test_that("missing_bootstrap_ci() still raises the generic NA warning for other reasons", {
	inf = fx_bca_once()
	p = inf$.__enclos_env__$private
	expect_warning(ci <- p$missing_bootstrap_ci(0.05, "bootstrap_too_few_finite_estimates", stage = "estimate"),
		class = "edi_procedure_na_warning")
	expect_true(all(is.na(ci)))
	expect_no_warning(p$missing_bootstrap_ci(0.05, "bootstrap_too_few_finite_estimates", stage = "estimate", warn = FALSE))
})
