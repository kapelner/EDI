library(testthat)
library(EDI)

# InferenceRandCustom's private install_stat_cpp() (inference_rand_custom.R) has three distinct
# validation guards not exercised by test-inference-rand-custom.R (which only covers the source-string
# arity check and the bare-externalptr-missing-signature error):
#   1. custom_randomization_statistic_cpp is none of a character source string, a plain R function, or
#      an externalptr at all (e.g. a numeric) -- "must be a C++ source string, a compiled Rcpp function,
#      or an RcppXPtrUtils::cppXPtr() external pointer, not a <class>." (the final `else` arm).
#   2. A plain R function (not a source string, not an externalptr) with the wrong number of arguments
#      -- reuses the same "must accept 2 arguments... got N." message as the externalptr arity check,
#      but a genuinely different code branch (the function-arity check at the end of install_stat_cpp(),
#      never reached by the existing source-string-only arity test).
#   3. An RcppXPtrUtils::cppXPtr() pointer that DOES carry a recorded signature (so it passes the
#      "bare externalptr" check already covered elsewhere) but has the wrong arity (1 argument instead
#      of 2 or 3) -- confirmed reachable via a zero-hit grep for both the "not a" message and this
#      specific well-formed-but-wrong-arity externalptr scenario.

make_rand_custom_design = function(n = 20, seed = 1) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = n / 2))
	des$add_all_subject_responses(c(seq_len(n / 2), seq_len(n / 2) + 2))
	des
}

test_that("a value that is neither a source string, a function, nor an externalptr is rejected with the documented message", {
	des <- make_rand_custom_design()
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = 42),
		"custom_randomization_statistic_cpp must be a C\\+\\+ source string, a compiled Rcpp function, or an RcppXPtrUtils::cppXPtr\\(\\) external pointer, not a numeric\\."
	)
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = list(1, 2)),
		"not a list\\."
	)
})

test_that("a plain R function (not a source string) with the wrong arity is rejected via the function-arity branch, not the source-string one", {
	des <- make_rand_custom_design()
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = function(y) sum(y)),
		"custom_randomization_statistic_cpp must accept 2 arguments \\(y, w\\) or 3 arguments \\(y, w, dead\\); got 1\\."
	)
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = function(y, w, dead, extra) sum(y)),
		"got 4\\."
	)
})

test_that("a well-formed externalptr (carries a recorded signature) with the wrong arity is rejected via the externalptr-arity branch", {
	des <- make_rand_custom_design()
	xptr_one_arg <- RcppXPtrUtils::cppXPtr(
		"double f_one_arg(const Eigen::VectorXd& y) { return y.sum(); }",
		depends = "RcppEigen"
	)
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = xptr_one_arg),
		"custom_randomization_statistic_cpp must accept 2 arguments \\(y, w\\) or 3 arguments \\(y, w, dead\\); got 1\\."
	)
})
