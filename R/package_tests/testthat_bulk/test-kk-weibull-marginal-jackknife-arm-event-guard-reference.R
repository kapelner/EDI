library(testthat)
library(EDI)

make_kk_weibull_jackknife_fixture <- function(censored = TRUE) {
	set.seed(1L)
	n <- 24L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	latent <- rexp(n, rate = exp(-0.3 * w + 0.2 * X$x1))
	if (censored) {
		censoring <- rexp(n, rate = 1.2)
		y <- pmin(latent, censoring)
		dead <- as.integer(latent <= censoring)
	} else {
		y <- latent
		dead <- rep(1L, n)
	}
	des$add_all_subject_responses(
		ifelse(dead == 1L, y, NA_real_),
		ifelse(dead == 0L, y, NA_real_),
		ifelse(dead == 0L, Inf, NA_real_)
	)
	inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, dead = dead)
}

test_that("a matched-set deletion that removes one arm's only event is nonestimable", {
	f <- make_kk_weibull_jackknife_fixture(censored = TRUE)
	draws <- f$priv$build_jackknife_deletion_draws("matched_set")
	removed <- lapply(draws, function(draw) setdiff(seq_along(f$w), draw$i_b))
	bad_fold <- which(vapply(removed, identical, logical(1L), c(2L, 17L)))
	expect_identical(bad_fold, 14L)
	keep <- draws[[bad_fold]]$i_b
	expect_equal(sum(f$dead[keep][f$w[keep] == 1]), 0L)
	expect_gt(sum(f$dead[keep][f$w[keep] == 0]), 0L)

	jack <- f$inf$approximate_jackknife_distribution_beta_hat_T("matched_set")
	expect_true(is.na(jack[bad_fold]))
	expect_lt(max(abs(jack), na.rm = TRUE), 2)
	expect_true(is.na(f$inf$compute_jackknife_estimate("matched_set")))
	expect_identical(f$inf$get_nonestimable_reason(), "jackknife_nonfinite_replicate_estimates")
})

test_that("weighted refits reject effective samples with no event in one arm", {
	f <- make_kk_weibull_jackknife_fixture(censored = TRUE)
	f$priv$current_bayesian_bootstrap_context <- f$priv$build_bayesian_bootstrap_context()
	ctx <- f$priv$current_bayesian_bootstrap_context
	unit_weights <- rep(1, ctx$n_units)
	event_row <- which(f$w == 1 & f$dead == 1)
	expect_identical(event_row, 17L)
	unit_weights[ctx$row_to_unit[event_row]] <- 0

	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(unit_weights, estimate_only = TRUE)))
	expect_true(isTRUE(f$priv$last_weighted_refit$nonestimable))
	expect_identical(f$priv$last_weighted_refit$nonestimable_reason, "kk_weibull_marginal_treatment_arm_no_events")
})

test_that("well-identified all-event jackknife estimates retain the standard formula", {
	f <- make_kk_weibull_jackknife_fixture(censored = FALSE)
	theta_hat <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	jack <- f$inf$approximate_jackknife_distribution_beta_hat_T("matched_set")
	n_units <- length(jack)
	expect_true(all(is.finite(jack)))
	expect_true(f$priv$treatment_arms_have_events())

	jack_bar <- mean(jack)
	expected_bias <- (n_units - 1) * (jack_bar - theta_hat)
	expected_estimate <- theta_hat - expected_bias
	expected_se <- sqrt(((n_units - 1) / n_units) * sum((jack - jack_bar)^2))
	expect_equal(f$inf$compute_jackknife_bias_estimate("matched_set"), expected_bias, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_estimate("matched_set"), expected_estimate, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_std_error("matched_set"), expected_se, tolerance = 1e-12)
})
