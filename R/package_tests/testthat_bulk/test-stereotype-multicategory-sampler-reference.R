library(testthat)
library(EDI)

stereotype_sampler_fixture <- function() {
  list(y = c(rep(seq_len(5L), each = 20L),
             rep(seq_len(5L), c(8L, 12L, 18L, 27L, 40L))),
       w = c(rep(0L, 100L), rep(1L, 105L)))
}

# Independent ordered-score multinomial likelihood, fitted without native
# EDI score, Hessian, or fitting routines. Both arms observe every category.
stereotype_sampler_reference <- function(y, w) {
  category <- match(y, sort(unique(y)))
  K <- max(category)
  counts <- table(factor(w, levels = 0:1), factor(category, levels = seq_len(K)))
  nll <- function(par) {
    increments <- c(par[(K + 1L):(2L * K - 2L)], 0)
    increments <- exp(increments - max(increments))
    score <- c(0, cumsum(increments / sum(increments)))
    eta <- rbind(c(0, par[seq_len(K - 1L)]),
                 c(0, par[seq_len(K - 1L)]) + par[K] * score)
    row_max <- apply(eta, 1L, max)
    log_probability <- eta - row_max - log(rowSums(exp(eta - row_max)))
    -sum(counts * log_probability)
  }
  pooled <- colSums(counts)
  start <- c(log(pooled[-1L] / pooled[1L]), 0, rep(0, K - 2L))
  fit <- optim(start, nll, method = "BFGS",
               control = list(maxit = 5000L, reltol = 1e-13))
  list(beta = unname(fit$par[K]), convergence = fit$convergence,
       nll = fit$value)
}

test_that("independent five-category reference has an interior identifiable fit", {
  dat <- stereotype_sampler_fixture()
  reference <- stereotype_sampler_reference(dat$y, dat$w)
  expect_identical(reference$convergence, 0L)
  # The endpoint arm odds ratio identifies beta exactly in this saturated
  # treatment-only fixture; the interior ratios increase strictly.
  expect_equal(reference$beta, log(5), tolerance = 1e-4)
  expect_true(is.finite(reference$nll))
})

test_that("stereotype sampler optimizes five-category shifted outcomes", {
  dat <- stereotype_sampler_fixture()
  reference <- stereotype_sampler_reference(dat$y, dat$w)$beta
  raw_y <- dat$y - 0.5 * dat$w
  expect_length(unique(raw_y), 10L)
  X <- matrix(numeric(), length(raw_y), 0L)
  draws <- cbind(dat$w, dat$w)
  for (cores in c(1L, 2L)) {
    actual <- EDI:::compute_stereotype_logit_distr_parallel_cpp(
      X, raw_y, draws, 0.5, cores)
    expect_true(all(is.finite(actual)))
    expect_equal(as.numeric(actual), rep(reference, 2L), tolerance = 5e-4)
  }
  order <- rev(seq_along(raw_y))
  permuted <- EDI:::compute_stereotype_logit_distr_parallel_cpp(
    X[order, , drop = FALSE], raw_y[order], draws[order, , drop = FALSE], 0.5, 1L)
  expect_equal(as.numeric(permuted), rep(reference, 2L), tolerance = 5e-4)
})

test_that("five-category stereotype draw coefficients reverse with treatment", {
  dat <- stereotype_sampler_fixture()
  draws <- cbind(dat$w, 1L - dat$w)
  expected <- apply(draws, 2L, function(w) stereotype_sampler_reference(dat$y, w)$beta)
  actual <- EDI:::compute_stereotype_logit_distr_parallel_cpp(
    matrix(numeric(), length(dat$y), 0L), dat$y, draws, 0, 1L)
  expect_equal(expected, c(log(5), -log(5)), tolerance = 1e-4)
  expect_equal(as.numeric(actual), expected, tolerance = 5e-4)
})
