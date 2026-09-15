library(testthat)
library(EDI)

make_incidence_contract_design <- function() {
	y <- rep(c(0, 1, 1, 0), 5L)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("incidence risk-difference estimators agree with the unadjusted arm contrast", {
	des <- make_incidence_contract_design()
	w <- des$get_w()
	y <- des$get_y()
	expected <- mean(y[w == 1]) - mean(y[w == 0])

	for (generator in list(InferenceIncidRiskDiff, InferenceIncidBinomialIdentityRiskDiff)) {
		inf <- generator$new(des, model_formula = ~ 1, verbose = FALSE)
		expect_equal(inf$compute_estimate(estimate_only = TRUE), expected, tolerance = 1e-8)
		expect_equal(inf$compute_estimate(), expected, tolerance = 1e-8)
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	}
})

test_that("incidence estimators reject incompatible response designs", {
	continuous <- DesignFixediBCRD$new(n = 4L, response_type = "continuous", verbose = FALSE)
	continuous$add_all_subjects_to_experiment(data.frame(x = 1:4))
	continuous$overwrite_all_subject_assignments(c(0, 1, 0, 1))
	continuous$add_all_subject_responses(1:4)
	expect_error(InferenceIncidRiskDiff$new(continuous), "incidence")
})

test_that("conditional-logistic negative log-likelihood matches its Bernoulli definition", {
	X <- cbind(1, treatment = c(0, 1, 0, 1), x = c(-1, -0.5, 0.5, 1))
	y <- c(0, 1, 0, 1)
	b <- c(-0.2, 0.7, 0.3)
	eta <- as.numeric(X %*% b)
	expected <- -sum(y * eta - log1p(exp(eta)))
	expect_equal(EDI:::conditional_logit_neg_loglik(X, y, b), expected, tolerance = 1e-12)
})

test_that("conditional-logit GLMM numerical helpers remain stable at extreme inputs", {
	priv <- EDI:::InferenceAbstractKKCondLogitGLMM$private_methods
	expect_equal(priv$log_sum_exp(c(1000, 999)), 1000 + log1p(exp(-1)), tolerance = 1e-12)
	expect_equal(priv$log1pexp(1000), 1000, tolerance = 1e-12)
	expect_equal(priv$log1pexp(-1000), 0, tolerance = 1e-12)
})

test_that("KK incidence leaves advertise their intended response and estimands", {
	expect_identical(EDI:::InferenceIncidKKGEE$private_methods$gee_response_type(), "incidence")
	expect_identical(EDI:::InferenceIncidKKGCompRiskDiff$private_methods$get_estimand_type(), "RD")
	expect_identical(EDI:::InferenceIncidKKGCompRiskRatio$private_methods$get_estimand_type(), "RR")
})
