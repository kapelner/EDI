library(testthat)
library(EDI)

# InferenceSurvivalLogRank / InferenceSurvivalGehanWilcox under left-/interval-censored data
# (has_general_censoring = TRUE): compute_shared()/compute_shared_icen() dispatch through
# interval::ictest() (scores = "logrank1" for log-rank, "wmw" for Gehan-Wilcox) instead of the
# right-censoring martingale-residual path. Estimate, Wald CI (est +/- z*se where se =
# |est / ictest$statistic|) and p-value are checked against a direct interval::ictest() call.
# Existing coverage (test-survival-bootstrap-weighted-refit-*.R) only ever calls
# compute_estimate_with_bootstrap_weights() on interval-censored data to confirm it errors
# ("not yet supported"); compute_shared_icen() itself -- the actual estimate/CI/p-value
# computation under general censoring -- had no test anywhere calling it, directly or via the
# public API.

skip_if_not_installed("interval")

ic_fx <- function(seed, n = 40L, class = InferenceSurvivalLogRank) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	list(inf = class$new(des, verbose = FALSE), w = w, yL = yL, yR = yR)
}

ref_wald_ci <- function(ref, alpha = 0.05) {
	se <- abs(as.numeric(ref$estimate) / as.numeric(ref$statistic))
	as.numeric(ref$estimate) + c(-1, 1) * qnorm(1 - alpha / 2) * se
}

test_that("log-rank under interval censoring: estimate, Wald CI and p-value match interval::ictest(scores = 'logrank1')", {
	f <- ic_fx(3L)
	p <- f$inf$.__enclos_env__$private
	expect_true(p$has_general_censoring)
	ref <- suppressWarnings(interval::ictest(f$yL, f$yR, f$w, scores = "logrank1"))
	est <- suppressWarnings(f$inf$compute_estimate())
	expect_equal(est, as.numeric(ref$estimate), tolerance = 1e-6)
	ci <- suppressWarnings(f$inf$compute_asymp_confidence_interval(0.05))
	expect_equal(as.numeric(ci), ref_wald_ci(ref), tolerance = 1e-6)
	pv <- suppressWarnings(f$inf$compute_asymp_two_sided_pval())
	expect_equal(pv, as.numeric(ref$p.value), tolerance = 1e-6)
	lrpv <- suppressWarnings(f$inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect())
	expect_equal(lrpv, as.numeric(ref$p.value), tolerance = 1e-6)
	expect_error(f$inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(delta = 0.3), "not yet implemented")
})

test_that("Gehan-Wilcox under interval censoring: estimate, Wald CI and p-value match interval::ictest(scores = 'wmw'), and differ from log-rank on the same data", {
	f <- ic_fx(3L, class = InferenceSurvivalGehanWilcox)
	ref <- suppressWarnings(interval::ictest(f$yL, f$yR, f$w, scores = "wmw"))
	est <- suppressWarnings(f$inf$compute_estimate())
	expect_equal(est, as.numeric(ref$estimate), tolerance = 1e-6)
	ci <- suppressWarnings(f$inf$compute_asymp_confidence_interval(0.05))
	expect_equal(as.numeric(ci), ref_wald_ci(ref), tolerance = 1e-6)
	pv <- suppressWarnings(f$inf$compute_asymp_two_sided_pval())
	expect_equal(pv, as.numeric(ref$p.value), tolerance = 1e-6)

	logrank_ref <- suppressWarnings(interval::ictest(f$yL, f$yR, f$w, scores = "logrank1"))
	expect_false(isTRUE(all.equal(as.numeric(ref$estimate), as.numeric(logrank_ref$estimate))))     # genuinely a different score
})

test_that("a mix of left-, right- and interval-censored rows within one design still matches interval::ictest on the same (L, R) construction", {
	set.seed(9); n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	type <- sample(1:3, n, replace = TRUE)                                             # 1 = left, 2 = right, 3 = interval
	yL <- ifelse(type == 1, 0, runif(n, 0, 2))
	yR <- ifelse(type == 1, runif(n, 1, 3), ifelse(type == 2, Inf, yL + runif(n, 0.5, 2)))
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	inf <- InferenceSurvivalLogRank$new(des, verbose = FALSE)
	ref <- suppressWarnings(interval::ictest(yL, yR, w, scores = "logrank1"))
	est <- suppressWarnings(inf$compute_estimate())
	expect_equal(est, as.numeric(ref$estimate), tolerance = 1e-6)
})

test_that("an estimate-only interval-censored call can be followed by a full call in both score classes", {
	for (class in list(InferenceSurvivalLogRank, InferenceSurvivalGehanWilcox)) {
		f <- ic_fx(3L, class = class)
		p <- f$inf$.__enclos_env__$private
		scores <- if (identical(class, InferenceSurvivalLogRank)) "logrank1" else "wmw"
		ref <- suppressWarnings(interval::ictest(f$yL, f$yR, f$w, scores = scores))
		est <- suppressWarnings(f$inf$compute_estimate(estimate_only = TRUE))
		expect_equal(est, as.numeric(ref$estimate), tolerance = 1e-6)
		expect_null(p$cached_values$s_beta_hat_T)
		ci <- suppressWarnings(f$inf$compute_asymp_confidence_interval(0.05))
		expect_equal(p$cached_values$s_beta_hat_T,
		             abs(as.numeric(ref$estimate) / as.numeric(ref$statistic)), tolerance = 1e-6)
		expect_true(is.finite(p$cached_values$s_beta_hat_T))
		expect_equal(as.numeric(ci), ref_wald_ci(ref), tolerance = 1e-6)
		expect_equal(suppressWarnings(f$inf$compute_estimate()), est, tolerance = 1e-6)
		expect_equal(as.numeric(suppressWarnings(f$inf$compute_asymp_confidence_interval(0.05))),
		             as.numeric(ci), tolerance = 1e-6)
	}
})
