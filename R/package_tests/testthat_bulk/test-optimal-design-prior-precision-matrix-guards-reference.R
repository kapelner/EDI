library(testthat)
library(EDI)

# helper_optimal_shared.R's validate_optimal_design_objective_args() has three sibling prior_precision
# guards: a scalar-branch guard ("prior_precision must be NULL, a single positive scalar, or a
# symmetric numeric matrix.", already covered via a negative scalar in
# test-design-core-helper-contracts.R) and two matrix-branch guards that were never exercised --
# "A matrix prior_precision must be numeric and square." (non-numeric, or numeric but non-square) and
# "A matrix prior_precision must be symmetric." (numeric square but asymmetric). All reachable
# directly on this pure, exported-internal helper without constructing any Design object.

test_that("a non-numeric matrix prior_precision errors with the numeric-and-square message", {
	expect_error(
		EDI:::validate_optimal_design_objective_args("D", "all", matrix(c("a", "b", "c", "d"), 2, 2), TRUE, c("D")),
		"A matrix prior_precision must be numeric and square\\."
	)
})

test_that("a non-square numeric matrix prior_precision errors with the numeric-and-square message", {
	expect_error(
		EDI:::validate_optimal_design_objective_args("D", "all", matrix(1:6, 2, 3), TRUE, c("D")),
		"A matrix prior_precision must be numeric and square\\."
	)
})

test_that("a square but asymmetric numeric matrix prior_precision errors with the symmetric message", {
	expect_error(
		EDI:::validate_optimal_design_objective_args("D", "all", matrix(c(1, 2, 3, 4), 2, 2), TRUE, c("D")),
		"A matrix prior_precision must be symmetric\\."
	)
})

test_that("a symmetric numeric matrix prior_precision passes without error", {
	res <- EDI:::validate_optimal_design_objective_args("D", "all", diag(2), TRUE, c("D"))
	expect_identical(res$interest_kind, "all")
})
