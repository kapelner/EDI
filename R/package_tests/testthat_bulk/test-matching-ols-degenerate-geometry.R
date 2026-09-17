library(testthat)
library(EDI)

# TODO-3: missing pair/reservoir components and no covariates are valid geometries.
test_that("combined matching OLS retains pure pair and pure reservoir designs", {
  yd <- c(2, -3)
  Xd <- matrix(c(1, 4, -2, 5), nrow = 2)
  paired <- EDI:::build_matching_combined_ols_design_cpp(
    yd, Xd, numeric(), numeric(), matrix(numeric(), 0, 2))
  expect_equal(paired$X_comb, cbind(0, 1 / sqrt(2), Xd / sqrt(2)))
  expect_equal(as.numeric(paired$y_comb), yd / sqrt(2))

  yr <- c(6, 9, 2)
  wr <- c(0, 1, 0)
  Xr <- matrix(c(1, 2, 4, -1, 3, 2), nrow = 3)
  reservoir <- EDI:::build_matching_combined_ols_design_cpp(
    numeric(), matrix(numeric(), 0, 2), yr, wr, Xr)
  expect_equal(reservoir$X_comb, unname(cbind(1, wr, Xr)))
  expect_equal(as.numeric(reservoir$y_comb), yr)
})

test_that("combined matching OLS preserves treatment weighting without covariates", {
  yd <- c(2, 4)
  yr <- c(1, 7)
  wr <- c(0, 1)
  got <- EDI:::build_matching_combined_ols_design_cpp(
    yd, matrix(numeric(), 2, 0), yr, wr, matrix(numeric(), 2, 0))
  expected_X <- rbind(c(0, 1 / sqrt(2)), c(0, 1 / sqrt(2)), c(1, 0), c(1, 1))
  expect_equal(got$X_comb, expected_X)
  expect_equal(as.numeric(got$y_comb), c(yd / sqrt(2), yr))
  # Two pair differences and the reservoir contrast each have variance 2 sigma^2.
  fit <- lm.fit(got$X_comb, as.numeric(got$y_comb))
  expect_equal(unname(fit$coefficients[2]), mean(c(yd, diff(yr))), tolerance = 1e-12)
})
