# Numerical-robustness review audit, 2026-11-17: With large but valid counts (cell means around 2e4)
# and the class's default zero cold start, the first IRLS step from beta = 0 overshoots by a factor
# of about 1e4. Ten step-halvings (smallest factor 2^-9) cannot bring eta below about 39, so every
# trial is rejected and the kernel stops at b = 0 with converged = FALSE. InferenceCountPoisson's
# fit_ok never checks converged, so compute_estimate() returns 0 instead of the glm MLE log(2) ~
# 0.69, and the Wald SE is evaluated at b = 0.
# Where: R/EDI/R/inference_count_poisson.R:847 (kind: converged_unchecked).
# On commit 48765322fe90 this test failed with: Expected `as.numeric(kfit$b)` to equal
# `unname(stats::coef(ref0))`. Differences: 2/2 mismatches (average diff: 5.29) [1] 0 - 9.938 ==
# -9.938 [2] 0 - 0.651 == -0.651
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("Poisson estimate matches glm for large counts under the default zero cold start", {
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
		kfit = EDI:::fast_poisson_regression_cpp(cbind(1, w), as.numeric(y))
		ref0 = stats::glm(y ~ w, family = stats::poisson(), data = data.frame(y = y, w = w))
		expect_equal(as.numeric(kfit$b), unname(stats::coef(ref0)), tolerance = 1e-4)
		inf = InferenceCountPoisson$new(des, verbose = FALSE)
		est = as.numeric(inf$compute_estimate())
		expect_equal(est, unname(stats::coef(ref)["w"]), tolerance = 1e-4)
})
