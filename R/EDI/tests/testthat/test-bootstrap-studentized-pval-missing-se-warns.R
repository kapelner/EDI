library(testthat)
library(EDI)

# v1.0.6-TODO-93: the studentized (bootstrap-t) bootstrap p-value returned a silent NA when standard
# errors were missing, while the studentized bootstrap CI warned (edi_procedure_na_warning). Seen on
# KMDiff and RestrictedMeanDiff with interval censoring, whose fits supply no SE. The p-value now warns
# with the reason it records; the value (NA) is unchanged. The Bayesian-bootstrap studentized p-value
# had the same gap and gets the same warning (tested on a forced missing SE, since the interval-censored
# survival classes refuse the Bayesian bootstrap up front, v1.0.6-TODO-94).

make_visit_schedule_design = function(){
	set.seed(7); n = 120
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	t_event = rweibull(n, 1.5, 12 * exp(0.4 * w))
	L = floor(t_event / 3) * 3
	des$add_all_subject_responses(y_Ls = L, y_Rs = L + 3)
	des
}

expect_one_procedure_na_warning = function(expr, procedure){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	na_warns = Filter(function(w) inherits(w, "edi_procedure_na_warning"), warns)
	expect_length(na_warns, 1L)
	expect_identical(na_warns[[1L]]$procedure, procedure)
	expect_match(na_warns[[1L]]$reason, "standard_error")
	val
}

test_that("studentized bootstrap p-value warns when SEs are missing (KMDiff, RestrictedMeanDiff)", {
	skip_if_not_installed("interval")
	des = make_visit_schedule_design()
	for (cls in c("InferenceSurvivalKMDiff", "InferenceSurvivalRestrictedMeanDiff")) {
		inf = get(cls)$new(des)
		set.seed(1)
		p = expect_one_procedure_na_warning(
			inf$compute_bootstrap_two_sided_pval(B = 51, type = "studentized", show_progress = FALSE),
			"bootstrap p-value"
		)
		expect_true(is.na(p))
		# the percentile p-value on the same data is finite and silent
		set.seed(1)
		expect_no_warning(p_perc <- inf$compute_bootstrap_two_sided_pval(B = 51, type = "percentile", show_progress = FALSE))
		expect_true(is.finite(p_perc))
	}
})

test_that("studentized Bayesian-bootstrap p-value warns when the original SE is missing", {
	set.seed(3); n = 60
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf = InferenceAllSimpleAverageDiff$new(des)
	priv = inf$.__enclos_env__$private
	# force the "original SE unavailable" branch without depending on a class that lacks SEs
	unlockBinding("infer_original_se", priv)
	priv$infer_original_se = function() NA_real_
	set.seed(1)
	p = expect_one_procedure_na_warning(
		inf$compute_bayesian_bootstrap_two_sided_pval(B = 51, type = "studentized", show_progress = FALSE),
		"Bayesian bootstrap p-value"
	)
	expect_true(is.na(p))
	set.seed(1)
	p = expect_one_procedure_na_warning(
		inf$compute_bootstrap_two_sided_pval(B = 51, type = "studentized", show_progress = FALSE),
		"bootstrap p-value"
	)
	expect_true(is.na(p))
})
