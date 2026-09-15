library(testthat)
library(EDI)

make_regression_contract_design <- function(y) {
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("continuous OLS agrees with the corresponding lm coefficient", {
	y <- c(1.1, 2.8, 1.6, 4.0, 2.9, 5.1, 4.2, 6.5, 5.0, 7.4, 6.2, 8.1)
	des <- make_regression_contract_design(y)
	w <- des$get_w()
	x1 <- des$get_X()[, "x1"]
	inf <- InferenceContinOLS$new(des, model_formula = ~ x1, verbose = FALSE)
	expect_equal(inf$compute_estimate(estimate_only = TRUE), unname(coef(lm(y ~ w + x1))[[2]]), tolerance = 1e-10)
	expect_true(is.finite(inf$compute_estimate()))
	expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
})

test_that("robust and quantile regression expose finite median-scale effects", {
	skip_if_not_installed("quantreg")
	y <- c(1, 3, 2, 4, 3, 6, 4, 8, 5, 9, 6, 30, 7, 11, 8, 12)
	des <- make_regression_contract_design(y)
	robust <- InferenceContinRobustRegr$new(des, model_formula = ~ x1, method = "MM", verbose = FALSE)
	quantile <- InferenceContinQuantileRegr$new(des, model_formula = ~ x1, tau = 0.5, verbose = FALSE)
	for (inf in list(robust, quantile)) {
		expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
		expect_true(is.finite(inf$compute_estimate()))
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	}
	expect_error(InferenceContinQuantileRegr$new(des, tau = 0), "tau")
})

test_that("ordinal ridit reports scores and treatment mean consistently", {
	y <- rep(1:4, 4L)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)

	for (reference in c("control", "pooled")) {
		inf <- InferenceOrdinalRidit$new(des, reference = reference, verbose = FALSE)
		scores <- inf$get_ridit_scores()
		expect_length(scores, length(y))
		level_scores <- tapply(scores, y, mean)
		expect_true(all(diff(level_scores) > 0))
		expect_true(is.finite(inf$get_mean_ridit_treatment()))
		expect_true(is.finite(inf$compute_estimate()))
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
	}
	expect_error(InferenceOrdinalRidit$new(des, reference = "invalid"), "reference")
})

test_that("stratified Cox helper functions identify informative strata", {
	w <- c(0, 1, 0, 1, 0, 0)
	y <- c(1, 2, 3, 4, 5, 6)
	dead <- c(1, 1, 1, 0, 1, 1)
	strata <- c(1L, 1L, 2L, 2L, 3L, 3L)
	keep <- EDI:::cox_partial_likelihood_informative_rows(strata, y, dead, w)
	expect_identical(keep, 1:4)

	X <- cbind(w = w, constant = 1, varying = seq_along(w))
	info <- EDI:::cox_partial_likelihood_strata_info(X, length(w))
	expect_length(info$strata_id, length(w))
	reduced <- EDI:::cox_partial_likelihood_reduce_covariates(w, y, X[, -1, drop = FALSE])
	expect_identical(dim(reduced), c(length(w), 2L))
	expect_true(all(is.finite(reduced)))
})
