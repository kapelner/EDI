library(testthat)
library(EDI)

# v1.0.6-TODO-219: seeded InferenceSuite$run_all_inference() runs on real forked
# workers (num_cores = 2, one parallel::mcparallel() child per task) are
# reproducible and equal the sequential run. Before, each child reseeded itself
# from the clock and PID, so bootstrap and randomization p-values changed run to
# run. Named test-aa-* so it forks before any test starts mirai in the session.

suite_design_219_fork = function(n = 30L){
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(20261119)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(1 + 0.5 * des$get_w() + rnorm(n))
	des
}

run_suite_219_fork = function(cores){
	suite = InferenceSuite$new(suite_design_219_fork())
	set.seed(7L)
	res = NULL
	utils::capture.output(res <- suppressWarnings(suppressMessages(suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(), num_cores = cores,
		classes = c("InferenceAllSimpleAverageDiff", "InferenceContinOLS"), methods = c("bootstrap", "rand"),
		B = 19L, r = 19L))))
	res$results_table[, c("inference_class", "method", "type", "estimate", "pval", "status")]
}

test_that("two seeded runs on 2 forked workers are identical and equal the sequential run", {
	skip_on_cran()
	skip_if_not(identical(Sys.info()[["sysname"]], "Linux"), "fork workers are tested on Linux")
	skip_if(identical(Sys.getenv("R_COVR"), "true"), "avoid real forks under covr's gcov-instrumented build")
	skip_if(isTRUE(EDI:::edi_env$mirai_has_been_used), "forks cannot be started safely after mirai has been used in this R session")
	available = parallel::detectCores(logical = TRUE)
	skip_if(is.na(available) || available < 2L, "fewer than 2 logical cores available")
	withr::local_envvar(EDI_TESTING_DISABLE_FORK_CLUSTER = "")
	fork_a = run_suite_219_fork(2L)
	fork_b = run_suite_219_fork(2L)
	seq_res = run_suite_219_fork(1L)
	expect_identical(fork_a, fork_b)
	expect_identical(fork_a, seq_res)
	expect_gt(sum(is.finite(fork_a$pval)), 4L)
})
