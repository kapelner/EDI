library(testthat)
library(EDI)

# pocock_simon_redraw_w_cpp (pocock_simon_assign.cpp) sequentially re-draws a full treatment-arm
# assignment vector for the Pocock-Simon minimization design, continuing R's live .Random.seed
# stream (rather than an independent seed) -- used for redrawing a fresh assignment vector under
# resampling/replay. Its own doc comment references an independent-reference test
# ("test-pocock-simon-redraw-buffers.R") that does not actually exist anywhere in the tree (confirmed
# via find/grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/); the
# function itself has ZERO test references of any kind. It shares the identical 3-guard input
# validation with its file-sibling pocock_simon_assign_cpp/generate_permutations_pocock_simon_cpp
# (the latter already has 2 of 3 tested in test-pocock-simon-permutation-kernel-marginal-balance-
# rule-replay-and-tie-handling-reference.R, but this function's own copy of the same guards was
# never exercised):
#   1. `if (num_levels_total <= 0) throw ("num_levels_total must be positive")`.
#   2. `if (weights.size() != num_covs) throw ("weights length must match the number of
#      covariates")`.
#   3. `if (row_idx < 0 || row_idx >= num_levels_total) throw ("x_levels_matrix contains a level
#      index outside 1..num_levels_total")`.
# The guards fire inside pocock_simon_redraw_w_internal() before any RNG state is consumed, so no
# special .Random.seed setup is needed to reach them (confirmed directly below). A basic
# well-formedness check pins the successful path's output contract (a length-n vector of 0/1 arm
# assignments) and its dependence on R's live RNG stream via set.seed().

f <- get("pocock_simon_redraw_w_cpp", envir = asNamespace("EDI"))
lv <- matrix(c(1L, 2L, 1L, 2L), ncol = 1)
wts <- 1

test_that("num_levels_total <= 0 throws the positive-levels error", {
	expect_error(f(lv, 0L, wts, 1, 0.5), "num_levels_total must be positive")
	expect_error(f(lv, -1L, wts, 1, 0.5), "num_levels_total must be positive")
})

test_that("a weights vector of the wrong length throws the length-mismatch error", {
	expect_error(f(lv, 2L, c(1, 1), 1, 0.5), "weights length must match the number of covariates")
})

test_that("an out-of-range level index in x_levels_matrix throws the level-index error", {
	lv_bad <- matrix(c(1L, 5L, 1L, 2L), ncol = 1)
	expect_error(f(lv_bad, 2L, wts, 1, 0.5), "x_levels_matrix contains a level index outside 1\\.\\.num_levels_total")
})

test_that("well-formed inputs return a length-n vector of 0/1 arm assignments, driven by R's live RNG stream", {
	set.seed(17)
	out <- f(lv, 2L, wts, 1, 0.5)
	expect_length(out, nrow(lv))
	expect_true(all(out %in% c(0L, 1L)))

	set.seed(17)
	out2 <- f(lv, 2L, wts, 1, 0.5)
	expect_identical(out, out2)
})
