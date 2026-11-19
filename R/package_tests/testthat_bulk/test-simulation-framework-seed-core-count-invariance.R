# Thread and random-number review audit, 2026-11-19: A seeded SimulationFramework run gives different
# replications depending on num_cores. The serial path (num_cores = 1) calls set.seed(seed) once at
# the start of run() and then draws every w-replication from that one continuing R RNG stream;
# .run_single_replication_in_worker never reseeds. The fork path (num_cores > 1 on Unix) calls
# set.seed(seed + rep) at the start of each replication, and the mirai path calls set.seed(seed +
# rep) before each (rep, cell) unit. So the same seed produces different covariates, assignments and
# responses, and therefore different estimates and p-values, for num_cores = 1 and num_cores = 2. The
# two parallel backends also disagree with each other when a grid has more than one cell: fork
# continues one stream across the cells of a rep, while mirai resets every cell to seed + rep.
# Where: R/EDI/R/simulations_framework.R:1881 (kind: core_count_dependence).
# On commit 0231668c948b this test failed with: Expected `est_parallel` to equal `est_serial`.
# Differences: 4/4 mismatches (average diff: 1) [1] 0.493 - 1.06 == -0.570 [2] 0.590 - 1.16 == -0.568
# [3] 1.921 - 3.56 == -1.635 [4] 0.498 - 1.74 == -1.245
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("seeded SimulationFramework results do not depend on num_cores", {
	skip("open a release TODO for this")
		on.exit(unset_num_cores(), add = TRUE)
		run_sim = function(cores) {
			sim = SimulationFramework$new(
				response_type = "continuous",
				design_classes_and_params = list(DesignFixedBernoulli),
				inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
				inference_types_and_params = list(asymp_pval = list()),
				n = 20L, Nrep_W = 4L, Nrep_Y_w = 1L, seed = 321,
				num_cores = cores,
				results_filename = tempfile(fileext = ".csv"), verbose = FALSE,
				continue_from_last_result_row = FALSE
			)
			sim$run()
			res = as.data.frame(SimulationFrameworkReport$new(sim)$get_results())
			res = res[order(res$rep), , drop = FALSE]
			as.numeric(res$estimate)
		}
		est_serial = run_sim(1L)
		est_parallel = run_sim(2L)
		expect_equal(length(est_serial), 4L)
		expect_equal(est_parallel, est_serial)
})
