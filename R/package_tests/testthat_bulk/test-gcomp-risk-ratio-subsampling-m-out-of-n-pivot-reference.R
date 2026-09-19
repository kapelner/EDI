library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's RR-specific subsampling / m-out-of-n
# bootstrap delegation (compute_rr_resampling_pivot() and the four
# compute_rr_* methods reached from the public compute_subsampling_* /
# compute_m_out_of_n_bootstrap_* entry points). The sibling
# test-gcomp-risk-ratio-resampling-coverage.R covers bootstrap/jackknife only.
# The reference recentres on log(estimate) exactly as documented and is built
# from the same seeded resampling distribution.

rr_fixture <- function(y_fun = NULL, n = 60L, seed = 4L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- if (is.null(y_fun)) rbinom(n, 1, plogis(-0.5 + 0.9 * w + 0.3 * x)) else y_fun(w, x)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	priv <- inf$.__enclos_env__$private
	priv$seed <- 11L
	list(inf = inf, priv = priv, n = n)
}

ref_rr_ci <- function(draws, est, size, n_units, alpha) {
	fin <- draws[is.finite(draws) & draws > 0]
	cs <- sqrt(size) * (log(fin) - log(est))
	q <- quantile(cs, c(alpha / 2, 1 - alpha / 2), names = FALSE, type = 8)
	exp(log(est) - c(q[2], q[1]) / sqrt(n_units))
}

ref_rr_pval <- function(draws, est, size, n_units, delta) {
	fin <- draws[is.finite(draws) & draws > 0]
	cs <- sqrt(size) * (log(fin) - log(est))
	tobs <- sqrt(n_units) * (log(est) - log(delta))
	min(1, max(2 / length(cs), 2 * min(mean(cs <= tobs), mean(cs >= tobs))))
}

test_that("m-out-of-n RR interval and p-value match the log-centered reference built from the same draws", {
	f <- rr_fixture()
	est <- f$inf$compute_estimate()
	expect_true(is.finite(est) && est > 0)
	d <- f$inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 40, m = 15, show_progress = FALSE)
	ci <- f$inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 40, m = 15, show_progress = FALSE)
	expect_equal(as.numeric(ci), ref_rr_ci(d, est, 15, f$n, 0.05), tolerance = 1e-8)
	expect_equal(names(ci), c("2.5%", "97.5%"))
	for (delta in c(1, 2, 0.5)) {
		pv <- f$inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = delta, B = 40, m = 15, show_progress = FALSE)
		expect_equal(pv, ref_rr_pval(d, est, 15, f$n, delta), tolerance = 1e-10, info = delta)
	}
	# The default null for a ratio estimand is 1.
	expect_equal(
		f$inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 40, m = 15, show_progress = FALSE),
		ref_rr_pval(d, est, 15, f$n, 1), tolerance = 1e-10
	)
})

test_that("subsampling RR interval and p-value match the same log-centered reference", {
	f <- rr_fixture()
	est <- f$inf$compute_estimate()
	d <- f$inf$approximate_subsampling_distribution_beta_hat_T(B = 40, b = 15, show_progress = FALSE)
	ci <- f$inf$compute_subsampling_confidence_interval(B = 40, b = 15, show_progress = FALSE)
	expect_equal(as.numeric(ci), ref_rr_ci(d, est, 15, f$n, 0.05), tolerance = 1e-8)
	ci90 <- f$inf$compute_subsampling_confidence_interval(alpha = 0.1, B = 40, b = 15, show_progress = FALSE)
	expect_equal(as.numeric(ci90), ref_rr_ci(d, est, 15, f$n, 0.1), tolerance = 1e-8)
	# A 90% interval is nested inside the 95% interval.
	expect_gte(ci90[1], ci[1] - 1e-12)
	expect_lte(ci90[2], ci[2] + 1e-12)
	pv <- f$inf$compute_subsampling_two_sided_pval(B = 40, b = 15, show_progress = FALSE)
	expect_equal(pv, ref_rr_pval(d, est, 15, f$n, 1), tolerance = 1e-10)
})

test_that("nonpositive nulls, too few usable draws and an unusable original estimate give NA with a cached reason", {
	f <- rr_fixture()
	expect_true(is.na(f$inf$compute_m_out_of_n_bootstrap_two_sided_pval(delta = -1, B = 40, m = 15, show_progress = FALSE)))
	expect_true(f$inf$is_nonestimable("estimate"))
	f0 <- rr_fixture()
	expect_true(is.na(f0$inf$compute_subsampling_two_sided_pval(delta = 0, B = 40, b = 15, show_progress = FALSE)))
	expect_true(f0$inf$is_nonestimable("estimate"))

	f2 <- rr_fixture()
	ci <- f2$inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 40, m = 15, min_number_usable_samples = 1000L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(is.na(f2$inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 40, m = 15, min_number_usable_samples = 1000L, show_progress = FALSE)))
	ci_s <- f2$inf$compute_subsampling_confidence_interval(B = 40, b = 15, min_number_usable_samples = 1000L, show_progress = FALSE)
	expect_true(all(is.na(ci_s)))

	# An unusable (nonpositive or non-finite) original estimate makes the log pivot unavailable.
	for (bad in list(0, -1, NA_real_)) {
		f3 <- rr_fixture()
		unlockBinding("compute_estimate", f3$inf)
		f3$inf$compute_estimate <- function(estimate_only = FALSE) bad
		ci3 <- f3$inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 40, m = 15, show_progress = FALSE)
		expect_true(all(is.na(ci3)), info = format(bad))
		expect_true(is.na(f3$inf$compute_subsampling_two_sided_pval(B = 40, b = 15, show_progress = FALSE)), info = format(bad))
		expect_true(f3$inf$is_nonestimable("estimate"), info = format(bad))
	}
})
