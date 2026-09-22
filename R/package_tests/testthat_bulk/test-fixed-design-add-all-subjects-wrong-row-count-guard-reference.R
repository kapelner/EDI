library(testthat)
library(EDI)

# design_fixed_abstract.R's add_all_subjects_to_experiment() -- the primary, universally-used entry
# point for populating any fixed design's covariates -- stop()s "X_all must have exactly <n> rows
# for this fixed design." when the supplied data frame's row count doesn't match the design's own
# declared n. Despite this being one of the single most-used methods in the entire package (every
# fixed-design fixture in the test suite calls it, always with a correctly-sized X_all), the actual
# wrong-row-count guard itself had zero test references anywhere; every existing test only exercises
# the success path. The sibling re-entry guard ("Subjects have already been added to this design.")
# is already covered by test-design-lifecycle-completeness-and-single-enrollment-guards-reference.R.

test_that("add_all_subjects_to_experiment(): too few rows errors with the documented message", {
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = 10L, verbose = FALSE)
	expect_error(
		d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(5))),
		"X_all must have exactly 10 rows for this fixed design\\."
	)
})

test_that("add_all_subjects_to_experiment(): too many rows errors with the documented message", {
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = 10L, verbose = FALSE)
	expect_error(
		d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(15))),
		"X_all must have exactly 10 rows for this fixed design\\."
	)
})

test_that("add_all_subjects_to_experiment(): exactly n rows succeeds without error", {
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = 10L, verbose = FALSE)
	expect_no_error(d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10))))
})
