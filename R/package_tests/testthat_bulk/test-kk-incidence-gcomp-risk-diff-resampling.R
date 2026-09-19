library(testthat)
library(EDI)

# inference_incidence_KK_gcomp_abstract.R's shared jackknife/bootstrap
# resampling machinery, exercised on InferenceIncidKKGCompRiskDiff (linear
# RD scale), was previously only smoke-checked for finiteness
# (test-kk-incidence-gcomp-risk-ratio-resampling.R's "RD sibling ignores the
# RR-only overrides" case), never checked against an independent reference.
# This mirrors that RR-focused file's pattern but on the additive scale.

kk_gcomp_rd_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 40L
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$overwrite_all_subject_assignments(w)
	y <- rbinom(n, 1, plogis(-0.5 + 1.0 * w + 0.4 * x))
	des$add_all_subject_responses(y)
	InferenceIncidKKGCompRiskDiff$new(des, model_formula = ~ x, verbose = FALSE)
}

test_that("RD jackknife-Wald pval/CI match an independently derived linear-scale jackknife reference", {
	inf <- kk_gcomp_rd_fixture(2026)
	est <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1L]
	priv <- inf$.__enclos_env__$private
	jack <- as.numeric(priv$approximate_jackknife_distribution_beta_hat_T_private(unit = "auto"))
	jack_f <- jack[is.finite(jack)]
	n_units <- length(jack_f)
	expect_gt(n_units, 1L)
	var_j <- ((n_units - 1) / n_units) * sum((jack_f - mean(jack_f))^2)
	se_j <- sqrt(var_j)
	z <- qnorm(0.975)
	expected_pval <- 2 * pnorm(-abs(est / se_j))
	expected_ci <- est + c(-1, 1) * z * se_j

	expect_equal(inf$compute_jackknife_wald_two_sided_pval(), expected_pval, tolerance = 1e-8)
	expect_equal(unname(inf$compute_jackknife_wald_confidence_interval()), expected_ci, tolerance = 1e-8)

	# Unlike RR (which rejects delta <= 0 on the ratio scale), RD accepts a
	# delta of exactly 0, confirming it never reaches an RR-only guard.
	expect_true(is.finite(inf$compute_jackknife_wald_two_sided_pval(delta = 0)))
})

test_that("RD basic-bootstrap CI reproduces the linear-scale reflection formula", {
	fixture_seed <- 4041
	inf_est <- kk_gcomp_rd_fixture(fixture_seed)
	est <- as.numeric(inf_est$compute_estimate(estimate_only = TRUE))[1L]

	withr::local_seed(777)
	inf_boot <- kk_gcomp_rd_fixture(fixture_seed)
	boot <- as.numeric(inf_boot$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
	q <- stats::quantile(boot, probs = c(0.975, 0.025), names = FALSE, type = 8)
	expected_basic_ci <- 2 * est - q

	withr::local_seed(777)
	inf_actual <- kk_gcomp_rd_fixture(fixture_seed)
	actual_ci <- inf_actual$compute_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "basic", show_progress = FALSE)
	expect_equal(unname(actual_ci), expected_basic_ci, tolerance = 1e-8)
})

test_that("RD subsampling and m-out-of-n bootstrap dispatch run and produce valid intervals", {
	inf <- kk_gcomp_rd_fixture(909)
	sub_pval <- inf$compute_subsampling_two_sided_pval(B = 15, show_progress = FALSE)
	sub_ci <- inf$compute_subsampling_confidence_interval(B = 15, show_progress = FALSE)
	expect_true(is.na(sub_pval) || (sub_pval >= 0 && sub_pval <= 1))
	expect_length(sub_ci, 2L)

	mn_pval <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 15, show_progress = FALSE)
	mn_ci <- inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 15, show_progress = FALSE)
	expect_true(is.na(mn_pval) || (mn_pval >= 0 && mn_pval <= 1))
	expect_length(mn_ci, 2L)

	# RD accepts delta = 0, unlike RR's strictly-positive-ratio requirement.
	expect_true(is.finite(inf$compute_subsampling_two_sided_pval(delta = 0, B = 15, show_progress = FALSE)))
	expect_true(is.finite(inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = 0, B = 15, show_progress = FALSE)))
})
