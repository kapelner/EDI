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
  # decreasing bounds (y_R < y_L) carry no interval observation for this
  # helper; they are excluded with a warning (TODO-109). y_R == y_L is an
  # exact event and is NOT unusable.
  extra_L <- c(NA_real_, -1, 2, 7)
  extra_R <- c(2, 1, NA_real_, 6)
  expect_warning(m <- EDI:::turnbull_npmle_group_stat(c(L, extra_L), c(R, extra_R), "median"), "excluded 4 row")
  expect_equal(m, 3.5)
  expect_warning(r <- EDI:::turnbull_npmle_group_stat(c(L, extra_L), c(R, extra_R), "restricted_mean"), "excluded 4 row")
  expect_equal(r, 3.6)
})

test_that("Turnbull statistics treat y_R == y_L as an exact event rather than dropping it", {
  skip_if_not_installed("interval")
  # Four exact events at 1, 2, 3, 4: the NPMLE is the empirical distribution.
  expect_equal(EDI:::turnbull_npmle_group_stat(1:4, 1:4, "median"), 2)
  expect_equal(EDI:::turnbull_npmle_group_stat(1:4, 1:4, "restricted_mean", tau = 4), 1 + 0.75 + 0.5 + 0.25)
})

test_that("unbounded Turnbull support produces unavailable finite group statistics", {
  skip_if_not_installed("interval")
  # No event is observed at all, so no median exists. The restricted mean
  # is the follow-up horizon, as for an all-censored Kaplan-Meier arm.
  expect_true(is.na(EDI:::turnbull_npmle_group_stat(c(1, 3, 5), rep(Inf, 3), "median")))
  expect_equal(EDI:::turnbull_npmle_group_stat(c(1, 3, 5), rep(Inf, 3), "restricted_mean"), 5)
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
    # Median shifts by 2. The restricted mean is truncated at the shared
    # horizon 6 (the control arm's follow-up), so the shifted arm's area is
    # 1*3 + 0.8*2 + 0.5*1 = 5.1 against 3.6: a difference of 1.5, not 2.
    expected <- if (stat == "median") 2 else 1.5
    expect_equal(EDI:::turnbull_npmle_stat_diff(lower, upper, w, stat), expected, tolerance = 1e-8)
    expect_equal(EDI:::turnbull_npmle_stat_diff(lower, upper, 1 - w, stat), -expected, tolerance = 1e-8)
    expect_true(is.na(EDI:::turnbull_npmle_stat_diff(lower, upper, rep(1, length(w)), stat)))
    if (stat == "median") {
      expect_true(is.na(EDI:::turnbull_npmle_stat_diff(c(L, L), c(R, rep(Inf, length(R))), w, stat)))
    }
  }
})
