library(testthat)
library(EDI)

test_that("run_all_inference_fork_dispatch: a hung worker is force-killed on max_secs_per_class without blocking or corrupting sibling tasks (TODO-5)", {
	# Deliberately does NOT go through InferenceSuite$run_all_inference() or
	# a real Inference class -- exercising the scheduler
	# (parallel_fork_cluster_test_safety.md's TODO-5) directly with a
	# test-double worker_fn is both faster and safer than trying to make a
	# real class hang on purpose. Uses real parallel::mcparallel() forking
	# (this file's other real-fork test already establishes that forking is
	# safe to exercise outside CI/CRAN/prepush -- same skip gates apply
	# here, for the same reason: still real OS-level forking).
	skip_on_cran()
	skip_on_os("windows")
	skip_if_prepush_no_parallel()
	setTimeLimit(elapsed = 60, transient = TRUE)
	on.exit(setTimeLimit(elapsed = Inf, transient = TRUE), add = TRUE)

	mk_task = function(nm) list(cls_name = nm, model_formula = NULL, method = NA_character_, type = NA_character_, result_name = nm)
	tasks = list(mk_task("fast1"), mk_task("fast2"), mk_task("hang1"), mk_task("fast3"))

	ok_row = function(nm) list(
		inference_class = nm, method = NA_character_, type = NA_character_,
		response_type = "continuous", design_family = "iid", likelihood_tier = "full", cov_model = NA_character_,
		estimate = 1.0, se = 0.1, ci_a = 0.8, ci_b = 1.2, ci_method = "wald",
		pval = 0.01, pval_method = "wald", estimand = "conditional",
		fit_secs = 0.1, warnings = NA_character_, status = "ok", message = NA_character_,
		diagnostics = list(converged = TRUE, hit_iteration_cap = FALSE, iterations = 5L, optimizer = "lbfgs")
	)
	worker_fn = function(task) {
		if (identical(task$cls_name, "hang1")) Sys.sleep(30) else Sys.sleep(0.1)
		ok_row(task$cls_name)
	}

	t0 = Sys.time()
	res = EDI:::run_all_inference_fork_dispatch(
		tasks, worker_fn, num_cores = 2L, max_secs_per_class = 2,
		design_family = "iid", response_type = "continuous"
	)
	elapsed = as.numeric(difftime(Sys.time(), t0, units = "secs"))

	# Must not wait anywhere near the hung task's real 30s sleep -- bounded
	# by roughly max_secs_per_class plus one poll interval, not by the
	# longest-running task.
	expect_lt(elapsed, 15)
	expect_identical(names(res), c("fast1", "fast2", "hang1", "fast3"))
	expect_identical(res$fast1$status, "ok")
	expect_identical(res$fast2$status, "ok")
	expect_identical(res$fast3$status, "ok")
	expect_identical(res$hang1$status, "timeout")
	expect_true(grepl("force-killed", res$hang1$message, fixed = TRUE))
	# The killed task's row must not have corrupted or replaced any sibling
	# task's already-collected result (the exact bug class this test guards
	# against: a completed job left in the scheduler's live-jobs set gets
	# force-killed and overwritten a second time).
	expect_identical(res$fast1$estimate, 1.0)
	expect_identical(res$fast3$estimate, 1.0)
})

