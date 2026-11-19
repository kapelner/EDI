library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d0b9f7e7d (InferenceIncidRiskDiff):
# the SE and Wald CI use the Huber-White HC0 sandwich (not the classical OLS
# variance), the CI and p-value use a z reference (never t, at any n), and the
# CI bounds are not clamped to [-1, 1].

risk_diff_fixture <- function(n, seed, y = NULL) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n), x2 = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	if (is.null(y)) y <- rbinom(n, 1, 0.4)
	des$add_all_subject_responses(y)
	des
}

test_that("risk-diff SE and Wald CI are the HC0 sandwich of lm(y ~ w + x), not the classical OLS SE", {
	skip_if_not_installed("sandwich")
	for (seed in c(1L, 7L)) {
		des <- risk_diff_fixture(30L, seed)
		inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)
		est <- inf$compute_estimate()
		ci <- inf$compute_asymp_confidence_interval(alpha = 0.05)
		pval <- inf$compute_asymp_two_sided_pval()

		w <- des$get_w(); y <- des$get_y(); X <- as.matrix(des$get_X())
		fit <- lm(y ~ w + X)
		se_hc0 <- sqrt(sandwich::vcovHC(fit, type = "HC0")["w", "w"])
		se_ols <- summary(fit)$coefficients["w", "Std. Error"]
		expect_equal(unname(est), unname(coef(fit)["w"]), tolerance = 1e-10)
		expect_equal(unname(ci), unname(est + c(-1, 1) * qnorm(0.975) * se_hc0), tolerance = 1e-8)
		expect_equal(pval, 2 * pnorm(-abs(est / se_hc0)), tolerance = 1e-8)
		# and it is really not the homoskedastic OLS SE
		expect_gt(abs(se_hc0 - se_ols), 1e-4)
	}
})

test_that("risk-diff CI half-width / SE is qnorm(1 - alpha/2), never qt, even at n = 8", {
	des <- risk_diff_fixture(8L, 3L, y = c(0, 1, 0, 1, 1, 0, 0, 1))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)
	est <- inf$compute_estimate()
	se <- inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
	for (alpha in c(0.05, 0.1)) {
		ci <- inf$compute_asymp_confidence_interval(alpha = alpha)
		ratio <- unname((ci[2] - est) / se)
		expect_equal(ratio, qnorm(1 - alpha / 2), tolerance = 1e-10)
		expect_gt(abs(ratio - qt(1 - alpha / 2, df = 8 - 4)), 0.1)
	}
	expect_equal(inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(est / se)), tolerance = 1e-10)
})

test_that("risk-diff CI bounds are not clamped to [-1, 1]", {
	# treated arm all 1, control arm mostly 0: beta_hat near 1 with a sizable SE
	des <- risk_diff_fixture(8L, 2L, y = c(0, 1, 0, 1, 0, 1, 1, 1))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)
	est <- inf$compute_estimate()
	ci <- inf$compute_asymp_confidence_interval()
	expect_gt(est, 0.75)
	expect_gt(ci[[2]], 1)
})
