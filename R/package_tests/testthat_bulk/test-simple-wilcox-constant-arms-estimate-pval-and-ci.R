# v1.0.6-TODO-23: when each arm is constant, InferenceAllSimpleWilcox returned an NA
# Hodges-Lehmann estimate because stats::wilcox.test(conf.int = TRUE) errors ("cannot compute
# confidence interval when all observations are tied") and shared() treated that as a failed fit.
# Every pairwise difference is yT - yC, so the estimate is that difference; the ties-corrected
# rank-sum p-value is defined (it matches stats::wilcox.test(exact = FALSE)); the test-inversion
# CI does not exist, so the CI is NA with a classed warning and the fit is not nonestimable.

make_constant_arm_wilcox = function(y_treat, y_ctrl, n = 20L) {
	set.seed(1)
	des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(ifelse(w == 1, y_treat, y_ctrl))
	list(inf = InferenceAllSimpleWilcox$new(des, verbose = FALSE), w = w)
}

test_that("constant arms: estimate is the arm difference on both paths, fit stays estimable", {
	obj = make_constant_arm_wilcox(2.5, 1)
	inf = obj$inf
	expect_true(any(obj$w == 1) && any(obj$w == 0))
	expect_equal(inf$compute_estimate(), 1.5)
	expect_false(inf$is_nonestimable())
	expect_equal(inf$compute_estimate(estimate_only = TRUE), 1.5)
	# stats' exact path gives the same location estimate on R >= 4.6. On R 4.5 (oldrel-1, R-CMD-check
	# 2026-11-19) it errors too ("missing value where TRUE/FALSE needed" in its root search), so
	# the cross-check runs only where stats can compute it.
	yT = rep(2.5, sum(obj$w == 1)); yC = rep(1, sum(obj$w == 0))
	ref = tryCatch(unname(stats::wilcox.test(yT, yC, conf.int = TRUE, exact = TRUE)$estimate), error = function(e) NULL)
	if (!is.null(ref)) expect_equal(ref, 1.5)
})

test_that("constant arms: p-value matches stats::wilcox.test(exact = FALSE) and is 1 at the HL shift", {
	obj = make_constant_arm_wilcox(2.5, 1)
	inf = obj$inf
	yT = rep(2.5, sum(obj$w == 1)); yC = rep(1, sum(obj$w == 0))
	ref = stats::wilcox.test(yT, yC, exact = FALSE)$p.value
	expect_equal(expect_no_warning(inf$compute_asymp_two_sided_pval()), ref)
	expect_equal(inf$compute_wald_two_sided_pval(), ref)
	expect_lt(ref, 0.001)
	expect_equal(inf$compute_asymp_two_sided_pval(delta = 1.5), 1)
})

test_that("constant arms: CI is NA with a classed warning and a recorded procedure failure", {
	obj = make_constant_arm_wilcox(2.5, 1)
	inf = obj$inf
	# stats' asymptotic CI errors here; EDI must not leak its raw warnings, only the classed one
	expect_error(suppressWarnings(stats::wilcox.test(rep(2.5, 5), rep(1, 5), conf.int = TRUE, exact = FALSE)))
	expect_no_warning(inf$compute_estimate())
	for (alpha in c(0.05, 0.1)) {
		expect_warning(ci <- inf$compute_asymp_confidence_interval(alpha = alpha), class = "edi_wilcox_ci_unavailable_warning")
		expect_identical(ci, c(NA_real_, NA_real_))
		expect_warning(ci <- inf$compute_wald_confidence_interval(alpha = alpha), class = "edi_wilcox_ci_unavailable_warning")
		expect_identical(ci, c(NA_real_, NA_real_))
	}
	priv = inf$.__enclos_env__$private
	expect_true(is.na(priv$get_standard_error()))
	expect_identical(priv$cached_values$procedure_failure_reason$wald, "wilcox_ci_each_arm_constant")
})

test_that("identical constant arms: estimate 0, p-value 1, CI NA", {
	obj = make_constant_arm_wilcox(3, 3)
	inf = obj$inf
	expect_equal(inf$compute_estimate(), 0)
	expect_false(inf$is_nonestimable())
	expect_equal(inf$compute_asymp_two_sided_pval(), 1)
	expect_warning(ci <- inf$compute_asymp_confidence_interval(), class = "edi_wilcox_ci_unavailable_warning")
	expect_identical(ci, c(NA_real_, NA_real_))
})

test_that("one constant arm only is unaffected: CI still comes from stats::wilcox.test", {
	set.seed(3); n = 20L
	des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = ifelse(w == 1, 2, round(rnorm(n), 2))
	des$add_all_subject_responses(y)
	inf = InferenceAllSimpleWilcox$new(des, verbose = FALSE)
	ref = stats::wilcox.test(y[w == 1], y[w == 0], conf.int = TRUE, exact = FALSE)
	expect_equal(expect_no_warning(inf$compute_asymp_confidence_interval()), as.numeric(ref$conf.int))
	expect_null(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$wald)
})
