# v1.0.6-TODO-109: InferenceIncidLogRegr (and the logistic g-computation classes)
# warn when fitted probabilities are numerically 0 or 1 ((quasi-)complete
# separation), once per object, never from resampling inner loops, and without
# changing any estimate.
context("logistic separation warning")

fx_sep_109 = function(separated = TRUE, seed = 1){
	set.seed(seed); n = 40
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = as.numeric(des$get_w())
	y = if (separated) ifelse(w == 1, 1, rbinom(n, 1, 0.4)) else rbinom(n, 1, plogis(0.5 * w + X$x1))
	des$add_all_subject_responses(y)
	des
}

count_sep_warnings_109 = function(expr){
	n_warn = 0L
	# other (unrelated) warnings are muffled so only the separation warning is counted
	val = withCallingHandlers(expr, warning = function(w){
		if (inherits(w, "edi_logistic_separation_warning")) n_warn <<- n_warn + 1L
		invokeRestart("muffleWarning")
	})
	list(value = val, n_warn = n_warn)
}

test_that("InferenceIncidLogRegr warns once under quasi-complete separation, estimate unchanged", {
	des = fx_sep_109(TRUE)
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	w = NULL
	est = withCallingHandlers(inf$compute_estimate(), edi_logistic_separation_warning = function(cnd){
		w <<- cnd
		invokeRestart("muffleWarning")
	})
	expect_false(is.null(w))
	expect_match(conditionMessage(w), "fitted probabilities numerically 0 or 1")
	expect_true(w$n_extreme > 0L)
	expect_identical(w$n, 40L)
	# later calls on the same object stay silent
	expect_no_warning(inf$compute_asymp_two_sided_pval(), message = "fitted probabilities")
	expect_no_warning(inf$compute_asymp_confidence_interval(), message = "fitted probabilities")
	# no numeric change: same estimate with the warning suppressed on a fresh object
	inf2 = InferenceIncidLogRegr$new(des, verbose = FALSE)
	est2 = suppressWarnings(inf2$compute_estimate(), classes = "edi_logistic_separation_warning")
	expect_identical(est, est2)
	b = inf2$.__enclos_env__$private$cached_mod$b
	expect_equal(est, as.numeric(b[2L]))
})

test_that("InferenceIncidLogRegr is silent on non-separated data", {
	inf = InferenceIncidLogRegr$new(fx_sep_109(FALSE, seed = 3), verbose = FALSE)
	res = count_sep_warnings_109({
		inf$compute_estimate()
		inf$compute_asymp_two_sided_pval()
	})
	expect_identical(res$n_warn, 0L)
})

test_that("resampling on a separated fit warns at most once per user-facing call", {
	des = fx_sep_109(TRUE)
	inf = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$num_cores = 1L
	res = count_sep_warnings_109(inf$compute_bootstrap_confidence_interval(B = 51, type = "percentile", show_progress = FALSE))
	expect_lte(res$n_warn, 1L)
	inf_j = InferenceIncidLogRegr$new(des, verbose = FALSE)
	res_j = count_sep_warnings_109(tryCatch(inf_j$compute_jackknife_wald_confidence_interval(), error = function(e) NULL))
	expect_lte(res_j$n_warn, 1L)
	inf_pb = InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf_pb$num_cores = 1L
	res_bb = count_sep_warnings_109(tryCatch(inf_pb$compute_bayesian_bootstrap_confidence_interval(B = 51, show_progress = FALSE), error = function(e) NULL))
	expect_lte(res_bb$n_warn, 1L)
})

test_that("InferenceIncidGCompRiskDiff warns once under quasi-complete separation", {
	des = fx_sep_109(TRUE)
	inf = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)
	res = count_sep_warnings_109({
		inf$compute_estimate()
		inf$compute_asymp_two_sided_pval()
	})
	expect_identical(res$n_warn, 1L)
	inf_ok = InferenceIncidGCompRiskDiff$new(fx_sep_109(FALSE, seed = 3), verbose = FALSE)
	expect_identical(count_sep_warnings_109(inf_ok$compute_estimate())$n_warn, 0L)
})
