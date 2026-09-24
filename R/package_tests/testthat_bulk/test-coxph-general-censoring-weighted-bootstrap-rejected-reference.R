library(testthat)
library(EDI)

# InferenceSurvivalCoxPHRegr$compute_estimate_with_bootstrap_weights() (inference_survival_coxph.R)
# refuses immediately under left-/interval-censored data (has_general_censoring = TRUE), since
# weighted_cox_bootstrap_surrogate_fit() assumes ordinary right-censoring semantics -- "Bayesian-
# bootstrap weighted re-estimation is not yet supported for left-/interval-censored survival data
# (weighted_cox_bootstrap_surrogate_fit() assumes ordinary right-censoring semantics, which does not
# apply here)." A codebase-wide grep confirmed this guard had zero test references for THIS class:
# the sibling test file test-coxph-general-censoring-non-wald-testing-type-rejected-reference.R
# only exercises the testing_type-rejection guard on compute_asymp_confidence_interval()/
# compute_asymp_two_sided_pval(), never this weighted-bootstrap guard, and the identically-shaped
# guard on InferenceSurvivalWeibullRegr (already covered in test-weibull-general-censoring-
# unsupported-operations-rejected-reference.R) is a different class with its own message text
# naming weighted_weibull_bootstrap_surrogate_fit() instead. Exercised via the plain public API,
# reusing the same interval-censored fixture as the sibling Cox PH file.

ic_fx <- function(seed = 3L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	des
}

test_that("compute_estimate_with_bootstrap_weights() refuses under general censoring with the documented message", {
	des <- ic_fx()
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$has_general_censoring)

	expect_error(
		inf$compute_estimate_with_bootstrap_weights(rep(2, des$get_n())),
		"Bayesian-bootstrap weighted re-estimation is not yet supported for left-/interval-censored survival data",
		fixed = TRUE
	)
})

test_that("the guard is specific to general censoring: the same call works on an ordinary right-censored design", {
	set.seed(4)
	n <- 40L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, rate = exp(0.3 * w)))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$has_general_censoring)
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	expect_no_error(inf$compute_estimate_with_bootstrap_weights(rep(2, n)))
})
