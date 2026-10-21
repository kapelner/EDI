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

test_that("multi-core runs send contiguous draw slices and initialize one worker per batch", {
	f <- np_fx(); log <- wire(f)
	chunks_seen <- NULL
	dispatch_seen <- NULL
	stub_priv(f$p, "par_lapply", function(X, FUN, n_cores, budget, show_progress, ...) {
		chunks_seen <<- X
		dispatch_seen <<- list(FUN = FUN, batches = X)
		lapply(X, FUN)
	})
	out <- f$p$compute_reusable_bootstrap_worker_distribution(as.list(1:7), actual_cores = 3L)
	expect_equal(lapply(chunks_seen, function(batch) {
		lapply(batch, function(task) unlist(task$draws, use.names = FALSE))
	}), list(`1` = list(1:3), `2` = list(4:6), `3` = list(7L)))       # ceiling(7 / 3) = 3 draws per logical chunk
	expect_equal(out, 10 * (1:7))
	expect_equal(log$created, 3L)                                       # one worker state per worker batch
	expect_null(f$p$cached_values$reusable_bootstrap_worker)

	# Capture and serialize the production par_lapply boundary, not a lookalike
	# task closure. The current FUN's fresh runner environment must not retain
	# the full draws binding; every logical task in a worker batch carries only
	# its assigned draw slice. Compare with the legacy full-draws-per-task shape.
	current_env <- as.list(environment(dispatch_seen$FUN), all.names = TRUE)
	expect_false("draws" %in% names(current_env))
	current_payloads <- lapply(seq_along(dispatch_seen$batches), function(i) {
		serialize(list(FUN = dispatch_seen$FUN, batch = dispatch_seen$batches[[i]]), NULL, xdr = FALSE)
	})
	expect_true(all(lengths(current_payloads) > 0L))
	expect_equal(lapply(dispatch_seen$batches, function(batch) {
		lapply(batch, function(task) unlist(task$draws, use.names = FALSE))
	}), list(`1` = list(1:3), `2` = list(4:6), `3` = list(7L)))
	legacy_fun <- local({
		full_draws <- as.list(1:7)
		function(batch) invisible(full_draws)
	})
	legacy_payloads <- lapply(seq_along(dispatch_seen$batches), function(i) {
		serialize(list(FUN = legacy_fun, batch = seq_len(7L)), NULL, xdr = FALSE)
	})
	expect_true(all(lengths(legacy_payloads) > 0L))
	expect_lt(sum(lengths(current_payloads)), sum(lengths(legacy_payloads)))
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

checkout_reusable_worker_distribution <- function(eval_env){
	source_candidates = c(
		file.path("R", "EDI", "R", "inference_all_abstract_non_param_boot.R"),
		file.path("..", "..", "EDI", "R", "inference_all_abstract_non_param_boot.R")
	)
	source_file = source_candidates[file.exists(source_candidates)][1L]
	if (is.na(source_file)) stop("Could not locate checkout bootstrap source")
	source_lines = readLines(source_file, warn = FALSE)
	start_line = grep("^\\s*compute_reusable_bootstrap_worker_distribution\\s*=\\s*function\\s*\\(", source_lines)
	if (!length(start_line)) stop("Could not locate checkout reusable-worker method")
	partial = character()
	definition = NULL
	for (line in source_lines[seq.int(start_line[1L], length(source_lines))]) {
		partial = c(partial, line)
		candidate = sub(",\\s*$", "", paste(partial, collapse = "\n"))
		parsed = tryCatch(parse(text = candidate), error = function(e) NULL)
		if (length(parsed) == 1L) {
			assignment = parsed[[1L]]
			if (is.call(assignment) && identical(assignment[[1L]], as.name("=")) &&
					identical(assignment[[2L]], as.name("compute_reusable_bootstrap_worker_distribution"))) {
				definition = assignment[[3L]]
				break
			}
		}
	}
	if (is.null(definition)) stop("Could not extract checkout reusable-worker method")
	eval(definition, envir = eval_env)
}

source_worker_distribution_fixture <- function(fail_draws = numeric()){
	eval_env = new.env(parent = baseenv())
	eval_env$private = new.env(parent = emptyenv())
	eval_env$private$cached_values = list()
	eval_env$fork_cluster = NULL
	eval_env$mirai_cores = NULL
	eval_env$get_global_fork_cluster = function() eval_env$fork_cluster
	eval_env$get_global_mirai_cores = function() eval_env$mirai_cores
	eval_env$creation_log = integer()
	eval_env$private$get_resampling_draw_contract = function(operation) {
		list(loader = "load_draw", estimator = "estimate_draw")
	}
	eval_env$private$create_reusable_bootstrap_worker = function() {
		eval_env$creation_log = c(eval_env$creation_log, length(eval_env$creation_log) + 1L)
		worker_state = new.env(parent = emptyenv())
		worker_state$id = length(eval_env$creation_log)
		worker_state$current = NULL
		worker_state
	}
	eval_env$private$check_bootstrap_replicate_deadline = function(label) invisible(FALSE)
	eval_env$private$resampling_error_to_na = function(e) {
		if (grepl("reached elapsed time limit", conditionMessage(e), fixed = TRUE)) stop(e)
		NA_real_
	}
	eval_env$private[["load_draw"]] = function(worker_state, draw, ...) {
		if (draw %in% fail_draws) stop(paste("bad draw", draw))
		worker_state$current = draw
		invisible(NULL)
	}
	eval_env$private[["estimate_draw"]] = function(worker_state) 10 * worker_state$current
	eval_env$private$par_lapply = function(X, FUN, n_cores, budget, show_progress, ...) {
		eval_env$captured_batches = X
		eval_env$captured_fun = FUN
		lapply(X, FUN)
	}
	eval_env$tryCatch_calls = 0L
	eval_env$tryCatch = function(expr, ...) {
		eval_env$tryCatch_calls = eval_env$tryCatch_calls + 1L
		base::tryCatch(expr, ...)
	}
	eval_env$run = checkout_reusable_worker_distribution(eval_env)
	eval_env
}

test_that("checkout reusable-worker fast path has one error guard per chunk", {
	f = source_worker_distribution_fixture()
	out = f$run(as.list(1:4), actual_cores = 1L)
	expect_equal(out, 10 * (1:4))
	expect_equal(f$tryCatch_calls, 1L)
})

test_that("checkout chunk fallback isolates the failed draw and continues the rest", {
	f = source_worker_distribution_fixture(fail_draws = c(2, 4))
	out = f$run(as.list(1:5), actual_cores = 1L)
	expect_equal(out, c(10, NA_real_, 30, NA_real_, 50))
	expect_equal(f$tryCatch_calls, 4L) # one chunk guard plus draws 3, 4, and 5
})

test_that("checkout chunk guard still propagates resampling control conditions", {
	f = source_worker_distribution_fixture()
	f$private[["load_draw"]] = function(worker_state, draw, ...) {
		stop("resampling reached elapsed time limit")
	}
	expect_error(f$run(list(1, 2), actual_cores = 1L), "reached elapsed time limit")
})

test_that("checkout fork dispatch sends worker-local draw slices and creates one worker per node", {
	f = source_worker_distribution_fixture()
	# With two persistent nodes and three unchanged logical chunks, static fork
	# assignment gives the first node two contiguous chunks and the second one.
	f$fork_cluster = list("node-1", "node-2")
	out = f$run(as.list(1:7), actual_cores = 3L)
	expect_equal(out, 10 * (1:7))
	expect_equal(length(f$creation_log), 2L)
	expect_equal(length(f$captured_batches), 2L)
	expect_equal(length(f$captured_batches[[1L]]), 2L)
	expect_equal(length(f$captured_batches[[2L]]), 1L)
	expect_equal(unlist(lapply(f$captured_batches, function(batch) {
	lapply(batch, function(task) unlist(task$draws, use.names = FALSE))
	}), use.names = FALSE), 1:7)
	fun_env = environment(f$captured_fun)
	expect_false(exists("draws", envir = fun_env, inherits = FALSE))
	expect_false(exists("draws", envir = parent.env(fun_env), inherits = FALSE))
})

test_that("checkout worker batches preserve per-draw error recovery across logical chunks", {
	f = source_worker_distribution_fixture(fail_draws = 5)
	f$fork_cluster = list("node-1", "node-2")
	out = f$run(as.list(1:7), actual_cores = 3L)
	expect_equal(out, c(10, 20, 30, 40, NA_real_, 60, 70))
	expect_equal(length(f$creation_log), 2L)
})

test_that("checkout mirai batching preserves each original logical-chunk seed", {
	f = source_worker_distribution_fixture()
	f$mirai_cores = 2L
	f$private$seed = 71L
	f$private[["estimate_draw"]] = function(worker_state) 10 * worker_state$current + runif(1L)
	out = f$run(as.list(1:7), actual_cores = 3L)
	expect_equal(length(f$creation_log), 2L)
	expect_equal(length(f$captured_batches), 2L)
	expect_equal(unlist(lapply(f$captured_batches, function(batch) {
	lapply(batch, function(task) unlist(task$draws, use.names = FALSE))
	}), use.names = FALSE), 1:7)
	# The three logical chunks remain 1:3, 4:6, 7 and each gets the same
	# private$seed + logical chunk id as before daemon-level batching.
	expected = numeric(7L)
	for (i in seq_len(3L)) {
		set.seed(71L + i)
		idxs = switch(as.character(i), "1" = 1:3, "2" = 4:6, "3" = 7L)
		expected[idxs] = 10 * idxs + vapply(idxs, function(x) runif(1L), numeric(1L))
	}
	expect_equal(out, expected, tolerance = 0)
	fun_env = environment(f$captured_fun)
	expect_false(exists("draws", envir = fun_env, inherits = FALSE))
})
