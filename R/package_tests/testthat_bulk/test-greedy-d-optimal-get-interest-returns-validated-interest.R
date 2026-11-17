library(testthat)
library(EDI)

# v1.0.6-TODO-70 (GitHub issue #28): DesignFixedGreedyDOptimal$get_interest() was documented as
# returning "treatment" or "all", but `interest` also accepts a one-sided formula, a formula
# string (promoted to a formula) and a character vector of column names, and get_interest()
# returns the validated value unchanged.

dopt_interest = function(interest) {
	DesignFixedGreedyDOptimal$new(response_type = "continuous", n = 12L, objective = "A",
		interest = interest, verbose = FALSE, seed = 1L)$get_interest()
}

test_that("get_interest() returns the interest as validated at construction", {
	expect_identical(dopt_interest("treatment"), "treatment")
	expect_identical(dopt_interest("all"), "all")
	f = dopt_interest(~ x1 + x2)
	expect_s3_class(f, "formula")
	expect_identical(deparse(f), "~x1 + x2")
	g = dopt_interest("x1 * x2 + x7")
	expect_s3_class(g, "formula")
	expect_identical(deparse(g), "~x1 * x2 + x7")
	expect_identical(dopt_interest(c("x1", "x2")), c("x1", "x2"))
})
