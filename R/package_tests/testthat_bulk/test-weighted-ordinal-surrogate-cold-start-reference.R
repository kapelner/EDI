library(testthat)
library(EDI)

test_that("cold weighted ordinal surrogates fit the requested cumulative link", {
  skip_if_not_installed("ordinal")
  # The two empirical CDFs differ by a common log(3) shift on the logit scale.
  y <- c(rep(1:3, c(5, 10, 5)), rep(1:3, c(2, 8, 10)))
  treatment <- rep(c(0, 1), each = 20L)
  weights <- rep(c(2, 3), each = 20L)
  X <- matrix(treatment, ncol = 1L, dimnames = list(NULL, "treatment"))
  for (method in c("logistic", "probit", "cauchit", "cloglog")) {
    reference <- ordinal::clm(ordered(y) ~ treatment, weights = weights,
                              link = if (method == "logistic") "logit" else method,
                              control = ordinal::clm.control(gradTol = 1e-8))
    reference_beta <- unname(stats::coef(reference)["treatment"])
    if (method == "cauchit") {
      # MASS caps endpoint arguments at +/-100. Cauchy tail mass there is
      # appreciable, so compare to that backend's actual likelihood convention.
      nll <- function(par) {
        thresholds <- c(-Inf, par[2L], par[2L] + exp(par[3L]), Inf)
        eta <- par[1L] * treatment
        probabilities <- pcauchy(pmin(100, thresholds[y + 1L] - eta)) -
          pcauchy(pmax(-100, thresholds[y] - eta))
        -sum(weights * log(probabilities))
      }
      start <- c(reference_beta, reference$alpha[1L], log(diff(reference$alpha)))
      reference_beta <- stats::optim(start, nll, method = "BFGS",
        control = list(reltol = 1e-12, maxit = 1000L))$par[1L]
    }
    fit <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, weights, method = method)
    expect_identical(fit$fit_type, paste0("polr_", method))
    expect_equal(fit$beta_hat, unname(reference_beta), tolerance = 5e-4)
    scaled_fit <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, 5 * weights, method = method)
    expect_identical(scaled_fit$fit_type, paste0("polr_", method))
    expect_equal(scaled_fit$beta_hat, fit$beta_hat, tolerance = 1e-10)
  }
})

test_that("a rejected ordinal warm start retries a real cold fit", {
  y <- c(rep(1:3, c(5, 10, 5)), rep(1:3, c(2, 8, 10)))
  X <- matrix(rep(c(0, 1), each = 20L), ncol = 1L,
               dimnames = list(NULL, "treatment"))
  weights <- rep(c(2, 3), each = 20L)
  # Finite ordered thresholds can still produce an unusable starting likelihood.
  fit <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, weights,
    method = "logistic", warm_start_params = c(1000, 1001, 0))
  expect_identical(fit$fit_type, "polr_logistic")
  expect_equal(fit$beta_hat, log(3), tolerance = 5e-4)
  warm_fit <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, weights,
    method = "logistic", warm_start_params = c(-log(3), log(3), log(3)))
  expect_identical(warm_fit$fit_type, "polr_logistic")
  expect_equal(warm_fit$beta_hat, log(3), tolerance = 1e-5)
})

test_that("ordinal surrogates retain the linear fallback when polr cannot fit", {
  X <- matrix(rep(c(0, 1), each = 4L), ncol = 1L,
               dimnames = list(NULL, "treatment"))
  # polr requires at least three levels; this reachable two-level fit uses the
  # documented weighted linear surrogate, with an empirical mean shift of 0.5.
  y <- c(1, 1, 1, 2, 1, 2, 2, 2)
  fit <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, rep(1, 8L))
  expect_identical(fit$fit_type, "weighted_lm_surrogate")
  expect_equal(fit$beta_hat, 0.5, tolerance = 1e-12)
  expect_null(EDI:::weighted_ordinal_bootstrap_surrogate_fit(X, y, rep(0, 8L)))
})
