# Numerical-robustness review audit, 2026-11-17: With the default harden = TRUE, a perfect fit makes
# compute_estimate() return NA (reason model_fit_unavailable). Example: y = w, where the risk
# difference is exactly 1. generate_mod()'s fit_ok requires a positive HC0 variance, so the
# zero-variance fit is rejected and every column-dropping retry fails too. A failed SE check
# therefore throws away a finite point estimate, while compute_estimate(estimate_only = TRUE) returns
# 1 on the same data.
# Where: R/EDI/R/inference_incidence_risk_diff.R:369 (kind: na_where_defined).
# On commit 48765322fe90 this test failed with: Expected `is.finite(est)` to be TRUE. Differences:
# `actual`: FALSE `expected`: TRUE
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("risk-difference estimate is returned for a perfect fit even though the HC0 SE is not estimable", {
	skip("open a release TODO for this")
		set.seed(1)
		n = 40L
		x = rnorm(n)
		w = rep(0:1, n / 2)
		y = as.numeric(w)
		des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = x))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf = InferenceIncidRiskDiff$new(des, verbose = FALSE)
		est = inf$compute_estimate()
		expect_true(is.finite(est))
		expect_equal(as.numeric(est), mean(y[w == 1]) - mean(y[w == 0]), tolerance = 1e-8)
})
