library(testthat)
library(EDI)

# Worker-count invariance with fork workers (cross_platform_reproducibility.md,
# TODO-2 and TODO-4).
#
# The same seed must give the same bootstrap CI whether it is computed serially
# or on 2 or 3 fork workers. This file deliberately does NOT call
# skip_if_prepush_no_parallel(). The R-CMD-check matrix sets
# EDI_PREPUSH_NO_PARALLEL=true to avoid the nanonext/mirai daemon hang, and
# that hang lives in mirai's transport, which fork clusters never touch. Without
# this file, worker-count invariance would be tested only in the sanitizer and
# valgrind jobs.
#
# Linux only: fork is unavailable on Windows, and the macOS legs are covered by
# the thread-count digests instead. Named test-aa-* so it runs before any test
# that starts mirai, after which fork clusters cannot be started in the same
# session.
#
# The randomization p-value is not tested here: for these classes it runs in a
# C++ kernel and never dispatches to R workers. The test records the n_cores
# that par_lapply() actually received, so it fails rather than passing
# vacuously if a future change makes the bootstrap path serial too.

make_fork_worker_invariance_design = function() {
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(11L)
	n = 60L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x1 + 0.5 * des$get_w() + rnorm(n))
	des
}

# Returns the CI plus every n_cores value par_lapply() was called with.
bootstrap_ci_at_workers = function(inference_class, des, workers) {
	set_num_cores(workers)
	on.exit(unset_num_cores(), add = TRUE)
	inf = inference_class$new(des)
	inf$set_seed(99L)
	priv = inf$.__enclos_env__$private
	original = priv$par_lapply
	used = integer()
	unlockBinding("par_lapply", priv)
	priv$par_lapply = function(..., n_cores = 1L) {
		used <<- c(used, as.integer(n_cores))
		original(..., n_cores = n_cores)
	}
	lockBinding("par_lapply", priv)
	ci = inf$compute_bootstrap_confidence_interval(B = 199L, show_progress = FALSE)
	list(ci = ci, used = used)
}

test_that("bootstrap CIs are identical at 1, 2 and 3 fork workers", {
	skip_on_cran()
	skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "fork worker invariance is tested on Linux")
	skip_if(
		identical(Sys.getenv("R_COVR"), "true"),
		"avoid spawning a real fork cluster under covr's gcov-instrumented build"
	)
	skip_if(
		isTRUE(EDI:::edi_env$mirai_has_been_used),
		"fork clusters cannot be started safely after mirai has been used in this R session"
	)
	available = parallel::detectCores(logical = TRUE)
	skip_if(is.na(available) || available < 2L, "fewer than 2 logical cores available")
	worker_counts = c(2L, if (available >= 3L) 3L)

	des = make_fork_worker_invariance_design()
	for (class_name in c("InferenceAllSimpleAverageDiff", "InferenceContinOLS")) {
		inference_class = get(class_name, envir = asNamespace("EDI"))
		serial = bootstrap_ci_at_workers(inference_class, des, 1L)
		for (workers in worker_counts) {
			parallel_run = bootstrap_ci_at_workers(inference_class, des, workers)
			expect_true(any(parallel_run$used == workers),
				info = paste(class_name, "bootstrap never dispatched to", workers, "fork workers"))
			expect_identical(parallel_run$ci, serial$ci, info = paste(class_name, workers, "fork workers"))
		}
	}
})
