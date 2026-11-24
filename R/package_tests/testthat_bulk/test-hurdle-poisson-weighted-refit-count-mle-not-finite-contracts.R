# Untested-code audit, 2026-11-24: covers
# R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:176-177
# (compute_estimate_with_bootstrap_weights; region unt-be82cb32413f).
# Reference: The documented NA return and its nonestimable reason 'hurdle_count_mle_not_finite'. A
# plain-R closed form shows that the zero-truncated Poisson log-likelihood at y = 1 decreases
# strictly in the rate, so it has no finite maximizer.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 2 of 2
# target lines (6.7 s).

library(testthat)
library(EDI)

test_that("hurdle Poisson weighted refit returns NA with the count-MLE-not-finite reason when treated positives are all 1", {
	# Reference: the zero-truncated Poisson log-likelihood of y = 1 is log(l) - l - log(1 - exp(-l)),
	# with derivative 1/l - 1/(1 - exp(-l)) < 0 (because 1 - exp(-l) < l), so it rises as l -> 0 and has
	# no finite maximizer: an arm whose positive counts are all 1 has no finite treatment MLE.
	lam = seq(0.01, 10, by = 0.01)
	ll1 = log(lam) - lam - log(1 - exp(-lam))
	expect_true(all(diff(ll1) < 0))
	expect_true(all(ll1 < 0))

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
	inf = InferenceCountHurdlePoisson$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)

	set.seed(11)
	wts = rexp(n)
	est = suppressWarnings(inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE))
	expect_true(is.na(est))
	reason = if (!is.null(priv$last_weighted_refit)) priv$last_weighted_refit$nonestimable_reason else priv$cached_values$nonestimable_reason
	expect_identical(reason, "hurdle_count_mle_not_finite")
})
