# Numerical-robustness review audit, 2026-11-17: InferenceCountRobustPoisson fits with
# fast_poisson_regression_cpp from a zero start. With counts around 2e4 the first IRLS step cannot be
# backtracked into an accepted step in 10 halvings, so the kernel returns b = 0 with converged =
# FALSE. fit_count_model_with_var only checks that the coefficients are finite, so the class reports
# a treatment estimate of 0 (with a sandwich SE evaluated at b = 0) instead of the Poisson MLE of
# about 0.69.
# Where: R/EDI/R/inference_count_robust_poisson.R:243 (kind: converged_unchecked).
# On commit 48765322fe90 this test failed with: Expected `est` to equal
# `unname(stats::coef(ref)["w"])`. Differences: 1/1 mismatches [1] 0 - 0.694 == -0.694
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("robust Poisson estimate matches glm for large counts under the default zero cold start", {
	skip("open a release TODO for this")
		set.seed(1)
		n = 40
		X = data.frame(x1 = rnorm(n))
		des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w = des$get_w()
		y = stats::rpois(n, 2e4 * exp(log(2) * w + 0.1 * X$x1))
		des$add_all_subject_responses(y)
		ref = stats::glm(y ~ w + x1, family = stats::poisson(), data = data.frame(y = y, w = w, x1 = X$x1))
		inf = InferenceCountRobustPoisson$new(des, verbose = FALSE)
		est = as.numeric(inf$compute_estimate())
		expect_equal(est, unname(stats::coef(ref)["w"]), tolerance = 1e-4)
})
