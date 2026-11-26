# v1.0.6-TODO-73: InferenceIncidProbitRegr warns when fitted probabilities
# Phi(X b) are numerically 0 or 1 ((quasi-)complete separation), once per
# object, never from resampling inner loops, and without changing any estimate.
# Same classed warning (edi_logistic_separation_warning, link = "probit") as the
# logistic classes of v1.0.6-TODO-63 (see test-logistic-separation-warning.R).
context("probit separation warning")

fx_sep_probit = function(separated = TRUE, seed = 1){
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

count_probit_sep_warnings = function(expr){
	n_warn = 0L
	# other (unrelated) warnings are muffled so only the separation warning is counted
	val = withCallingHandlers(expr, warning = function(w){
		if (inherits(w, "edi_logistic_separation_warning")) n_warn <<- n_warn + 1L
		invokeRestart("muffleWarning")
	})
	list(value = val, n_warn = n_warn)
}

test_that("separation helpers keep the logit default and add a probit edge", {
	X = cbind(1, c(0, 0, 1, 1))
	b_probit = c(0, 7)   # Phi(7) is within 1e-8 of 1; plogis(7) is not
	expect_identical(edi_logistic_n_fitted_extreme(X, b_probit), 0L)
	expect_identical(edi_logistic_n_fitted_extreme(X, b_probit, link = "logit"), 0L)
	expect_identical(edi_logistic_n_fitted_extreme(X, b_probit, link = "probit"), 2L)
	expect_identical(edi_logistic_n_fitted_extreme(X, c(0, 2), link = "probit"), 0L)
	expect_identical(edi_logistic_n_fitted_extreme(X, c(0, 23)), 2L)
	expect_error(edi_logistic_n_fitted_extreme(X, b_probit, link = "cloglog"))
})

test_that("InferenceIncidProbitRegr warns once under quasi-complete separation, estimate unchanged", {
	des = fx_sep_probit(TRUE)
	inf = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	w = NULL
	est = withCallingHandlers(inf$compute_estimate(), edi_logistic_separation_warning = function(cnd){
		w <<- cnd
		invokeRestart("muffleWarning")
	})
	expect_false(is.null(w))
	expect_match(conditionMessage(w), "InferenceIncidProbitRegr: fitted probabilities numerically 0 or 1")
	expect_true(w$n_extreme > 0L)
	expect_identical(w$n, 40L)
	expect_identical(w$link, "probit")
	# later calls on the same object stay silent
	expect_no_warning(inf$compute_asymp_two_sided_pval(), message = "fitted probabilities")
	expect_no_warning(inf$compute_asymp_confidence_interval(), message = "fitted probabilities")
	# no numeric change: same estimate with the warning suppressed on a fresh object
	inf2 = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	est2 = suppressWarnings(inf2$compute_estimate(), classes = "edi_logistic_separation_warning")
	expect_identical(est, est2)
	expect_equal(est, as.numeric(inf2$.__enclos_env__$private$cached_mod$b[2L]))
	# the warning fires on the asymptotic p-value path too (fresh object)
	inf3 = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	expect_identical(count_probit_sep_warnings(inf3$compute_asymp_two_sided_pval())$n_warn, 1L)
})

test_that("InferenceIncidProbitRegr is silent on non-separated data", {
	inf = InferenceIncidProbitRegr$new(fx_sep_probit(FALSE, seed = 3), verbose = FALSE)
	res = count_probit_sep_warnings({
		inf$compute_estimate()
		inf$compute_asymp_two_sided_pval()
		inf$compute_asymp_confidence_interval()
	})
	expect_identical(res$n_warn, 0L)
})

test_that("probit resampling on a separated fit warns at most once per user-facing call", {
	des = fx_sep_probit(TRUE)
	inf = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf$num_cores = 1L
	res = count_probit_sep_warnings(inf$compute_bootstrap_confidence_interval(B = 51, type = "percentile", show_progress = FALSE))
	expect_lte(res$n_warn, 1L)
	inf_j = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	res_j = count_probit_sep_warnings(inf_j$compute_jackknife_wald_confidence_interval())
	expect_lte(res_j$n_warn, 1L)
	inf_bb = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf_bb$num_cores = 1L
	res_bb = count_probit_sep_warnings(inf_bb$compute_bayesian_bootstrap_confidence_interval(B = 51, show_progress = FALSE))
	expect_lte(res_bb$n_warn, 1L)
	inf_r = InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf_r$num_cores = 1L
	res_r = count_probit_sep_warnings(inf_r$compute_rand_two_sided_pval(r = 51, show_progress = FALSE))
	expect_lte(res_r$n_warn, 1L)
})
