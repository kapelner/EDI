library(testthat)
library(EDI)

# The m-out-of-n bootstrap and PRW subsampling extensions' private pivot
# builders (m_out_of_n_bootstrap_centered_pivot, subsampling_centered_pivot with
# its finite-population correction), their cache-key helpers
# (m_out_of_n_bootstrap_cache_key, subsampling_cache_key,
# resampling_scaling_key) and evaluate_m_out_of_n_bootstrap_size(). None had a
# direct test reference. Distributions are stubbed so every branch is
# exercised against hand-computed expectations.

rs_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

stub_public <- function(inf, name, fn) {
	unlockBinding(name, inf)
	assign(name, fn, envir = inf)
}

test_that("cache keys join B, size, type, scaling and centering, and scaling keys cover every scaling form", {
	f <- rs_fixture()
	expect_equal(f$priv$m_out_of_n_bootstrap_cache_key(500, 12L), "500|12|NULL|sqrt_n|full_estimate")
	expect_equal(f$priv$m_out_of_n_bootstrap_cache_key(500.9, 12.7, "within_blocks", "sqrt_n", "other"),
		"500|12|within_blocks|sqrt_n|other")
	expect_equal(f$priv$subsampling_cache_key(200, 8L, "resample_blocks"), "200|8|resample_blocks|sqrt_n|full_estimate")
	expect_equal(f$priv$subsampling_cache_key(200, 8L), "200|8|NULL|sqrt_n|full_estimate")

	sk <- f$priv$resampling_scaling_key
	expect_equal(sk("sqrt_n"), "sqrt_n")
	expect_equal(sk(c("a", "b")), "a,b")
	expect_equal(sk(list(rate_exponent = 0.4)), "rate_exponent 0.4")
	expect_equal(sk(function(m) m), "<function>")
	expect_equal(sk(2), "2")
	expect_false(identical(f$priv$m_out_of_n_bootstrap_cache_key(500, 12L, scaling = list(rate_exponent = 0.4)),
		f$priv$m_out_of_n_bootstrap_cache_key(500, 12L, scaling = list(rate_exponent = 0.5))))
})

test_that("the m-out-of-n pivot centers finite draws at the full estimate, scales by sqrt(m), and caches", {
	f <- rs_fixture()
	est <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	draws <- c(est + c(-0.4, -0.1, 0, 0.2, 0.5), NA, Inf)
	calls <- 0L
	stub_public(f$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(B, m, show_progress, bootstrap_type, scaling) {
		calls <<- calls + 1L
		draws
	})
	unit_info <- list(n_units = f$n)
	piv <- f$priv$m_out_of_n_bootstrap_centered_pivot(B = 7, m = 9L, unit_info = unit_info, show_progress = FALSE)
	expect_true(piv$ok)
	expect_equal(piv$est, est)
	expect_equal(piv$finite, draws[is.finite(draws)])
	expect_equal(piv$centered_scaled, sqrt(9) * (draws[is.finite(draws)] - est), tolerance = 1e-12)
	expect_equal(c(piv$m, piv$n_units), c(9L, f$n))

	again <- f$priv$m_out_of_n_bootstrap_centered_pivot(B = 7, m = 9L, unit_info = unit_info, show_progress = FALSE)
	expect_identical(again, piv)
	expect_equal(calls, 1L)                                    # served from the cache
	f$priv$m_out_of_n_bootstrap_centered_pivot(B = 7, m = 10L, unit_info = unit_info, show_progress = FALSE)
	expect_equal(calls, 2L)                                    # a different m recomputes

	# Rate-exponent scaling changes the multiplier.
	p2 <- f$priv$m_out_of_n_bootstrap_centered_pivot(B = 7, m = 9L, unit_info = unit_info, show_progress = FALSE,
		scaling = list(rate_exponent = 0.25))
	expect_equal(p2$centered_scaled, 9^0.25 * (draws[is.finite(draws)] - est), tolerance = 1e-12)
})

test_that("the m-out-of-n pivot is unavailable when the estimate is missing or most replicates failed", {
	f <- rs_fixture()
	stub_public(f$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(...) c(1, NA, NA, NA))
	est <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	bad <- f$priv$m_out_of_n_bootstrap_centered_pivot(B = 4, m = 9L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_false(bad$ok)
	expect_equal(bad$reason, "m_out_of_n_high_replicate_failure_rate")

	# Exactly half finite is allowed (the gate is strictly below 50%).
	g <- rs_fixture()
	stub_public(g$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(...) c(1, 2, NA, NA))
	expect_true(g$priv$m_out_of_n_bootstrap_centered_pivot(B = 4, m = 9L, unit_info = list(n_units = 20L), show_progress = FALSE)$ok)

	h <- rs_fixture()
	stub_public(h$inf, "compute_estimate", function(estimate_only = FALSE) NA_real_)
	noest <- h$priv$m_out_of_n_bootstrap_centered_pivot(B = 4, m = 9L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_equal(noest, list(ok = FALSE, reason = "m_out_of_n_original_estimate_unavailable"))
})

test_that("the subsampling pivot applies the finite-population correction 1 / sqrt(1 - b / n)", {
	f <- rs_fixture()
	est <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	draws <- est + c(-0.3, 0.1, 0.4, -0.2, 0.05)
	stub_public(f$inf, "approximate_subsampling_distribution_beta_hat_T", function(B, b, show_progress, subsampling_type, scaling) draws)
	piv <- f$priv$subsampling_centered_pivot(B = 5, b = 8L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_true(piv$ok)
	fpc <- 1 / sqrt(1 - 8 / 20)
	expect_equal(piv$centered_scaled, fpc * sqrt(8) * (draws - est), tolerance = 1e-12)
	expect_equal(c(piv$b, piv$n_units), c(8L, 20L))

	# b close to n makes the correction blow up but stay finite (denominator floored at machine epsilon).
	full <- f$priv$subsampling_centered_pivot(B = 5, b = 20L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_true(all(is.finite(full$centered_scaled)))
	expect_gt(abs(full$centered_scaled[3]), abs(piv$centered_scaled[3]))
})

test_that("the subsampling pivot fails on a missing estimate or a high failure rate and caches successes", {
	f <- rs_fixture()
	calls <- 0L
	stub_public(f$inf, "approximate_subsampling_distribution_beta_hat_T", function(...) { calls <<- calls + 1L; c(NA, NA, NA, 1) })
	bad <- f$priv$subsampling_centered_pivot(B = 4, b = 8L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_equal(bad, list(ok = FALSE, reason = "subsampling_high_replicate_failure_rate"))

	g <- rs_fixture()
	n_calls <- 0L
	stub_public(g$inf, "approximate_subsampling_distribution_beta_hat_T", function(...) { n_calls <<- n_calls + 1L; c(1, 1.5, 2) })
	g$priv$subsampling_centered_pivot(B = 3, b = 8L, unit_info = list(n_units = 20L), show_progress = FALSE)
	g$priv$subsampling_centered_pivot(B = 3, b = 8L, unit_info = list(n_units = 20L), show_progress = FALSE)
	expect_equal(n_calls, 1L)

	h <- rs_fixture()
	stub_public(h$inf, "compute_estimate", function(estimate_only = FALSE) stop("cannot fit"))
	expect_equal(h$priv$subsampling_centered_pivot(B = 3, b = 8L, unit_info = list(n_units = 20L), show_progress = FALSE),
		list(ok = FALSE, reason = "subsampling_original_estimate_unavailable"))
})

test_that("evaluate_m_out_of_n_bootstrap_size returns the centered CI / p-value and classifies unusable results", {
	f <- rs_fixture()
	est <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	set.seed(3)
	offsets <- rnorm(300, sd = 0.3)
	stub_public(f$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(...) est + offsets)
	out <- f$priv$evaluate_m_out_of_n_bootstrap_size(m = 10L, B = 300L, alpha = 0.05)
	expect_equal(out$status, "ok")
	expect_equal(out$estimate, est)
	expect_equal(out$n_finite, 300L)
	expect_equal(out$finite_fraction, 1)
	expect_true(is.na(out$dominant_failure_reason))
	cs <- sqrt(10) * offsets
	q <- quantile(cs, c(0.025, 0.975), names = FALSE, type = 8)
	expect_equal(as.numeric(out$ci), est - c(q[2], q[1]) / sqrt(20), tolerance = 1e-10)
	tobs <- sqrt(20) * est
	expect_equal(out$pval, min(1, max(2 / 300, 2 * min(mean(cs <= tobs), mean(cs >= tobs)))), tolerance = 1e-12)

	g <- rs_fixture()
	stub_public(g$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(...) rep(NA_real_, 50))
	none <- g$priv$evaluate_m_out_of_n_bootstrap_size(m = 10L, B = 50L, alpha = 0.05)
	expect_equal(none$status, "nonestimable")
	expect_equal(none$dominant_failure_reason, "m_out_of_n_too_few_finite_estimates")
	expect_equal(none$n_finite, 0L)

	h <- rs_fixture()
	stub_public(h$inf, "approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", function(...) est + c(-1e7, 1e7, -1e7, 1e7, 0))
	ext <- h$priv$evaluate_m_out_of_n_bootstrap_size(m = 10L, B = 5L, alpha = 0.05)
	expect_equal(ext$status, "nonestimable")
	expect_equal(ext$dominant_failure_reason, "m_out_of_n_extreme_confidence_interval")

	k <- rs_fixture()
	stub_public(k$inf, "compute_estimate", function(estimate_only = FALSE) NA_real_)
	expect_equal(k$priv$evaluate_m_out_of_n_bootstrap_size(m = 10L, B = 5L, alpha = 0.05),
		list(status = "nonestimable", dominant_failure_reason = "m_out_of_n_original_estimate_unavailable",
			finite_fraction = 0, n_finite = 0L))
})
