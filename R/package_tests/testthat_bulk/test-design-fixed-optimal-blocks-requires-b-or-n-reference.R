library(testthat)
library(EDI)

# DesignFixedOptimalBlocks$new()'s B/n construction-time guard: supplying neither B nor n errors
# outright (B cannot be derived), supplying n without B derives B = max(1, floor(sqrt(n))), and
# supplying B without n uses B directly. Had zero test references anywhere (confirmed via
# repo-wide grep, both the full literal message and a shortened substring), despite this class
# being otherwise well-tested.

test_that("supplying neither B nor n errors with the documented message", {
	expect_error(
		DesignFixedOptimalBlocks$new(response_type = "continuous"),
		"DesignFixedOptimalBlocks requires B when n is not supplied\\."
	)
})

test_that("supplying n without B derives B = max(1, floor(sqrt(n)))", {
	des <- DesignFixedOptimalBlocks$new(response_type = "continuous", n = 25L)
	expect_identical(des$.__enclos_env__$private$B, 5L)

	des2 <- DesignFixedOptimalBlocks$new(response_type = "continuous", n = 3L)
	expect_identical(des2$.__enclos_env__$private$B, 1L)                        # floor(sqrt(3)) = 1, max(1, 1) = 1
})

test_that("supplying B without n uses B directly, no error", {
	des <- DesignFixedOptimalBlocks$new(response_type = "continuous", B = 3L)
	expect_identical(des$.__enclos_env__$private$B, 3L)
})
