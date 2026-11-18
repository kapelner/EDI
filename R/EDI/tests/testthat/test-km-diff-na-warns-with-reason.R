# v1.0.6-TODO-112: InferenceSurvivalKMDiff returned NA with no warning when an arm's
# Kaplan-Meier curve never reaches 0.5 (median not reached), and its jackknife-Wald
# interval was NA with no warning on plain uncensored data. A median that is not reached
# is a legitimate NA, so these tests check that the NA now comes with a warning naming
# the arm and suggesting the restricted mean, and that the jackknife NA names its cause
# (the |bias| > 2 SE guard, which leave-one-out medians trip easily).

km_diff_design = function(y_T, dead_T, y_C, dead_C) {
	n = length(y_T) + length(y_C)
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n) / n))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_equal(sum(w == 1), length(y_T))
	y = numeric(n); dead = numeric(n)
	y[w == 1] = y_T; dead[w == 1] = dead_T
	y[w == 0] = y_C; dead[w == 0] = dead_C
	# right-censored at y: y_L = y, y_R = Inf
	des$add_all_subject_responses(
		ys = ifelse(dead == 1, y, NA_real_),
		y_Ls = ifelse(dead == 1, NA_real_, y),
		y_Rs = ifelse(dead == 1, NA_real_, Inf)
	)
	des
}

test_that("KMDiff warns, naming the treated arm, when its median is not reached", {
	set.seed(1)
	des = km_diff_design(
		y_T = as.numeric(1:10), dead_T = c(1, 1, rep(0, 8)),
		y_C = as.numeric(1:10), dead_C = rep(1, 10)
	)
	inf = InferenceSurvivalKMDiff$new(des)
	expect_warning(est <- inf$compute_estimate(), class = "edi_km_median_not_reached_warning")
	expect_true(is.na(est))
	# once per object: the other methods on the same object do not repeat it
	expect_no_warning(inf$compute_asymp_two_sided_pval(), class = "edi_km_median_not_reached_warning")

	w = tryCatch(InferenceSurvivalKMDiff$new(des)$compute_estimate(), warning = function(w) w)
	expect_match(conditionMessage(w), "treated (w = 1)", fixed = TRUE)
	expect_no_match(conditionMessage(w), "control (w = 0)", fixed = TRUE)
	expect_match(conditionMessage(w), "InferenceSurvivalRestrictedMeanDiff", fixed = TRUE)
})

test_that("KMDiff warns on a fresh object for every inference method when a median is not reached", {
	set.seed(1)
	des = km_diff_design(
		y_T = as.numeric(1:10), dead_T = rep(1, 10),
		y_C = as.numeric(1:10), dead_C = c(1, rep(0, 9))
	)
	calls = list(
		asymp_ci = function(inf) inf$compute_asymp_confidence_interval(),
		asymp_p = function(inf) inf$compute_asymp_two_sided_pval(),
		boot_ci = function(inf) inf$compute_bootstrap_confidence_interval(B = 51),
		jack_ci = function(inf) inf$compute_jackknife_wald_confidence_interval()
	)
	for (nm in names(calls)) {
		inf = InferenceSurvivalKMDiff$new(des)
		w = NULL
		# the shared per-procedure NA warnings (v1.0.6-TODO-113) may follow; muffle them too
		out = withCallingHandlers(calls[[nm]](inf), edi_procedure_na_warning = function(cnd) {
			if (inherits(cnd, "edi_km_median_not_reached_warning")) w <<- cnd
			invokeRestart("muffleWarning")
		})
		expect_true(all(is.na(out)), info = nm)
		expect_false(is.null(w), info = nm)
		expect_match(conditionMessage(w), "control (w = 0)", fixed = TRUE, info = nm)
	}
})

test_that("KMDiff jackknife-Wald NA on uncensored data warns with the bias-guard reason", {
	set.seed(3)
	# Odd arms (21 each). The treated arm's order statistics have a gap of 1 below its
	# median and 0.01 above, so leave-one-out medians shift one way and the (n - 1)-scaled
	# jackknife bias is far more than twice the jackknife SE.
	m = 21L; k = (m + 1L) / 2L
	y_T = as.numeric(seq_len(m)); y_T[(k + 1L):m] = y_T[(k + 1L):m] - 0.99
	des = km_diff_design(y_T = y_T, dead_T = rep(1, m), y_C = as.numeric(seq_len(m)) + 0.5, dead_C = rep(1, m))
	inf = InferenceSurvivalKMDiff$new(des)
	expect_no_warning(est <- inf$compute_estimate())
	expect_true(is.finite(est))
	expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), class = "edi_km_jackknife_na_warning")
	expect_true(all(is.na(ci)))
	w = tryCatch(InferenceSurvivalKMDiff$new(des)$compute_jackknife_wald_two_sided_pval(), warning = function(w) w)
	expect_s3_class(w, "edi_km_jackknife_na_warning")
	expect_match(conditionMessage(w), "more than twice the jackknife standard error", fixed = TRUE)
	expect_match(conditionMessage(w), "compute_bootstrap_confidence_interval", fixed = TRUE)
})

test_that("KMDiff stays silent when both medians are reached and the jackknife is finite", {
	set.seed(1)
	des = km_diff_design(
		y_T = as.numeric(1:21) + 0.25, dead_T = rep(1, 21),
		y_C = as.numeric(1:21), dead_C = rep(1, 21)
	)
	inf = InferenceSurvivalKMDiff$new(des)
	expect_no_warning(est <- inf$compute_estimate(), class = "edi_km_median_not_reached_warning")
	expect_true(is.finite(est))
	expect_no_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), class = "edi_km_jackknife_na_warning")
	expect_true(all(is.finite(ci)))
})
