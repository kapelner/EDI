library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio: compute_rr_jackknife_wald_two_sided_pval / _confidence_interval (log RR +/- z * jackknife log SE),
# compute_rr_resampling_pivot (log-scale centred / sqrt(b)-scaled subsampling pivot) and
# compute_rr_subsampling_two_sided_pval / _confidence_interval. Resampling draws are stubbed with fixed vectors.

set.seed(5); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.5 * X$x1)); d$add_all_subject_responses(y)
mk <- function(jack = NULL, sub = NULL) {
	inf <- InferenceIncidGCompRiskRatio$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
	est <- inf$compute_estimate()
	if (!is.null(jack)) { unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", p); p$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") jack }
	if (!is.null(sub)) { unlockBinding("approximate_subsampling_distribution_beta_hat_T", inf)
		inf$approximate_subsampling_distribution_beta_hat_T <- function(B, show_progress = FALSE, b = NULL, subsampling_type = NULL) exp(log(est) + sub) }
	list(inf = inf, p = p, est = est)
}
jack <- exp(rnorm(40, log(1.29), 0.08)); lj <- log(jack); se_log <- sqrt((39 / 40) * sum((lj - mean(lj))^2))
grid <- seq(-0.4, 0.4, length.out = 101)

test_that("jackknife-Wald p-value and CI use the log RR and the jackknife log SE", {
	f <- mk(jack = jack)
	for (delta in c(1, 1.5, 0.8)) {
		expect_equal(f$p$compute_rr_jackknife_wald_two_sided_pval(delta), 2 * pnorm(-abs((log(f$est) - log(delta)) / se_log)), tolerance = 1e-10, info = delta)
	}
	for (a in c(0.1, 0.05)) {
		ci <- f$p$compute_rr_jackknife_wald_confidence_interval(a)
		expect_equal(unname(ci), exp(log(f$est) + c(-1, 1) * qnorm(1 - a / 2) * se_log), tolerance = 1e-10)
		expect_identical(names(ci), paste0(c(a / 2, 1 - a / 2) * 100, "%"))
	}
})

test_that("jackknife-Wald guards: non-positive null ratio, unusable estimate or SE give NA and a nonestimable flag", {
	f <- mk(jack = jack)
	expect_true(is.na(f$p$compute_rr_jackknife_wald_two_sided_pval(0))); expect_true(is.na(f$p$compute_rr_jackknife_wald_two_sided_pval(-1)))
	expect_true(is.na(f$p$compute_rr_jackknife_wald_two_sided_pval(NA)))
	g <- mk(jack = rep(1.3, 10))
	expect_true(is.na(g$p$compute_rr_jackknife_wald_two_sided_pval(1))); expect_true(all(is.na(g$p$compute_rr_jackknife_wald_confidence_interval(0.05))))
	h <- mk(jack = jack); unlockBinding("compute_estimate", h$inf); h$inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	expect_true(is.na(h$p$compute_rr_jackknife_wald_two_sided_pval(1))); expect_true(all(is.na(h$p$compute_rr_jackknife_wald_confidence_interval(0.05))))
})

test_that("resampling pivot: finite positive draws only, centred on log(est) and scaled by sqrt(size)", {
	f <- mk(sub = grid)
	pv <- f$p$compute_rr_resampling_pivot(f$inf$approximate_subsampling_distribution_beta_hat_T, "b", 50L, 101, NULL, FALSE)
	expect_true(pv$ok); expect_equal(pv$log_est, log(f$est), tolerance = 1e-12); expect_equal(pv$n_units, n)
	expect_equal(pv$centered_scaled, sqrt(50) * grid, tolerance = 1e-10)
	bad <- mk(sub = c(grid, NA, -Inf))
	expect_equal(length(bad$p$compute_rr_resampling_pivot(bad$inf$approximate_subsampling_distribution_beta_hat_T, "b", 50L, 103, NULL, FALSE)$finite), 101L)
	none <- mk(sub = rep(NA_real_, 5))
	r <- none$p$compute_rr_resampling_pivot(none$inf$approximate_subsampling_distribution_beta_hat_T, "b", 50L, 5, NULL, FALSE)
	expect_false(r$ok); expect_identical(r$reason, "resampling_too_few_finite_estimates")
})

test_that("subsampling p-value: two-sided empirical tail of the centred pivot at sqrt(n) * (log est - log delta), floored at 2/B", {
	f <- mk(sub = grid)
	cs <- sqrt(50) * grid
	for (delta in c(1, 1.2, 0.9)) {
		t_obs <- sqrt(n) * (log(f$est) - log(delta))
		ref <- min(1, max(2 / 101, 2 * min(mean(cs <= t_obs), mean(cs >= t_obs))))
		expect_equal(f$p$compute_rr_subsampling_two_sided_pval(delta, B = 101, b = 50L), ref, tolerance = 1e-12, info = delta)
	}
	expect_true(is.na(f$p$compute_rr_subsampling_two_sided_pval(0, B = 101))); expect_true(is.na(f$p$compute_rr_subsampling_two_sided_pval(-2, B = 101)))
	expect_true(isTRUE(f$inf$is_nonestimable("estimate")))
})

test_that("subsampling CI is a positive, ordered, percent-named interval and NA when too few usable draws remain", {
	f <- mk(sub = grid)
	ci <- f$p$compute_rr_subsampling_confidence_interval(0.1, B = 101, b = 50L)
	expect_identical(names(ci), c("5%", "95%")); expect_true(all(ci > 0)); expect_lt(ci[[1]], ci[[2]])
	expect_gt(ci[[2]], f$est); expect_lt(ci[[1]], f$est)
	few <- mk(sub = c(0.1, 0.2, 0.3))
	expect_true(all(is.na(few$p$compute_rr_subsampling_confidence_interval(0.1, B = 3, b = 50L, min_number_usable_samples = 5L))))
	expect_true(is.na(few$p$compute_rr_subsampling_two_sided_pval(1, B = 3, b = 50L, min_number_usable_samples = 5L)))
})
