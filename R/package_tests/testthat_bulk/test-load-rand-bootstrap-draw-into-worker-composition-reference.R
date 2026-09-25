library(testthat)
library(EDI)

# InferenceAllAbstract's private load_rand_bootstrap_draw_into_worker(worker_state, draw, delta,
# transform_responses, y0_full, zero_one_logit_clamp) (inference_all_abstract_rand_bootstrap.R) is the
# rand_bootstrap resampling contract's own loader: it composes two other loaders, first loading the
# row-resample (draw$i_b/draw$m_vec_b) via load_bootstrap_sample_into_worker(), then loading the
# permuted assignment via load_rand_bootstrap_assignment_into_worker(), forwarding delta/transform_
# responses/y0_full/zero_one_logit_clamp to the latter. The only existing reference to this exact
# private-method name (R/EDI/tests/testthat/test-bootstrap-worker-hook-contract.R) entirely REPLACES
# it with a fake stub to test the generic reused-worker executor's dispatch contract, never exercising
# the real composition body; a codebase-wide grep confirmed no other test calls the real
# implementation. Exercised by stubbing its two delegate loaders (both independently well-tested
# elsewhere: load_bootstrap_sample_into_worker, load_rand_bootstrap_assignment_into_worker) to capture
# their arguments.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("loads the row-resample via load_bootstrap_sample_into_worker(i_b, m_vec_b), then the permuted assignment via load_rand_bootstrap_assignment_into_worker(), forwarding delta/transform_responses/y0_full/zero_one_logit_clamp", {
	priv <- fx(1L)
	sample_call <- NULL
	assign_call <- NULL

	unlockBinding("load_bootstrap_sample_into_worker", priv)
	priv$load_bootstrap_sample_into_worker <- function(worker_state, boot_sample) {
		sample_call <<- list(worker_state = worker_state, boot_sample = boot_sample)
		invisible(NULL)
	}
	unlockBinding("load_rand_bootstrap_assignment_into_worker", priv)
	priv$load_rand_bootstrap_assignment_into_worker <- function(worker_state, draw, delta, transform_responses, y0_full, zero_one_logit_clamp) {
		assign_call <<- list(worker_state = worker_state, draw = draw, delta = delta,
			transform_responses = transform_responses, y0_full = y0_full, zero_one_logit_clamp = zero_one_logit_clamp)
		invisible(NULL)
	}

	ws <- list(id = 1)
	draw <- list(i_b = c(1, 2, 3), m_vec_b = c(9, 9, 9), w_b = c(1, 0, 1))
	res <- priv$load_rand_bootstrap_draw_into_worker(
		ws, draw, delta = 0.3, transform_responses = "none", y0_full = c(1, 2, 3)
	)

	# invisible(worker_state) is NOT returned by this composed loader itself (it returns whatever the
	# last inner call returns, here invisible(NULL) from the stubbed assignment loader)
	expect_null(res)

	expect_identical(sample_call$worker_state, ws)
	expect_identical(sample_call$boot_sample, list(i_b = draw$i_b, m_vec_b = draw$m_vec_b))

	expect_identical(assign_call$worker_state, ws)
	expect_identical(assign_call$draw, draw)  # the FULL draw (including w_b), not just i_b/m_vec_b
	expect_identical(assign_call$delta, 0.3)
	expect_identical(assign_call$transform_responses, "none")
	expect_identical(assign_call$y0_full, c(1, 2, 3))
	expect_identical(assign_call$zero_one_logit_clamp, .Machine$double.eps)  # default, not overridden
})

test_that("an explicit zero_one_logit_clamp is forwarded to the assignment loader instead of the default", {
	priv <- fx(2L)
	captured_clamp <- NULL
	unlockBinding("load_bootstrap_sample_into_worker", priv)
	priv$load_bootstrap_sample_into_worker <- function(worker_state, boot_sample) invisible(NULL)
	unlockBinding("load_rand_bootstrap_assignment_into_worker", priv)
	priv$load_rand_bootstrap_assignment_into_worker <- function(worker_state, draw, delta, transform_responses, y0_full, zero_one_logit_clamp) {
		captured_clamp <<- zero_one_logit_clamp
		invisible(NULL)
	}
	priv$load_rand_bootstrap_draw_into_worker(
		list(), list(i_b = 1:2, m_vec_b = c(1, 1)), delta = 0, transform_responses = "logit",
		y0_full = c(0.5, 0.5), zero_one_logit_clamp = 1e-3
	)
	expect_identical(captured_clamp, 1e-3)
})
