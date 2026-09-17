library(testthat)
library(EDI)

test_that("disjoint Turnbull intervals recover empirical masses and midpoint median", {
  skip_if_not_installed("interval")
  counts <- c(2L, 3L, 5L)
  L <- rep(c(1, 3, 5), counts)
  R <- L + 1
  # Half the empirical mass lies at or before (3,4], whose midpoint is 3.5.
  expect_equal(EDI:::turnbull_npmle_group_stat(L, R, "median"), 3.5, tolerance = 1e-8)
  # The package integrates the step representation at interval left endpoints.
  expect_equal(EDI:::turnbull_npmle_group_stat(L, R, "restricted_mean"),
               weighted.mean(c(1, 3, 5), counts), tolerance = 1e-8)
  order <- c(10:6, 1:5)
  expect_equal(EDI:::turnbull_npmle_group_stat(L[order], R[order], "median"), 3.5)
  expect_equal(EDI:::turnbull_npmle_group_stat(L[order], R[order], "restricted_mean"), 3.6)
})

test_that("Turnbull statistics filter unusable intervals without altering valid masses", {
  skip_if_not_installed("interval")
  L <- rep(c(1, 3, 5), c(2, 3, 5))
  R <- L + 1
  # Missing or negative lower endpoints, missing upper endpoints, and
  # nonincreasing bounds carry no interval observation for this helper.
  extra_L <- c(NA_real_, -1, 2, 4, 7)
  extra_R <- c(2, 1, NA_real_, 4, 6)
  expect_equal(EDI:::turnbull_npmle_group_stat(c(L, extra_L), c(R, extra_R), "median"), 3.5)
  expect_equal(EDI:::turnbull_npmle_group_stat(c(L, extra_L), c(R, extra_R), "restricted_mean"), 3.6)
})

test_that("unbounded Turnbull support produces unavailable finite group statistics", {
  skip_if_not_installed("interval")
  for (stat in c("median", "restricted_mean")) {
    expect_true(is.na(EDI:::turnbull_npmle_group_stat(c(1, 3, 5), rep(Inf, 3), stat)))
  }
  # A finite lower interval exists, but most mass remains beyond any finite median.
  expect_true(is.na(EDI:::turnbull_npmle_group_stat(c(1, 3, 5), c(2, Inf, Inf), "median")))
})

test_that("Turnbull contrasts preserve treatment direction and missing-arm contracts", {
  skip_if_not_installed("interval")
  L <- rep(c(1, 3, 5), c(2, 3, 5))
  R <- L + 1
  lower <- c(L, L + 2)
  upper <- c(R, R + 2)
  w <- rep(c(0, 1), each = length(L))
  for (stat in c("median", "restricted_mean")) {
    expect_equal(EDI:::turnbull_npmle_stat_diff(lower, upper, w, stat), 2, tolerance = 1e-8)
    expect_equal(EDI:::turnbull_npmle_stat_diff(lower, upper, 1 - w, stat), -2, tolerance = 1e-8)
    expect_true(is.na(EDI:::turnbull_npmle_stat_diff(lower, upper, rep(1, length(w)), stat)))
    expect_true(is.na(EDI:::turnbull_npmle_stat_diff(c(L, L), c(R, rep(Inf, length(R))), w, stat)))
  }
})
