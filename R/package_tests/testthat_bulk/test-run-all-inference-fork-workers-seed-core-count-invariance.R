# Thread and random-number review audit, 2026-11-17: With num_cores > 1, run_all_inference() runs
# each task in a child started by parallel::mcparallel() with its default mc.set.seed = TRUE. Under
# R's default Mersenne-Twister RNG, parallel's mc.set.stream() removes .Random.seed in the child, so
# every child reseeds from the clock and PID. Every class whose resampling draws come from the global
# stream (rand p-values/CIs on an unseeded design, bootstrap/bayes_boot/param_boot when no inference
# seed is set) then gets fresh random draws. After the same set.seed(), the p-values and intervals
# differ between num_cores = 1, which uses the caller's stream sequentially, and num_cores = 2, and
# two num_cores = 2 runs do not reproduce each other. Even under L'Ecuyer-CMRG, each child gets its
# own stream rather than the sequential stream, so results still depend on num_cores.
# Where: R/EDI/R/inference_suite.R:1465 (kind: core_count_dependence).
# On commit 6c326a75c09c this test failed with: Expected `p_par_a` to equal `p_seq`. Differences: 2/2
# mismatches (average diff: 0.024) [1] 0.152 - 0.176 == -0.024 [2] 0.184 - 0.208 == -0.024
# Fixed by v1.0.6-TODO-160: every task now runs from its own seed (drawn once from the caller's
# stream) with an empty design-level permutation cache, on both paths.

test_that("run_all_inference rand p-values after set.seed() do not depend on num_cores", {
	skip_on_cran()
	skip_on_os("windows")
	skip_if(isTRUE(EDI:::edi_env$mirai_has_been_used), "forks cannot be started safely after mirai has been used in this R session")
		old_env = Sys.getenv("EDI_TESTING_DISABLE_FORK_CLUSTER", unset = NA)
		Sys.setenv(EDI_TESTING_DISABLE_FORK_CLUSTER = "false")
		on.exit(if (is.na(old_env)) Sys.unsetenv("EDI_TESTING_DISABLE_FORK_CLUSTER") else Sys.setenv(EDI_TESTING_DISABLE_FORK_CLUSTER = old_env), add = TRUE)
		set.seed(20261117)
		n = 30L
		des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
		des$assign_w_to_all_subjects()
		w = des$get_w()
		des$add_all_subject_responses(1 + 0.35 * w + rnorm(n))
		run = function(k) {
			des$.__enclos_env__$private$permutations_cache = list()
			suite = InferenceSuite$new(des)
			set.seed(99L)
			capture.output({
				res <- suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinOLS",
					methods = "rand", formulas = list(~ 1, ~ x1), num_cores = k, max_secs_per_class = 90)
			})
			tbl = res$results_table
			tbl$pval[order(tbl$cov_model)]
		}
		# forked runs first, so the parent has not started any OpenMP pool before fork()
		p_par_a = run(2L)
		p_par_b = run(2L)
		p_seq = run(1L)
		expect_length(p_seq, 2L)
		expect_true(all(is.finite(p_seq)))
		expect_equal(p_par_a, p_seq)
		expect_equal(p_par_a, p_par_b)
})
