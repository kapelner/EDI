library(testthat)
library(EDI)

# v1.0.6-TODO-195 (docs-scenarios survival-censoring F9): on interval-censored data
# InferenceSurvivalCoxPHRegr's Wald SE comes from icenReg::ic_sp()'s bootstrap, which drew from the
# session RNG, so the CI and p-value changed with the global seed even after set_seed().

coxph_ic_design = function() {
	set.seed(7); n = 120
	X = data.frame(age = round(rnorm(n, 60, 10)))
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
	t_event = rweibull(n, shape = 1.5, scale = 12 * exp(0.4 * w - 0.02 * (X$age - 60)))
	visits = seq(3, 24, by = 3)
	y_L = sapply(t_event, function(t) max(c(0, visits[visits < t])))
	y_R = sapply(t_event, function(t) if (t > max(visits)) Inf else min(visits[visits >= t]))
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	des
}

test_that("interval-censored Cox Wald results depend on the object seed, not the global RNG state", {
	skip_if_not_installed("icenReg")
	des = coxph_ic_design()
	run = function(object_seed, global_seed) {
		inf = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
		inf$set_seed(object_seed)
		set.seed(global_seed)
		c(suppressWarnings(inf$compute_asymp_confidence_interval()), suppressWarnings(inf$compute_asymp_two_sided_pval()))
	}
	a = run(123, 1); b = run(123, 2)
	expect_true(all(is.finite(a)))
	expect_identical(a, b)
	expect_false(identical(a, run(456, 1)))
	# the session stream is restored: the global draw after the fit is the same as without it
	set.seed(99); u0 = runif(1)
	inf = InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE); inf$set_seed(123)
	set.seed(99); invisible(suppressWarnings(inf$compute_asymp_two_sided_pval())); u1 = runif(1)
	expect_identical(u1, u0)
})
