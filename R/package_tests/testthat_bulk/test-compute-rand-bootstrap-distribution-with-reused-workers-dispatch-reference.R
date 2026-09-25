library(testthat)
library(EDI)

# InferenceAllAbstract's private compute_rand_bootstrap_distribution_with_reused_workers(rand_bootstrap_
# draws, delta, transform_responses, y0_full, actual_cores, show_progress, zero_one_logit_clamp)
# (inference_all_abstract_rand_bootstrap.R) is a thin 1-line delegator to the generic reused-worker
# driver compute_reusable_bootstrap_worker_distribution(), fixing operation = "rand_bootstrap" and
# packaging delta/transform_responses/y0_full/zero_one_logit_clamp into loader_args. The generic driver
# itself is exhaustively tested (test-non-param-boot-reusable-worker-distribution-driver-and-worker-
# estimate-reference.R), but only ever with operation = "non_param_boot"/"jackknife" -- never
# "rand_bootstrap" -- and this specific wrapper is never called by name anywhere, confirmed via grep.
# Its own return-value passthrough and argument-forwarding contract had no direct test. Exercised by
# stubbing compute_reusable_bootstrap_worker_distribution() to capture its call, the same
# stub-and-verify pattern already established for the sibling load_resampling_draw_into_worker()
# dispatcher.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("delegates to compute_reusable_bootstrap_worker_distribution() with operation = 'rand_bootstrap' and the loader_args exactly packaged, returning its result unchanged", {
	priv <- fx(1L)
	captured <- NULL
	unlockBinding("compute_reusable_bootstrap_worker_distribution", priv)
	priv$compute_reusable_bootstrap_worker_distribution <- function(draws, actual_cores, show_progress = FALSE, operation = "non_param_boot", loader_args = list()) {
		captured <<- list(draws = draws, actual_cores = actual_cores, show_progress = show_progress, operation = operation, loader_args = loader_args)
		c(1.1, 2.2, 3.3)  # the driver's own (already-tested) return value
	}

	draws <- list(list(i_b = 1:3, m_vec_b = NULL), list(i_b = 4:6, m_vec_b = NULL))
	res <- priv$compute_rand_bootstrap_distribution_with_reused_workers(
		rand_bootstrap_draws = draws, delta = 0.5, transform_responses = "none",
		y0_full = c(1, 2, 3), actual_cores = 2L, show_progress = TRUE
	)

	expect_identical(res, c(1.1, 2.2, 3.3))  # passthrough, not recomputed
	expect_identical(captured$draws, draws)
	expect_identical(captured$actual_cores, 2L)
	expect_identical(captured$show_progress, TRUE)
	expect_identical(captured$operation, "rand_bootstrap")
	expect_identical(captured$loader_args, list(
		delta = 0.5, transform_responses = "none", y0_full = c(1, 2, 3),
		zero_one_logit_clamp = .Machine$double.eps
	))
})

test_that("show_progress defaults to FALSE and zero_one_logit_clamp defaults to .Machine$double.eps when not supplied", {
	priv <- fx(2L)
	captured <- NULL
	unlockBinding("compute_reusable_bootstrap_worker_distribution", priv)
	priv$compute_reusable_bootstrap_worker_distribution <- function(draws, actual_cores, show_progress = FALSE, operation = "non_param_boot", loader_args = list()) {
		captured <<- list(show_progress = show_progress, loader_args = loader_args)
		numeric(0)
	}
	priv$compute_rand_bootstrap_distribution_with_reused_workers(
		rand_bootstrap_draws = list(), delta = 0, transform_responses = "log", y0_full = numeric(0), actual_cores = 1L
	)
	expect_identical(captured$show_progress, FALSE)
	expect_identical(captured$loader_args$zero_one_logit_clamp, .Machine$double.eps)
})
