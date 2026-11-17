# Thread and random-number review audit, 2026-11-17:
# InferencePropGCompMeanDiff$approximate_bootstrap_distribution_beta_hat_T() draws its bootstrap
# indices inside each worker chunk (draw_one() -> private$bootstrap_sample_indices() -> design
# draw_bootstrap_indices() -> sample_int_replace_cpp, i.e. R's RNG). With 1 core every draw comes
# from the one stream started by set.seed(private$seed). With more than 1 core, B is split into
# `actual_cores` chunks and par_lapply seeds each fork worker separately
# (parallel::clusterSetRNGStream(worker_cl, private$seed), L'Ecuyer streams), or seeds each mirai
# chunk with seed + i. So the resamples a given replicate b gets depend on the number of cores and on
# how the work is chunked, and the seeded bootstrap distribution (and the CIs built from it) changes
# with set_num_cores(). The KK pass-through mixin avoids this by drawing all indices serially before
# the parallel step; gcomp does not.
# Where: R/EDI/R/inference_proportion_gcomp.R:367 (kind: core_count_dependence).
# On commit 6c326a75c09c this test failed with: Expected `b2` to equal `b1`. Differences: 40/40
# mismatches (average diff: 0.0424) [1] 0.1026 - 0.1003 == 0.00231 [2] 0.1258 - 0.1073 == 0.01852 [3]
# 0.1148 - 0.1188 == -0.00402 [4] 0.1119 - 0.1448 == -0.03290 [5] 0.1028 - 0.1229 == -0.02003 [6]
# 0.0682 - 0.0638 == 0.00439 [7] 0.1287 - 0.0974 == 0.
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("seeded prop g-computation bootstrap distribution does not depend on the core count", {
	skip("open a release TODO for this")
		on.exit(unset_num_cores(), add = TRUE)
		set.seed(1)
		n = 60L
		x = rnorm(n)
		w = rep(0:1, n / 2)
		y = plogis(-0.2 + 0.4 * w + 0.4 * x + rnorm(n, sd = 0.6))
		run = function(cores) {
			set_num_cores(cores)
			des = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
			des$add_all_subjects_to_experiment(data.frame(x = x))
			des$overwrite_all_subject_assignments(w)
			des$add_all_subject_responses(y)
			inf = InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE)
			inf$set_seed(3L)
			inf$approximate_bootstrap_distribution_beta_hat_T(B = 40L, show_progress = FALSE)
		}
		b1 = run(1L)
		b2 = run(2L)
		expect_true(sum(is.finite(b1)) >= 30L)
		expect_equal(b2, b1)
})
