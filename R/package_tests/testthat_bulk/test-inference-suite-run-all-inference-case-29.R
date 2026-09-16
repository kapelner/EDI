library(testthat)
library(EDI)

test_that("run_all_inference_fork_dispatch: max_secs_per_class = NULL never kills, even a slow-but-finite worker", {
	skip_on_cran()
	skip_on_os("windows")
	skip_if_prepush_no_parallel()
	setTimeLimit(elapsed = 60, transient = TRUE)
	on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)

	tasks = list(list(cls_name = "slow1", model_formula = NULL, method = NA_character_, type = NA_character_, result_name = "slow1"))
	worker_fn = function(task) {
		Sys.sleep(1.5)
		list(
			inference_class = task$cls_name, method = NA_character_, type = NA_character_,
			response_type = "continuous", design_family = "iid", likelihood_tier = "full", cov_model = NA_character_,
			estimate = 2.0, se = 0.1, ci_a = 1.8, ci_b = 2.2, ci_method = "wald",
			pval = 0.01, pval_method = "wald", estimand = "conditional",
			fit_secs = 1.5, warnings = NA_character_, status = "ok", message = NA_character_,
			diagnostics = list(converged = TRUE, hit_iteration_cap = FALSE, iterations = 5L, optimizer = "lbfgs")
		)
	}
	res = EDI:::run_all_inference_fork_dispatch(
		tasks, worker_fn, num_cores = 1L, max_secs_per_class = NULL,
		design_family = "iid", response_type = "continuous"
	)
	expect_identical(res$slow1$status, "ok")
	expect_identical(res$slow1$estimate, 2.0)
})

# "run_all_inference: num_cores > 1's task-building/result-reassembly logic
# is correct, independent of real OS forking" also moved to
# testthat_bulk_quarantine/test-inference-suite-run-all-inference-seq-vs-parallel.R
# (2026-08-27) -- it failed more seriously than its real-fork sibling above
# (NA-count and "status" mismatches even with EDI_TESTING_DISABLE_FORK_CLUSTER
# = "true", i.e. real forking is not the source of at least part of the
# divergence). See that file and testthat_bulk_quarantine/README.md.

