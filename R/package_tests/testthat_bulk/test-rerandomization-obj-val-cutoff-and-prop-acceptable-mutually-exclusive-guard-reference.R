library(testthat)
library(EDI)

# DesignFixedRerandomization$new()'s construction-time guard: obj_val_cutoff and prop_acceptable
# are mutually exclusive acceptance-mode arguments, and exactly one is required (owner, 2026-11-17: with
# neither, the design accepted every candidate, i.e. was complete randomization under a rerandomization name).
# test-rerandomization-objective-and-draw-paths-reference.R and others exercise each mode separately.

test_that("supplying both obj_val_cutoff and prop_acceptable errors with the documented message", {
	expect_error(
		DesignFixedRerandomization$new(response_type = "continuous", n = 10L, obj_val_cutoff = 1, prop_acceptable = 0.1, verbose = FALSE),
		"Cannot specify both obj_val_cutoff and prop_acceptable\\."
	)
})

test_that("supplying only obj_val_cutoff or only prop_acceptable constructs without error", {
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, obj_val_cutoff = 1, verbose = FALSE))
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, prop_acceptable = 0.1, verbose = FALSE))
	# The explicit "accept every draw" forms stay available.
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, obj_val_cutoff = Inf, verbose = FALSE))
	expect_no_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, prop_acceptable = 1, verbose = FALSE))
})

test_that("supplying neither acceptance rule errors and names both", {
	expect_error(DesignFixedRerandomization$new(response_type = "continuous", n = 10L, verbose = FALSE),
		"Specify an acceptance rule: obj_val_cutoff .* prop_acceptable")
})
