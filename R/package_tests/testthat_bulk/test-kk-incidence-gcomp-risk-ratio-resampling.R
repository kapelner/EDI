library(testthat)
library(EDI)

# inference_incidence_KK_gcomp_abstract.R's risk-ratio-specific resampling
# machinery (compute_rr_bootstrap_basic_confidence_interval,
# compute_rr_bayesian_bootstrap_log_confidence_interval,
# compute_rr_jackknife_log_se/wald_*, compute_rr_resampling_pivot and the
# compute_rr_subsampling_*/compute_rr_m_out_of_n_bootstrap_* dispatch it
# feeds) was previously only checked for existence by name
# (test-marginal-gcomp-helper-contracts.R), never actually invoked. This
# mirrors the identically-structured, already-tested non-KK sibling
# (test-incidence-gcomp-sandwich-asymptotic-inference.R) but for the real
# exported InferenceIncidKKGCompRiskRatio/RiskDiff classes and their KK
# matched-pair/reservoir cluster structure.

kk_gcomp_rr_fixture <- function(generator, seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 40L
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$overwrite_all_subject_assignments(w)
	y <- rbinom(n, 1, plogis(-0.5 + 1.0 * w + 0.4 * x))
	des$add_all_subject_responses(y)
	generator$new(des, model_formula = ~ x, verbose = FALSE)
}

test_that("RR jackknife-Wald pval/CI match an independently derived log-scale jackknife reference", {
	inf <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, 2026)
	est <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1L]
	priv <- inf$.__enclos_env__$private
	jack <- as.numeric(priv$approximate_jackknife_distribution_beta_hat_T_private(unit = "auto"))
	jack_pos <- jack[is.finite(jack) & jack > 0]
	n_units <- length(jack_pos)
	expect_gt(n_units, 1L)
	log_jack <- log(jack_pos)
	var_j <- ((n_units - 1) / n_units) * sum((log_jack - mean(log_jack))^2)
	se_log <- sqrt(var_j)
	z <- qnorm(0.975)
	expected_pval <- 2 * pnorm(-abs(log(est) / se_log))
	expected_ci <- exp(log(est) + c(-1, 1) * z * se_log)

	expect_equal(inf$compute_jackknife_wald_two_sided_pval(), expected_pval, tolerance = 1e-8)
	expect_equal(unname(inf$compute_jackknife_wald_confidence_interval()), expected_ci, tolerance = 1e-8)

	# A negative or zero null is invalid on the ratio scale and leaves the result non-estimable.
	expect_true(is.na(inf$compute_jackknife_wald_two_sided_pval(delta = -1)))
	expect_true(is.na(inf$compute_jackknife_wald_two_sided_pval(delta = 0)))
})

test_that("RR basic-bootstrap and Bayesian-bootstrap CIs reproduce the log-scale reflection formula", {
	fixture_seed <- 4041
	inf_est <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	est <- as.numeric(inf_est$compute_estimate(estimate_only = TRUE))[1L]

	withr::local_seed(777)
	inf_boot <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	boot <- as.numeric(inf_boot$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
	q <- stats::quantile(log(boot), probs = c(0.975, 0.025), names = FALSE, type = 8)
	expected_basic_ci <- exp(2 * log(est) - q)

	withr::local_seed(777)
	inf_actual <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	actual_ci <- inf_actual$compute_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "basic", show_progress = FALSE)
	expect_equal(unname(actual_ci), expected_basic_ci, tolerance = 1e-8)

	withr::local_seed(555)
	inf_bboot <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	bboot <- as.numeric(inf_bboot$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
	log_bboot <- log(bboot)
	z <- qnorm(0.975)

	se_log_b <- stats::sd(log_bboot)
	expected_wald_ci <- exp(log(est) + c(-1, 1) * z * se_log_b)
	withr::local_seed(555)
	inf_wald <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	actual_wald_ci <- inf_wald$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "wald", show_progress = FALSE)
	expect_equal(unname(actual_wald_ci), expected_wald_ci, tolerance = 1e-8)

	qb <- stats::quantile(log_bboot, probs = c(0.975, 0.025), names = FALSE, type = 8)
	expected_basic_bb_ci <- exp(2 * log(est) - qb)
	withr::local_seed(555)
	inf_basic <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, fixture_seed)
	actual_basic_bb_ci <- inf_basic$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "basic", show_progress = FALSE)
	expect_equal(unname(actual_basic_bb_ci), expected_basic_bb_ci, tolerance = 1e-8)
})

test_that("RR subsampling and m-out-of-n bootstrap dispatch run and validate their null like the jackknife path", {
	inf <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskRatio, 909)
	sub_pval <- inf$compute_subsampling_two_sided_pval(B = 15, show_progress = FALSE)
	sub_ci <- inf$compute_subsampling_confidence_interval(B = 15, show_progress = FALSE)
	expect_true(is.na(sub_pval) || (sub_pval >= 0 && sub_pval <= 1))
	expect_length(sub_ci, 2L)

	mn_pval <- inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 15, show_progress = FALSE)
	mn_ci <- inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 15, show_progress = FALSE)
	expect_true(is.na(mn_pval) || (mn_pval >= 0 && mn_pval <= 1))
	expect_length(mn_ci, 2L)

	# Delta must be strictly positive on the ratio scale for both resampling families.
	expect_true(is.na(inf$compute_subsampling_two_sided_pval(delta = 0, B = 15, show_progress = FALSE)))
	expect_true(is.na(inf$compute_subsampling_two_sided_pval(delta = -1, B = 15, show_progress = FALSE)))
	expect_true(is.na(inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = 0, B = 15, show_progress = FALSE)))
})

test_that("RD sibling ignores the RR-only overrides and uses the shared base-class jackknife/resampling path", {
	inf <- kk_gcomp_rr_fixture(InferenceIncidKKGCompRiskDiff, 2026)
	ci <- inf$compute_jackknife_wald_confidence_interval()
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
	# RD accepts a delta of zero (invalid for RR), confirming it never reaches the RR-only guard.
	expect_true(is.finite(inf$compute_jackknife_wald_two_sided_pval(delta = 0)))

	sub_ci <- inf$compute_subsampling_confidence_interval(B = 15, show_progress = FALSE)
	expect_length(sub_ci, 2L)
})
