library(testthat)
library(EDI)

# TODO-3: invariant within-pair covariates are removed by the legacy differences API.
test_that("matched differences remove invariant pair columns and keep varying contrasts", {
  X <- cbind(c(2, 2, 5, 5), c(1, 4, 9, 7), c(3, 3, 8, 8))
  y <- c(8, 3, 6, 10)
  w <- c(1L, 0L, 0L, 1L)
  matches <- c(1L, 1L, 2L, 2L)
  got <- EDI:::match_diffs_cpp(X, y, w, matches, 2L)
  expect_equal(got$yTs_matched, c(8, 10))
  expect_equal(got$yCs_matched, c(3, 6))
  expect_equal(got$X_matched_diffs, matrix(c(-3, -2), ncol = 1))
  invariant <- EDI:::match_diffs_cpp(X[, c(1, 3), drop = FALSE], y, w, matches, 2L)
  expect_equal(dim(invariant$X_matched_diffs), c(2L, 0L))
})

test_that("matched differences retain column shape with only reservoir subjects", {
  X <- matrix(c(1, 2, 3, 4), nrow = 2)
  got <- EDI:::match_diffs_cpp(X, c(3, 6), c(0L, 1L), c(0L, NA_integer_), 0L)
  expect_identical(got$yTs_matched, numeric())
  expect_identical(got$yCs_matched, numeric())
  expect_equal(dim(got$X_matched_diffs), c(0L, 2L))
})

test_that("matched differences reject incompatible subject dimensions", {
  X <- matrix(c(1, 2), ncol = 1)
  expect_error(EDI:::match_diffs_cpp(X, c(3, 6), c(0L, 1L), 1L, 1L), "m_vec size")
  expect_error(EDI:::match_diffs_cpp(X, 3, c(0L, 1L), c(1L, 1L), 1L), "y size")
  expect_error(EDI:::match_diffs_cpp(X[1, , drop = FALSE], c(3, 6),
                                     c(0L, 1L), c(1L, 1L), 1L), "X row count")
})
