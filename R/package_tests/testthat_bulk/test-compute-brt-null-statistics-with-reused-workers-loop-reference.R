library(testthat)
library(EDI)

# InferenceAllAbstract's private compute_brt_null_statistics_with_reused_workers(draws, delta,
# transform_arg, y0_full, zero_one_logit_clamp) (inference_all_abstract_rand_bootstrap.R) is the
# reused-worker fast path behind compute_brt_null_statistics_with_se(): for each draw it loads it into
# a single reused worker via the rand_bootstrap contract's loader, calls the worker's own
# compute_estimate(estimate_only = FALSE), and reads t0/se0 back out of the worker's own cached_values
# -- UNLESS the worker reports itself nonestimable, or either the load or the compute_estimate() call
# errors, in which case that row is c(NA, NA) and the loop continues to the next draw (this is a batch
# loop over B draws on ONE worker, not one worker per draw). A codebase-wide grep confirmed zero test
# references anywhere for this exact private-method name; compute_brt_null_statistics_with_se() itself
# is well tested but only ever via its non-reused-worker fallback path (no class enabling reused
# workers happens to also lack a fast kernel in the existing test corpus's fixtures). Exercised by
# stubbing create_bootstrap_worker_state() to return a minimal hand-built fake worker object (a plain
# environment standing in for the real R6 instance, since only $compute_estimate()/$is_nonestimable()/
# $.__enclos_env__$private$cached_values are actually read) and the rand_bootstrap loader
# (load_rand_bootstrap_draw_into_worker, already independently tested), isolating this function's own
# per-draw extraction/error-handling loop.

fx <- function(seed = 1L, n = 12L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

make_fake_worker <- function(beta, se, nonestimable = FALSE, err_on_compute = FALSE) {
	priv_env <- new.env()
	priv_env$cached_values <- list()
	worker_env <- new.env()
	worker_env$.__enclos_env__ <- list(private = priv_env)
	worker_env$compute_estimate <- function(estimate_only = FALSE) {
		if (err_on_compute) stop("fit failed")
		priv_env$cached_values$beta_hat_T <- beta
		priv_env$cached_values$s_beta_hat_T <- se
		invisible(NULL)
	}
	worker_env$is_nonestimable <- function(what) nonestimable
	worker_env
}

wire <- function(priv, worker, loader = function(...) invisible(NULL)) {
	unlockBinding("create_bootstrap_worker_state", priv)
	priv$create_bootstrap_worker_state <- function() list(worker = worker)
	unlockBinding("load_rand_bootstrap_draw_into_worker", priv)
	priv$load_rand_bootstrap_draw_into_worker <- loader
	priv
}

test_that("a successful draw loads via the rand_bootstrap loader, calls compute_estimate(estimate_only = FALSE), and reads t0/se0 from the worker's own cached_values", {
	priv <- fx(1L)
	calls <- list()
	priv <- wire(priv, make_fake_worker(1.5, 0.3), loader = function(worker_state, draw, delta, transform_responses, y0_full, zero_one_logit_clamp) {
		calls[[length(calls) + 1L]] <<- list(draw = draw, delta = delta, transform_responses = transform_responses, y0_full = y0_full)
		invisible(NULL)
	})
	draws <- list(list(id = 1), list(id = 2), list(id = 3))
	res <- priv$compute_brt_null_statistics_with_reused_workers(draws, delta = 0.1, transform_arg = "none", y0_full = c(1, 2, 3), zero_one_logit_clamp = .Machine$double.eps)
	expect_equal(res$t0, c(1.5, 1.5, 1.5))
	expect_equal(res$se0, c(0.3, 0.3, 0.3))
	expect_length(calls, 3L)
	expect_identical(calls[[2L]]$draw, draws[[2L]])
	expect_identical(calls[[1L]]$transform_responses, "none")
})

test_that("a worker that reports itself nonestimable('estimate') after fitting gives c(NA, NA) for that draw", {
	priv <- fx(2L)
	priv <- wire(priv, make_fake_worker(1.5, 0.3, nonestimable = TRUE))
	res <- priv$compute_brt_null_statistics_with_reused_workers(list(list(id = 1)), delta = 0, transform_arg = "none", y0_full = c(1), zero_one_logit_clamp = .Machine$double.eps)
	expect_true(is.na(res$t0)); expect_true(is.na(res$se0))
})

test_that("an error inside compute_estimate() gives c(NA, NA) for that draw without aborting the batch", {
	priv <- fx(3L)
	priv <- wire(priv, make_fake_worker(1.5, 0.3, err_on_compute = TRUE))
	res <- priv$compute_brt_null_statistics_with_reused_workers(list(list(id = 1)), delta = 0, transform_arg = "none", y0_full = c(1), zero_one_logit_clamp = .Machine$double.eps)
	expect_true(is.na(res$t0)); expect_true(is.na(res$se0))
})

test_that("an error inside the loader itself also gives c(NA, NA) for that draw, without aborting the batch", {
	priv <- fx(4L)
	priv <- wire(priv, make_fake_worker(1.5, 0.3), loader = function(...) stop("loader boom"))
	res <- priv$compute_brt_null_statistics_with_reused_workers(list(list(id = 1)), delta = 0, transform_arg = "none", y0_full = c(1), zero_one_logit_clamp = .Machine$double.eps)
	expect_true(is.na(res$t0)); expect_true(is.na(res$se0))
})

test_that("a single reused worker (not one per draw) handles every draw: only one create_bootstrap_worker_state() call is made across the whole batch", {
	priv <- fx(5L)
	n_created <- 0L
	unlockBinding("create_bootstrap_worker_state", priv)
	priv$create_bootstrap_worker_state <- function() { n_created <<- n_created + 1L; list(worker = make_fake_worker(0.5, 0.1)) }
	unlockBinding("load_rand_bootstrap_draw_into_worker", priv)
	priv$load_rand_bootstrap_draw_into_worker <- function(...) invisible(NULL)
	priv$compute_brt_null_statistics_with_reused_workers(list(list(id = 1), list(id = 2), list(id = 3)), delta = 0, transform_arg = "none", y0_full = c(1), zero_one_logit_clamp = .Machine$double.eps)
	expect_identical(n_created, 1L)
})

test_that("an empty draw list returns empty t0/se0 vectors", {
	priv <- fx(6L)
	priv <- wire(priv, make_fake_worker(0.5, 0.1))
	res <- priv$compute_brt_null_statistics_with_reused_workers(list(), delta = 0, transform_arg = "none", y0_full = numeric(0), zero_one_logit_clamp = .Machine$double.eps)
	expect_length(res$t0, 0L)
	expect_length(res$se0, 0L)
})
