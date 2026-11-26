# v1.0.7-TODO-182: InferenceSurvivalKMDiff returned silent NAs on real survival trials (the
# real-data crash corpus, v1.0.7-TODO-102). Its warnings fired once per fit, so on an object
# whose estimate had already been computed, the asymptotic CI and p-value and the randomization
# p-value returned NA with no warning; and after the Wald CI had warned that a Brookmeyer-Crowley
# bound is unavailable, the Wald p-value was a silent NA. Every call that returns NA now says why,
# exactly once per call.

km_explain_design = function(y_T, dead_T, y_C, dead_C) {
	n = length(y_T) + length(y_C)
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n) / n))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = numeric(n); dead = numeric(n)
	y[w == 1] = y_T; dead[w == 1] = dead_T
	y[w == 0] = y_C; dead[w == 0] = dead_C
	des$add_all_subject_responses(
		ys = ifelse(dead == 1, y, NA_real_),
		y_Ls = ifelse(dead == 1, NA_real_, y),
		y_Rs = ifelse(dead == 1, NA_real_, Inf)
	)
	des
}

# The classes of the edi_procedure_na_warnings a call raises (all muffled) and its value.
km_warning_classes = function(fn) {
	cls = character()
	out = withCallingHandlers(fn(), warning = function(cnd) {
		cls <<- c(cls, class(cnd)[1L])
		invokeRestart("muffleWarning")
	})
	list(value = out, classes = cls)
}

test_that("each NA call explains a median that is not reached, once per call, in any order", {
	set.seed(1)
	des = km_explain_design(
		y_T = as.numeric(1:10), dead_T = c(1, 1, rep(0, 8)),
		y_C = as.numeric(1:10), dead_C = rep(1, 10)
	)
	calls = list(
		estimate = function(inf) inf$compute_estimate(),
		asymp_ci = function(inf) inf$compute_asymp_confidence_interval(),
		asymp_p = function(inf) inf$compute_asymp_two_sided_pval(),
		rand_p = function(inf) inf$compute_rand_two_sided_pval(r = 19, show_progress = FALSE)
	)
	for (first in names(calls)) {
		inf = InferenceSurvivalKMDiff$new(des)
		for (nm in c(first, setdiff(names(calls), first), first)) {
			r = km_warning_classes(function() calls[[nm]](inf))
			expect_true(all(is.na(r$value)), info = paste(first, nm))
			expect_equal(sum(r$classes == "edi_km_median_not_reached_warning"), 1L, info = paste(first, "then", nm))
		}
	}
})

test_that("the Wald p-value explains an unavailable Brookmeyer-Crowley bound after the CI did", {
	set.seed(2)
	# Both medians are reached, but the treated arm is censored right after its median, so its
	# Brookmeyer-Crowley upper bound is infinite and the MOVER interval is unavailable.
	des = km_explain_design(
		y_T = as.numeric(1:12), dead_T = c(rep(1, 6), rep(0, 6)),
		y_C = as.numeric(1:12), dead_C = rep(1, 12)
	)
	inf = InferenceSurvivalKMDiff$new(des)
	expect_true(is.finite(inf$compute_estimate()))
	for (i in 1:2) {
		ci = km_warning_classes(function() inf$compute_asymp_confidence_interval())
		p = km_warning_classes(function() inf$compute_asymp_two_sided_pval())
		expect_true(all(is.na(ci$value)))
		expect_true(is.na(p$value))
		expect_equal(sum(ci$classes == "edi_wald_unavailable_warning"), 1L)
		expect_equal(sum(p$classes == "edi_wald_unavailable_warning"), 1L)
	}
	# A finite randomization p-value raises no NA warning.
	r = km_warning_classes(function() inf$compute_rand_two_sided_pval(r = 19, show_progress = FALSE))
	expect_true(is.finite(r$value))
	expect_false(any(r$classes %in% c("edi_km_median_not_reached_warning", "edi_wald_unavailable_warning")))
})
