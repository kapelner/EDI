library(testthat)
library(EDI)

# v1.0.6-TODO-210 (owner follow-up 2026-11-19): run_all_inference() runs the parametric-bootstrap
# likelihood-ratio CI (sentinel "param_boot") at the method's default B = 199. Its smallest
# attainable p-value is 2 / (B + 1) = 0.01, so for alpha < 0.01 the suite errors before any fitting
# instead of reporting a per-row error. Only when that CI is actually in the run.

suite_fixture_210 = function(n = 30L){
	set.seed(20261119)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(1 + 0.5 * des$get_w() + rnorm(n))
	InferenceSuite$new(des)
}

run_quiet_210 = function(suite, ...) {
	out = NULL
	utils::capture.output(out <- suppressWarnings(suppressMessages(
		suite$run_all_inference(screen = TRUE, html = FALSE, plots = FALSE, output_dir = tempdir(), ...))))
	out
}

test_that("the default B of every LR-bootstrap CI definition is 199", {
	default_B = getFromNamespace("run_all_inference_param_boot_ci_default_B", "EDI")
	for (nm in c("InferenceContinLin", "InferenceCountPoisson", "InferenceCountNegBin", "InferenceSurvivalWeibullRegr"))
		expect_identical(default_B(nm), 199, info = nm)
	# The count-likelihood component's wrapper is not on any generator (lazy component); the
	# helper falls back to the base default, so keep the two equal.
	plumbing = getFromNamespace("CountLikelihoodPlumbingSource", "EDI")
	expect_identical(formals(plumbing$public$compute_lik_ratio_bootstrap_confidence_interval)$B, 199)
})

test_that("alpha below 2 / (199 + 1) errors before fitting, naming the minimum B", {
	suite = suite_fixture_210()
	err = expect_error(
		suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinLin",
			methods = "param_boot", compute_conf_intervals = TRUE, alpha = 0.005),
		"B must be at least 399 for alpha = 0.005", fixed = TRUE)
	expect_match(conditionMessage(err), "the method default is B = 199 for InferenceContinLin", fixed = TRUE)
	expect_match(conditionMessage(err), "Pass B >= 399 to run_all_inference()", fixed = TRUE)
})

test_that("a user B is the effective B: below the minimum errors naming it, at the minimum no error", {
	suite = suite_fixture_210()
	err = expect_error(
		suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinLin",
			methods = "param_boot", compute_conf_intervals = TRUE, B = 38L),
		"B must be at least 39 for alpha = 0.05", fixed = TRUE)
	expect_match(conditionMessage(err), "got B = 38 for InferenceContinLin", fixed = TRUE)
	expect_match(conditionMessage(err), "Pass B >= 39 to run_all_inference()", fixed = TRUE)
	# A large enough user B lifts the default's limit.
	check = getFromNamespace("run_all_inference_check_param_boot_ci_B", "EDI")
	tasks = list(list(cls_name = "InferenceContinLin", method = "param_boot", type = NA_character_))
	expect_null(check(tasks, alpha = 0.005, compute_conf_intervals = TRUE, B = 399L))
	expect_error(check(tasks, alpha = 0.005, compute_conf_intervals = TRUE, B = 398L), "got B = 398", fixed = TRUE)
	expect_null(check(tasks, alpha = 0.05, compute_conf_intervals = TRUE, B = 39L))
})

test_that("the check covers the boundary and skips runs without the LR-bootstrap CI", {
	check = getFromNamespace("run_all_inference_check_param_boot_ci_B", "EDI")
	tasks = list(list(cls_name = "InferenceContinLin", method = "param_boot", type = NA_character_))
	expect_null(check(tasks, alpha = 0.01, compute_conf_intervals = TRUE))   # B = 199 is exactly the minimum
	expect_error(check(tasks, alpha = 0.0099, compute_conf_intervals = TRUE), "B must be at least 202", fixed = TRUE)
	expect_null(check(tasks, alpha = 0.001, compute_conf_intervals = FALSE))
	other = list(list(cls_name = "InferenceContinLin", method = "param_boot_direct", type = NA_character_))
	expect_null(check(other, alpha = 0.001, compute_conf_intervals = TRUE))

	suite = suite_fixture_210()
	# CIs off: the p-value has no alpha floor, so no error.
	expect_no_error(run_quiet_210(suite, classes = "InferenceContinLin", methods = c("wald", "param_boot"),
		compute_conf_intervals = FALSE, alpha = 0.005))
	# "param_boot" not requested.
	expect_no_error(run_quiet_210(suite, classes = "InferenceContinLin", methods = "wald",
		compute_conf_intervals = TRUE, alpha = 0.005))
	# A class without the LR-bootstrap CI: no param_boot task is built.
	expect_no_error(run_quiet_210(suite, classes = "InferenceAllSimpleAverageDiff", methods = c("wald", "param_boot"),
		compute_conf_intervals = TRUE, alpha = 0.005))
})
