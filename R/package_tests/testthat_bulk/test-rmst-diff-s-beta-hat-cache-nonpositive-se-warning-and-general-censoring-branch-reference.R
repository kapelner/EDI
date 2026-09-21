library(testthat)
library(EDI)

# InferenceSurvivalRestrictedMeanDiff private compute_s_beta_hat_T(): caches the kernel SE of the RMST difference; a non-positive / NA SE
# (e.g. every subject right-censored) warns and caches NA; with general (interval / left) censoring the SE is left NA without a kernel call.
# References: the exported-namespace kernel get_restricted_mean_se_diff and survfit-based per-arm SEs.

mk <- function(mode = "exact") {
	set.seed(3); n <- 30L
	d <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); t <- rexp(n) + 0.1
	switch(mode,
		exact = d$add_all_subject_responses(ys = t, y_Ls = rep(NA, n), y_Rs = rep(NA, n)),
		censored = d$add_all_subject_responses(ys = rep(NA, n), y_Ls = t, y_Rs = rep(Inf, n)),
		interval = d$add_all_subject_responses(ys = c(t[1:10], rep(NA, n - 10L)), y_Ls = c(rep(NA, 10), t[11:n]), y_Rs = c(rep(NA, 10), t[11:n] + 0.5)))
	inf <- InferenceSurvivalRestrictedMeanDiff$new(d, verbose = FALSE); suppressWarnings(inf$compute_estimate())      # the estimate itself triggers the SE step (and its warning for degenerate data)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

test_that("with exact times the cached SE equals the kernel's SE of the RMST difference and per-arm survfit SEs in quadrature", {
	f <- mk("exact"); f$p$compute_s_beta_hat_T()
	se <- f$p$cached_values$s_beta_hat_T
	expect_equal(se, EDI:::get_restricted_mean_se_diff(f$p$y, f$p$dead, f$p$w), tolerance = 1e-12)
	arm_se <- function(a) { i <- f$p$w == a; summary(survival::survfit(survival::Surv(f$p$y[i], f$p$dead[i]) ~ 1), rmean = max(f$p$y[i]))$table[["se(rmean)"]] }
	expect_equal(se, sqrt(arm_se(0)^2 + arm_se(1)^2), tolerance = 1e-8)
	expect_gt(se, 0)
})

test_that("SE is available to the asymptotic CI and p-value once cached", {
	f <- mk("exact"); est <- f$inf$compute_estimate(); se <- f$inf$compute_asymp_confidence_interval(0.1)
	expect_equal(unname(se[2] - se[1]) / 2, qnorm(0.95) * f$p$cached_values$s_beta_hat_T, tolerance = 1e-6)
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(est / f$p$cached_values$s_beta_hat_T)), tolerance = 1e-6)
})

test_that("all-censored data give a zero SE from the kernel: a warning is raised and NA is cached", {
	f <- mk("censored")
	expect_warning(f$p$compute_s_beta_hat_T(), "Restricted mean SE is non-positive or NA")
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
})

test_that("interval censoring leaves the SE NA without any warning (bootstrap fallback downstream)", {
	f <- mk("interval")
	expect_true(isTRUE(f$p$has_general_censoring))
	expect_no_warning(f$p$compute_s_beta_hat_T())
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
})
