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
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "jackknife_extreme_summary")
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
			expect_identical(f$inf$get_nonestimable_reason(), "jackknife_estimate_unavailable")
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
			expect_identical(f$inf$get_nonestimable_reason(), "jackknife_standard_error_unavailable")
		} else {
			expect_false(isTRUE(f$inf$is_nonestimable()))
		}
	}
})
