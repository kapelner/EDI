library(testthat)
library(EDI)

# Class-level survival results against independent references: the Cox class equals coxph's treatment
# coefficient, the Weibull class equals survreg's AFT coefficient, KM-difference equals the difference
# of Kaplan-Meier medians, the RMST class equals the difference of Kaplan-Meier restricted means with each
# group truncated at its OWN last observation (survfit(rmean = "individual"), NOT the common-tau default)
# together with the matching SE, and the log-rank class' estimate is the difference in mean null-model
# (Breslow) martingale residuals whose dedicated log-rank p-value equals survival::survdiff's (the generic asymptotic p-value is a Wald-style one).

skip_if_not_installed("survival")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t <- rweibull(n, 1.5, exp(1 - 0.4 * w + 0.3 * x)); cens <- runif(n, 0, quantile(t, 0.85))
	y <- pmin(t, cens); dead <- as.numeric(t <= cens)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA), ifelse(dead == 0, y, NA), ifelse(dead == 0, Inf, NA))
	list(des = des, w = w, x = x, y = y, dead = dead, S = survival::Surv(y, dead))
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("Cox and Weibull classes equal coxph / survreg treatment coefficients", {
	f <- fx()
	expect_equal(unname(new_inf("InferenceSurvivalStratCoxPHRegr", f$des)$compute_estimate()), unname(coef(survival::coxph(f$S ~ f$w + f$x))["f$w"]), tolerance = 1e-5)
	expect_equal(unname(new_inf("InferenceSurvivalWeibullRegr", f$des)$compute_estimate()), unname(coef(survival::survreg(f$S ~ f$w + f$x))["f$w"]), tolerance = 1e-4)
})

test_that("KM-difference is the difference of Kaplan-Meier medians", {
	f <- fx()
	q <- unname(quantile(survival::survfit(f$S ~ f$w), 0.5)$quantile)
	expect_equal(unname(new_inf("InferenceSurvivalKMDiff", f$des)$compute_estimate()), q[2] - q[1], tolerance = 1e-8)
})

test_that("RMST class: estimate and SE use each group's own truncation time (individual), which differs from the common-tau default here", {
	f <- fx()
	km <- survival::survfit(f$S ~ f$w)
	ind <- summary(km, rmean = "individual")$table; com <- summary(km, rmean = "common")$table
	d_ind <- unname(ind[2, "rmean"] - ind[1, "rmean"]); d_com <- unname(com[2, "rmean"] - com[1, "rmean"])
	expect_gt(abs(d_ind - d_com), 0.01)                                     # the fixture distinguishes the two definitions
	inf <- new_inf("InferenceSurvivalRestrictedMeanDiff", f$des)
	expect_equal(unname(inf$compute_estimate()), d_ind, tolerance = 1e-8)
	expect_equal(K("get_restricted_mean_se_diff")(f$y, f$dead, f$w), sqrt(sum(ind[, "se(rmean)"]^2)), tolerance = 1e-6)
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, sqrt(sum(ind[, "se(rmean)"]^2)), tolerance = 1e-6)
})

test_that("log-rank class: estimate = mean martingale-residual difference under the Breslow null; p-value equals survdiff's", {
	f <- fx()
	inf <- new_inf("InferenceSurvivalLogRank", f$des)
	M <- as.numeric(residuals(survival::coxph(f$S ~ 1, method = "breslow"), type = "martingale"))
	expect_equal(unname(inf$compute_estimate()), mean(M[f$w == 1]) - mean(M[f$w == 0]), tolerance = 1e-8)
	lr <- survival::survdiff(f$S ~ f$w)
	# compute_asymp_two_sided_pval() is the Wald-style p-value of the martingale estimate / its SE ...
	pv <- inf$.__enclos_env__$private$cached_values
	expect_equal(inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(pv$beta_hat_T / pv$s_beta_hat_T)), tolerance = 1e-5)   # obtained by CI inversion, hence the tolerance
	# ... while the dedicated log-rank method is the classical chi-square test, equal to survdiff's p-value.
	expect_equal(inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0), pchisq(lr$chisq, 1, lower.tail = FALSE), tolerance = 1e-8)
	expect_equal(pv$logrank_score^2 / pv$logrank_var, lr$chisq, tolerance = 1e-8)
})
