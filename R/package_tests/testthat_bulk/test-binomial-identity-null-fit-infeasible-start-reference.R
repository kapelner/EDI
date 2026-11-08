library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff (v1.0.5, found by the pre-push calibration endpoint check
# 2026-11-08): the identity-link kernel stops after one iteration when its start has a fitted
# probability outside [0, 1]. On the pre-push sign-check replicate (incidence, n = 313, prob_T = 0.2,
# effect 1.5, `~.`) every start fit_null() tried at delta = 0.49 was infeasible (max mu 1.08-1.09)
# although the null MLE is interior (max mu 0.993), so fit_null() returned NULL there and the gradient
# CI's upper endpoint stopped at 0.4874 (gradient p 0.030) instead of the root 0.4781. fit_null() now
# also tries a feasible start (covariates 0, beta_T = delta, intercept clamped into the feasible range).

sign_check_rep <- function() {
	set.seed(1e6 * 2L + 1e4 + 7L * 313L + 1L)
	X <- data.frame(x1 = stats::rnorm(313), x2 = stats::rbinom(313, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = 313, response_type = "incidence", prob_T = 0.2)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(ys = stats::rbinom(313, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2 + 1.5 * w)))
	des
}

test_that("the feasible start keeps every fitted probability in [0, 1]", {
	X <- cbind(1, c(0, 1, 1, 0), c(-2, 3, 0.5, 1))
	b <- EDI:::edi_binomial_identity_feasible_start(X, c(0, 1, 1, 1), 2L, 0.9)
	mu <- as.numeric(X %*% b)
	expect_true(all(mu >= 1e-3 - 1e-12 & mu <= 1 - 1e-3 + 1e-12))
	expect_equal(b[2], 0.9)
	expect_equal(b[3], 0)
	expect_null(EDI:::edi_binomial_identity_feasible_start(X[, -1, drop = FALSE], c(0, 1, 1, 1), 1L, 0.2))
	expect_null(EDI:::edi_binomial_identity_feasible_start(X, c(0, 1, 1, 1), 2L, 1.2))
})

test_that("sign-check replicate: the null fit at delta = 0.49 converges and CI endpoints are roots", {
	des <- sign_check_rep()
	o <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~ .)
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	f <- spec$fit_null(0.49)
	expect_false(is.null(f))
	expect_true(isTRUE(f$converged))
	expect_lt(max(spec$X %*% f$b), 1)
	ci <- suppressWarnings(o$compute_gradient_confidence_interval())
	expect_equal(ci[[2]], 0.4780708, tolerance = 1e-4)
	for (d in ci) {
		p <- suppressWarnings(InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~ .)$compute_gradient_two_sided_pval(delta = d))
		expect_equal(p, 0.05, tolerance = 2e-3)
	}
})
