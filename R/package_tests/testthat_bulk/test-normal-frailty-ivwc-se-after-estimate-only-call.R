# Numerical-robustness review audit, 2026-11-19: InferenceSurvivalGLMMWeibullFrailtyNormalIVWC's
# shared() returns early when beta_hat_T is cached (line 353), regardless of estimate_only. After
# compute_estimate(estimate_only = TRUE), which returns at line 384/391/395 without setting
# s_beta_hat_T, the Wald CI and p-value are NA for the rest of the object's life, although the SE is
# defined (a fresh object gives a finite one).
# Where: R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R:353 (kind: na_where_defined).
# On commit 0231668c948b this test failed with: Expected `all(is.finite(ci))` to be TRUE.
# Differences: `actual`: FALSE `expected`: TRUE
# Covered and fixed by v1.0.6-TODO-132 (2026-11-19): estimate_only now runs the full fit, which caches the SE.

test_that("Normal-frailty IVWC Wald CI stays finite after an estimate-only call", {
		make_des = function() {
			set.seed(2L)
			n = 40L
			x1 = rnorm(n)
			des = DesignSeqOneByOneKK14$new(response_type = "survival", n = n, design_formula = ~ x1, verbose = FALSE, lambda = 0.07)
			for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
			w = des$get_w()
			g = rep(rnorm(n / 2L, 0, 0.3), each = 2L)
			y = rexp(n, exp(-(0.4 * w + g)))
			for (i in seq_len(n)) des$add_one_subject_response(i, y[i])
			des
		}
		inf_ref = InferenceSurvivalGLMMWeibullFrailtyNormalIVWC$new(make_des(), verbose = FALSE)
		ci_ref = suppressWarnings(inf_ref$compute_asymp_confidence_interval(0.05))
		expect_true(all(is.finite(ci_ref)))
		inf = InferenceSurvivalGLMMWeibullFrailtyNormalIVWC$new(make_des(), verbose = FALSE)
		inf$compute_estimate(estimate_only = TRUE)
		ci = suppressWarnings(inf$compute_asymp_confidence_interval(0.05))
		expect_true(all(is.finite(ci)))
		expect_equal(unname(ci), unname(ci_ref), tolerance = 1e-6)
})
