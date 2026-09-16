library(testthat)
library(EDI)

test_that("run_all_inference: sentinel tables stay complete against the live capability registry (TODO-23)", {
	missing = run_all_inference_check_sentinel_completeness()
	expect_identical(missing, character())
})

