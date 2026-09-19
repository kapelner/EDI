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

test_that("debug = TRUE under multi-core dispatch reproduces the single-core distribution", {
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
