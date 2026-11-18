# v1.0.6-TODO-116: when the BCa bias correction or acceleration is unstable (|z0| > 2.5, |a| > 1,
# non-finite, or a zero BCa denominator) the BCa interval and p-value are NA. That NA used to be
# silent; it now raises one edi_bootstrap_bca_unstable_warning per object (separately for the
# interval and the p-value) suggesting type = "percentile", and never inside resampling.

fx_bca_unstable = function(){
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

# Bootstrap draws that all lie above the estimate: the mid-rank CDF at the estimate is 0, so
# z0 = qnorm(eps) ~ -8 and |z0| > 2.5 is the "unstable bias" branch. (|a| > 1 cannot arise from a
# real jackknife: |sum d^3| <= (sum d^2)^1.5 bounds |a| by 1/6.)
stub_draws_above_estimate = function(inf, nm){
	est = as.numeric(inf$compute_estimate())
	stub = function(B = 201, ...) est + 1 + seq_len(B) / B
	if (bindingIsLocked(nm, inf)) unlockBinding(nm, inf)
	assign(nm, stub, envir = inf)
}

collect_unstable = function(expr_fn){
	got = list()
	val = withCallingHandlers(expr_fn(),
		edi_bootstrap_bca_unstable_warning = function(w){ got[[length(got) + 1L]] <<- w; invokeRestart("muffleWarning") },
		edi_bootstrap_bca_boundary_warning = function(w) stop("unexpected boundary warning"),
		# the Bayesian CI path no longer adds the generic procedure-NA warning (checked in
		# test-bootstrap-bca-na-warns-exactly-once.R); muffled here in case another path does
		edi_procedure_na_warning = function(w) invokeRestart("muffleWarning"))
	list(value = val, warnings = got)
}

test_that("bootstrap BCa CI and p-value NA from an unstable acceleration each warn once", {
	inf = fx_bca_unstable()
	stub_draws_above_estimate(inf, "approximate_bootstrap_distribution_beta_hat_T")

	r = collect_unstable(function() inf$compute_bootstrap_confidence_interval(B = 201, show_progress = FALSE))
	expect_true(all(is.na(r$value)))
	expect_length(r$warnings, 1L)
	expect_identical(r$warnings[[1]]$what, "interval")
	expect_identical(r$warnings[[1]]$reason, "bootstrap_bca_unstable_bias_or_acceleration")
	expect_match(conditionMessage(r$warnings[[1]]), "type = \"percentile\"", fixed = TRUE)
	expect_match(conditionMessage(r$warnings[[1]]), "The returned interval is NA", fixed = TRUE)

	r = collect_unstable(function() inf$compute_bootstrap_two_sided_pval(B = 201, show_progress = FALSE))
	expect_true(is.na(r$value))
	expect_length(r$warnings, 1L)
	expect_identical(r$warnings[[1]]$what, "p-value")
	expect_match(conditionMessage(r$warnings[[1]]), "The returned p-value is NA", fixed = TRUE)

	# once per object: repeating either call is silent
	r = collect_unstable(function() inf$compute_bootstrap_confidence_interval(B = 201, show_progress = FALSE))
	expect_length(r$warnings, 0L)
	r = collect_unstable(function() inf$compute_bootstrap_two_sided_pval(B = 201, show_progress = FALSE))
	expect_length(r$warnings, 0L)

	# the percentile type is unaffected and silent
	expect_no_warning(ci <- inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE))
	expect_true(all(is.finite(ci)))
})

test_that("Bayesian bootstrap BCa CI and p-value NA from an unstable acceleration each warn once", {
	inf = fx_bca_unstable()
	stub_draws_above_estimate(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T")

	r = collect_unstable(function() inf$compute_bayesian_bootstrap_confidence_interval(B = 201, type = "bca", show_progress = FALSE))
	expect_true(all(is.na(r$value)))
	expect_length(r$warnings, 1L)
	expect_identical(r$warnings[[1]]$what, "interval")
	expect_identical(r$warnings[[1]]$reason, "bayesian_bootstrap_bca_unstable_bias_or_acceleration")

	r = collect_unstable(function() inf$compute_bayesian_bootstrap_two_sided_pval(B = 201, type = "bca", show_progress = FALSE))
	expect_true(is.na(r$value))
	expect_length(r$warnings, 1L)
	expect_identical(r$warnings[[1]]$what, "p-value")

	r = collect_unstable(function() inf$compute_bayesian_bootstrap_two_sided_pval(B = 201, type = "bca", show_progress = FALSE))
	expect_length(r$warnings, 0L)
})

test_that("the unstable-BCa warning is silent inside a resampling operation", {
	inf = fx_bca_unstable()
	p = inf$.__enclos_env__$private
	p$active_resampling_operation = "bootstrap"
	expect_no_warning(edi_warn_bca_boundary_once(inf, p, 201, "bca", "bootstrap_bca_unstable_bias_or_acceleration", what = "p-value"))
	p$active_resampling_operation = NULL
	expect_warning(edi_warn_bca_boundary_once(inf, p, 201, "bca", "bootstrap_bca_unstable_bias_or_acceleration", what = "p-value"),
		class = "edi_bootstrap_bca_unstable_warning")
})
