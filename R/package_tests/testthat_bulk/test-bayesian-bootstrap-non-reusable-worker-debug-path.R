library(testthat)
library(EDI)

# inference_all_abstract_bayesian_bootstrap.R's debug=TRUE/FALSE dispatch has
# two branches keyed on use_reusable_bootstrap_worker(): a reusable-worker-state
# branch (covered by test-bayesian-bootstrap-debug-distribution-contract.R via
# InferenceAllSimpleAverageDiff) and a per-iteration inf_template$duplicate()
# branch for classes that return FALSE from that private method. No existing
# test exercised the latter for the Bayesian bootstrap specifically (confirmed
# via grep: InferencePropZeroOneInflatedBetaRegr's existing tests never call
# approximate_bayesian_bootstrap_distribution_beta_hat_T at all).
# InferencePropZeroOneInflatedBetaRegr is a confirmed use_reusable_bootstrap_worker()
# == FALSE class (see local_machine_tuning_axes.R's comment on its jackknife cost)
# while still supporting Bayesian bootstrap (supports_bayesian_bootstrap() is the
# unoverridden TRUE default), making it the right target for the non-reusable
# duplicate()-per-iteration debug/warmup/par_lapply branches (lines ~148-246).

simulate_zoib_design = function(seed = 1L, n = 60L, beta_T = 0.6){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	lin = 0.3 + beta_T * w + 0.4 * x1
	mu = plogis(lin)
	p0 = plogis(-2 - 0.2 * w)
	p1 = plogis(-2 + 0.1 * w)
	u = runif(n)
	y = numeric(n)
	for (i in seq_len(n)) {
		if (u[i] < p0[i]) {
			y[i] = 0
		} else if (u[i] < p0[i] + p1[i]) {
			y[i] = 1
		} else {
			y[i] = rbeta(1L, mu[i] * 8, (1 - mu[i]) * 8)
		}
	}
	seq_des$add_all_subject_responses(y)
	seq_des
}

test_that("InferencePropZeroOneInflatedBetaRegr is a confirmed non-reusable-bootstrap-worker, Bayesian-bootstrap-capable class", {
	seq_des = simulate_zoib_design(1L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	expect_false(inf$.__enclos_env__$private$use_reusable_bootstrap_worker())
	expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
})

test_that("debug=TRUE reproduces the debug=FALSE distribution exactly on the non-reusable duplicate() branch, single core", {
	seq_des = simulate_zoib_design(2L)

	inf_a = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_a$set_seed(123)
	values_only = inf_a$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 12L, show_progress = FALSE, debug = FALSE)

	inf_b = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
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
	seq_des = simulate_zoib_design(3L)

	inf_single = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_single$set_seed(456)
	values_single = inf_single$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = FALSE)

	# num_cores > 1 exercises the non-reusable do_warmup_iter() and the
	# unlist(private$par_lapply(...)) chunked-dispatch arm (lines ~199-246),
	# not just the sequential actual_cores<=1L branch.
	inf_multi = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_multi$set_seed(456)
	inf_multi$num_cores = 2L
	values_multi = inf_multi$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = FALSE)

	expect_equal(values_multi, values_single)

	inf_multi_debug = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_multi_debug$set_seed(456)
	inf_multi_debug$num_cores = 2L
	debug_multi = inf_multi_debug$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, show_progress = FALSE, debug = TRUE)

	# The multi-core debug run_debug_chunk() dispatch (lines 153-160) must also
	# reproduce the sequential values exactly under the same seed.
	expect_equal(debug_multi$values, values_single)
	expect_length(debug_multi$values, 16L)
	expect_equal(debug_multi$num_errors, rep(0L, 16L))
	expect_equal(debug_multi$num_warnings, rep(0L, 16L))
})
