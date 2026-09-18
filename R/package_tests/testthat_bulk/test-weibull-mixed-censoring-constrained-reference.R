library(testthat)
library(EDI)

test_that("constrained mixed-censoring Weibull fits match independent densities and probabilities", {
  X <- cbind(1, rep(0:1, each = 12))
  times <- rep(c(.35, .7, 1.2, 2.1, .55, 1.4, 2.8, .9, 1.8, .45, 3.2, 1.1), 2) *
    exp(.3 * X[, 2])
  censoring <- rep(1:4, 6)
  exact <- censoring == 1L
  y <- ifelse(exact, times, NA_real_)
  lower <- ifelse(exact, NA_real_, ifelse(censoring == 2L, 0, times))
  upper <- ifelse(exact, NA_real_, ifelse(censoring == 3L, Inf, 1.5 * times))
  nll <- function(parameters) {
    scale <- exp(drop(X %*% parameters[1:2]))
    shape <- exp(-parameters[3])
    exact_ll <- dweibull(y[exact], shape, scale[exact], log = TRUE)
    # Censored contributions are P(L < T <= R), including zero and Inf.
    probability <- pweibull(upper[!exact], shape, scale[!exact]) -
      pweibull(lower[!exact], shape, scale[!exact])
    -sum(exact_ll) - sum(log(probability))
  }
  constraints <- list(list(index = integer(), value = numeric()),
                      list(index = 2L, value = .15),
                      list(index = 3L, value = log(.8)))
  for (constraint in constraints) {
    free <- setdiff(1:3, constraint$index)
    expand <- function(values) {
      parameters <- numeric(3)
      parameters[free] <- values
      parameters[constraint$index] <- constraint$value
      parameters
    }
    reference <- optim(c(.5, .3, log(.8))[free], function(z) nll(expand(z)),
                       method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
    expect_identical(reference$convergence, 0L)
    expected <- expand(reference$par)
    args <- list(X = X, y = y, y_L = lower, y_R = upper, maxit = 1000L, tol = 1e-10)
    if (length(constraint$index)) {
      args$fixed_idx <- constraint$index
      args$fixed_values <- constraint$value
    }
    actual <- do.call(EDI:::fast_weibull_regression_general_cpp, args)
    parameters <- as.numeric(actual$params)
    expect_true(actual$converged)
    expect_equal(parameters, expected, tolerance = 1e-4)
    expect_lt(abs(actual$neg_loglik - reference$value), 1e-7)
    expect_equal(actual$neg_loglik, nll(parameters), tolerance = 1e-10)
    expect_equal(actual$loglik, -nll(parameters), tolerance = 1e-10)
    information <- optimHess(parameters, nll, control = list(ndeps = rep(1e-4, 3)))
    expect_equal(actual$observed_information, information, tolerance = 3e-5)
    expect_equal(actual$hessian, -information, tolerance = 3e-5)
    expect_equal(actual$vcov[free, free], solve(information[free, free, drop = FALSE]),
                 tolerance = 3e-5)
    if (length(constraint$index)) {
      expect_equal(parameters[constraint$index], constraint$value, tolerance = 1e-12)
      expect_true(all(is.na(actual$vcov[constraint$index, ])))
      expect_true(all(is.na(actual$vcov[, constraint$index])))
    }
    warm_args <- args
    warm_args$warm_start_params <- expected
    warm_args$warm_start_fisher_info <- information
    warm <- do.call(EDI:::fast_weibull_regression_general_cpp, warm_args)
    expect_equal(as.numeric(warm$params), expected, tolerance = 1e-4)
    expect_equal(warm$neg_loglik, reference$value, tolerance = 1e-8)
    estimate_args <- warm_args
    estimate_args$estimate_only <- TRUE
    estimate_only <- do.call(EDI:::fast_weibull_regression_general_cpp, estimate_args)
    expect_equal(c(estimate_only$b, estimate_only$log_sigma), expected, tolerance = 1e-4)
    expect_false(any(c("vcov", "observed_information", "score", "hessian") %in%
                       names(estimate_only)))

    # An observation censored over the entire support has probability one
    # and contributes no likelihood, score, or information, regardless of X.
    neutral_args <- warm_args
    neutral_args$X <- rbind(X, c(1, -2), c(1, 3))
    neutral_args$y <- c(y, NA_real_, NA_real_)
    neutral_args$y_L <- c(lower, 0, 0)
    neutral_args$y_R <- c(upper, Inf, Inf)
    neutral <- do.call(EDI:::fast_weibull_regression_general_cpp, neutral_args)
    expect_equal(as.numeric(neutral$params), expected, tolerance = 1e-4)
    expect_equal(neutral$neg_loglik, warm$neg_loglik, tolerance = 1e-10)
    expect_equal(neutral$observed_information, warm$observed_information, tolerance = 1e-8)
  }
})
