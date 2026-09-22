library(testthat)
library(EDI)

# InferenceSurvivalCoxPHRegr$compute_asymp_confidence_interval()/compute_asymp_two_sided_pval(): under left-/
# interval-censored data (has_general_censoring = TRUE), the class dispatches through icenReg::ic_sp(), which has
# no partial-likelihood score/gradient/likelihood-ratio machinery to reuse -- so any testing_type other than
# "wald" is rejected with an explicit, informative error rather than being silently attempted (and presumably
# crashing deeper in code that assumes right-censoring partial-likelihood internals). This guard, reached from
# every one of this class's other supported testing types, had no test anywhere triggering it -- existing
# general-censoring coverage (test-*coxph*-general-censoring*) only exercises the default testing_type = "wald"
# path (compute_estimate()/its CI, checked against an independent icenReg::ic_sp() reference).

ic_fx <- function(seed = 3L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	des
}

test_that("has_general_censoring is TRUE and only 'wald' is offered as a supported testing type for this design", {
	des <- ic_fx()
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_true(p$has_general_censoring)
	expect_identical(p$testing_type, "wald")                                    # the default, still supported
})

test_that("every non-wald supported testing type is rejected for both compute_asymp_confidence_interval and compute_asymp_two_sided_pval, with an informative message naming that type", {
	des <- ic_fx()
	base <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	for (tt in setdiff(base$get_supported_testing_types(), "wald")) {
		inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
		inf$set_testing_type(tt)
		expect_error(
			inf$compute_asymp_confidence_interval(0.05),
			paste0("testing_type = '", tt, "' is not supported for left-/interval-censored survival data"),
			info = tt
		)
		inf2 <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
		inf2$set_testing_type(tt)
		expect_error(
			inf2$compute_asymp_two_sided_pval(0),
			paste0("testing_type = '", tt, "' is not supported for left-/interval-censored survival data"),
			info = tt
		)
	}
})

test_that("the guard is specific to general censoring: the same non-wald testing types work (don't error with this message) on an ordinary right-censored design", {
	set.seed(4); n <- 40L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	base <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	expect_false(base$.__enclos_env__$private$has_general_censoring)
	for (tt in setdiff(base$get_supported_testing_types(), "wald")) {
		inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
		inf$set_testing_type(tt)
		out <- tryCatch(inf$compute_asymp_confidence_interval(0.05), error = function(e) e)
		expect_false(inherits(out, "error") && grepl("not supported for left-/interval-censored", conditionMessage(out)), info = tt)
	}
})

test_that("the wald testing type still works and is unaffected by the guard (already independently reference-checked elsewhere)", {
	des <- ic_fx()
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	ci <- suppressWarnings(inf$compute_asymp_confidence_interval(0.05))
	expect_true(all(is.finite(ci)))
})
