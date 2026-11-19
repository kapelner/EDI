library(testthat)
library(EDI)

# v1.0.6-TODO-219: a seeded InferenceSuite$run_all_inference() is reproducible.
# Every task runs from its own seed, drawn once from the caller's stream and
# keyed by the task's name, so results do not depend on what earlier tasks drew,
# on task order, or on whether the fork path (here its same-process stand-in)
# is used. Also: a user B below 5 errors before any fitting.

suite_design_219 = function(n = 30L){
	old_seed = if (exists(".Random.seed", envir = globalenv())) get(".Random.seed", envir = globalenv()) else NULL
	on.exit(if (!is.null(old_seed)) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(20261119)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(1 + 0.5 * des$get_w() + rnorm(n))
	des
}

run_suite_219 = function(seed, classes, methods, cores = 1L, B = 19L, r = 19L, suite = InferenceSuite$new(suite_design_219())){
	force(suite)
	set.seed(seed)
	res = NULL
	utils::capture.output(res <- suppressWarnings(suppressMessages(suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(), num_cores = cores,
		classes = classes, methods = methods, B = B, r = r))))
	tab = res$results_table
	rownames(tab) = paste(tab$inference_class, tab$method, tab$type)
	tab[, c("estimate", "pval", "status")]
}

test_that("two seeded sequential runs are identical, and a task does not depend on the tasks run before it", {
	classes = c("InferenceAllSimpleAverageDiff", "InferenceContinOLS")
	a = run_suite_219(7L, classes, c("bootstrap", "rand"))
	b = run_suite_219(7L, classes, c("bootstrap", "rand"))
	expect_identical(a, b)
	# The same suite (and design) reused under another seed and then the first one again:
	# randomization draws cached on the design by an earlier run must not leak into the next.
	suite = InferenceSuite$new(suite_design_219())
	d8 = run_suite_219(8L, classes, c("bootstrap", "rand"), suite = suite)
	a_again = run_suite_219(7L, classes, c("bootstrap", "rand"), suite = suite)
	expect_identical(a_again, a)
	expect_gt(sum(is.finite(a$pval)), 4L)
	# Dropping the first class (whose draws used to shift every later task) leaves the rest unchanged.
	c_only = run_suite_219(7L, "InferenceContinOLS", c("bootstrap", "rand"))
	expect_identical(c_only, a[rownames(c_only), ])
	# A different seed gives different resampling p-values.
	d = run_suite_219(8L, classes, c("bootstrap", "rand"))
	expect_identical(d8, d)
	expect_false(identical(a$pval, d$pval))
	rand_rows = grepl(" rand ", paste0(rownames(a), " "))
	expect_false(identical(a$pval[rand_rows], d$pval[rand_rows]))
})

test_that("the fork path's task runner gives the sequential results", {
	withr::local_envvar(EDI_TESTING_DISABLE_FORK_CLUSTER = "true")
	classes = c("InferenceAllSimpleAverageDiff", "InferenceContinOLS")
	seq_res = run_suite_219(7L, classes, c("bootstrap", "rand"), cores = 1L)
	fork_res = run_suite_219(7L, classes, c("bootstrap", "rand"), cores = 2L)
	expect_identical(fork_res, seq_res)
})

test_that("the run leaves the caller's RNG stream one draw further on", {
	set.seed(99L)
	invisible(sample.int(.Machine$integer.max, 1L))
	want = runif(1L)
	suite = InferenceSuite$new(suite_design_219())
	set.seed(99L)
	utils::capture.output(suppressWarnings(suppressMessages(suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(),
		classes = "InferenceAllSimpleAverageDiff", methods = "bootstrap", B = 19L))))
	expect_identical(runif(1L), want)
})

test_that("task seeds depend only on the master draw and the task name", {
	seeds_fn = getFromNamespace("run_all_inference_task_seeds", "EDI")
	set.seed(1L); s1 = seeds_fn(c("A{bootstrap:bca}", "B{rand}"))
	set.seed(1L); s2 = seeds_fn(c("B{rand}", "C", "A{bootstrap:bca}"))
	expect_identical(s1, s2[c(3L, 1L)])
	expect_true(all(s1 >= 1L & !is.na(s1)))
	expect_identical(seeds_fn(character()), integer())
})

test_that("a B below 5 errors before any fitting when a bootstrap method runs", {
	suite = InferenceSuite$new(suite_design_219())
	fit_called = FALSE
	local_mocked_bindings(run_all_inference_one_class = function(...) { fit_called <<- TRUE; stop("fit should not run") }, .package = "EDI")
	for (m in c("bootstrap", "param_boot_direct")) {
		expect_error(
			utils::capture.output(suite$run_all_inference(screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(),
				classes = "InferenceContinOLS", methods = m, B = 4L)),
			"B must be at least 5", info = m)
	}
	expect_false(fit_called)
	# B = 4 is fine when no bootstrap method runs (it is not passed to anything).
	expect_no_error(getFromNamespace("run_all_inference_check_min_usable_B", "EDI")(
		list(list(method = "rand"), list(method = "wald")), 4L))
	expect_no_error(getFromNamespace("run_all_inference_check_min_usable_B", "EDI")(
		list(list(method = "bootstrap")), 5L))
})
