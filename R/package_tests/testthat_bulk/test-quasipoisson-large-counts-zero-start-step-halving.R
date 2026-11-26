# Numerical-robustness review audit, 2026-11-17: InferenceCountQuasiPoisson uses the same zero-start
# IRLS kernel. With counts around 2e4 the step-halving fails on the first iteration and the kernel
# returns b = 0 with converged = FALSE. fit_ok accepts that fit because the Pearson dispersion at mu
# = 1 is huge but finite, so compute_estimate() returns 0 instead of the glm quasi-Poisson
# coefficient of about 0.69.
# Where: R/EDI/R/inference_count_quasipoisson.R:317 (kind: converged_unchecked).
# On commit 48765322fe90 this test failed with: Expected `est` to equal
# `unname(stats::coef(ref)["w"])`. Differences: 1/1 mismatches [1] 0 - 0.694 == -0.694
# Tracked as v1.0.6-TODO-200; skip removed 2026-11-23 (kernel zero-start retry + fit_ok converged check).

test_that("quasi-Poisson estimate matches glm for large counts under the default zero cold start", {
		set.seed(1)
		n = 40
		X = data.frame(x1 = rnorm(n))
		des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		w = des$get_w()
		y = stats::rpois(n, 2e4 * exp(log(2) * w + 0.1 * X$x1))
		des$add_all_subject_responses(y)
		ref = stats::glm(y ~ w + x1, family = stats::quasipoisson(), data = data.frame(y = y, w = w, x1 = X$x1))
		inf = InferenceCountQuasiPoisson$new(des, verbose = FALSE)
		est = as.numeric(inf$compute_estimate())
		expect_equal(est, unname(stats::coef(ref)["w"]), tolerance = 1e-4)
})
