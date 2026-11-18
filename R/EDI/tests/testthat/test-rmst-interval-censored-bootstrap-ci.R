library(testthat)
library(EDI)

# v1.0.6-TODO-91 (and the NA asymptotic CI of v1.0.6-TODO-115): on left-/interval-censored
# data private$y is NA for every censored row, so the bootstrap outcome scale fell back to 1,
# the CI width cap became 5 time units, and ordinary RMST percentile intervals (width ~6)
# were discarded as "extreme" -> silent NA. The scale now uses the interval midpoints.

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

test_that("interval-censored outcome scale is on the time scale, not the fallback 1", {
	skip_if_not_installed("interval")
	inf = InferenceSurvivalRestrictedMeanDiff$new(make_visit_schedule_design())
	p = inf$.__enclos_env__$private
	expect_true(all(is.na(p$y)))
	s = p$bootstrap_outcome_scale()
	mid = (p$y_L + p$y_R) / 2
	expect_equal(s, max(1, stats::sd(mid)))
	expect_gt(s, 5)
})

test_that("RMST percentile bootstrap CI and the asymptotic fallback are finite on interval-censored data", {
	skip_if_not_installed("interval")
	inf = InferenceSurvivalRestrictedMeanDiff$new(make_visit_schedule_design())
	est = inf$compute_estimate()
	set.seed(1)
	ci = inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], est)
	expect_gt(ci[2], est)
	set.seed(1)
	ci_asymp = inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci_asymp)))
})
