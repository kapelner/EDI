library(testthat)
library(EDI)

test_that("a single matched pair supplies its mean but not a variance", {
  fit <- EDI:::compute_matching_reservoir_stats_cpp(7, c(2, 4, 9, 13), c(0, 0, 1, 1))
  expect_equal(fit$d_bar, 7)
  expect_true(is.na(fit$ssqD_bar))
  expect_equal(fit$r_bar, 8)
  expect_equal(fit$ssqR, (var(c(2, 4)) + var(c(9, 13))) / 2)
  expect_true(is.na(fit$w_star))
})

test_that("reservoir singleton arms retain a contrast without pooled variance", {
  for (w in list(c(0, 1), c(0, 0, 1), c(0, 1, 1))) {
    y <- seq_along(w)^2
    fit <- EDI:::compute_matching_reservoir_stats_cpp(c(2, 5), y, w)
    expect_equal(fit$r_bar, mean(y[w == 1]) - mean(y[w == 0]))
    expect_true(is.na(fit$ssqR))
    expect_true(is.na(fit$w_star))
  }
})

test_that("zero-variance components have the limiting inverse-variance weights", {
  zero_pair <- EDI:::compute_matching_reservoir_stats_cpp(c(4, 4, 4), c(1, 3, 8, 12), c(0, 0, 1, 1))
  expect_equal(zero_pair$w_star, 1)
  zero_reservoir <- EDI:::compute_matching_reservoir_stats_cpp(c(1, 3, 5), c(2, 2, 7, 7), c(0, 0, 1, 1))
  expect_equal(zero_reservoir$w_star, 0)
  both_zero <- EDI:::compute_matching_reservoir_stats_cpp(c(4, 4), c(2, 2, 7, 7), c(0, 0, 1, 1))
  expect_true(is.na(both_zero$w_star))
  expect_equal(both_zero$ssqR, 0)
  expect_equal(both_zero$ssqD_bar, 0)
})

test_that("unequal reservoir arms use pooled degrees of freedom and survive permutation", {
  d <- c(-3, 2, 8, 5)
  y <- c(1, 4, 9, 13, 2, 6, 10)
  w <- c(0, 1, 0, 1, 0, 1, 1)
  fit <- EDI:::compute_matching_reservoir_stats_cpp(d, y, w)
  pooled <- ((sum(w == 1) - 1) * var(y[w == 1]) +
             (sum(w == 0) - 1) * var(y[w == 0])) / (length(w) - 2)
  vr <- pooled * (1 / sum(w == 1) + 1 / sum(w == 0))
  expect_equal(fit$ssqR, vr)
  expect_equal(fit$w_star, vr / (vr + var(d) / length(d)))
  order <- c(7, 2, 5, 1, 4, 6, 3)
  expect_equal(EDI:::compute_matching_reservoir_stats_cpp(rev(d), y[order], w[order]), fit)
  empty <- EDI:::compute_matching_reservoir_stats_cpp(numeric(), numeric(), numeric())
  expect_true(all(is.na(unlist(empty[1:5]))))
  expect_identical(c(empty$nRT, empty$nRC), c(0L, 0L))
})
