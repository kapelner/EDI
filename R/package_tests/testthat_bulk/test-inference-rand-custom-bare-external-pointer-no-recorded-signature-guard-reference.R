library(testthat)
library(EDI)

# InferenceRandCustom$initialize()'s install_stat_cpp() (inference_rand_custom.R:89-105), when given
# a raw externalptr custom_randomization_statistic_cpp (as opposed to a C++ source string), requires
# RcppXPtrUtils::cppXPtr()'s own recorded `args` attribute to determine the pointed-to function's
# arity -- a bare externalptr with that attribute stripped cannot have its arity determined and is
# rejected: "custom_randomization_statistic_cpp external pointers must carry RcppXPtrUtils::cppXPtr()'s
# recorded signature...". Distinct from the two already-covered sibling constructor guards ("Supply
# ... not both" / "requires custom_randomization_statistic_function or ..._cpp", both in test-
# inference-rand-custom.R). A codebase-wide grep confirmed this exact message had zero test
# references anywhere. Exercised with a genuine RcppXPtrUtils::cppXPtr() pointer (a real, trivial,
# fast single-function compile -- not EDI's own package build) whose `args` attribute is then
# stripped to simulate the "bare pointer" case.

test_that("a raw externalptr with no recorded RcppXPtrUtils args attribute is rejected", {
	skip_if_not_installed("RcppXPtrUtils")
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	xptr <- RcppXPtrUtils::cppXPtr(
		"double f(const Eigen::VectorXd& y, const Eigen::VectorXd& w) { return 0.0; }",
		depends = "RcppEigen"
	)
	attr(xptr, "args") <- NULL

	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = xptr, verbose = FALSE),
		"custom_randomization_statistic_cpp external pointers must carry RcppXPtrUtils::cppXPtr\\(\\)'s recorded signature",
	)
})
