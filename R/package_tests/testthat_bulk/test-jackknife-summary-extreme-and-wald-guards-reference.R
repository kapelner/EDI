library(testthat)
library(EDI)

# InferenceJackknife (inference_all_abstract_jackknife.R) has three "jackknife_*" nonestimable
# guards with no test reference anywhere, distinct from the sibling guards already covered by
# test-jackknife-deletion-draws-and-summary-reference.R (original_estimate_unavailable,
# nonfinite_replicate_estimates, extreme_finite_estimates all closed there; that file's own
# "|bias| > 2 * se or extreme summary" case accepts either outcome and never actually pins the
# extreme_summary reason -- confirmed by hand-computation that its specific jack values don't
# trip any of the three final-stage checks):
#   1. "jackknife_extreme_summary": compute_jackknife_summary()'s final-stage check
#      (|theta_j| / se_j / |bias_j| > 2*se_j exceeding the separation threshold) fires even though
#      the raw replicates individually pass bootstrap_estimates_extreme(). Reached with replicates
#      c(9e5, -9e5, 9e5, -9e5): each value is individually under the 1e6 threshold and the
#      97.5%-2.5% width (1.8e6) is far under the width check's own much larger bound
#      (1e6 * scale_ref), so bootstrap_estimates_extreme() returns FALSE -- but the delete-1
#      variance formula still produces se_j ~= 1.56e6, over the threshold.
#   2. "jackknife_estimate_unavailable" (the OUTER cache_nonestimable_se(...) in
#      compute_jackknife_wald_two_sided_pval()/compute_jackknife_wald_confidence_interval(), distinct
#      from compute_jackknife_summary()'s own inner cache_nonestimable_estimate(
#      "jackknife_original_estimate_unavailable")): reached by directly seeding the jackknife-summary
#      cache with a NA estimate, bypassing compute_jackknife_summary() entirely, then calling the
#      public Wald methods.
#   3. "jackknife_standard_error_unavailable" (same outer-guard shape as (2), but for a non-finite
#      std_error on an otherwise-finite estimate -- a combination compute_jackknife_summary() never
#      actually produces on its own since var_j is always finite/non-negative for finite replicates,
#      so this is only reachable by direct cache injection, confirming the guard is a genuine
#      defensive check on a state compute_jackknife_summary() cannot organically produce).

smd_boot_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("compute_jackknife_summary caches 'jackknife_extreme_summary' when se_j exceeds the separation threshold", {
	f <- smd_boot_fixture()
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", f$priv)
	f$priv$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") c(9e5, -9e5, 9e5, -9e5)

	s <- f$priv$compute_jackknife_summary("observation")
	expect_true(all(is.na(c(s$estimate, s$bias, s$std_error))))
	expect_identical(length(s$distribution), 4L)
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(f$priv$cached_values$procedure_failure_reason$jackknife, "jackknife_extreme_summary")
})

test_that("compute_jackknife_summary rejects finite draws when jackknife bias exceeds twice its standard error", {
	f <- smd_boot_fixture()
	theta_hat <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))[1L]
	jack <- theta_hat + c(0.099, 0.100, 0.101, 0.102)
	n_units <- length(jack)
	jack_bar <- mean(jack)
	bias_j <- (n_units - 1) * (jack_bar - theta_hat)
	se_j <- sqrt(((n_units - 1) / n_units) * sum((jack - jack_bar)^2))

	# Independently establish that the replicate-level extreme checks do not explain
	# this result; the final |bias_j| > 2 * se_j clause is the intended guard.
	# AverageDiff inherits the fallback EDI separation threshold rather than
	# defining a class-local bootstrap threshold.
	max_abs <- EDI:::EDI_SEPARATION_THRESHOLD
	scale_ref <- max(1, abs(theta_hat), stats::median(abs(jack)))
	jack_width <- diff(stats::quantile(jack, probs = c(0.025, 0.975), names = FALSE, type = 8))
	expect_true(all(is.finite(jack)))
	expect_true(all(abs(jack) < max_abs))
	expect_true(jack_width < max_abs * scale_ref)
	expect_true(is.finite(theta_hat - bias_j) && abs(theta_hat - bias_j) < max_abs)
	expect_true(se_j < max_abs)
	expect_gt(abs(bias_j), 2 * se_j)

	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", f$priv)
	f$priv$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack
	s <- f$priv$compute_jackknife_summary("observation")
	expect_true(all(is.na(c(s$estimate, s$bias, s$std_error))))
	expect_equal(s$distribution, jack, tolerance = 0)
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(f$priv$cached_values$procedure_failure_reason$jackknife, "jackknife_extreme_summary")
})

test_that("compute_jackknife_wald_two_sided_pval/CI cache 'jackknife_estimate_unavailable' when the cached summary estimate is NA", {
	for (harden in c(TRUE, FALSE)) {
		f <- smd_boot_fixture()
		f$priv$harden <- harden
		f$priv$cached_values$jackknife_summary <- list(
			observation = list(estimate = NA_real_, bias = NA_real_, std_error = NA_real_, distribution = c(1, 2, 3))
		)

		pval <- f$inf$compute_jackknife_wald_two_sided_pval(delta = 0, unit = "observation")
		expect_true(is.na(pval))
		if (harden) {
			expect_identical(f$priv$cached_values$procedure_failure_reason$jackknife, "jackknife_estimate_unavailable")
		} else {
			expect_false(isTRUE(f$inf$is_nonestimable()))
		}
	}
})

test_that("compute_jackknife_wald_two_sided_pval/CI cache 'jackknife_standard_error_unavailable' when the cached summary std_error is NA but estimate is finite", {
	for (harden in c(TRUE, FALSE)) {
		f <- smd_boot_fixture()
		f$priv$harden <- harden
		f$priv$cached_values$jackknife_summary <- list(
			observation = list(estimate = 0.5, bias = 0, std_error = NA_real_, distribution = c(1, 2, 3))
		)

		ci <- f$inf$compute_jackknife_wald_confidence_interval(unit = "observation")
		expect_true(all(is.na(ci)))
		if (harden) {
			expect_identical(f$priv$cached_values$procedure_failure_reason$jackknife, "jackknife_standard_error_unavailable")
		} else {
			expect_false(isTRUE(f$inf$is_nonestimable()))
		}
	}
})

test_that("jackknife Wald p-values and intervals center on the bias-corrected jackknife estimate", {
	f <- smd_boot_fixture()
	f$priv$cached_values$jackknife_summary <- list(
		observation = list(estimate = 0.25, bias = 0.5, std_error = 0.1, distribution = c(0.1, 0.2, 0.3))
	)

	expect_equal(
		f$inf$compute_jackknife_wald_two_sided_pval(delta = 0, unit = "observation"),
		2 * pnorm(-2.5),
		tolerance = 1e-12
	)
	expect_equal(
		unname(f$inf$compute_jackknife_wald_confidence_interval(alpha = 0.05, unit = "observation")),
		0.25 + c(-1, 1) * qnorm(0.975) * 0.1,
		tolerance = 1e-12
	)
})
