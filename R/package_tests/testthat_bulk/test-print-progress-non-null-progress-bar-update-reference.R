library(testthat)
library(EDI)

# helper_package_checks.R's print_progress(pb, i, total) -- the shared parallel-progress-bar helper
# called throughout the package's bootstrap/randomization/jackknife loops -- had only its `pb = NULL`
# no-op branch tested (test-sequential-design-validation-contracts.R). The other branch (a real
# txtProgressBar object) delegates to utils::setTxtProgressBar(pb, i) and had no test reference
# anywhere: confirmed via a zero-hit grep for the function name paired with a non-NULL first argument.
#   1. A real txtProgressBar's reported value is updated to i after the call.
#   2. The NULL branch remains a true no-op (re-confirmed alongside the new non-NULL case for contrast).

test_that("a real txtProgressBar is updated to the requested position", {
	pb <- utils::txtProgressBar(min = 0, max = 10, style = 1)
	on.exit(close(pb), add = TRUE)
	expect_equal(utils::getTxtProgressBar(pb), 0)
	invisible(capture.output(EDI:::print_progress(pb, 5, 10), type = "message"))
	expect_equal(utils::getTxtProgressBar(pb), 5)
	invisible(capture.output(EDI:::print_progress(pb, 10, 10), type = "message"))
	expect_equal(utils::getTxtProgressBar(pb), 10)
})

test_that("a NULL progress bar is a true no-op", {
	expect_null(EDI:::print_progress(NULL, 3, 10))
})
