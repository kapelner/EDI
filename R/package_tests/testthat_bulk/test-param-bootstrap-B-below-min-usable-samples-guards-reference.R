library(testthat)
library(EDI)

# inference_all_abstract_param_boot.R has two sibling early-argument guards, both fired immediately
# after the should_run_asserts() block and before any actual bootstrap fitting: compute_lik_ratio_
# bootstrap_two_sided_pval() stop()s "B must be at least min_number_usable_samples for bootstrap LR
# calibration." and compute_param_bootstrap_estimate() stop()s "B must be at least min_number_
# usable_samples for parametric-bootstrap estimate bias correction." whenever B <
# min_number_usable_samples. Both were zero-hit despite InferenceCountHurdleNegBin's parametric-
# bootstrap paths being otherwise well-tested (test-hurdle-negbin-parametric-bootstrap-lr.R).

hurdle_negbin_fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	x1 <- rnorm(n); x2 <- rnorm(n)
	w <- rep(c(1, 0), length.out = n)
	p_pos <- plogis(-0.35 + 0.75 * w + 0.30 * x1 - 0.20 * x2)
	mu <- exp(0.45 + 0.30 * w + 0.20 * x1 - 0.15 * x2)
	theta <- 2.5
	u_pos <- rbinom(n, 1L, p_pos)
	cdf0 <- pnbinom(0, size = theta, mu = mu)
	u_trunc <- cdf0 + (1 - cdf0) * runif(n)
	y_pos <- pmax(1L, as.integer(qnbinom(u_trunc, size = theta, mu = mu)))
	y <- ifelse(u_pos == 1L, y_pos, 0L)

	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	InferenceCountHurdleNegBin$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
}

test_that("compute_lik_ratio_bootstrap_two_sided_pval(): B below min_number_usable_samples errors with the documented message", {
	inf <- hurdle_negbin_fx(seed = 1L)
	expect_error(
		inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 3L, min_number_usable_samples = 5L, show_progress = FALSE),
		"B must be at least min_number_usable_samples for bootstrap LR calibration\\."
	)
})

test_that("compute_param_bootstrap_estimate(): B below min_number_usable_samples errors with the documented message", {
	inf <- hurdle_negbin_fx(seed = 2L)
	expect_error(
		inf$compute_param_bootstrap_estimate(B = 3L, min_number_usable_samples = 5L, show_progress = FALSE),
		"B must be at least min_number_usable_samples for parametric-bootstrap estimate bias correction\\."
	)
})
