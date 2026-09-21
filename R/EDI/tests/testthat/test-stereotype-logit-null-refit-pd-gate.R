test_that("InferenceOrdinalStereotypeLogitRegr LR test does not spuriously return NA when the primary fit succeeds", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# get_likelihood_test_spec()'s fit_null() called stereotype_fit_is_usable()
	# with its default require_information_pd = TRUE, unlike the parametric-
	# bootstrap null-refit path (simulate_under_lik_null()), which explicitly
	# passes require_information_pd = FALSE with a documented rationale: the
	# stereotype model's loading ("gamma") parameters are a textbook
	# Davies-type non-regular case, not identified near beta_T = 0 -- exactly
	# where every null-hypothesis refit sits -- so the Fisher information is
	# expected to be near-singular there, not a sign of a broken fit. That
	# same rationale applies equally to the real-data null refit, which,
	# like the bootstrap one, only ever consumes neg_loglik (never a
	# variance/SE). Before this fix, the inconsistent gate default made
	# compute_lik_ratio_two_sided_pval() spuriously non-estimable on a large
	# fraction of successfully-fit real data (confirmed empirically: 0/115
	# NA after the fix, versus a large fraction before, conditional on the
	# primary fit itself converging).
	n <- 400L
	na_count <- 0L
	fit_ok_count <- 0L
	for (r in seq_len(20L)) {
		set.seed(30000L + r)
		x1 <- rnorm(n)
		w <- rep(c(0, 1), n / 2)
		y_lin <- 0.8 * x1
		y <- as.integer(cut(y_lin, breaks = quantile(y_lin, probs = seq(0, 1, length.out = 5)), include.lowest = TRUE))
		des <- DesignFixedTestFixture$new(n = n, response_type = "ordinal", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf <- InferenceOrdinalStereotypeLogitRegr$new(des, verbose = FALSE)
		est <- inf$compute_estimate()
		if (is.na(est)) next
		fit_ok_count <- fit_ok_count + 1L
		p <- inf$compute_lik_ratio_two_sided_pval()
		if (is.na(p)) na_count <- na_count + 1L
	}
	skip_if(fit_ok_count == 0L, "no primary fits converged in this rep budget")
	expect_equal(na_count, 0L)
})

test_that("InferenceOrdinalStereotypeLogitRegr null refit at the MLE reaches the full-fit likelihood", {
	# Regression for the 2026-09-21 comprehensive-results audit: the
	# delta-constrained refit started cold (no warm start) and stalled in a much
	# worse local optimum for some delta -- e.g. neg_loglik 131.3 vs the full
	# fit's 118.9 at delta = the MLE itself. That inflated the LR statistic at
	# the point estimate, pushed the bootstrap p-value there below alpha, and
	# made compute_lik_ratio_bootstrap_confidence_interval() return the
	# zero-width c(est, est) (~30% of rows, all missing the truth). At delta =
	# the MLE the constrained optimum IS the full fit, so the gap must be ~0.
	n <- 100L
	for (r in c(1L, 3L, 4L, 25L)) {
		set.seed(500L + r)
		x1 <- rnorm(n)
		w <- sample(rep(c(0, 1), n / 2))
		y_lin <- 0.8 * x1 + rnorm(n)
		y <- as.integer(cut(y_lin, quantile(y_lin, seq(0, 1, length.out = 5)), include.lowest = TRUE))
		des <- DesignFixedTestFixture$new(n = n, response_type = "ordinal", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf <- InferenceOrdinalStereotypeLogitRegr$new(des, verbose = FALSE)
		est <- inf$compute_estimate()
		skip_if(is.na(est), "primary fit did not converge")
		spec <- inf$.__enclos_env__$private$get_likelihood_test_spec()
		null_fit <- spec$fit_null(est)
		expect_false(is.null(null_fit))
		expect_lt(null_fit$neg_loglik - spec$full_fit$neg_loglik, 1e-3)
	}
})
