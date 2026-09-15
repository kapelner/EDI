library(testthat)
library(EDI)

make_contract_design <- function(response_type, y, w = rep(c(0, 1), length.out = length(y))) {
	n <- length(y)
	X <- data.frame(x1 = seq(-1.5, 1.5, length.out = n), x2 = rep(c(-1, 1), length.out = n))
	des <- DesignFixediBCRD$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("Lin estimator matches its centered interacted OLS definition", {
	y <- c(1.2, 2.5, 1.8, 4.1, 3.0, 5.4, 4.2, 6.8, 5.5, 7.1, 6.3, 8.4)
	w <- rep(c(0, 1), 6L)
	des <- make_contract_design("continuous", y, w)
	inf <- InferenceContinLin$new(des, model_formula = ~ x1 + x2, verbose = FALSE)

	X <- des$get_X()
	Xc <- sweep(as.matrix(X), 2L, colMeans(X), "-")
	manual <- lm.fit(cbind(1, w, Xc, w * Xc), y)$coefficients[2L]
	expect_equal(inf$compute_estimate(estimate_only = TRUE), unname(manual), tolerance = 1e-10)
	expect_equal(inf$compute_estimate(), unname(manual), tolerance = 1e-10)
	expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval(delta = 0)))
})

test_that("Lin without covariates reduces to the treatment-control mean difference", {
	y <- c(1, 4, 2, 6, 3, 8, 5, 9)
	w <- rep(c(0, 1), 4L)
	des <- make_contract_design("continuous", y, w)
	inf <- InferenceContinLin$new(des, model_formula = ~ 1, verbose = FALSE)
	expect_equal(inf$compute_estimate(), mean(y[w == 1]) - mean(y[w == 0]), tolerance = 1e-10)
})

test_that("right-censored rank-survival classes expose finite public inference", {
	y <- c(2, 4, 5, 8, 3, 7, 9, 10, 4, 11, 6, 12, 7, 13, 8, 14)
	des <- make_contract_design("survival", y)

	for (generator in list(InferenceSurvivalLogRank, InferenceSurvivalGehanWilcox)) {
		inf <- generator$new(des, verbose = FALSE)
		expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
		expect_true(is.finite(inf$compute_estimate()))
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
		expect_error(inf$compute_rand_confidence_interval(), "not supported")
	}

	logrank <- InferenceSurvivalLogRank$new(des, verbose = FALSE)
	expect_true(is.finite(logrank$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()))
	expect_error(logrank$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(1), "non-zero delta")
	gehan <- InferenceSurvivalGehanWilcox$new(des, verbose = FALSE)
	expect_error(gehan$compute_asymp_two_sided_pval(1), "non-zero delta")
})

test_that("KM median-difference class covers estimate and log-rank companion test", {
	y <- c(2, 4, 5, 8, 3, 7, 9, 10, 4, 11, 6, 12, 7, 13, 8, 14)
	des <- make_contract_design("survival", y)
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
	expect_true(is.finite(inf$compute_estimate()))
	expect_true(is.finite(inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect()))
	expect_error(inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(1), "non-zero delta")
})
