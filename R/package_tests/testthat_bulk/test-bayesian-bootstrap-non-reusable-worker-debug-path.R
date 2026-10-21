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

manual_non_reusable_bayesian_bootstrap_reference = function(des, seed, B){
	inf = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf$set_seed(seed)
	set.seed(seed)
	p = inf$.__enclos_env__$private
	draws = p$bayesian_bootstrap_sample_weight_draws(B = B, weighting_unit_type = NULL)
	inf_template = inf$duplicate()
	vapply(draws, function(draw){
		worker_inf = inf_template$duplicate(make_fork_cluster = FALSE)
		worker_inf$.__enclos_env__$private$current_bayesian_bootstrap_context = draw$context
		tryCatch(
			as.numeric(worker_inf$compute_estimate_with_bootstrap_weights(
				subject_or_block_weights = draw$subject_or_block_weights,
				estimate_only = TRUE
			))[1L],
			error = function(e) NA_real_
		)
	}, numeric(1))
}

test_that("InferenceCountHurdleNegBin is a confirmed non-reusable-bootstrap-worker, Bayesian-bootstrap-capable class", {
	des = simulate_hurdle_negbin_design(1L)
	inf = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	expect_false(inf$.__enclos_env__$private$use_reusable_bootstrap_worker())
	expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
})

test_that("debug=TRUE reproduces the debug=FALSE distribution exactly on the non-reusable duplicate() branch, single core", {
	des = simulate_hurdle_negbin_design(2L)
	values_reference = manual_non_reusable_bayesian_bootstrap_reference(des, seed = 123, B = 12L)

	inf_b = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_b$set_seed(123)
	debug_out = inf_b$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 12L, show_progress = FALSE, debug = TRUE)

	expect_equal(debug_out$values, values_reference)
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
	values_reference = manual_non_reusable_bayesian_bootstrap_reference(des, seed = 789, B = 8L)

	# Keep the ordinary path's dispatch contract under test without creating a
	# real fork cluster.  par_lapply normally partitions X and applies FUN to
	# each element, so this serial spy preserves its result shape while proving
	# the non-debug branch still reaches the parallel-dispatch seam.
	inf_ordinary = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_ordinary$set_seed(789)
	inf_ordinary$num_cores = 2L
	ordinary_priv = inf_ordinary$.__enclos_env__$private
	ordinary_dispatches = 0L
	ordinary_policy_core_requests = integer(0)
	ordinary_core_requests = integer(0)
	ordinary_payload_chunk_sizes = integer(0)
	ordinary_payload_is_draw_records = logical(0)
	ordinary_callback_env_names = character(0)
	ordinary_callback_captures_full_draws = NA
	unlockBinding("effective_parallel_cores", ordinary_priv)
	ordinary_priv$effective_parallel_cores = function(operation, requested_cores = inf_ordinary$num_cores) {
		ordinary_policy_core_requests <<- c(ordinary_policy_core_requests, as.integer(requested_cores))
		2L
	}
	# Count the explicit warmup deadline checks rather than relying on elapsed
	# time: the old implementation emits exactly two when it enters its warmup
	# branch, while the serial fallback must clamp before warmup. This remains
	# deterministic and never starts a real fork.
	ordinary_deadline_labels = character(0)
	unlockBinding("check_bootstrap_replicate_deadline", ordinary_priv)
	ordinary_priv$check_bootstrap_replicate_deadline = function(label, ...) {
		ordinary_deadline_labels <<- c(ordinary_deadline_labels, as.character(label)[1L])
		# This fixture has no replicate deadline configured; the spy only records
		# which branch was entered.
		invisible(NULL)
	}
	unlockBinding("par_lapply", ordinary_priv)
	ordinary_priv$par_lapply = function(X, FUN, n_cores = inf_ordinary$num_cores, ...) {
		ordinary_dispatches <<- ordinary_dispatches + 1L
		ordinary_core_requests <<- c(ordinary_core_requests, as.integer(n_cores))
		ordinary_payload_chunk_sizes <<- unname(lengths(X))
		ordinary_payload_is_draw_records <<- vapply(X, function(chunk) {
			is.list(chunk) && length(chunk) > 0L && all(vapply(chunk, function(draw) {
				is.list(draw) && "subject_or_block_weights" %in% names(draw)
			}, logical(1)))
		}, logical(1))
		callback_env = environment(FUN)
		ordinary_callback_env_names <<- sort(ls(callback_env, all.names = TRUE))
		ordinary_callback_captures_full_draws <<- exists("draws", envir = callback_env, inherits = FALSE)
		lapply(X, FUN)
	}
	ordinary_values = inf_ordinary$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 8L, show_progress = FALSE, debug = FALSE
	)
	expect_gt(ordinary_dispatches, 0L)
	expect_identical(ordinary_policy_core_requests, 2L)
	expect_length(ordinary_deadline_labels[ordinary_deadline_labels == "Bayesian bootstrap warmup"], 0L)
	expect_identical(ordinary_core_requests, 1L)
	expect_identical(ordinary_payload_chunk_sizes, 8L)
	expect_true(all(ordinary_payload_is_draw_records))
	expect_identical(ordinary_callback_env_names, c("inf_template", "private"))
	expect_false(ordinary_callback_captures_full_draws)
	expect_length(ordinary_values, 8L)
	expect_equal(ordinary_values, values_reference, tolerance = 1e-5)

	# A regression that routes debug through par_lapply fails immediately here,
	# rather than attempting a flaky fork/hang in the test process.
	inf_debug = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_debug$set_seed(789)
	inf_debug$num_cores = 2L
	debug_priv = inf_debug$.__enclos_env__$private
	debug_dispatches = 0L
	debug_policy_core_requests = integer(0)
	unlockBinding("effective_parallel_cores", debug_priv)
	debug_priv$effective_parallel_cores = function(operation, requested_cores = inf_debug$num_cores) {
		debug_policy_core_requests <<- c(debug_policy_core_requests, as.integer(requested_cores))
		2L
	}
	unlockBinding("par_lapply", debug_priv)
	debug_priv$par_lapply = function(...) {
		debug_dispatches <<- debug_dispatches + 1L
		stop("non-reusable debug path unexpectedly called par_lapply")
	}
	debug_values = inf_debug$approximate_bayesian_bootstrap_distribution_beta_hat_T(
		B = 8L, show_progress = FALSE, debug = TRUE
	)
	expect_identical(debug_policy_core_requests, 2L)
	expect_identical(debug_dispatches, 0L)
	expect_length(debug_values$values, 8L)
	expect_equal(debug_values$values, values_reference, tolerance = 1e-5)
	expect_equal(debug_values$num_errors, rep(0L, 8L))
})
