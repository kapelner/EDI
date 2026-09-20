library(testthat)
library(EDI)

kk_poisson_profile_fixture <- function() {
  withr::local_seed(715)
  n <- 37L
  des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
  for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
  w <- des$get_w()
  y <- 1 + seq_len(n) %% 7 + 2 * w
  des$add_all_subject_responses(y)
  inf <- InferenceCountKKCondPoissonOneLik$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  context <- private$build_bayesian_bootstrap_context()
  private$current_bayesian_bootstrap_context <- context
  list(inf = inf, context = context, w = w, y = y)
}

kk_poisson_profile_reference <- function(fixture, weights) {
  units <- split(seq_along(fixture$y), fixture$context$row_to_unit)
  pairs <- units[lengths(units) == 2L]
  singles <- unlist(units[lengths(units) == 1L], use.names = FALSE)
  pair_weight <- weights[as.integer(names(pairs))]
  total <- vapply(pairs, function(idx) sum(fixture$y[idx]), numeric(1))
  treated <- vapply(pairs, function(idx) fixture$y[idx[fixture$w[idx] == 1]], numeric(1))
  single_weight <- weights[fixture$context$row_to_unit[singles]]
  # Profile the reservoir intercept analytically, then minimize the conditional
  # binomial pair likelihood plus independent reservoir Poisson likelihood.
  loss <- function(beta) {
    intercept <- log(sum(single_weight * fixture$y[singles]) /
                       sum(single_weight * exp(beta * fixture$w[singles])))
    -sum(pair_weight * dbinom(treated, total, plogis(beta), log = TRUE)) -
      sum(single_weight * dpois(fixture$y[singles],
                                exp(intercept + beta * fixture$w[singles]), log = TRUE))
  }
  list(estimate = optimize(loss, c(-5, 5), tol = 1e-10)$minimum, loss = loss)
}

test_that("KK count bootstrap estimates match independently profiled mixed likelihoods", {
  for (omit_units in c(FALSE, TRUE)) {
    fixture <- kk_poisson_profile_fixture()
    weights <- rep(c(1, 2, 4, 7), length.out = fixture$context$n_units)
    if (omit_units) weights[c(1, 3, 5)] <- 0
    expected <- kk_poisson_profile_reference(fixture, weights)
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
    expect_equal(actual, expected$estimate, tolerance = 5e-5)
    expect_lt(expected$loss(actual) - expected$loss(expected$estimate), 1e-7)
    expect_true(is.na(fixture$inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
  }
})

test_that("fresh KK count bootstrap fits preserve relative weights at tiny scales", {
  for (scale in c(1e-12, 1e-200)) {
    fixture <- kk_poisson_profile_fixture()
    weights <- rep(c(1, 2, 4, 7), length.out = fixture$context$n_units)
    expected <- kk_poisson_profile_reference(fixture, weights)
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights,
                                                                  estimate_only = TRUE)
    expect_equal(actual, expected$estimate, tolerance = 5e-5)
    expect_lt(expected$loss(actual) - expected$loss(expected$estimate), 1e-7)
  }
})

test_that("empty KK count bootstrap draws cannot reuse a warm fitted treatment effect", {
  fixture <- kk_poisson_profile_fixture()
  weights <- rep(c(1, 2, 4, 7), length.out = fixture$context$n_units)
  expect_true(is.finite(fixture$inf$compute_estimate_with_bootstrap_weights(weights)))
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
  private <- fixture$inf$.__enclos_env__$private
  expect_true(is.na(private$last_weighted_refit$beta_hat_T))
  expect_true(is.na(private$last_weighted_refit$s_beta_hat_T))
})

test_that("positive uniform KK count draws retain the unweighted mixed-likelihood estimate", {
  for (scale in c(1e-200, 1e200)) {
    fixture <- kk_poisson_profile_fixture()
    weights <- rep(1, fixture$context$n_units)
    expected <- kk_poisson_profile_reference(fixture, weights)
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights,
                                                                estimate_only = TRUE)
    expect_equal(actual, expected$estimate, tolerance = 5e-5)
    expect_true(is.na(fixture$inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
  }
})
