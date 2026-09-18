library(testthat)
library(EDI)

test_that("mixed ZOIB fits separate beta densities and saturated endpoint probabilities", {
  X <- cbind(1, rep(0:1, each = 12))
  y <- c(0, 0, 1, .15, .28, .41, .52, .33, .61, .24, .45, .56,
         0, 1, 1, 1, .31, .44, .62, .73, .53, .68, .39, .57)
  interior <- which(y > 0 & y < 1)
  counts <- vapply(0:1, function(arm) {
    response <- y[X[, 2] == arm]
    c(sum(response == 0), sum(response == 1), sum(response > 0 & response < 1))
  }, numeric(3))
  gamma0 <- log(counts[1, ] / counts[3, ])
  gamma1 <- log(counts[2, ] / counts[3, ])
  expected_mixture <- c(gamma0[1], diff(gamma0), gamma1[1], diff(gamma1))
  beta_nll <- function(parameters) {
    mu <- plogis(drop(X[interior, ] %*% parameters[1:2]))
    phi <- exp(parameters[3])
    -sum(dbeta(y[interior], mu * phi, (1 - mu) * phi, log = TRUE))
  }
  nll <- function(parameters) {
    logits <- cbind(drop(X %*% parameters[4:5]), drop(X %*% parameters[6:7]), 0)
    probability <- exp(logits - apply(logits, 1, max))
    probability <- probability / rowSums(probability)
    category <- ifelse(y == 0, 1L, ifelse(y == 1, 2L, 3L))
    -sum(log(probability[cbind(seq_along(y), category)])) + beta_nll(parameters[1:3])
  }
  for (fixed_precision in c(FALSE, TRUE)) {
    reference <- if (fixed_precision) {
      optim(c(-.3, .7), function(beta) beta_nll(c(beta, log(6))),
            method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
    } else {
      optim(c(-.3, .7, log(8)), beta_nll, method = "BFGS",
            control = list(reltol = 1e-12, maxit = 2000L))
    }
    expect_identical(reference$convergence, 0L)
    expected <- c(reference$par, if (fixed_precision) log(6), expected_mixture)
    args <- list(X = X, X_zero_one = X, y = y)
    if (fixed_precision) {
      args$fixed_idx <- 3L
      args$fixed_values <- log(6)
    }
    actual <- do.call(EDI:::fast_zero_one_inflated_beta_cpp, args)
    parameters <- as.numeric(actual$params)
    expect_true(actual$converged)
    expect_equal(parameters, expected, tolerance = 5e-4)
    expect_lt(abs(nll(parameters) - nll(expected)), 1e-5)
    expect_equal(actual$neg_loglik, nll(parameters), tolerance = 1e-10)
    information <- optimHess(parameters, nll, control = list(ndeps = rep(1e-4, 7)))
    expect_equal(actual$observed_information, information, tolerance = 2e-5)
    expect_equal(actual$hessian, -information, tolerance = 2e-5)
    # The mixture and interior beta likelihoods have disjoint parameters.
    expect_equal(actual$observed_information[1:3, 4:7], matrix(0, 3L, 4L))
    free <- if (fixed_precision) setdiff(1:7, 3L) else 1:7
    expect_equal(actual$vcov[free, free], solve(information[free, free]), tolerance = 2e-5)
    if (fixed_precision) {
      expect_equal(parameters[3], log(6), tolerance = 1e-12)
      expect_true(all(is.na(actual$vcov[3, ])))
      expect_true(all(is.na(actual$vcov[, 3])))
    }
    warm_args <- args
    warm_args$warm_start_params <- expected
    warm_args$warm_start_fisher_info <- information
    warm <- do.call(EDI:::fast_zero_one_inflated_beta_cpp, warm_args)
    expect_equal(as.numeric(warm$params), expected, tolerance = 5e-4)
    expect_lt(abs(warm$neg_loglik - nll(expected)), 1e-5)
    estimate_args <- args
    estimate_args$estimate_only <- TRUE
    estimate_only <- do.call(EDI:::fast_zero_one_inflated_beta_cpp, estimate_args)
    expect_equal(as.numeric(estimate_only$params), expected, tolerance = 5e-4)
    expect_equal(estimate_only$neg_loglik, nll(as.numeric(estimate_only$params)), tolerance = 1e-10)
    expect_false(any(c("vcov", "observed_information", "hessian") %in% names(estimate_only)))
  }
})
