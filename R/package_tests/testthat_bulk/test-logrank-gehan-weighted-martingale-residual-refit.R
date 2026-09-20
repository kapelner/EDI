library(testthat)
library(EDI)

# InferenceSurvivalLogRank$compute_estimate_with_bootstrap_weights() (weighted_logrank_mean_difference(),
# inference_survival_log_rank.R) and InferenceSurvivalGehanWilcox$compute_estimate_with_bootstrap_weights()
# (weighted_peto_prentice_mean_difference(), inference_survival_gehan_wilcox.R) had no test anywhere
# calling compute_estimate_with_bootstrap_weights on either class (grepped testthat/testthat_bulk for
# both method names together with either class name; only compute_estimate()/asymp CI/pval paths were
# exercised, via test-continuous-survival-contracts.R, test-design-inference.R, test-rand-bootstrap.R).

logrank_fixture <- function(seed = 20260918L, n = 60L, class = InferenceSurvivalLogRank) {
	set.seed(seed)
	x1 <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- -0.1 + 0.25 * w
	true_time <- rexp(n, rate = exp(lin))
	cens_time <- rexp(n, rate = 0.15)
	y <- pmin(true_time, cens_time)
	dead <- as.integer(true_time <= cens_time)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_),
	                               ifelse(dead == 0, y, NA_real_),
	                               ifelse(dead == 0, Inf, NA_real_))
	inf <- class$new(des, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, dead = dead, w = w)
}

reference_martingale_diff <- function(y, dead, w, weights, peto = FALSE) {
	dat <- data.frame(time = y, dead = dead, treatment = w)
	cox_null <- survival::coxph(survival::Surv(time, dead) ~ 1, data = dat, weights = weights, method = "breslow")
	M <- as.numeric(residuals(cox_null, type = "martingale"))
	if (peto) {
		km_all <- survival::survfit(survival::Surv(time, dead) ~ 1, data = dat, weights = weights)
		idx <- findInterval(y, km_all$time, left.open = TRUE)
		peto_w <- c(1.0, km_all$surv)[idx + 1L]
		M <- peto_w * M
	}
	idx_t <- w == 1
	idx_c <- w == 0
	sum(weights[idx_t] * M[idx_t]) / sum(weights[idx_t]) -
		sum(weights[idx_c] * M[idx_c]) / sum(weights[idx_c])
}

test_that("log-rank weighted refit matches an independent weighted-coxph martingale-residual reference", {
	f <- logrank_fixture(class = InferenceSurvivalLogRank)
	set.seed(1)
	weights <- runif(length(f$y), 0.5, 2)

	actual <- f$inf$compute_estimate_with_bootstrap_weights(weights)
	expected <- reference_martingale_diff(f$y, f$dead, f$w, weights, peto = FALSE)
	expect_equal(actual, expected, tolerance = 1e-6)

	# estimate_only leaves the variance-component caches unset/NA.
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE), actual)
	expect_true(is.na(f$private$last_weighted_refit$s_beta_hat_T))
	# class-specific variance caches are rolled back with the ordinary cache: never populated by a weighted draw
	expect_true(is.null(f$private$cached_values$logrank_score) || is.na(f$private$cached_values$logrank_score))
	expect_true(is.null(f$private$cached_values$logrank_var) || is.na(f$private$cached_values$logrank_var))
})

test_that("log-rank weighted refit is scale-invariant and reproduces the unweighted estimate under unit weights", {
	f <- logrank_fixture(seed = 5L, class = InferenceSurvivalLogRank)
	unit <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, length(f$y)))
	primary <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(unit, primary, tolerance = 1e-6)

	set.seed(2)
	weights <- runif(length(f$y), 0.5, 2)
	est1 <- f$inf$compute_estimate_with_bootstrap_weights(weights)
	est_scaled <- f$inf$compute_estimate_with_bootstrap_weights(3.75 * weights)
	expect_equal(est1, est_scaled, tolerance = 1e-8)
})

test_that("log-rank weighted refit returns NA when one arm has no positive weight, and rejects general censoring", {
	f <- logrank_fixture(seed = 9L, class = InferenceSurvivalLogRank)
	zeroed <- ifelse(f$w == 1, 0, 1)
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(zeroed)))

	set.seed(3)
	des_ic <- DesignFixedBernoulli$new(n = 20L, response_type = "survival", verbose = FALSE)
	des_ic$add_all_subjects_to_experiment(data.frame(x1 = rnorm(20L)))
	des_ic$assign_w_to_all_subjects()
	des_ic$add_all_subject_responses(
		ys = rep(NA_real_, 20L),
		y_Ls = runif(20L, 0, 3),
		y_Rs = runif(20L, 3, 6)
	)
	inf_ic <- InferenceSurvivalLogRank$new(des_ic, verbose = FALSE)
	expect_error(
		inf_ic$compute_estimate_with_bootstrap_weights(rep(1, 20L)),
		"not yet supported"
	)
})

test_that("Gehan-Wilcox weighted refit matches an independent weighted-coxph Peto-Prentice reference", {
	f <- logrank_fixture(seed = 11L, class = InferenceSurvivalGehanWilcox)
	set.seed(4)
	weights <- runif(length(f$y), 0.5, 2)

	actual <- f$inf$compute_estimate_with_bootstrap_weights(weights)
	expected <- reference_martingale_diff(f$y, f$dead, f$w, weights, peto = TRUE)
	expect_equal(actual, expected, tolerance = 1e-6)

	# Peto-Prentice weighting must genuinely differ from the plain log-rank
	# martingale-residual contrast on the same data -- not a no-op.
	plain <- reference_martingale_diff(f$y, f$dead, f$w, weights, peto = FALSE)
	expect_false(isTRUE(all.equal(actual, plain)))
})

test_that("Gehan-Wilcox weighted refit reproduces the unweighted estimate under unit weights and is scale-invariant", {
	f <- logrank_fixture(seed = 13L, class = InferenceSurvivalGehanWilcox)
	unit <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, length(f$y)))
	primary <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(unit, primary, tolerance = 1e-6)

	set.seed(5)
	weights <- runif(length(f$y), 0.5, 2)
	est1 <- f$inf$compute_estimate_with_bootstrap_weights(weights)
	est_scaled <- f$inf$compute_estimate_with_bootstrap_weights(2.5 * weights)
	expect_equal(est1, est_scaled, tolerance = 1e-8)
})

test_that("Gehan-Wilcox weighted refit rejects general censoring the same way log-rank does", {
	set.seed(6)
	des_ic <- DesignFixedBernoulli$new(n = 20L, response_type = "survival", verbose = FALSE)
	des_ic$add_all_subjects_to_experiment(data.frame(x1 = rnorm(20L)))
	des_ic$assign_w_to_all_subjects()
	des_ic$add_all_subject_responses(
		ys = rep(NA_real_, 20L),
		y_Ls = runif(20L, 0, 3),
		y_Rs = runif(20L, 3, 6)
	)
	inf_ic <- InferenceSurvivalGehanWilcox$new(des_ic, verbose = FALSE)
	expect_error(
		inf_ic$compute_estimate_with_bootstrap_weights(rep(1, 20L)),
		"not yet supported"
	)
})
