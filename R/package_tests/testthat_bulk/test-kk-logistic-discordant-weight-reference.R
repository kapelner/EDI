library(testthat)
library(EDI)

kk_logistic_discordant_fixture <- function(reservoir) {
  withr::local_seed(715)
  if (reservoir) {
    n <- 37L
    des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
    for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
    y <- as.integer(seq_len(n) %% 4 %in% c(0, 1))
  } else {
    n <- 12L
    des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence",
                                     m = rep(c(6L, 1L, 5L, 2L, 4L, 3L), each = 2), verbose = FALSE)
    des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
    des$overwrite_all_subject_assignments(rep(c(0, 1), 6))
    y <- c(0, 0, 0, 1, 1, 1, 1, 0, 0, 1, 1, 0)
  }
  des$add_all_subject_responses(y)
  inf <- InferenceIncidKKCondLogitOneLik$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  if (reservoir) {
    # Pair identifiers need not follow completion order. Relabel an otherwise
    # unchanged realized KK structure to exercise alignment independently.
    matched <- is.finite(private$m) & private$m > 0
    private$m[matched] <- max(private$m[matched]) + 1L - private$m[matched]
  }
  context <- private$build_bayesian_bootstrap_context()
  private$current_bayesian_bootstrap_context <- context
  list(inf = inf, context = context, m = private$m, w = des$get_w(), y = y)
}

kk_logistic_discordant_reference <- function(fixture, weights) {
  pair_ids <- unique(fixture$m[is.finite(fixture$m) & fixture$m > 0])
  pairs <- lapply(pair_ids, function(pid) which(fixture$m == pid))
  pairs <- Filter(function(idx) fixture$y[idx[1]] != fixture$y[idx[2]], pairs)
  singles <- which(!is.finite(fixture$m) | fixture$m <= 0)
  outcome <- c(vapply(pairs, function(idx) fixture$y[idx[fixture$w[idx] == 1]], numeric(1)),
               fixture$y[singles])
  Z <- if (length(singles)) {
    rbind(cbind(0, rep(1, length(pairs))), cbind(1, fixture$w[singles]))
  } else matrix(1, nrow = length(pairs), ncol = 1)
  fit_weights <- c(vapply(pairs, function(idx) weights[fixture$context$row_to_unit[idx[1]]], numeric(1)),
                   weights[fixture$context$row_to_unit[singles]])
  keep <- fit_weights > 0
  Z <- Z[keep, , drop = FALSE]; outcome <- outcome[keep]; fit_weights <- fit_weights[keep]
  fit <- suppressWarnings(glm.fit(Z, outcome, weights = fit_weights, family = binomial(),
                                 control = glm.control(epsilon = 1e-12, maxit = 100)))
  j <- ncol(Z)
  information <- crossprod(Z, Z * (fit_weights * fit$fitted.values * (1 - fit$fitted.values)))
  loss <- function(beta) {
    evaluate <- function(intercept) -sum(fit_weights * dbinom(outcome, 1,
      plogis(if (j == 1L) rep(beta, nrow(Z)) else Z[, 1] * intercept + Z[, 2] * beta), log = TRUE))
    if (j == 1L) evaluate(0) else optimize(evaluate, c(-10, 10), tol = 1e-10)$objective
  }
  list(estimate = unname(fit$coefficients[j]), se = sqrt(solve(information)[j, j]), loss = loss)
}

test_that("KK logistic weights follow discordant rows despite concordance and pair-id order", {
  for (reservoir in c(FALSE, TRUE)) {
    for (scale in c(1, 3, 1e-12, 1e-200)) {
      fixture <- kk_logistic_discordant_fixture(reservoir)
      weights <- rep(c(1, 2, 4, 7), length.out = fixture$context$n_units)
      expected <- kk_logistic_discordant_reference(fixture, weights)
      actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights)
      expect_equal(actual, expected$estimate, tolerance = 1e-6)
      expect_equal(fixture$inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T * sqrt(scale),
                   expected$se, tolerance = 1e-6)
    }
  }
})

test_that("KK logistic omitted units and empty draws preserve estimate and uncertainty contracts", {
  for (reservoir in c(FALSE, TRUE)) {
    fixture <- kk_logistic_discordant_fixture(reservoir)
    weights <- rep(c(1, 2, 4, 7), length.out = fixture$context$n_units)
    weights[2] <- 0
    expected <- kk_logistic_discordant_reference(fixture, weights)
    expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE),
                 expected$estimate, tolerance = 1e-6)
    private <- fixture$inf$.__enclos_env__$private
    expect_true(is.na(private$last_weighted_refit$s_beta_hat_T))
    expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(0 * weights)))
    expect_true(is.na(private$last_weighted_refit$beta_hat_T))
    expect_true(is.na(private$last_weighted_refit$s_beta_hat_T))
  }
})

test_that("KK logistic Fisher warm starts retain weighted uncertainty across scale changes", {
  fixture <- kk_logistic_discordant_fixture(TRUE)
  for (iteration in seq_len(3)) {
    scale <- c(1, 1e-200, 2)[iteration]
    weights <- rep(c(1, 2, 4, 7) + iteration, length.out = fixture$context$n_units)
    expected <- kk_logistic_discordant_reference(fixture, weights)
    actual <- fixture$inf$compute_estimate_with_bootstrap_weights(scale * weights)
    expect_equal(actual, expected$estimate, tolerance = 1e-5)
    expect_lt(expected$loss(actual) - expected$loss(expected$estimate), 1e-8)
    expect_equal(fixture$inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T * sqrt(scale),
                 expected$se, tolerance = 1e-6)
  }
})
