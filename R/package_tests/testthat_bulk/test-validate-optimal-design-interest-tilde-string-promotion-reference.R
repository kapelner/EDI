library(testthat)
library(EDI)

# helper_optimal_shared.R's validate_optimal_design_objective_args() promotes a character `interest`
# containing formula operators to a one-sided formula via
# `if (grepl("~", interest, fixed = TRUE)) stats::as.formula(interest) else stats::as.formula(paste("~", interest))`.
# Existing coverage exercises the FALSE branch (a plain string with no "~", e.g. "x1 + x2") and,
# separately, the one-sided-formula guard on an already-constructed formula OBJECT (~ x1, via
# test-validate-optimal-design-interest-formula-one-sided-guard-reference.R) -- but no existing test
# passes a plain character STRING that already contains "~", so the grepl("~", ...) == TRUE branch
# itself had never been reached.
#   1. A one-sided string already containing "~" (e.g. "~ x1 + x2") is promoted to a formula that is
#      structurally identical (via deparse) to passing the equivalent bare formula object directly,
#      and interest_kind is "subset" in both cases.
#   2. A two-sided string containing "~" (e.g. "y ~ x1") is promoted to a formula and THEN caught by
#      the one-sided-formula guard -- the same error the formula-object case already covers, but
#      reached through the string-promotion branch instead.

test_that("a one-sided string already containing '~' promotes to a formula structurally identical to the equivalent bare formula object", {
	res_string <- EDI:::validate_optimal_design_objective_args("D", "~ x1 + x2", NULL, TRUE, c("D"))
	res_formula <- EDI:::validate_optimal_design_objective_args("D", ~ x1 + x2, NULL, TRUE, c("D"))
	expect_s3_class(res_string$interest, "formula")
	expect_identical(res_string$interest_kind, "subset")
	expect_identical(deparse(res_string$interest), deparse(res_formula$interest))
	expect_identical(res_string$interest_kind, res_formula$interest_kind)
})

test_that("a two-sided string containing '~' promotes to a formula, then is caught by the one-sided-formula guard", {
	expect_error(
		EDI:::validate_optimal_design_objective_args("D", "y ~ x1", NULL, TRUE, c("D")),
		"An interest formula must be one-sided, e.g. ~ x1 \\+ x2\\."
	)
})
