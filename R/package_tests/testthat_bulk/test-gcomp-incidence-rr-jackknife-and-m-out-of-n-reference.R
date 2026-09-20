library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's risk-ratio-specific resampling layer: the jackknife SE of the
# log risk ratio and its Wald interval / p-value against an independent leave-one-out g-computation
# (glm) reference, the nonestimable branches, and the m-out-of-n bootstrap p-value / interval built
# from a stubbed draw distribution so the pivot arithmetic can be checked in closed form.

rr_fx <- function(seed = 3L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.6 + 0.7 * w + 0.4 * x)); des$add_all_subject_responses(y)
	inf <- InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x = x, y = y, n = n)
}

gc_rr <- function(f, idx) {
	g <- suppressWarnings(glm(f$y[idx] ~ f$w[idx] + f$x[idx], family = binomial())); b <- coef(g)
	mean(plogis(cbind(1, 1, f$x[idx]) %*% b)) / mean(plogis(cbind(1, 0, f$x[idx]) %*% b))
}

test_that("the class estimate is the standardised risk ratio from a logistic outcome model", {
	f <- rr_fx()
	expect_equal(f$inf$compute_estimate(), gc_rr(f, seq_len(f$n)), tolerance = 1e-6)
})

test_that("jackknife log-RR SE, Wald CI and p-value equal the leave-one-out reference", {
	f <- rr_fx()
	est <- f$inf$compute_estimate()
	th <- vapply(seq_len(f$n), function(i) log(gc_rr(f, setdiff(seq_len(f$n), i))), numeric(1))
	se <- sqrt((f$n - 1) / f$n * sum((th - mean(th))^2))
	expect_equal(f$p$compute_rr_jackknife_log_se(unit = "auto"), se, tolerance = 1e-5)
	ci <- f$inf$compute_jackknife_wald_confidence_interval(0.1)
	expect_equal(as.numeric(ci), exp(log(est) + c(-1, 1) * qnorm(0.95) * se), tolerance = 1e-5)
	expect_equal(names(ci), c("5%", "95%"))
	expect_equal(f$inf$compute_jackknife_wald_two_sided_pval(1), 2 * pnorm(-abs(log(est) / se)), tolerance = 1e-5)
	expect_equal(f$inf$compute_jackknife_wald_two_sided_pval(1.5), 2 * pnorm(-abs((log(est) - log(1.5)) / se)), tolerance = 1e-5)
})

test_that("jackknife RR: a null value <= 0 is unavailable, an unusable original estimate gives NA and a nonestimable flag", {
	f <- rr_fx()
	for (d in c(0, -1, NA)) {
		g <- rr_fx()
		expect_true(is.na(g$inf$compute_jackknife_wald_two_sided_pval(d)))
		expect_identical(g$inf$get_nonestimable_reason(), "jackknife_log_risk_ratio_null_unavailable")
	}
	h <- rr_fx()
	unlockBinding("compute_estimate", h$inf); h$inf$compute_estimate <- function(estimate_only = FALSE) -0.2
	ci <- h$inf$compute_jackknife_wald_confidence_interval(0.05)
	expect_true(all(is.na(ci))); expect_equal(names(ci), c("2.5%", "97.5%"))
	expect_identical(h$inf$get_nonestimable_reason(), "jackknife_original_risk_ratio_unavailable")
	expect_true(h$inf$is_nonestimable("estimate"))
	k <- rr_fx()
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", k$p)
	k$p$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") c(1.2, NA, -1)   # one usable positive value
	expect_true(is.na(k$p$compute_rr_jackknife_log_se("auto")))
	expect_identical(k$inf$get_nonestimable_reason(), "jackknife_too_few_positive_risk_ratio_estimates")
	l <- rr_fx()
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", l$p)
	l$p$approximate_jackknife_distribution_beta_hat_T_private <- function(unit = "auto") rep(1.3, 10)     # zero spread
	expect_true(is.na(l$p$compute_rr_jackknife_log_se("auto")))
	expect_identical(l$inf$get_nonestimable_reason(), "jackknife_log_risk_ratio_standard_error_unavailable")
})

stub_mn <- function(f, draws) {
	unlockBinding("approximate_m_out_of_n_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T <- function(B, m, show_progress = FALSE, bootstrap_type = NULL, ...) draws
	invisible(f)
}

test_that("m-out-of-n RR interval and p-value equal the centred-pivot formulas on the log scale", {
	f <- rr_fx(); est <- f$inf$compute_estimate()
	set.seed(9); D <- est * exp(rnorm(400, 0, 0.3))
	stub_mn(f, D)
	m <- 15L
	cs <- sqrt(m) * (log(D) - log(est))
	q <- quantile(cs, c(0.95, 0.05), names = FALSE, type = 8)
	ci <- f$p$compute_rr_m_out_of_n_bootstrap_confidence_interval(0.1, B = 400L, m = m, show_progress = FALSE)
	expect_equal(as.numeric(ci), exp(log(est) - q / sqrt(f$n)), tolerance = 1e-8)
	expect_equal(names(ci), c("5%", "95%"))
	expect_lt(ci[[1]], est); expect_gt(ci[[2]], est)
	t_obs <- sqrt(f$n) * (log(est) - log(1.3))
	ref_p <- min(1, max(2 / length(cs), 2 * min(mean(cs <= t_obs), mean(cs >= t_obs))))
	expect_equal(f$p$compute_rr_m_out_of_n_bootstrap_two_sided_pval(1.3, B = 400L, m = m, show_progress = FALSE), ref_p, tolerance = 1e-10)
})

test_that("m-out-of-n RR: null <= 0, no positive draws, or too few usable draws are unavailable", {
	f <- rr_fx()
	expect_true(is.na(f$p$compute_rr_m_out_of_n_bootstrap_two_sided_pval(0, B = 50L, m = 15L, show_progress = FALSE)))
	expect_identical(f$inf$get_nonestimable_reason(), "m_out_of_n_log_risk_ratio_null_unavailable")
	g <- rr_fx(); stub_mn(g, c(NA, -1, 0))
	expect_true(all(is.na(g$p$compute_rr_m_out_of_n_bootstrap_confidence_interval(0.05, B = 50L, m = 15L, show_progress = FALSE))))
	expect_identical(g$inf$get_nonestimable_reason(), "resampling_too_few_finite_estimates")
	h <- rr_fx(); stub_mn(h, c(1.1, 1.2, 1.3))                                         # fewer than min_number_usable_samples = 5
	expect_true(all(is.na(h$p$compute_rr_m_out_of_n_bootstrap_confidence_interval(0.05, B = 50L, m = 15L, show_progress = FALSE))))
	expect_identical(h$inf$get_nonestimable_reason(), "m_out_of_n_too_few_finite_estimates")
	k <- rr_fx(); stub_mn(k, c(1.1, 1.2, 1.3))
	expect_true(is.na(k$p$compute_rr_m_out_of_n_bootstrap_two_sided_pval(1, B = 50L, m = 15L, show_progress = FALSE)))
	expect_identical(k$inf$get_nonestimable_reason(), "m_out_of_n_too_few_finite_estimates")
	expect_error(rr_fx()$p$compute_rr_m_out_of_n_bootstrap_confidence_interval(0.05, B = 50L, m = 2L, show_progress = FALSE), "must satisfy")   # size below the minimum
})
