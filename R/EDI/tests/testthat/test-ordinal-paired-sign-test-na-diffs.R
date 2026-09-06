test_that("InferenceOrdinalPairedSignTest ignores NA pair differences instead of propagating NaN", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# shared() computed pos/neg via sum(diffs > 0)/sum(diffs < 0) with no
	# na.rm, so a single NA in y_matched_diffs (e.g. a partially-resolved
	# pair) made pos/neg/n_eff/p_hat all NA/NaN instead of being screened
	# out of the sign count, producing a spurious NaN estimate instead of
	# either a valid estimate from the remaining pairs or the intended
	# "no discordant pairs" non-estimable path.
	set.seed(4501L)
	x_dat <- data.frame(x = rnorm(8L))
	des <- DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, 8L, replace = TRUE))

	inf <- InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	# Force the matched-pair diffs cache directly, injecting an NA among
	# otherwise valid, non-tied differences.
	priv$cached_values$KKstats <- list(y_matched_diffs = c(2, -1, NA_real_, 1, -2))
	priv$cached_values$beta_hat_T <- NULL
	priv$cached_values$s_beta_hat_T <- NULL

	est <- inf$compute_estimate()

	expect_true(is.finite(est))
	expect_false(is.nan(est))
	# 4 usable (non-NA) diffs: 2 positive, 2 negative -> p_hat = 0.5 -> beta_hat_T = 0
	expect_equal(est, 0)
})
