library(testthat)
library(EDI)

# helper_optimal_shared.R's validate_optimal_design_objective_args() resolves `interest` into
# interest_kind via an if/else-if chain ("treatment"/"all" strings, a one-sided formula, a
# character vector of covariate names) with two distinct rejection arms beyond the already-
# covered two-sided-formula guard (test-validate-optimal-design-interest-formula-one-sided-guard-
# reference.R) and the prior_precision matrix guards (test-optimal-design-prior-precision-matrix-
# guards-reference.R):
#   1. A matrix `interest` (contrast-matrix interest / general D_A) is explicitly not yet
#      supported: "Contrast-matrix interest (general D_A) arrives with Stage 2 of the
#      DesignFixedGreedyDOptimal plan...".
#   2. Anything else (NULL, a bare number, a list, ...) falls through to the generic type-mismatch
#      message: 'interest must be "treatment", "all", a one-sided formula, or a character vector
#      of covariate names.'
# A codebase-wide grep confirmed both exact messages had zero test references anywhere. Exercised
# via a direct namespace call, no Design fixture needed -- a lightweight, pure-function target.

test_that("a matrix interest is rejected with the documented 'contrast-matrix interest' not-yet-supported message", {
	f <- getFromNamespace("validate_optimal_design_objective_args", "EDI")
	expect_error(
		f("mahal_dist", interest = matrix(1, 2, 2), prior_precision = NULL, standardize_covariates = TRUE,
			allowed_objectives = c("mahal_dist", "D", "A")),
		"Contrast-matrix interest \\(general D_A\\) arrives with Stage 2 of the DesignFixedGreedyDOptimal plan"
	)
})

test_that("an interest value of an unrecognized type (NULL, numeric, list) falls through to the generic type-mismatch message", {
	f <- getFromNamespace("validate_optimal_design_objective_args", "EDI")
	for (bad_interest in list(NULL, 5, list("x1"))) {
		expect_error(
			f("mahal_dist", interest = bad_interest, prior_precision = NULL, standardize_covariates = TRUE,
				allowed_objectives = c("mahal_dist", "D", "A")),
			'interest must be "treatment", "all", a one-sided formula, or a character vector of covariate names\\.',
			fixed = FALSE
		)
	}
})
