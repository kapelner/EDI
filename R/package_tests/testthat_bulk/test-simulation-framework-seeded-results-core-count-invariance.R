# Thread and random-number review audit, 2026-11-17: With a fixed `seed`, SimulationFramework$run()
# seeds replications differently depending on num_cores. The serial path (num_cores = 1, line 1871
# loop) never re-seeds per replication: every rep consumes one continuous global stream started by
# set.seed(seed) at line 856 (and, when design caches are built serially, further reset by
# set.seed(seed + 1000003 + jj) inside .run_simulation_cache_job at line 2519 in the main process).
# The fork path instead calls set.seed(seed + rep) at the start of each replication in the worker
# (lines 1619/1664), and the mirai path calls set.seed(seed + rep) per (rep, cell) work unit (lines
# 1783-1785), so even fork vs mirai disagree when there is more than one DGP cell. Consequently the
# per-rep data, assignments, estimates, p-values and CIs written to the results file change when
# num_cores goes from 1 to >1.
# Where: R/EDI/R/simulations_framework.R:1871 (kind: core_count_dependence).
# On commit 6c326a75c09c this test failed with: Expected `est_2` to equal `est_1`. Differences: 4/4
# mismatches (average diff: 0.869) [1] 0.1475 - 0.713 == -0.5658 [2] -0.0639 - 1.688 == -1.7522 [3]
# 0.3585 - 1.448 == -1.0895 [4] 0.6421 - 0.574 == 0.0682
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("SimulationFramework seeded estimates do not depend on num_cores", {
	skip("open a release TODO for this")
		run_sim = function(nc) {
			f = tempfile(fileext = ".csv")
			on.exit(unlink(f), add = TRUE)
			sim = SimulationFramework$new(
				response_type = "continuous",
				design_classes_and_params = list(DesignFixedBernoulli),
				inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
				inference_types_and_params = list(asymp_pval = list()),
				n = 20L, p = 2L, Nrep_W = 4L, Nrep_Y_w = 1L, betaT = 1,
				seed = 4242,
				num_cores = nc,
				results_filename = f, verbose = FALSE,
				continue_from_last_result_row = FALSE
			)
			sim$run()
			res = as.data.frame(SimulationFrameworkReport$new(sim)$get_results())
			res = res[order(res$rep), , drop = FALSE]
			res$estimate
		}
		est_1 = run_sim(1L)
		est_2 = run_sim(2L)
		expect_length(est_1, 4L)
		expect_length(est_2, 4L)
		expect_equal(est_2, est_1)
})
