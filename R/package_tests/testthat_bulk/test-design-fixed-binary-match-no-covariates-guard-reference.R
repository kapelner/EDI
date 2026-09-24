library(testthat)
library(EDI)

# DesignFixedBinaryMatch's own private ensure_matching_structure_computed() (design_fixed_binary_match.R)
# stop()s with "no covariates provided to run the binary matching algorithm" when private$X has zero
# columns and no explicit m/matching structure has been supplied or computed yet -- confirmed reachable
# via a zero-hit grep for the exact message across the whole test suite: add_all_subjects_to_experiment()
# places no lower bound on ncol(X_all) (only checks nrow == n and that subjects haven't already been
# added), so a zero-column data.frame with the right number of rows reaches this guard the first time
# assign_w_to_all_subjects()/draw_ws_raw() (both call ensure_matching_structure_computed() first) is
# invoked. The class's normal, covariate-driven matching path is covered extensively elsewhere
# (test-design-fixed-binary-match-explicit-m-and-prob-t-argument-guards-reference.R and others); only
# this specific "genuinely no covariates, no explicit m" guard had never been exercised.
#   1. A design constructed with n but no explicit m, given a zero-column covariate data.frame, errors
#      with the documented message on assign_w_to_all_subjects().
#   2. The same zero-column data.frame does NOT error when an explicit m is supplied at construction
#      (private$bms is already set via set_binary_match_structure_from_m(), so ensure_matching_structure_
#      computed() never reaches the "is X empty" check at all).

test_that("a zero-column covariate data.frame with no explicit m errors with the documented message on assignment", {
	des <- DesignFixedBinaryMatch$new(response_type = "continuous", n = 6L, verbose = FALSE)
	X0 <- data.frame(matrix(nrow = 6L, ncol = 0L))
	des$add_all_subjects_to_experiment(X0)
	expect_error(
		des$assign_w_to_all_subjects(),
		"no covariates provided to run the binary matching algorithm"
	)
})

test_that("the same zero-column data.frame does NOT error when an explicit m was supplied at construction", {
	des <- DesignFixedBinaryMatch$new(response_type = "continuous", n = 6L, m = c(1, 1, 2, 2, 3, 3), verbose = FALSE)
	X0 <- data.frame(matrix(nrow = 6L, ncol = 0L))
	des$add_all_subjects_to_experiment(X0)
	expect_no_error(des$assign_w_to_all_subjects())
})
