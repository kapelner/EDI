library(testthat)
library(EDI)

# TODO-3: interleaved stratum state and rounded allocation away from one half.
test_that("random blocks independently balance interleaved strata at rounded probability", {
  keys <- rep(c("north", "south", "east"), 18L)
  set.seed(761)
  got <- EDI:::random_block_size_redraw_w_cpp(keys, 6L, 0.4)
  expect_length(got, length(keys))
  expect_true(all(got %in% c(0, 1)))
  for (key in unique(keys)) {
    stratum <- got[keys == key]
    # round(6 * .4) = 2, with independent replenishment every six arrivals.
    expect_equal(colSums(matrix(stratum, nrow = 6)), rep(2, 3))
  }
  set.seed(761)
  expect_identical(EDI:::random_block_size_redraw_w_cpp(keys, 6L, 0.4), got)
})

test_that("random blocks support all-control draws and empty arrival streams", {
  set.seed(762)
  expect_equal(EDI:::random_block_size_redraw_w_cpp(rep(c("a", "b"), 7), c(2L, 4L), 0),
               rep(0, 14))
  expect_identical(EDI:::random_block_size_redraw_w_cpp(character(), 4L, 0.5), numeric())
})
