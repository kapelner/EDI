# v1.0.6-TODO-144: on left/interval-censored data InferenceSurvivalKMDiff returned an NA
# estimate with no warning when an arm's Turnbull median is not reached (the general-
# censoring branch of shared() returned before the not-reached warning, and that warning
# read private$y, which is NA for every censored row). Its jackknife-Wald NA also gave the
# generic edi_procedure_na_warning instead of the median-specific one. These tests check the
# warning now comes from each arm's Turnbull NPMLE, names the arm and its lowest survival,
# suggests the restricted mean, stays silent inside resampling, and that the values are
# unchanged.

skip_if_not_installed("interval")

km_ic_designs = function() {
	# the censored-survival-outcomes article's visit-schedule data set
	set.seed(7)
	n = 120
	X = data.frame(age = round(rnorm(n, 60, 10)))
	des_full = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des_full$add_all_subjects_to_experiment(X)
	des_full$assign_w_to_all_subjects()
	w = des_full$get_w()
	t_event = rweibull(n, shape = 1.5, scale = 12 * exp(0.4 * w - 0.02 * (X$age - 60)))
	visits = seq(3, 24, by = 3)
	y_L = sapply(t_event, function(t) max(c(0, visits[visits < t])))
	y_R = sapply(t_event, function(t) if (t > max(visits)) Inf else min(visits[visits >= t]))
	des_full$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	# follow-up cut at month 9: the treated arm's survival never falls to 0.5
	des_9 = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des_9$add_all_subjects_to_experiment(X)
	des_9$assign_w_to_all_subjects(w_precomputed = w)
	des_9$add_all_subject_responses(y_Ls = ifelse(y_R > 9, 9, y_L), y_Rs = ifelse(y_R > 9, Inf, y_R))
	list(full = des_full, cut9 = des_9)
}

collect_warnings = function(expr) {
	ws = list()
	val = withCallingHandlers(expr, warning = function(w) {
		ws[[length(ws) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, warnings = ws)
}

n_of_class = function(ws, cls) sum(vapply(ws, inherits, logical(1), what = cls))

test_that("interval-censored KMDiff warns from the Turnbull NPMLE when a median is not reached", {
	des = km_ic_designs()$cut9
	inf = InferenceSurvivalKMDiff$new(des)
	res = collect_warnings(inf$compute_estimate())
	expect_true(is.na(res$value))
	expect_equal(n_of_class(res$warnings, "edi_km_median_not_reached_warning"), 1L)
	w = res$warnings[[which(vapply(res$warnings, inherits, logical(1), what = "edi_km_median_not_reached_warning"))]]
	expect_s3_class(w, "edi_procedure_na_warning")
	msg = conditionMessage(w)
	expect_match(msg, "treated (w = 1) arm's Turnbull (NPMLE) survival curve never falls to 0.5", fixed = TRUE)
	expect_match(msg, "lowest survival 0.6", fixed = TRUE)
	expect_no_match(msg, "control (w = 0)", fixed = TRUE)
	expect_match(msg, "InferenceSurvivalRestrictedMeanDiff", fixed = TRUE)
	# once per fit: later methods on the same object do not repeat it
	expect_no_warning(inf$compute_asymp_two_sided_pval(), class = "edi_km_median_not_reached_warning")
})

test_that("interval-censored KMDiff not-reached warning is silent inside bootstrap replicates", {
	des = km_ic_designs()$cut9
	inf = InferenceSurvivalKMDiff$new(des)
	inf$set_seed(1)
	res = collect_warnings(inf$compute_bootstrap_confidence_interval(B = 31))
	expect_true(all(is.na(res$value)))
	# the full-data fit warns once; the replicates do not add one each
	expect_equal(n_of_class(res$warnings, "edi_km_median_not_reached_warning"), 1L)
})

test_that("interval-censored KMDiff jackknife NA gives the median-specific warning", {
	ds = km_ic_designs()

	# full-data median not reached
	inf9 = InferenceSurvivalKMDiff$new(ds$cut9)
	res = collect_warnings(inf9$compute_jackknife_wald_confidence_interval())
	expect_true(all(is.na(res$value)))
	expect_equal(n_of_class(res$warnings, "edi_km_jackknife_na_warning"), 1L)
	generic_only = vapply(res$warnings, function(w) inherits(w, "edi_procedure_na_warning") &&
		!inherits(w, "edi_km_jackknife_na_warning") && !inherits(w, "edi_km_median_not_reached_warning"), logical(1))
	expect_false(any(generic_only))
	w = res$warnings[[which(vapply(res$warnings, inherits, logical(1), what = "edi_km_jackknife_na_warning"))]]
	expect_match(conditionMessage(w), "full-data difference in medians is NA", fixed = TRUE)
	expect_match(conditionMessage(w), "InferenceSurvivalRestrictedMeanDiff", fixed = TRUE)

	# median reached (6 months) but every leave-one-out median equals it: SE 0
	inf = InferenceSurvivalKMDiff$new(ds$full)
	expect_equal(suppressWarnings(inf$compute_estimate()), 6)
	for (call in list(
		function() inf$compute_jackknife_wald_confidence_interval(),
		function() inf$compute_jackknife_wald_two_sided_pval()
	)) {
		res = collect_warnings(call())
		expect_true(all(is.na(res$value)))
		expect_equal(length(res$warnings), 1L)
		expect_s3_class(res$warnings[[1L]], "edi_km_jackknife_na_warning")
		expect_match(conditionMessage(res$warnings[[1L]]), "jackknife standard error is 0", fixed = TRUE)
		expect_match(conditionMessage(res$warnings[[1L]]), "Turnbull median", fixed = TRUE)
	}
})

test_that("interval-censored KMDiff with both medians reached raises no not-reached warning", {
	inf = InferenceSurvivalKMDiff$new(km_ic_designs()$full)
	expect_no_warning(est <- inf$compute_estimate(), class = "edi_km_median_not_reached_warning")
	expect_equal(est, 6)
})
