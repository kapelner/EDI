library(testthat)
library(EDI)

test_that("SPBR redraw balances completed blocks separately in interleaved strata", {
  keys <- rep(c("east", "west", "north"), 11L)
  withr::local_seed(840)
  w <- EDI:::spbr_redraw_w_cpp(keys, 4L, 0.75)
  expect_length(w, length(keys))
  expect_true(all(w %in% c(0, 1)))
  for (key in unique(keys)) {
    assignments <- w[keys == key]
    expect_equal(colSums(matrix(assignments[1:8], nrow = 4)), c(3, 3))
    # Any three arrivals in a 3:1 block contain two or three treatments.
    expect_true(sum(assignments[9:11]) %in% c(2, 3))
  }
  set.seed(840)
  expect_identical(EDI:::spbr_redraw_w_cpp(keys, 4L, 0.75), w)
})

test_that("SPBR primitive supports degenerate allocations and empty arrival streams", {
  withr::local_seed(841)
  keys <- rep(c("A", "B"), 7L)
  expect_equal(EDI:::spbr_redraw_w_cpp(keys, 4L, 0), rep(0, length(keys)))
  expect_equal(EDI:::spbr_redraw_w_cpp(keys, 4L, 1), rep(1, length(keys)))
  expect_identical(EDI:::spbr_redraw_w_cpp(character(), 4L, 0.5), numeric())
})
