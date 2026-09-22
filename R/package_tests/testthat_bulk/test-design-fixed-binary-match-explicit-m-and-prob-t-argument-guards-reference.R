library(testthat)
library(EDI)

# DesignFixedBinaryMatch$new()'s explicit-m argument validation, and set_binary_match_structure_from_m()'s
# pair-structure validation: (1) prob_T must be exactly 0.5 (this design only supports balanced allocation);
# (2) supplying m requires n to also be supplied; (3) length(m) must equal n; (4) every distinct pair id in m
# must occur exactly twice (any other multiplicity -- 1, 3, etc. -- is rejected). This well-tested class (its
# normal package-computed matching path is covered extensively elsewhere) had no test calling any of these four
# argument-validation guards.

test_that("prob_T other than 0.5 is rejected at construction", {
	expect_error(
		DesignFixedBinaryMatch$new(response_type = "continuous", prob_T = 0.6, n = 10L),
		"Binary match designs only support even treatment allocation \\(prob_T = 0.5\\)"
	)
})

test_that("supplying m without n is rejected", {
	expect_error(
		DesignFixedBinaryMatch$new(response_type = "continuous", m = c(1, 1, 2, 2)),
		"When supplying m to DesignFixedBinaryMatch\\$new\\(\\), n must also be supplied\\."
	)
})

test_that("length(m) not equal to n is rejected", {
	expect_error(
		DesignFixedBinaryMatch$new(response_type = "continuous", m = c(1, 1, 2, 2), n = 6L),
		"When supplying m to DesignFixedBinaryMatch\\$new\\(\\), length\\(m\\) must equal n\\."
	)
})

test_that("a pair id that doesn't occur exactly twice is rejected by set_binary_match_structure_from_m()", {
	des <- DesignFixedBinaryMatch$new(response_type = "continuous", n = 6L, m = c(1, 1, 2, 2, 3, 3), verbose = FALSE)
	p <- des$.__enclos_env__$private
	expect_error(
		p$set_binary_match_structure_from_m(c(1, 1, 1, 2, 2, 3)),                    # pair 1 appears 3x, pair 3 appears 1x
		"Explicit m for DesignFixedBinaryMatch must define matched pairs only: each pair ID must occur exactly twice\\."
	)
})

test_that("a valid explicit m (n supplied, matching length, every pair exactly twice) constructs without error", {
	des <- DesignFixedBinaryMatch$new(response_type = "continuous", n = 6L, m = c(1, 1, 2, 2, 3, 3), verbose = FALSE)
	expect_identical(des$.__enclos_env__$private$m, c(1L, 1L, 2L, 2L, 3L, 3L))
})
