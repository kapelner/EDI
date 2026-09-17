library(testthat)
library(EDI)

# TODO-3: compare the count-recursion distribution with all individual allocations.
test_that("exact ordinal tails equal exhaustive allocation probabilities", {
  stat2_reference <- function(y, treated) {
    comparison <- outer(y[treated], y[-treated], "-")
    sum(2L * (comparison > 0) + (comparison == 0))
  }
  # Different sizes and tie patterns also exercise reuse of thread-local buffers.
  fixtures <- list(
    list(y = c(-4L, -4L, 2L, 9L, 9L, 15L, 20L), treated = c(2L, 6L)),
    list(y = rep(3L, 4L), treated = 1L),
    list(y = c(1L, 2L, 3L, 4L, 5L, 6L), treated = c(4L, 5L, 6L)),
    list(y = c(-4L, -4L, 2L, 9L, 9L, 15L, 20L), treated = c(2L, 6L))
  )
  for (fixture in fixtures) {
    y <- fixture$y
    treated <- fixture$treated
    assignments <- combn(seq_along(y), length(treated), simplify = FALSE)
    distribution <- vapply(assignments, function(idx) stat2_reference(y, idx), numeric(1))
    observed <- stat2_reference(y, treated)
    w <- integer(length(y))
    w[treated] <- 1L
    got <- EDI:::exact_jonckheere_terpstra_pval_cpp(y, w)
    lower <- mean(distribution <= observed)
    upper <- mean(distribution >= observed)
    expect_equal(got$stat2, observed)
    expect_equal(got$n_treat, length(treated))
    expect_equal(got$n_control, length(y) - length(treated))
    expect_equal(got$superiority, observed / (2 * length(treated) * (length(y) - length(treated))))
    expect_equal(got$p_lower, lower, tolerance = 1e-12)
    expect_equal(got$p_upper, upper, tolerance = 1e-12)
    expect_equal(got$p_exact, min(1, 2 * min(lower, upper)), tolerance = 1e-12)
  }
})

test_that("exact ordinal distribution rejects missing responses and assignments", {
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(c(NA_integer_, 2L), c(0L, 1L)),
               "missing values")
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(c(1L, 2L), c(0L, NA_integer_)),
               "missing values")
})
