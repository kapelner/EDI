library(testthat)
library(EDI)

# InferenceBayesianBootstrap$approximate_bayesian_bootstrap_distribution_beta_hat_T()'s
# debug = TRUE branch (run_debug_iter, the reusable-worker chunk dispatch, and
# the errors/warnings/num_errors/num_warnings/prop_* summary assembly --
# inference_all_abstract_bayesian_bootstrap.R lines ~113-189) had no test
# anywhere in the suite: grep across testthat/ and testthat_bulk/ found no
# `debug = TRUE` call on this method. Likewise its `supports_bayesian_bootstrap()`
# guard and its non-blocking-design `weighting_unit_type` rejection were
# untested by message.

bbdebug_design = function(response_type = "continuous", n = 12L, seed = 20260728L) {
	EDI:::inference_migration_complete_design(response_type, n = n, seed = seed)
}

test_that("debug = TRUE reproduces the non-debug distribution and its full summary contract", {
	des = bbdebug_design()
	obj = InferenceAllSimpleAverageDiff$new(des)
	obj$num_cores = 1L
	obj$set_seed(999L)
	plain = as.numeric(obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE))

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(999L)
	dbg = obj2$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE, debug = TRUE)

	expect_type(dbg, "list")
	expect_named(dbg, c(
		"values", "errors", "warnings", "num_errors", "num_warnings",
		"prop_iterations_with_errors", "prop_iterations_with_warnings", "prop_illegal_values"
	))
	# Same seed, same draws -> identical replicate-by-replicate estimates,
	# proving the debug path invokes the same underlying computation.
	expect_equal(dbg$values, plain, tolerance = 1e-10)

	expect_length(dbg$errors, 9L)
	expect_length(dbg$warnings, 9L)
	expect_true(all(vapply(dbg$errors, is.character, logical(1))))
	expect_true(all(vapply(dbg$errors, length, integer(1)) == 0L))
	expect_true(all(vapply(dbg$warnings, length, integer(1)) == 0L))
	expect_equal(dbg$num_errors, rep(0L, 9L))
	expect_equal(dbg$num_warnings, rep(0L, 9L))
	# Independent reference: the three prop_* fields are exactly the
	# documented aggregate formulas over num_errors/num_warnings/values.
	expect_equal(dbg$prop_iterations_with_errors, mean(dbg$num_errors > 0))
	expect_equal(dbg$prop_iterations_with_warnings, mean(dbg$num_warnings > 0))
	expect_equal(dbg$prop_illegal_values, mean(!is.finite(dbg$values)))
	expect_equal(dbg$prop_iterations_with_errors, 0)
	expect_equal(dbg$prop_iterations_with_warnings, 0)
	expect_equal(dbg$prop_illegal_values, 0)
})

test_that("non-debug public distribution uses the reusable worker and preserves draw order", {
	des = bbdebug_design()
	make_traced = function(num_cores = 1L, trace_dispatch = FALSE) {
		obj = InferenceAllSimpleAverageDiff$new(des)
		obj$num_cores = num_cores
		obj$set_seed(20261020L)
		private = obj$.__enclos_env__$private
		expect_true(private$use_reusable_bootstrap_worker())
		trace = new.env(parent = emptyenv())
		trace$created = 0L
		original_create = private$create_bootstrap_worker_state
		unlockBinding("create_bootstrap_worker_state", private)
		assign("create_bootstrap_worker_state", function(...) {
			trace$created = trace$created + 1L
			original_create(...)
		}, envir = private)
		lockBinding("create_bootstrap_worker_state", private)
		if (isTRUE(trace_dispatch)) {
			trace$actual_cores = integer()
			unlockBinding("compute_bayesian_bootstrap_distribution_with_reused_workers", private)
			assign("compute_bayesian_bootstrap_distribution_with_reused_workers", function(draws, actual_cores, show_progress = FALSE) {
				trace$actual_cores = c(trace$actual_cores, as.integer(actual_cores))
				private$compute_reusable_bootstrap_worker_distribution(
					draws = draws,
					actual_cores = actual_cores,
					show_progress = show_progress,
					operation = "bayesian_boot"
				)
			}, envir = private)
			lockBinding("compute_bayesian_bootstrap_distribution_with_reused_workers", private)
		}
		list(obj = obj, trace = trace)
	}

	production = make_traced()
	values = as.numeric(production$obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 9L, show_progress = FALSE
	))
	expect_gt(production$trace$created, 0L)

	debug_serial = make_traced()
	debug_values = debug_serial$obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 9L, show_progress = FALSE, debug = TRUE
	)
	expect_identical(values, debug_values$values)
	expect_identical(debug_values$num_errors, rep(0L, 9L))

	# The selected fixture is pure R in the weighted estimator, and the history
	# of the fork hang is specific to the non-reusable duplicate-per-draw path.
	# Still tear down any lazily created workers unconditionally like the
	# adjacent multi-core debug test does.
	on.exit(unset_num_cores(), add = TRUE)
	set_num_cores(2L)
	two_core_request = make_traced(num_cores = 2L, trace_dispatch = TRUE)
	two_core_values = as.numeric(two_core_request$obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 9L, show_progress = FALSE
	))
	expect_identical(two_core_request$obj$num_cores, 2L)
	expect_identical(two_core_request$trace$actual_cores, 2L)
	expect_identical(two_core_values, debug_values$values)
})

test_that("debug = TRUE under multi-core dispatch reproduces the single-core distribution", {
	# obj_parallel$num_cores <- 2L below drives par_lapply() into its lazy-fork-
	# cluster branch (inference_all_abstract.R's par_lapply()), which stores a
	# real, persistent 2-worker cluster in edi_env$global_fork_cluster -- by
	# design, meant to outlive the call for reuse by real callers. In a
	# bin-packed test shard that persistence leaks into every later test in the
	# same session (get_num_cores() then reports 2, not 1; see the identical
	# leak already fixed in test-bayesian-bootstrap-non-reusable-worker-debug-
	# path.R), so this test must tear it down itself.
	on.exit(unset_num_cores(), add = TRUE)
	des = bbdebug_design()
	obj_serial = InferenceAllSimpleAverageDiff$new(des)
	obj_serial$num_cores = 1L
	obj_serial$set_seed(4242L)
	serial = obj_serial$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE, debug = TRUE)

	obj_parallel = InferenceAllSimpleAverageDiff$new(des)
	obj_parallel$num_cores = 2L
	obj_parallel$set_seed(4242L)
	parallel = obj_parallel$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 9L, show_progress = FALSE, debug = TRUE)

	# Draws are pre-generated from the object's own seed before dispatch, so the
	# chunked/multi-core code path (chunk_id split + unlist combine) must
	# reproduce the identical serial values, not just a same-length vector.
	expect_equal(parallel$values, serial$values, tolerance = 1e-10)
	expect_equal(parallel$num_errors, rep(0L, 9L))
	expect_equal(parallel$prop_illegal_values, 0)
})

test_that("supports_bayesian_bootstrap() = FALSE stops before any draw is generated, even under debug = TRUE", {
	des = bbdebug_design("ordinal", n = 20L)
	obj = InferenceOrdinalStereotypeLogitRegr$new(des)
	expect_false(obj$.__enclos_env__$private$supports_bayesian_bootstrap())
	expect_error(
		obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 3L, show_progress = FALSE),
		"does not support Bayesian bootstrap"
	)
	expect_error(
		obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 3L, show_progress = FALSE, debug = TRUE),
		"does not support Bayesian bootstrap"
	)
})

test_that("a non-blocking design rejects an explicit weighting_unit_type with the documented message", {
	des = bbdebug_design()
	obj = InferenceAllSimpleAverageDiff$new(des)
	expect_error(
		obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 3L, show_progress = FALSE, weighting_unit_type = "within_blocks"),
		"bootstrap_type can only be set for blocking designs"
	)
	expect_error(
		obj$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 3L, show_progress = FALSE, debug = TRUE, weighting_unit_type = "resample_blocks"),
		"bootstrap_type can only be set for blocking designs"
	)
})
