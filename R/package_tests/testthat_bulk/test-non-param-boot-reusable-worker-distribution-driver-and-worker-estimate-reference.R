library(testthat)
library(EDI)

# InferenceNonParamBootstrap's reusable-worker distribution driver:
# compute_reusable_bootstrap_worker_distribution() (empty input, draw chunking by
# core count, serial worker reuse keyed by operation, per-draw loader/estimator
# dispatch with loader_args, error -> NA), its bootstrap / jackknife wrappers, and
# compute_bootstrap_worker_estimate_via_compute_treatment_estimate(). Worker
# creation, loaders and estimators are stubbed so the driver logic is exact.

np_fx <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private)
}

stub_priv <- function(p, name, fn) { unlockBinding(name, p); assign(name, fn, envir = p) }

# Wire stubs: draws are numbers; the "estimate" of a draw is 10 * draw.
wire <- function(f, loader = NULL) {
	log <- new.env(); log$created <- 0L; log$loaded <- list()
	stub_priv(f$p, "get_resampling_draw_contract", function(operation)
		list(loader = "load_bootstrap_sample_into_worker", estimator = "compute_bootstrap_worker_estimate"))
	stub_priv(f$p, "create_reusable_bootstrap_worker", function() {
		log$created <- log$created + 1L
		list(id = log$created, current = NULL)
	})
	stub_priv(f$p, "load_bootstrap_sample_into_worker", loader %||% function(worker_state, draw, ...) {
		log$loaded[[length(log$loaded) + 1L]] <- list(id = worker_state$id, draw = draw, extra = list(...))
		worker_state$current <- draw
		invisible(NULL)
	})
	stub_priv(f$p, "compute_bootstrap_worker_estimate", function(worker_state) {
		e <- log$loaded[[length(log$loaded)]]
		if (isTRUE(is.nan(e$draw))) stop("bad draw")
		10 * e$draw
	})
	log
}

test_that("empty draw lists return numeric(0) without creating a worker", {
	f <- np_fx(); log <- wire(f)
	expect_identical(f$p$compute_reusable_bootstrap_worker_distribution(list(), 1L), numeric(0))
	expect_equal(log$created, 0L)
})

test_that("serial run: every draw is loaded then estimated in order, on one worker", {
	f <- np_fx(); log <- wire(f)
	out <- f$p$compute_reusable_bootstrap_worker_distribution(list(1, 2, 3, 4), actual_cores = 1L)
	expect_equal(out, c(10, 20, 30, 40))
	expect_equal(log$created, 1L)
	expect_equal(vapply(log$loaded, function(e) e$draw, numeric(1)), 1:4)
	expect_true(all(vapply(log$loaded, function(e) e$id, numeric(1)) == 1))
})

test_that("serial worker reuse is keyed by operation and survives across calls until the cache is cleared", {
	f <- np_fx(); log <- wire(f)
	f$p$compute_reusable_bootstrap_worker_distribution(list(1, 2), 1L, operation = "non_param_boot")
	f$p$compute_reusable_bootstrap_worker_distribution(list(3), 1L, operation = "non_param_boot")
	expect_equal(log$created, 1L)                                       # same operation: cached worker reused
	expect_equal(f$p$cached_values$reusable_bootstrap_worker$key, "non_param_boot")
	f$p$compute_reusable_bootstrap_worker_distribution(list(4), 1L, operation = "jackknife")
	expect_equal(log$created, 2L)                                       # a different operation gets its own worker
	f$p$cached_values$reusable_bootstrap_worker <- NULL
	f$p$compute_reusable_bootstrap_worker_distribution(list(5), 1L, operation = "jackknife")
	expect_equal(log$created, 3L)
})

test_that("multi-core runs split the draws into contiguous chunks and never cache a worker", {
	f <- np_fx(); log <- wire(f)
	chunks_seen <- NULL
	stub_priv(f$p, "par_lapply", function(X, FUN, n_cores, budget, show_progress, ...) {
		chunks_seen <<- X
		lapply(X, FUN)
	})
	out <- f$p$compute_reusable_bootstrap_worker_distribution(as.list(1:7), actual_cores = 3L)
	expect_equal(chunks_seen, list(`1` = 1:3, `2` = 4:6, `3` = 7L))    # ceiling(7 / 3) = 3 draws per chunk
	expect_equal(out, 10 * (1:7))
	expect_equal(log$created, 3L)                                       # one worker per chunk
	expect_null(f$p$cached_values$reusable_bootstrap_worker)
	# More cores than draws: one draw per chunk.
	chunks_seen <- NULL
	f$p$compute_reusable_bootstrap_worker_distribution(as.list(1:2), actual_cores = 8L)
	expect_equal(names(chunks_seen), c("1", "2"))
})

test_that("a failing draw becomes NA without stopping the run; loader_args are forwarded", {
	f <- np_fx(); log <- wire(f)
	out <- f$p$compute_reusable_bootstrap_worker_distribution(list(1, NaN, 3), 1L)
	expect_equal(out, c(10, NA, 30))
	g <- np_fx(); glog <- wire(g)
	g$p$compute_reusable_bootstrap_worker_distribution(list(1, 2), 1L, loader_args = list(mode = "fast", k = 2L))
	expect_equal(glog$loaded[[1]]$extra, list(mode = "fast", k = 2L))
	expect_equal(glog$loaded[[2]]$extra, list(mode = "fast", k = 2L))
})

test_that("the bootstrap and jackknife wrappers use the non_param_boot operation and forward cores", {
	f <- np_fx()
	seen <- list()
	stub_priv(f$p, "compute_reusable_bootstrap_worker_distribution", function(draws, actual_cores, show_progress = FALSE, operation = "non_param_boot", loader_args = list()) {
		seen[[length(seen) + 1L]] <<- list(draws = draws, cores = actual_cores, op = operation); c(1, 2)
	})
	expect_equal(f$p$compute_bootstrap_distribution_with_reused_workers(list("a"), 2L, bootstrap_type = "x"), c(1, 2))
	expect_equal(f$p$compute_jackknife_distribution_with_reused_workers(list("b", "c"), 3L), c(1, 2))
	expect_equal(vapply(seen, function(s) s$op, character(1)), c("non_param_boot", "non_param_boot"))
	expect_equal(vapply(seen, function(s) s$cores, numeric(1)), c(2, 3))
	expect_equal(seen[[2]]$draws, list("b", "c"))
})

test_that("worker estimate via compute_estimate: first element, NA when the worker is nonestimable", {
	f <- np_fx()
	mk <- function(est, nonest) list(worker = list(
		compute_estimate = function(estimate_only) { expect_true(estimate_only); est },
		is_nonestimable = function(what) { expect_equal(what, "estimate"); nonest }))
	fn <- f$p$compute_bootstrap_worker_estimate_via_compute_treatment_estimate
	expect_equal(fn(mk(c(0.7, 9), FALSE)), 0.7)
	expect_true(is.na(fn(mk(0.7, TRUE))))
	expect_equal(fn(list(worker = list(compute_estimate = function(estimate_only) 1.5))), 1.5)   # no nonestimable hook
})
