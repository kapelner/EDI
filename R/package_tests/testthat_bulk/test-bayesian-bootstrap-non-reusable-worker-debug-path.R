library(testthat)
library(EDI)

# inference_all_abstract_bayesian_bootstrap.R's debug=TRUE/FALSE dispatch has
# two branches keyed on use_reusable_bootstrap_worker(): a reusable-worker-state
# branch (covered by test-bayesian-bootstrap-debug-distribution-contract.R via
# InferenceAllSimpleAverageDiff) and a per-iteration inf_template$duplicate()
# branch for classes that return FALSE from that private method. No existing
# test exercised the latter for the Bayesian bootstrap specifically.
#
# 2026-10-08: originally targeted InferencePropZeroOneInflatedBetaRegr, but
# that class gained supports_reusable_bootstrap_worker() = TRUE in commit
# bca39750 ("a few more bugs fixed for v1.5.0") -- closing GitHub issue #4
# ("extend the reusable-bootstrap-worker pattern... jackknife is ~50x slower
# than peers"), an intentional feature change, not a regression -- so it no
# longer exercises the duplicate()-per-iteration branch this file is about.
# InferenceCountHurdleNegBin is a confirmed use_reusable_bootstrap_worker()
# == FALSE class (inference_count_hurdle.R's own supports_reusable_bootstrap_
# worker() returns FALSE, unlike InferenceCountHurdlePoisson) while still
# supporting Bayesian bootstrap (supports_bayesian_bootstrap() is the
# unoverridden TRUE default), making it the right target for the non-reusable
# duplicate()-per-iteration debug/warmup/par_lapply branches (lines ~148-246).

simulate_hurdle_negbin_design = function(seed = 1L, n = 60L, beta_T = 0.4){
	set.seed(seed)
	x1 = rnorm(n)
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rnbinom(n, mu = exp(0.5 + beta_T * w + 0.3 * x1), size = 2)
	des$add_all_subject_responses(y)
	des
}

test_that("InferenceCountHurdleNegBin is a confirmed non-reusable-bootstrap-worker, Bayesian-bootstrap-capable class", {
	des = simulate_hurdle_negbin_design(1L)
	inf = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	expect_false(inf$.__enclos_env__$private$use_reusable_bootstrap_worker())
	expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
})

test_that("debug=TRUE reproduces the debug=FALSE distribution exactly on the non-reusable duplicate() branch, single core", {
	des = simulate_hurdle_negbin_design(2L)

	inf_a = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_a$set_seed(123)
	values_only = inf_a$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 12L, show_progress = FALSE, debug = FALSE)

	inf_b = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_b$set_seed(123)
	debug_out = inf_b$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 12L, show_progress = FALSE, debug = TRUE)

	expect_equal(debug_out$values, values_only)
	expect_length(debug_out$values, 12L)
	expect_setequal(names(debug_out), c(
		"values", "errors", "warnings", "num_errors", "num_warnings",
		"prop_iterations_with_errors", "prop_iterations_with_warnings", "prop_illegal_values"
	))
	expect_length(debug_out$errors, 12L)
	expect_length(debug_out$warnings, 12L)
	expect_true(all(vapply(debug_out$errors, is.character, logical(1))))
	expect_true(all(vapply(debug_out$warnings, is.character, logical(1))))
	expect_equal(debug_out$num_errors, lengths(debug_out$errors))
	expect_equal(debug_out$num_warnings, lengths(debug_out$warnings))
	# Error-free simulated fixture: the three summary proportions all resolve to 0.
	expect_equal(debug_out$prop_iterations_with_errors, 0)
	expect_equal(debug_out$prop_iterations_with_warnings, 0)
	expect_equal(debug_out$prop_illegal_values, 0)
})

test_that("non-reusable Bayesian-bootstrap debug bypasses outer par_lapply but ordinary mode still dispatches", {
	des = simulate_hurdle_negbin_design(4L)
	inf_single = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_single$set_seed(789)
	values_single = inf_single$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 8L, show_progress = FALSE, debug = FALSE
	)

	# Keep the ordinary path's dispatch contract under test without creating a
	# real fork cluster.  par_lapply normally partitions X and applies FUN to
	# each element, so this serial spy preserves its result shape while proving
	# the non-debug branch still reaches the parallel-dispatch seam.
	inf_ordinary = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_ordinary$set_seed(789)
	inf_ordinary$num_cores = 2L
	ordinary_priv = inf_ordinary$.__enclos_env__$private
	ordinary_dispatches = 0L
	unlockBinding("par_lapply", ordinary_priv)
	ordinary_priv$par_lapply = function(X, FUN, ...) {
		ordinary_dispatches <<- ordinary_dispatches + 1L
		lapply(X, FUN)
	}
	ordinary_values = inf_ordinary$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 8L, show_progress = FALSE, debug = FALSE
	)
	expect_gt(ordinary_dispatches, 0L)
	expect_length(ordinary_values, 8L)
	expect_equal(ordinary_values, values_single, tolerance = 1e-5)

	# A regression that routes debug through par_lapply fails immediately here,
	# rather than attempting a flaky fork/hang in the test process.
	inf_debug = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_debug$set_seed(789)
	inf_debug$num_cores = 2L
	debug_priv = inf_debug$.__enclos_env__$private
	debug_dispatches = 0L
	unlockBinding("par_lapply", debug_priv)
	debug_priv$par_lapply = function(...) {
		debug_dispatches <<- debug_dispatches + 1L
		stop("non-reusable debug path unexpectedly called par_lapply")
	}
	debug_values = inf_debug$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 8L, show_progress = FALSE, debug = TRUE
	)
	expect_identical(debug_dispatches, 0L)
	expect_length(debug_values$values, 8L)
	expect_equal(debug_values$values, values_single, tolerance = 1e-5)
	expect_equal(debug_values$num_errors, rep(0L, 8L))
})
