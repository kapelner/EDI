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

test_that("multi-core dispatch on the non-reusable duplicate()-per-iteration branch reproduces the single-core distribution under the same seed", {
	# num_cores = 2 below drives par_lapply() into its lazy-fork-cluster branch
	# (inference_all_abstract.R's par_lapply(), "Unix with no pre-existing
	# cluster: create one lazily and cache it"), which stores a real,
	# persistent 2-worker cluster in edi_env$global_fork_cluster -- by design,
	# for real callers this cluster is meant to outlive the call for reuse.
	# In a bin-packed test shard that persistence leaks into every later test
	# in the same session (get_num_cores() then reports 2, not 1), so this
	# test must tear it down itself.
	on.exit(unset_num_cores(), add = TRUE)
	des = simulate_hurdle_negbin_design(3L)

	inf_single = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_single$set_seed(456)
	values_single = inf_single$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = FALSE)

	# num_cores > 1 exercises the non-reusable do_warmup_iter() and the
	# unlist(private$par_lapply(...)) chunked-dispatch arm (lines ~199-246),
	# not just the sequential actual_cores<=1L branch. tolerance (not exact
	# equality) because the per-replicate NegBin fit's OpenMP-parallel linear
	# algebra does not sum in the same order at 1 vs 2 active threads, so the
	# optimizer can land a few ULPs apart even under the same seed -- confirmed
	# empirically (differences ~1e-7, not a real divergence).
	inf_multi = InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	inf_multi$set_seed(456)
	inf_multi$num_cores = 2L
	values_multi = inf_multi$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = FALSE)

	expect_equal(values_multi, values_single, tolerance = 1e-5)

	# NOTE: debug=TRUE under num_cores=2 is deliberately NOT exercised here.
	# It triggers an intermittent hang (confirmed directly, outside testthat,
	# 2026-10-08: the exact same call sometimes completes in ~1-2s and
	# sometimes never returns) consistent with a fork-after-OpenMP-threading
	# race -- forking while the parent has live OMP worker threads can hand a
	# child process an inherited, permanently-locked mutex. This is a
	# pre-existing bug in that dispatch combination, not something to newly
	# bake into CI as a flaky assertion; worth its own investigation/issue
	# separately from this file's non-reusable-worker coverage goal.
	debug_multi = inf_single$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = TRUE)
	expect_equal(debug_multi$values, values_single)
	expect_length(debug_multi$values, 16L)
	expect_equal(debug_multi$num_errors, rep(0L, 16L))
	expect_equal(debug_multi$num_warnings, rep(0L, 16L))
})
