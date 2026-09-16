library(testthat)
library(EDI)

test_that("KK Newcombe inverse-variance pooling handles every component availability case", {
	pool <- EDI:::KKNewcombeRiskDiffIVWCSource$private$pool_estimates_ivwc
	expect_equal(pool(0.2, 2, 0.8, 1), list(estimate = 0.6, variance = 2 / 3))
	expect_identical(pool(0.2, 2, NA, NA), list(estimate = 0.2, variance = 2))
	expect_identical(pool(NA, NA, 0.8, 1), list(estimate = 0.8, variance = 1))
	expect_true(all(is.na(unlist(pool(NA, NA, NA, NA)))))
})

test_that("logistic marginal functionals standardize both potential treatment arms", {
	des <- DesignFixediBCRD$new(n = 8L, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq(-1, 1, length.out = 8)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), 4L))
	des$add_all_subject_responses(rep(c(0, 1, 1, 0), 2L))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	X <- cbind(1, w = rep(c(0, 1), 4L), x = seq(-1, 1, length.out = 8))
	beta <- c(-0.3, 0.6, 0.2)
	X1 <- X; X1[, 2] <- 1
	X0 <- X; X0[, 2] <- 0
	risk1 <- mean(plogis(X1 %*% beta))
	risk0 <- mean(plogis(X0 %*% beta))
	expect_equal(priv$logistic_mean_from_coefs(beta, X), as.numeric(plogis(X %*% beta)))
	expect_equal(priv$logistic_marginal_functional(beta, X, "marginal_difference"), risk1 - risk0)
	expect_equal(priv$logistic_marginal_functional(beta, X, "marginal_ratio"), log(risk1 / risk0))
})

test_that("conditional-logit GLMM leaves choose reservoir combination policy", {
	expect_false(InferenceIncidKKCondLogitGLMMIVWC$private_methods$combine_reservoir_into_glmm())
	expect_true(InferenceIncidKKCondLogitGLMMOneLik$private_methods$combine_reservoir_into_glmm())
})
