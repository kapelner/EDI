library(testthat)
library(EDI)

# InferenceBayesianBootstrap's private helpers with no direct test references:
# bayesian_bootstrap_cache_key(), bayesian_bootstrap_sample_weights(),
# approximate_bayesian_jackknife_distribution_beta_hat_T(), ci_bayesian_bca()
# and pval_bayesian_bca(). Checked against from-scratch references (rgamma
# normalization, leave-one-out mean differences, textbook BCa formulas).

bb_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.3)
	for (t in seq_len(n)) des$add_one_subject_response(t, y[t])
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, y = y, n = n)
}

mean_diff <- function(y, w, wt = rep(1, length(y))) {
	weighted.mean(y[w == 1], wt[w == 1]) - weighted.mean(y[w == 0], wt[w == 0])
}

test_that("bayesian_bootstrap_cache_key encodes B and the weighting unit", {
	f <- bb_fixture()
	expect_equal(f$priv$bayesian_bootstrap_cache_key(501, NULL), "501::default")
	expect_equal(f$priv$bayesian_bootstrap_cache_key(10.9, "resample_blocks"), "10::resample_blocks")
})

test_that("sample weights are gamma draws normalized to sum to the group size", {
	f <- bb_fixture()
	set.seed(2)
	sw <- f$priv$bayesian_bootstrap_sample_weights()
	set.seed(2)
	g <- rgamma(f$n, shape = 1, rate = 1)
	expect_equal(sw$subject_or_block_weights, g / sum(g) * f$n, tolerance = 1e-12)
	expect_equal(sw$context$n_units, f$n)
	expect_equal(sw$context$row_to_unit, seq_len(f$n))
	expect_true(all(sw$subject_or_block_weights > 0))
})

test_that("jackknife distribution equals independent leave-one-out mean differences and is cached", {
	f <- bb_fixture()
	ref <- vapply(seq_len(f$n), function(k) {
		i <- setdiff(seq_len(f$n), k)
		mean_diff(f$y[i], f$w[i])
	}, numeric(1))
	jk <- f$priv$approximate_bayesian_jackknife_distribution_beta_hat_T()
	expect_equal(jk, ref, tolerance = 1e-10)
	expect_equal(f$priv$cached_values$bayes_jack_distr_cache[["default"]], ref, tolerance = 1e-10)

	f$priv$cached_values$bayes_jack_distr_cache[["default"]] <- rep(5, f$n)
	expect_identical(f$priv$approximate_bayesian_jackknife_distribution_beta_hat_T(), rep(5, f$n))
})

ref_bca_ci <- function(boot, alpha, est, jack) {
	z0 <- qnorm(min(1 - .Machine$double.eps, max(.Machine$double.eps, mean(boot < est))))
	jb <- mean(jack)
	a <- sum((jb - jack)^3) / (6 * sum((jb - jack)^2)^1.5)
	za <- qnorm(c(alpha / 2, 1 - alpha / 2))
	adj <- sort(pnorm(z0 + (z0 + za) / (1 - a * (z0 + za))))
	quantile(boot, probs = adj, names = FALSE, type = 8)
}

ref_bca_pval <- function(boot, est, delta, jack) {
	z0 <- qnorm(min(1 - .Machine$double.eps, max(.Machine$double.eps, mean(boot < est))))
	jb <- mean(jack)
	a <- sum((jb - jack)^3) / (6 * sum((jb - jack)^2)^1.5)
	zd <- qnorm(min(1 - .Machine$double.eps, max(.Machine$double.eps, mean(boot < delta))))
	s <- zd - z0
	adj_z <- s / (1 + a * s) - z0
	if (!is.finite(adj_z) || abs(adj_z) > 8) return(NA_real_)
	min(1, max(2 / length(boot), min(1, 2 * min(pnorm(adj_z), 1 - pnorm(adj_z)))))
}

test_that("ci_bayesian_bca and pval_bayesian_bca match textbook BCa references", {
	f <- bb_fixture()
	est <- mean_diff(f$y, f$w)
	set.seed(3)
	boot <- replicate(400, {
		g <- rgamma(f$n, 1, 1)
		mean_diff(f$y, f$w, g / sum(g) * f$n)
	})
	jack <- vapply(seq_len(f$n), function(k) { i <- setdiff(seq_len(f$n), k); mean_diff(f$y[i], f$w[i]) }, numeric(1))

	ci <- f$priv$ci_bayesian_bca(boot, 0.05, est)
	expect_equal(as.numeric(ci), ref_bca_ci(boot, 0.05, est, jack), tolerance = 1e-8)
	expect_true(ci[1] < ci[2])

	# A null value far outside the bootstrap distribution makes the adjustment
	# blow up (|adj_z| > 8), so the source reports NA there and the reference
	# mirrors that guard.
	expect_true(is.na(ref_bca_pval(boot, est, 0.5, jack)))
	for (delta in c(est, 0.5, 1.5, quantile(boot, 0.1))) {
		expect_equal(f$priv$pval_bayesian_bca(boot, est, delta), ref_bca_pval(boot, est, delta, jack),
			tolerance = 1e-8, info = as.character(delta))
	}
})

test_that("BCa returns unavailable results when the jackknife is unusable", {
	f <- bb_fixture()
	f$priv$cached_values$bayes_jack_distr_cache <- list(default = c(1, NA, NA))
	boot <- rnorm(50)
	ci <- f$priv$ci_bayesian_bca(boot, 0.05, 0)
	expect_true(all(is.na(ci)))
	expect_true(is.na(f$priv$pval_bayesian_bca(boot, 0, 0)))
})

test_that("compute_estimate() after a weighted refit returns the stale weighted value (real source bug, not fixed)", {
	# SOURCE BUG (noted, not fixed): compute_estimate_with_bootstrap_weights()
	# overwrites cached_values$beta_hat_T, so a later compute_estimate() on the
	# same object returns the last weighted estimate instead of the unweighted one.
	f <- bb_fixture()
	f$priv$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n
	)
	set.seed(9)
	ww <- runif(f$n, 0.2, 3)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(ww)
	expect_equal(weighted, mean_diff(f$y, f$w, ww), tolerance = 1e-10)
	expect_equal(f$inf$compute_estimate(), weighted, tolerance = 1e-12)
	expect_false(isTRUE(all.equal(f$inf$compute_estimate(), mean_diff(f$y, f$w))))
})
