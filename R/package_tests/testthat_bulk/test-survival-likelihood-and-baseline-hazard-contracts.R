library(testthat)
library(EDI)

make_survival_likelihood_design <- function() {
	y <- c(2, 4, 5, 8, 3, 7, 9, 10, 4, 11, 6, 12, 7, 13, 8, 14)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("Cox PH and Weibull classes expose finite likelihood inference", {
	des <- make_survival_likelihood_design()
	for (inf in list(
		InferenceSurvivalCoxPHRegr$new(des, model_formula = ~ x1, verbose = FALSE),
		InferenceSurvivalWeibullRegr$new(des, model_formula = ~ x1, verbose = FALSE)
	)) {
		expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
		expect_true(is.finite(inf$compute_estimate()))
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	}
})

test_that("Weibull AFT margin terms match their analytic definition", {
	y <- c(1, 2, 4)
	eta <- c(0.1, -0.2, 0.3)
	sigma <- 0.8
	out <- EDI:::.weibull_aft_margin_terms(y, eta, sigma)
	log_H <- (log(y) - eta) / sigma
	expect_equal(out$H, exp(log_H))
	expect_equal(out$log_f, log_H - log(sigma) - log(y) - exp(log_H))
})

test_that("Clayton copula helper is stable and symmetric", {
	a <- EDI:::.clayton_copula_logA(c(0.2, 2), c(0.5, 3), theta = 1.7)
	b <- EDI:::.clayton_copula_logA(c(0.5, 3), c(0.2, 2), theta = 1.7)
	expect_equal(a, b)
	expect_true(all(is.finite(a)))
})

test_that("Weibull frailty design keeps treatment, intercept, and unique covariates", {
	w <- c(0, 1, 0, 1)
	X_cov <- cbind(w = w, `(Intercept)` = 1, x1 = 1:4, x2 = 4:1)
	X <- EDI:::.weibull_frailty_design_matrix(w, X_cov)
	expect_identical(colnames(X), c("w", "(Intercept)", "x1", "x2"))
	expect_equal(X[, "w"], w)
	expect_equal(X[, "(Intercept)"], rep(1, 4L))
})

test_that("Breslow baseline hazard is monotone and handles no-event samples", {
	y <- c(1, 2, 3, 4)
	dead <- c(1, 0, 1, 1)
	X <- cbind(x = c(-1, 0, 1, 2))
	b <- EDI:::.breslow_hazard(y, dead, X, b_null = 0.2)
	expect_equal(b$times, c(1, 3, 4))
	expect_true(all(diff(b$cumhaz) > 0))
	empty <- EDI:::.breslow_hazard(y, rep(0, 4L), X, b_null = 0.2)
	expect_length(empty$times, 0L)
	expect_length(empty$cumhaz, 0L)
})

test_that("R Breslow Cox likelihood derivatives have coherent dimensions", {
	X <- cbind(treatment = c(0, 1, 0, 1, 0, 1), x = seq(-1, 1, length.out = 6))
	y <- c(1, 2, 3, 4, 5, 6)
	dead <- c(1, 1, 0, 1, 1, 1)
	beta <- c(0.2, -0.1)
	nll <- EDI:::.cox_neg_loglik_breslow_r(X, y, dead, beta)
	score <- EDI:::.cox_score_breslow_fd_r(X, y, dead, beta)
	info <- EDI:::.cox_information_breslow_fd_r(X, y, dead, beta)
	expect_true(is.finite(nll))
	expect_length(score, ncol(X))
	expect_true(all(is.finite(score)))
	expect_identical(dim(info), c(ncol(X), ncol(X)))
	expect_equal(info, t(info), tolerance = 1e-8)
	expect_true(is.na(EDI:::.cox_neg_loglik_breslow_r(X, y, dead, beta = 0)))
})
