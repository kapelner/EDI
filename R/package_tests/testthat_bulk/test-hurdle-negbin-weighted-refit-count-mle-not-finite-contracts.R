# Untested-code audit, 2026-11-24: covers R/EDI/R/inference_count_hurdle.R:555-556
# (compute_estimate_with_bootstrap_weights; region unt-714e4fd0ff27).
# Reference: The documented NA return and its nonestimable reason
# 'hurdle_negbin_count_mle_not_finite'. A plain-R dnbinom check shows that P(Y = 1 | Y > 0) decreases
# strictly in the mean, so the count-part MLE is not finite.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 2 of 2
# target lines (6.6 s).

library(testthat)
library(EDI)

test_that("hurdle negative binomial weighted refit returns NA with the count-MLE-not-finite reason when treated positives are all 1", {
	# Reference: given Y > 0, the zero-truncated NB probability of Y = 1 decreases strictly in the mean
	# (the NB pmf ratio P(k)/P(k-1) = (k-1+size)/k * mu/(size+mu) grows with mu, so the family is
	# MLR-ordered). An arm whose positive counts are all 1 therefore pushes its rate to 0: no finite MLE.
	mu_grid = seq(0.01, 5, by = 0.01)
	for (size in c(0.5, 2, 10)) {
		p1_given_pos = dnbinom(1, size = size, mu = mu_grid) / (1 - dnbinom(0, size = size, mu = mu_grid))
		expect_true(all(diff(p1_given_pos) < 0))
		expect_true(all(p1_given_pos < 1))
	}

	set.seed(7)
	n = 60L
	x = rnorm(n)
	w = sample(rep(0:1, n / 2))
	y = rpois(n, exp(0.4 + 0.3 * w + 0.2 * x)) * rbinom(n, 1, 0.65)
	y[w == 1 & y > 0] = 1
	expect_true(any(w == 1 & y > 0))
	expect_true(all(y[w == 1 & y > 0] == 1))
	expect_true(any(y[w == 0] > 1))

	des = DesignFixediBCRD$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)

	set.seed(11)
	wts = rexp(n)
	est = suppressWarnings(inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE))
	expect_true(is.na(est))
	reason = if (!is.null(priv$last_weighted_refit)) priv$last_weighted_refit$nonestimable_reason else priv$cached_values$nonestimable_reason
	expect_identical(reason, "hurdle_negbin_count_mle_not_finite")
})
