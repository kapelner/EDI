library(testthat)
library(EDI)

# helper_optimal_shared.R's validate_optimal_design_objective_args() has an interest-formula guard
# distinct from its prior_precision matrix guards (test-optimal-design-prior-precision-matrix-guards-
# reference.R) and the objective/prior_precision-scalar/standardize_covariates guards already
# covered in test-design-core-helper-contracts.R: a two-sided `interest` formula (length(interest) !=
# 2L, i.e. it has a left-hand side) errors "An interest formula must be one-sided, e.g. ~ x1 + x2."
# Every existing test only ever supplies a one-sided formula (~ x1 + x2) or a character vector; the
# two-sided-formula rejection itself had zero test references anywhere.

test_that("a two-sided interest formula errors with the documented message", {
	expect_error(
		EDI:::validate_optimal_design_objective_args("D", y ~ x1, NULL, TRUE, c("D")),
		"An interest formula must be one-sided, e\\.g\\. ~ x1 \\+ x2\\."
	)
})

test_that("a one-sided interest formula is accepted (interest_kind = 'subset')", {
	res <- EDI:::validate_optimal_design_objective_args("D", ~ x1 + x2, NULL, TRUE, c("D"))
	expect_identical(res$interest_kind, "subset")
})
