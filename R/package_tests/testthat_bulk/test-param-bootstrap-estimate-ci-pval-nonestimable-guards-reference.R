library(testthat)
library(EDI)

# InferenceExtParamBootstrapEstimate's three "basic" (reflected-quantile) parametric-bootstrap
# entry points -- compute_param_bootstrap_estimate(), compute_param_bootstrap_confidence_interval(),
# and compute_param_bootstrap_pval() -- all share run_param_bootstrap_estimate_batch() and each has
# its own too-few-usable-replicates guard plus its own extreme-result guard, none of which had a
# test reference anywhere. All 4 guards are reached cheaply by mocking run_param_bootstrap_estimate_
# batch() directly (unlockBinding, private) to return a synthetic batch object, avoiding any real
# B-replicate simulation/refitting -- the same technique already used for the sibling
# lik_ratio_bootstrap_* preflight guards closed earlier this session, via the same InferenceContinLin
# fixture (supports_param_bootstrap_estimate() automatically follows supports_lik_ratio_param_
# bootstrap(), per inference_ext_param_bootstrap_estimate.R's own header comment).

lin_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	InferenceContinLin$new(des, verbose = FALSE)
}

test_that("'param_bootstrap_estimate_too_few_usable_replicates' fires on compute_param_bootstrap_estimate()", {
	inf <- lin_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))

	res <- inf$compute_param_bootstrap_estimate(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_too_few_usable_replicates")
})

test_that("'param_bootstrap_estimate_extreme_bias_correction' fires when the bias-corrected theta is flagged extreme", {
	inf <- lin_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 10L, raw_estimate = 0.5, finite_reps = rnorm(10, 0.5, 0.1))
	unlockBinding("param_bootstrap_estimate_extreme", p)
	p$param_bootstrap_estimate_extreme <- function(...) TRUE

	res <- inf$compute_param_bootstrap_estimate(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_extreme_bias_correction")
})

test_that("'param_bootstrap_estimate_too_few_usable_replicates' fires on compute_param_bootstrap_confidence_interval()", {
	inf <- lin_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))

	ci <- inf$compute_param_bootstrap_confidence_interval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_too_few_usable_replicates")
})

test_that("'param_bootstrap_estimate_extreme_confidence_interval' fires when the reflected CI is flagged extreme", {
	inf <- lin_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 10L, raw_estimate = 0.5, finite_reps = rnorm(10, 0.5, 0.1))
	unlockBinding("param_bootstrap_confidence_interval_extreme", p)
	p$param_bootstrap_confidence_interval_extreme <- function(...) TRUE

	ci <- inf$compute_param_bootstrap_confidence_interval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_extreme_confidence_interval")
})

test_that("'param_bootstrap_estimate_too_few_usable_replicates' fires on compute_param_bootstrap_pval()", {
	inf <- lin_fixture(seed = 5L)
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 2L, raw_estimate = 0.5, finite_reps = c(0.4, 0.6))

	pval <- inf$compute_param_bootstrap_pval(delta = 0, B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_too_few_usable_replicates")
})

test_that("'param_bootstrap_estimate_extreme_pvalue_reflection' fires when the reflected delta statistic is flagged extreme", {
	inf <- lin_fixture(seed = 6L)
	p <- inf$.__enclos_env__$private
	unlockBinding("run_param_bootstrap_estimate_batch", p)
	p$run_param_bootstrap_estimate_batch <- function(...) list(n_success = 10L, raw_estimate = 0.5, finite_reps = rnorm(10, 0.5, 0.1))
	unlockBinding("param_bootstrap_estimate_extreme", p)
	p$param_bootstrap_estimate_extreme <- function(...) TRUE

	pval <- inf$compute_param_bootstrap_pval(delta = 0, B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_extreme_pvalue_reflection")
})
