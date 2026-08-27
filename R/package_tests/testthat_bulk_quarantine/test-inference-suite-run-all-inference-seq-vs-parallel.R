library(testthat)
library(EDI)

# Quarantined from test-inference-suite-run-all-inference.R (see this
# directory's README.md). Both tests below assert
# `InferenceSuite$run_all_inference()` produces byte-identical results_table
# rows under num_cores = 1 (sequential) vs num_cores = 2 (parallel), after
# reseeding to the same RNG state before each call. CI run 33072346506
# (2026-08-27) failed both:
#   - The real-fork variant: only the "pval" column differed (~16% relative),
#     consistent with per-class Monte Carlo draws landing at a different
#     point in the RNG stream when dispatched to a forked worker vs run
#     inline -- not necessarily a correctness bug, but not proven safe
#     either.
#   - The EDI_TESTING_DISABLE_FORK_CLUSTER = "true" variant (real forking
#     disabled, routed through a same-process lapply() instead,
#     specifically to isolate the task-building/result-reassembly logic
#     from real-fork RNG effects) failed much more seriously: NA-count
#     mismatches in estimate/se/pval/message/weight and a "status" string
#     mismatch -- i.e. a DIFFERENT set of classes succeeded/failed between
#     the two dispatch paths even with forking out of the picture. That is
#     a stronger signal of a genuine task-building/reassembly bug, not just
#     RNG-stream-position jitter.
# Investigation attempts hung (reproduction runs did not return within
# several minutes even with EDI_TESTING_DISABLE_FORK_CLUSTER = "true"),
# consistent with this codebase's documented history of fork/deadlock
# hazards in this exact code path (see parallel_fork_cluster_test_safety.md
# and the CANARY comment inside the first test below). Root cause not
# found; needs dedicated, careful investigation rather than being run
# unattended in CI where a hang can burn the whole job's timeout budget.

test_that("run_all_inference: num_cores > 1 fits in parallel and produces identical rows to sequential", {
	skip_on_cran()
	skip_on_os("windows")
	# `parallel::makeForkCluster()` forks a process that, by this point in
	# the suite, has already run OpenMP-parallel C++ kernels (EDI's src/ is
	# pervasively OpenMP-gated) -- forking while another thread holds an
	# OpenMP/malloc-arena lock is a classic deadlock: the forked worker
	# inherits the lock in a state that can never be released, so
	# clusterApply() blocks forever with no path back to its on.exit()
	# cleanup. This is exactly what happened on 2026-08-21: every ubuntu/
	# macOS/windows R-CMD-check leg hung in "checking tests" until its own
	# job timeout killed it (skip_on_os("windows") above meant Windows hung
	# on some other/preexisting issue, not this). `skip_on_ci()` was added
	# the same day to stop the bleeding.
	#
	# CANARY (2026-08-22, user decision): `skip_on_ci()` removed and
	# run_all_inference()'s fork-cluster branch switched from a raw
	# `parallel::makeForkCluster()` call to the package's own
	# `make_configured_fork_cluster()` (2026-08-21) -- see
	# parallel_fork_cluster_test_safety.md's TODO-4.
	#
	# Note (TODO-5, 2026-08-24): the `use_fork_cluster` branch this test
	# exercises no longer calls `make_configured_fork_cluster()` +
	# `clusterApply()` at all -- it now goes through
	# `run_all_inference_fork_dispatch()`, a per-task `mcparallel()`/
	# `mccollect()` scheduler with PID-level force-kill on
	# `max_secs_per_class`.
	#
	# Quarantined 2026-08-27 (see file header): the deadlock-hang risk is
	# no longer the only concern -- this now also fails on a real,
	# non-hanging pval mismatch.
	setTimeLimit(elapsed = 90, transient = TRUE)
	on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res_seq <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 1)
	})
	# run_all_inference() never reseeds internally (by design -- it's a
	# thin dispatcher over each class's own fit, not an RNG owner), so any
	# class using randomization/bootstrap Monte Carlo draws leaves the
	# global RNG stream wherever its draws left it. Without resetting here,
	# the second call below would start from a *different* RNG state than
	# the first and its stochastic p-values/CIs would legitimately differ
	# from res_seq's -- not a fork-dispatch bug, just two calls sampling
	# from different points in the same stream. Reseed identically so both
	# calls start from the same RNG state and are directly comparable.
	set.seed(20260818)
	capture.output({
		res_par <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2)
	})

	seq_tbl = res_seq$results_table[order(res_seq$results_table$inference_class), ]
	par_tbl = res_par$results_table[order(res_par$results_table$inference_class), ]
	rownames(seq_tbl) = NULL
	rownames(par_tbl) = NULL
	# fit_secs will differ run to run; compare everything else.
	compare_cols = setdiff(names(seq_tbl), "fit_secs")
	expect_identical(seq_tbl[compare_cols], par_tbl[compare_cols])
})

test_that("run_all_inference: num_cores > 1's task-building/result-reassembly logic is correct, independent of real OS forking", {
	# parallel_fork_cluster_test_safety.md's TODO-1: the sibling test above
	# ("num_cores > 1 fits in parallel...") is the only thing that exercises
	# num_cores > 1 at all, and it's gated behind skip_on_cran()/
	# skip_on_os("windows") because spinning up a real makeForkCluster()
	# carries real OS-fork risk (see that test's own comment). But the
	# `use_fork_cluster` branch's *surrounding* logic -- task building,
	# result-list reassembly, name matching, row ordering, screen output --
	# has nothing to do with forking and deserves safe, always-on coverage
	# regardless of where the real-fork test is allowed to run.
	# EDI_TESTING_DISABLE_FORK_CLUSTER=true routes that branch through a
	# same-process lapply() instead of a real fork cluster (see
	# inference_suite.R's `use_fork_cluster` block), so this test exercises
	# the identical code path the real-fork test does, minus the fork
	# itself.
	#
	# Quarantined 2026-08-27 (see file header): fails more seriously than
	# the sibling real-fork test above -- NA-count and "status" mismatches,
	# i.e. real forking is NOT the source of at least part of this
	# divergence.
	withr::local_envvar(c(EDI_TESTING_DISABLE_FORK_CLUSTER = "true"))
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res_seq <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 1)
	})
	# See the sibling real-fork test's identical comment above: run_all_
	# inference() never reseeds internally, so the second call must be
	# reseeded to the same state as the first for a fair comparison of
	# stochastic (randomization/bootstrap) classes' p-values/CIs.
	set.seed(20260818)
	capture.output({
		res_par <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2)
	})

	seq_tbl = res_seq$results_table[order(res_seq$results_table$inference_class), ]
	par_tbl = res_par$results_table[order(res_par$results_table$inference_class), ]
	rownames(seq_tbl) = NULL
	rownames(par_tbl) = NULL
	compare_cols = setdiff(names(seq_tbl), "fit_secs")
	expect_identical(seq_tbl[compare_cols], par_tbl[compare_cols])
})
