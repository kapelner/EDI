# Thread and random-number review audit, 2026-11-17: The reused-worker randomization path splits the
# nsim permutations into chunk_n = num_cores contiguous chunks and, for concave likelihoods, chains
# the fit warm start from one permutation to the next within a chunk (base_fit_warm_start = previous
# converged params). With 1 core all permutations are one chain. With 2 cores the second chunk
# restarts from the full-data MLE (and its Fisher information) at permutation nsim/2+1. Each null fit
# therefore starts from a point that depends on the core count, so the optimizer stops at a slightly
# different iterate. The seeded randomization distribution (and anything cached from it) is not
# identical across core counts, even though the permutations are the same. For iterative fits with
# loose tolerances (L-BFGS Weibull, ordinal) the drift is larger than ulps.
# Where: R/EDI/R/inference_all_abstract_rand.R:672 (kind: core_count_dependence).
# On commit 4fc58cd063bc this test failed with: Expected `r1$t0` to be identical to `r2$t0`.
# Differences: Objects equal but not identical
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("seeded randomization distribution of a warm-started GLM is identical with 1 and 2 cores", {
	skip("open a release TODO for this")
		child = function(cores) {
			suppressPackageStartupMessages(library(EDI))
			set_num_cores(cores)
			on.exit(unset_num_cores(), add = TRUE)
			n = 40L
			set.seed(20261117)
			X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
			yc = rpois(n, 3)
			d = DesignFixediBCRD$new(response_type = "count", n = n, seed = 7L, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			d$add_all_subject_responses(yc + d$get_w())
			inf = InferenceCountPoisson$new(d)
			inf$set_seed(3L)
			set.seed(1000L + cores)
			invisible(runif(7L * cores))
			t0 = inf$approximate_randomization_distribution_beta_hat_T(r = 200L, show_progress = FALSE)
			list(cores = EDI:::get_num_cores(), inf_cores = as.integer(inf$num_cores), t0 = as.numeric(t0))
		}
		run = function(cores) callr::r(
			child,
			args = list(cores = cores),
			env = c(callr::rcmd_safe_env(), NOT_CRAN = "true"),
			timeout = 280
		)
		r1 = run(1L)
		r2 = run(2L)
		expect_identical(r2$inf_cores, 2L)
		expect_identical(length(r1$t0), 200L)
		expect_identical(r1$t0, r2$t0)
})
