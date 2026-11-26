# v1.0.6-TODO-160 (coordinator note, from the v1.0.6-TODO-155 agent): the randomization-
# bootstrap sequential Monte Carlo path did not apply min_fraction_usable_samples
# (v1.0.6-TODO-2) with na.rm = TRUE. A batch prefix with too small a valid fraction is now
# "draw more" (not a stopping point), and the check runs on the full B draws exactly as on the
# one-shot path: NA with reason rand_bootstrap_too_few_valid_replicates_fraction and one
# edi_procedure_na_warning.

library(testthat)
library(EDI)

brt_frac_smc_control = function(min_draws = 50L) {
	list(mc_enable = TRUE, mc_batch_size = 25L, mc_min_draws = min_draws,
		mc_conf_level = 0.5, mc_stop_threshold = 0.2)
}

# The first 30 of B = 200 null draws are NA, so the full draws are 85% valid; a prefix of k
# draws is (k - 30) / k valid. The rest are normal quantiles, so an observed t = 3 has a tiny
# p-value and the 50% band clears the 0.2 threshold at the first prefix allowed to stop.
brt_frac_fixture = function() {
	set.seed(219)
	n = 30L
	d = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$overwrite_all_subject_assignments(rep(c(1, 0), n / 2L))
	d$add_all_subject_responses(rnorm(n))
	o = InferenceAllSimpleAverageDiff$new(d, verbose = FALSE)
	priv = o$.__enclos_env__$private
	B = 200L
	null_vals = c(rep(NA_real_, 30L), stats::qnorm(stats::ppoints(B - 30L)))
	unlockBinding("get_brt_distribution_prefix", priv)
	priv$get_brt_distribution_prefix = function(draws, target, delta, transform_arg, y0_full, zero_one_logit_clamp) null_vals[seq_len(target)]
	list(d = d, o = o, priv = priv, B = B, null_vals = null_vals,
		draws = replicate(B, list(w_b = rep(c(1, 0), n / 2L)), simplify = FALSE))
}

brt_frac_smc = function(fx, t, min_fraction, min_draws = 50L) {
	fx$priv$brt_mc_control = brt_frac_smc_control(min_draws)
	fx$priv$compute_two_sided_brt_pval_with_sequential_mc(t, fx$B, 0, "none", fx$d$get_y(), fx$draws,
		.Machine$double.eps, na.rm = TRUE, min_fraction_usable_samples = min_fraction)
}

test_that("a full set of draws below the cap is NA, not an early-stop p-value", {
	fx = brt_frac_fixture()
	p = brt_frac_smc(fx, 3, 0.95)
	expect_true(is.na(p))
	expect_true(isTRUE(attr(p, "too_few_valid_fraction")))
	expect_identical(attr(p, "n_valid"), 170L)
	expect_identical(attr(p, "n_total"), 200L)
})

test_that("a prefix with too small a valid fraction draws more before it may stop", {
	fx = brt_frac_fixture()
	pval_k = function(k) fx$priv$compute_two_sided_randomization_pval_from_t0s(fx$null_vals[seq_len(k)], 3)
	# Cap 0.8: prefixes 75..125 are 60-76% valid; 150 is 80% valid and the first allowed stop.
	expect_identical(brt_frac_smc(fx, 3, 0.8), pval_k(150L))
	# Cap 0 (check off): the first prefix with min_draws finite draws (100: 70 finite) stops.
	expect_identical(brt_frac_smc(fx, 3, 0), pval_k(100L))
	# With no early stop the result is the full-draw p-value.
	expect_identical(brt_frac_smc(fx, 3, 0.8, min_draws = fx$B), pval_k(fx$B))
})

test_that("the cached full distribution gets the same check", {
	fx = brt_frac_fixture()
	attr(fx$draws, "draws_id") = "brt-frac-test"
	full_key = paste(fx$B, formatC(0, digits = 17L, format = "fg", flag = "#"), "none", "brt-frac-test", sep = "|")
	fx$priv$set_cached_resampling_distribution("rand_bootstrap", full_key, fx$null_vals)
	p = brt_frac_smc(fx, 3, 0.95)
	expect_true(is.na(p) && isTRUE(attr(p, "too_few_valid_fraction")))
	expect_identical(brt_frac_smc(fx, 3, 0.8),
		fx$priv$compute_two_sided_randomization_pval_from_t0s(fx$null_vals, 3))
})

test_that("the public p-value records and warns like the one-shot path", {
	fx = brt_frac_fixture()
	fx$priv$brt_mc_control = brt_frac_smc_control()
	expect_warning(p <- fx$o$compute_rand_bootstrap_two_sided_pval(B = fx$B, show_progress = FALSE),
		"rand_bootstrap_too_few_valid_replicates_fraction", class = "edi_procedure_na_warning")
	expect_identical(p, NA_real_)
	expect_no_warning(p_08 <- fx$o$compute_rand_bootstrap_two_sided_pval(B = fx$B, show_progress = FALSE,
		min_fraction_usable_samples = 0.8))
	expect_true(is.finite(p_08))
	# Without sequential MC the one-shot path gives the same NA for the same draws.
	fx$priv$brt_mc_control = NULL
	unlockBinding("approximate_rand_bootstrap_distribution_beta_hat_T", fx$o)
	fx$o$approximate_rand_bootstrap_distribution_beta_hat_T = function(...) fx$null_vals
	expect_warning(p_one <- fx$o$compute_rand_bootstrap_two_sided_pval(B = fx$B, show_progress = FALSE),
		"rand_bootstrap_too_few_valid_replicates_fraction", class = "edi_procedure_na_warning")
	expect_identical(p_one, NA_real_)
})
