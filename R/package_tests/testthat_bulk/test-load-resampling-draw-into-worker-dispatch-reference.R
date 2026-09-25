library(testthat)
library(EDI)

# InferenceAllAbstract's private load_resampling_draw_into_worker(operation, worker_state, draw, ...)
# (inference_all_abstract_rand.R) is the shared dispatcher behind every reused-worker resampling path
# (randomization, non-parametric bootstrap, Bayesian bootstrap all call it by name, per grep), but is
# always exercised only through a full reused-worker pipeline (jackknife/bootstrap/randomization
# integration tests), never referenced by its own name -- confirmed via a codebase-wide grep. Its own
# contract is small and easy to isolate directly: (1) look up the operation's contract via
# get_resampling_draw_contract(), (2) dispatch by NAME to private[[contract$loader]] with worker_state/
# draw plus any ... args forwarded, (3) return invisible(worker_state) regardless of what the loader
# itself returns (the mutated worker_state, not the loader's return value, is the real output), and
# (4) propagate resampling_draw_contract()'s "Unknown resampling operation" error for a bad operation
# name unchanged. Exercised by stubbing the "rand" operation's real loader
# (load_randomization_draw_into_worker) to capture its arguments, on a real InferenceAllSimpleAverageDiff
# instance.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("dispatches to the operation's contract loader by name, forwarding worker_state/draw/... verbatim, and returns invisible(worker_state) regardless of the loader's own return value", {
	priv <- fx(1L)
	captured <- NULL
	unlockBinding("load_randomization_draw_into_worker", priv)
	priv$load_randomization_draw_into_worker <- function(worker_state, draw, delta, transform_responses, setup, zero_one_logit_clamp = .Machine$double.eps) {
		captured <<- list(worker_state = worker_state, draw = draw, delta = delta,
			transform_responses = transform_responses, setup = setup, zero_one_logit_clamp = zero_one_logit_clamp)
		"loader's own return value, which the dispatcher must ignore"
	}

	ws <- list(id = 42)
	res <- priv$load_resampling_draw_into_worker(
		"rand", worker_state = ws, draw = c(1, 0, 1),
		delta = 0.5, transform_responses = "none", setup = list(a = 1)
	)

	expect_identical(res, ws)  # invisible(worker_state), NOT the loader's own return value
	expect_identical(captured$worker_state, ws)
	expect_identical(captured$draw, c(1, 0, 1))
	expect_identical(captured$delta, 0.5)
	expect_identical(captured$transform_responses, "none")
	expect_identical(captured$setup, list(a = 1))
	expect_identical(captured$zero_one_logit_clamp, .Machine$double.eps)  # default, not overridden
})

test_that("an unrecognized operation name propagates resampling_draw_contract()'s own error unchanged", {
	priv <- fx(2L)
	expect_error(
		priv$load_resampling_draw_into_worker("not_a_real_operation", list(), c(1, 0)),
		"Unknown resampling operation: not_a_real_operation",
		fixed = TRUE
	)
})

test_that("dispatches to a different operation's own loader (non_param_boot), confirming the lookup is genuinely by contract, not hardcoded to 'rand'", {
	priv <- fx(3L)
	captured_op <- NULL
	unlockBinding("load_non_param_bootstrap_draw_into_worker", priv)
	priv$load_non_param_bootstrap_draw_into_worker <- function(worker_state, draw) {
		captured_op <<- list(worker_state = worker_state, draw = draw)
		NULL
	}
	ws <- list(marker = "np-boot")
	res <- priv$load_resampling_draw_into_worker("non_param_boot", worker_state = ws, draw = 1:5)
	expect_identical(res, ws)
	expect_identical(captured_op$worker_state, ws)
	expect_identical(captured_op$draw, 1:5)
})
