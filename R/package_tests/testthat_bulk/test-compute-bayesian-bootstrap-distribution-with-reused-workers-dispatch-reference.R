library(testthat)
library(EDI)

# InferenceAllAbstract's private compute_bayesian_bootstrap_distribution_with_reused_workers(draws,
# actual_cores, show_progress) (inference_all_abstract_bayesian_bootstrap.R) is a thin delegator to the
# generic reused-worker driver compute_reusable_bootstrap_worker_distribution(), fixing operation =
# "bayesian_boot" and passing no loader_args (the bayesian_boot contract's loader reads weights/context
# straight off each draw, unlike rand_bootstrap's delta/transform_responses/y0_full/zero_one_logit_clamp
# packaging). The generic driver is exhaustively tested elsewhere but never with operation =
# "bayesian_boot", and this specific wrapper -- the sibling of the already-covered
# compute_rand_bootstrap_distribution_with_reused_workers() -- had zero test references anywhere,
# confirmed via grep. Exercised via the same stub-and-verify pattern.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("delegates to compute_reusable_bootstrap_worker_distribution() with operation = 'bayesian_boot' and no loader_args, forwarding draws/actual_cores/show_progress and returning its result unchanged", {
	priv <- fx(1L)
	captured <- NULL
	unlockBinding("compute_reusable_bootstrap_worker_distribution", priv)
	priv$compute_reusable_bootstrap_worker_distribution <- function(draws, actual_cores, show_progress = FALSE, operation = "non_param_boot", loader_args = list()) {
		captured <<- list(draws = draws, actual_cores = actual_cores, show_progress = show_progress, operation = operation, loader_args = loader_args)
		c(9.9, 8.8)  # the driver's own (already-tested) return value
	}

	draws <- list(list(subject_or_block_weights = c(1, 2), context = list(a = 1)), list(subject_or_block_weights = c(3, 4), context = list(a = 2)))
	res <- priv$compute_bayesian_bootstrap_distribution_with_reused_workers(draws = draws, actual_cores = 3L, show_progress = TRUE)

	expect_identical(res, c(9.9, 8.8))  # passthrough, not recomputed
	expect_identical(captured$draws, draws)
	expect_identical(captured$actual_cores, 3L)
	expect_identical(captured$show_progress, TRUE)
	expect_identical(captured$operation, "bayesian_boot")
	expect_identical(captured$loader_args, list())  # unlike rand_bootstrap's sibling, no loader_args are packaged
})

test_that("show_progress defaults to FALSE when not supplied", {
	priv <- fx(2L)
	captured_show_progress <- NULL
	unlockBinding("compute_reusable_bootstrap_worker_distribution", priv)
	priv$compute_reusable_bootstrap_worker_distribution <- function(draws, actual_cores, show_progress = FALSE, operation = "non_param_boot", loader_args = list()) {
		captured_show_progress <<- show_progress
		numeric(0)
	}
	priv$compute_bayesian_bootstrap_distribution_with_reused_workers(draws = list(), actual_cores = 1L)
	expect_identical(captured_show_progress, FALSE)
})
