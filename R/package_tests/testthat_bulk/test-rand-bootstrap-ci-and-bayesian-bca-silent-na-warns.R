library(testthat)
library(EDI)

# v1.0.6-TODO-165 (follow-up of v1.0.6-TODO-136 / -145): the randomization-bootstrap CI's own NA
# returns (every missing_ci() reason, including rand_bootstrap_ci_bisection_failed and
# rand_bootstrap_ci_closed_form_unavailable) and the Bayesian-bootstrap BCa p-value's
# bayesian_bootstrap_bca_pvalue_unavailable used to return a silent NA. Each now warns once
# (edi_procedure_na_warning, with the recorded reason); values unchanged. The per-delta p-value
# warnings inside the CI search stay muffled, so an NA CI gives exactly one warning.

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
	val = suppressMessages(withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	}))
	list(value = val, na = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns), all = warns)
}

RB_CI = "randomization-bootstrap confidence interval"

expect_one_rb_ci_warning = function(res, reason){
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, RB_CI)
	expect_identical(res$na[[1L]]$reason, reason)
	expect_length(res$value, 2L)
	expect_true(all(is.na(res$value)))
}

rb_ci = function(inf, ...) inf$compute_rand_bootstrap_confidence_interval(B = 51, show_progress = FALSE, ...)

test_that("rand-bootstrap CI with too few finite null draws warns once", {
	des = make_cont_design()
	for (type in c("percentile", "smoothed")) {
		inf = InferenceAllSimpleAverageDiff$new(des)
		stub_method(inf, "approximate_rand_bootstrap_distribution_beta_hat_T",
			function(B = 501, ...) c(rnorm(1), rep(NA_real_, B - 1)))
		# skip the closed-form affine shortcut so the percentile path reaches the null draws
		stub_method(inf$.__enclos_env__$private, "compute_rand_bootstrap_ci_affine_coefs", function(...) NULL)
		expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf, type = type)), "rand_bootstrap_ci_too_few_finite_null_draws")
	}
})

test_that("rand-bootstrap CI with an unavailable estimate or studentized SE warns once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "compute_estimate", function(...) NA_real_)
	expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf, type = "smoothed")), "rand_bootstrap_ci_estimate_unavailable")
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf$.__enclos_env__$private, "infer_original_se", function(...) NA_real_)
	expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf, type = "studentized")), "rand_bootstrap_ci_studentized_se_unavailable")
})

test_that("rand-bootstrap CI search-bounds, bisection and closed-form failures warn once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf$.__enclos_env__$private, "expand_rand_bootstrap_bound", function(...) NA_real_)
	expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf, type = "smoothed")), "rand_bootstrap_ci_search_bounds_failed")
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf$.__enclos_env__$private, "invert_rand_bootstrap_test_bisection", function(...) NA_real_)
	expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf, type = "smoothed")), "rand_bootstrap_ci_bisection_failed")
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf$.__enclos_env__$private, "closed_form_ci_from_affine_null_draws", function(...) NA_real_)
	expect_one_rb_ci_warning(collect_na_warnings(rb_ci(inf)), "rand_bootstrap_ci_closed_form_unavailable")
})

test_that("rand-bootstrap CI whose per-delta p-values are NA warns once, from the CI", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	# enough finite draws at delta = 0, too few everywhere else: every off-centre p-value is NA
	stub_method(inf, "approximate_rand_bootstrap_distribution_beta_hat_T", function(B = 501, delta = 0, ...)
		if (delta == 0) rnorm(B) else c(rnorm(3), rep(NA_real_, B - 3)))
	res = collect_na_warnings(rb_ci(inf, type = "smoothed"))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, RB_CI)
	expect_true(all(is.na(res$value)))
})

test_that("rand-bootstrap CI that succeeds is silent", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	for (type in c("percentile", "smoothed")) {
		res = collect_na_warnings(rb_ci(inf, type = type))
		expect_length(res$na, 0L)
		expect_true(all(is.finite(res$value)))
	}
})

test_that("rand-bootstrap CI NA is silent while a resampling operation is active", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	# set the flag from inside the search: the null-draw computation before it resets the field
	stub_method(priv, "invert_rand_bootstrap_test_bisection", function(...){
		priv$active_resampling_operation = "boot"
		NA_real_
	})
	res = collect_na_warnings(rb_ci(inf, type = "smoothed"))
	expect_length(res$na, 0L)
	expect_true(all(is.na(res$value)))
})

test_that("Bayesian-bootstrap BCa p-value that is unavailable warns once", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rnorm(B, 1))
	stub_method(priv, "pval_bayesian_bca", function(...) stop("stub failure"))
	res = collect_na_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$procedure, "Bayesian bootstrap p-value")
	expect_identical(res$na[[1L]]$reason, "bayesian_bootstrap_bca_pvalue_unavailable")
	expect_match(conditionMessage(res$na[[1L]]), "stub failure", fixed = TRUE)
	expect_true(is.na(res$value))
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rnorm(B, 1))
	stub_method(priv, "pval_bayesian_bca", function(...) NA_real_)
	res = collect_na_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE))
	expect_length(res$na, 1L)
	expect_identical(res$na[[1L]]$reason, "bayesian_bootstrap_bca_pvalue_unavailable")
	expect_true(is.na(res$value))
})

test_that("Bayesian-bootstrap BCa NA that already warned (boundary) does not warn twice", {
	des = make_cont_design()
	inf = InferenceAllSimpleAverageDiff$new(des)
	stub_method(inf, "approximate_bayesian_bootstrap_distribution_beta_hat_T", function(B = 501, ...) rnorm(B, 1))
	# B = 51: the nominal BCa tail sits on the extreme draws, which already warns (boundary class)
	res = collect_na_warnings(inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, type = "bca", show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_length(res$na, 0L)
	expect_true(any(vapply(res$all, inherits, logical(1), "edi_bootstrap_bca_boundary_warning")))
})
