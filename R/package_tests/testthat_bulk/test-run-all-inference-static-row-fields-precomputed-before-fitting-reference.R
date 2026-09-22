library(testthat)
library(EDI)

# run_all_inference_static_row_fields(task, des_obj, inference_params): the live table's precomputable-before-fitting fields -- inference_class_disp (short
# class label, tau-aware), cov_model_raw (deparsed covariate formula, or NA when the class does not adjust for covariates), estimand_disp (short estimand
# label, tau-aware). Reference: independent calls to inference_class_short_label()/estimand_short_label() with the same class/estimand/tau, and
# get_inference_class_metadata()$adjusts_for_covariates for the cov_model_raw branch.

ns <- asNamespace("EDI")
static_fields <- get("run_all_inference_static_row_fields", envir = ns)
class_label <- get("inference_class_short_label", envir = ns)
estimand_label <- get("estimand_short_label", envir = ns)
class_metadata <- get("get_inference_class_metadata", envir = ns)
class_estimand <- get("run_all_inference_estimand", envir = ns)

set.seed(1); n <- 10L
d <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(rnorm(n))

test_that("with no task formula, cov_model_raw is the design's own formula deparsed; estimand/class labels match the standalone label helpers", {
	task <- list(cls_name = "InferenceContinOLS", model_formula = NULL, method = "wald")
	r <- static_fields(task, d)
	expect_identical(r$cov_model_raw, deparse1(d$get_design_formula()))
	expect_identical(r$inference_class_disp, class_label("InferenceContinOLS", NA_real_))
	e <- class_estimand("InferenceContinOLS")
	expect_identical(r$estimand_disp, estimand_label(e, NA_real_))
	expect_setequal(names(r), c("inference_class_disp", "cov_model_raw", "estimand_disp"))
})

test_that("a task-supplied model_formula overrides the design's own formula in cov_model_raw", {
	task <- list(cls_name = "InferenceContinOLS", model_formula = y ~ x + z, method = "wald")
	r <- static_fields(task, d)
	expect_identical(r$cov_model_raw, deparse1(y ~ x + z))
	expect_false(identical(r$cov_model_raw, deparse1(d$get_design_formula())))
})

test_that("a class with adjusts_for_covariates = FALSE gets NA cov_model_raw regardless of the task formula", {
	expect_false(class_metadata("InferenceAllSimpleMeanDiffPooledVar")$adjusts_for_covariates)
	task <- list(cls_name = "InferenceAllSimpleMeanDiffPooledVar", model_formula = y ~ x, method = "wald")
	r <- static_fields(task, d)
	expect_true(is.na(r$cov_model_raw))
})

test_that("a quantile-regression class defaults tau = 0.5 in both labels (median effect) unless inference_params overrides it", {
	task <- list(cls_name = "InferenceContinKKQuantileRegrOneLik", model_formula = NULL, method = "wald")
	expect_identical(class_estimand("InferenceContinKKQuantileRegrOneLik"), "quantile_regression_effect")
	r_default <- static_fields(task, d)
	expect_identical(r_default$estimand_disp, "median effect")
	expect_identical(r_default$inference_class_disp, class_label("InferenceContinKKQuantileRegrOneLik", 0.5))
	r_tau <- static_fields(task, d, inference_params = list(InferenceContinKKQuantileRegrOneLik = list(tau = 0.9)))
	expect_identical(r_tau$estimand_disp, "quantile (90%ile)")
	expect_identical(r_tau$inference_class_disp, class_label("InferenceContinKKQuantileRegrOneLik", 0.9))
	expect_false(identical(r_tau$estimand_disp, r_default$estimand_disp))
})

test_that("a class with an unregistered (NA) estimand gets the literal string 'NA', not the character NA", {
	task <- list(cls_name = "InferenceAllSimpleMeanDiffPooledVar", model_formula = NULL, method = "wald")
	r <- static_fields(task, d)
	e <- class_estimand("InferenceAllSimpleMeanDiffPooledVar")
	if (is.na(e)) {
		expect_identical(r$estimand_disp, "NA")
	} else {
		expect_identical(r$estimand_disp, estimand_label(e, NA_real_))
	}
})
