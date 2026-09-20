library(testthat)
library(EDI)

# The base Inference class's fit warm-start state machine (set_fit_warm_start /
# clear_fit_warm_start / get_fit_warm_start* accessors, with the resampling-
# operation gate and the untrusted validation path), the tier-based
# get_optimal_warm_start_config() dispatcher, and the Wald component's
# invert_ci_to_find_two_sided_pval_for_treatment_effect() (bisection over the
# CI level). None had a direct test reference. The CI inversion is checked
# against the closed-form Welch t-test p-value it must reproduce.

ws_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("trusted warm-start writes store the value, type, Fisher matrix and weights; clearing resets all four", {
	f <- ws_priv()
	p <- f$priv
	expect_true(isTRUE(p$fit_warm_start_enabled))
	fisher <- diag(3)
	p$set_fit_warm_start(c(1, 2, 3), "beta", fisher = fisher, weights = c(.5, .5))
	expect_equal(p$get_fit_warm_start("beta"), c(1, 2, 3))
	expect_null(p$get_fit_warm_start("params"))                         # type must match
	expect_equal(p$get_fit_warm_start_fisher(3), fisher)
	expect_null(p$get_fit_warm_start_fisher(2))                         # wrong dimension
	expect_equal(p$get_fit_warm_start_weights(), c(.5, .5))
	expect_equal(p$get_fit_warm_start_for_length("beta", 3), c(1, 2, 3))
	expect_null(p$get_fit_warm_start_for_length("beta", 2))
	expect_null(p$get_fit_warm_start_for_length("beta", 0))
	expect_equal(p$get_fit_warm_start_for_length("beta", NULL), c(1, 2, 3))

	p$clear_fit_warm_start()
	expect_null(p$get_fit_warm_start("beta"))
	expect_null(p$get_fit_warm_start_fisher(3))
	expect_null(p$get_fit_warm_start_weights())
})

test_that("non-finite stored starts are never returned, and a disabled warm start is inert", {
	f <- ws_priv()
	p <- f$priv
	p$set_fit_warm_start(c(1, NA), "beta")
	expect_null(p$get_fit_warm_start("beta"))
	p$set_fit_warm_start(c(1, 2), "params")
	expect_equal(p$get_fit_warm_start("params"), c(1, 2))

	p$fit_warm_start_enabled <- FALSE
	expect_null(p$get_fit_warm_start("params"))
	expect_null(p$get_fit_warm_start_fisher(2))
	expect_null(p$get_fit_warm_start_weights())
	p$set_fit_warm_start(c(9, 9), "beta")                                # disabled: clears instead of storing
	p$fit_warm_start_enabled <- TRUE
	expect_null(p$get_fit_warm_start("beta"))
})

test_that("resampling operations may not overwrite the primary warm start, except randomization", {
	f <- ws_priv()
	p <- f$priv
	p$set_fit_warm_start(c(1, 2), "beta")
	p$active_resampling_operation <- "bootstrap"
	p$set_fit_warm_start(c(7, 7), "beta")
	expect_equal(p$get_fit_warm_start("beta"), c(1, 2))
	p$active_resampling_operation <- "rand"
	p$set_fit_warm_start(c(5, 5), "beta")
	expect_equal(p$get_fit_warm_start("beta"), c(5, 5))
})

test_that("untrusted writes validate, symmetrize and positive-definiteness-check the Fisher matrix and sanitize weights", {
	f <- ws_priv()
	p <- f$priv
	skewed <- matrix(c(2, 0.2, 0.4, 3), 2)
	p$set_fit_warm_start(c(1, 2), "beta", fisher = skewed, weights = c(1, 2, 3), force_pd = FALSE)
	expect_equal(p$get_fit_warm_start_fisher(2), (skewed + t(skewed)) / 2)
	expect_equal(p$get_fit_warm_start_weights(), c(1, 2, 3))

	p$set_fit_warm_start(c(1, 2), "beta", fisher = matrix(c(1, 2, 2, 1), 2), weights = c(1, NA), force_pd = FALSE)   # indefinite
	expect_null(p$get_fit_warm_start_fisher(2))
	expect_null(p$get_fit_warm_start_weights())
	p$set_fit_warm_start(c(1, 2), "beta", fisher = diag(3), force_pd = FALSE)                                        # wrong size
	expect_null(p$get_fit_warm_start_fisher(2))
	expect_equal(p$get_fit_warm_start("beta"), c(1, 2))

	p$set_fit_warm_start(c(1, Inf), "beta", force_pd = FALSE)                                                        # non-finite start clears everything
	expect_null(p$get_fit_warm_start("beta"))
	p$set_fit_warm_start(c(1, 2), "beta", force_pd = FALSE)
	p$set_fit_warm_start(NULL, "beta", force_pd = FALSE)
	expect_null(p$get_fit_warm_start("beta"))
})

test_that("get_optimal_warm_start_config adds components by complexity tier", {
	f <- ws_priv()
	p <- f$priv
	p$set_fit_warm_start(c(1, 2, 3), "beta", fisher = diag(3), weights = rep(1, 40))
	set_tier <- function(tier) {
		unlockBinding("get_complexity_tier", p)
		p$get_complexity_tier <- function() tier
	}
	nm <- function() sort(names(p$get_optimal_warm_start_config(3)))

	set_tier("light")
	expect_equal(nm(), c("start_beta", "start_params", "warm_start_beta"))
	expect_equal(p$get_optimal_warm_start_config(3)$start_beta, c(1, 2, 3))

	set_tier("medium")
	expect_equal(nm(), c("start_beta", "start_params", "warm_start_beta", "warm_start_weights"))
	p$active_resampling_operation <- "bayesian_boot"
	expect_equal(nm(), c("start_beta", "start_params", "warm_start_beta"))
	p$active_resampling_operation <- NULL

	set_tier("heavy")
	expect_equal(nm(), c("start_beta", "start_params", "warm_start_beta", "warm_start_fisher_info", "warm_start_weights"))
	expect_equal(p$get_optimal_warm_start_config(3)$warm_start_fisher_info, diag(3))
	# Very high dimensionality falls back to beta-only regardless of tier.
	expect_equal(sort(names(p$get_optimal_warm_start_config(60))), c("start_beta", "start_params", "warm_start_beta"))
	# A wrong expected length yields no start at all.
	expect_null(p$get_optimal_warm_start_config(5)$start_beta)
})

test_that("CI inversion reproduces the closed-form Welch t-test p-value on either side of the estimate", {
	set.seed(123)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 123)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	est <- inf$compute_estimate()
	tt <- function(delta) t.test(y[w == 1], y[w == 0], mu = delta)$p.value

	for (delta in c(0, 0.5, est - 0.3, est + 0.4, 2.5)) {
		expect_equal(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(delta), tt(delta), tolerance = 5e-4, info = as.character(delta))
	}
	expect_equal(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(est), 1)
	# A null wildly outside every CI gives the smallest representable level; hugely large
	# nulls on the other side behave symmetrically.
	expect_lt(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(1e6), 1e-6)
	expect_lt(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(-1e6), 1e-6)
})

test_that("CI inversion returns NA when the estimate or the interval endpoints are unavailable", {
	set.seed(123)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 123)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	p <- inf$.__enclos_env__$private

	unlockBinding("compute_estimate", inf)
	inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	expect_true(is.na(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(0)))

	inf$compute_estimate <- function(estimate_only = FALSE) 1
	unlockBinding("compute_asymp_confidence_interval", inf)
	inf$compute_asymp_confidence_interval <- function(alpha = 0.05) c(NA_real_, NA_real_)
	expect_true(is.na(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(0)))
	inf$compute_asymp_confidence_interval <- function(alpha = 0.05) stop("no interval")
	expect_true(is.na(p$invert_ci_to_find_two_sided_pval_for_treatment_effect(0)))
})
