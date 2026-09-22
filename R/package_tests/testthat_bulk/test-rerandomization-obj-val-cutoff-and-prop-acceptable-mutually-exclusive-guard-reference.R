library(testthat)
library(EDI)

# DesignFixedRerandomization$new()'s construction-time guard: obj_val_cutoff and prop_acceptable
# are mutually exclusive acceptance-mode arguments (either, or neither -- which accepts every
# candidate -- but never both). Had zero test references anywhere despite this class being
# otherwise well-tested (test-rerandomization-objective-and-draw-paths-reference.R and others
# exercise each mode separately, but never the combined-arguments error itself).

test_that("supplying both obj_val_cutoff and prop_acceptable errors with the documented message", {
	expect_error(
		DesignFixedRerandomization$new(response_type = "continuous", n = 10L, obj_val_cutoff = 1, prop_acceptable = 0.1, verbose = FALSE),
		"Cannot specify both obj_val_cutoff and prop_acceptable\\."
	)
})

test_that("supplying only obj_val_cutoff, only prop_acceptable, or neither all construct without error", {
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, obj_val_cutoff = 1, verbose = FALSE))
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, prop_acceptable = 0.1, verbose = FALSE))
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, verbose = FALSE))
})
