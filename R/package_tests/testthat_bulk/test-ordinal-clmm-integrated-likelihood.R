library(testthat)
library(EDI)

# TODO-3: validate link probabilities and random-intercept integration independently.
test_that("constrained ordinal CLMM likelihood equals direct normal integration", {
  X <- matrix(c(-1, 0, 1, -0.5, 0.5, 1.5), ncol = 1)
  y <- c(1L, 2L, 3L, 1L, 2L, 3L)
  groups <- rep(1:3, each = 2)
  sigma <- 0.7
  raw_thresholds <- c(-0.6, log(1.3))
  thresholds <- c(-Inf, -0.6, 0.7, Inf)
  cdfs <- list(logit = plogis, probit = pnorm, cauchit = pcauchy,
               cloglog = function(z) -expm1(-exp(z)))
  for (link in names(cdfs)) {
    fit <- EDI:::fast_ordinal_clmm_cpp(
      X, y, groups, K = 3L, j_T = 0L, link = link, estimate_only = FALSE,
      n_gh = 40L, maxit = 100L, eps_g = 1e-8,
      warm_start_params = c(raw_thresholds, 0.4, log(sigma)),
      fixed_idx = c(1L, 2L, 4L), fixed_values = c(raw_thresholds, log(sigma)))
    cdf <- cdfs[[link]]
    reference_neg_ll <- function(b) {
      group_prob <- vapply(unique(groups), function(g) {
        rows <- which(groups == g)
        integrand <- function(z) {
          joint <- rep(1, length(z))
          for (i in rows) {
            eta <- X[i, 1] * b + sigma * z
            joint <- joint * (cdf(thresholds[y[i] + 1L] - eta) - cdf(thresholds[y[i]] - eta))
          }
          joint * dnorm(z)
        }
        integrate(integrand, -Inf, Inf, rel.tol = 1e-10)$value
      }, numeric(1))
      -sum(log(group_prob))
    }
    expect_true(fit$converged)
    expect_equal(fit$alpha, raw_thresholds, tolerance = 1e-12)
    expect_equal(fit$log_sigma, log(sigma), tolerance = 1e-12)
    expect_equal(fit$neg_loglik, reference_neg_ll(fit$b[1]), tolerance = 2e-6)
    expect_true(is.finite(fit$ssq_b_T) && fit$ssq_b_T > 0)
    h <- 1e-4
    ll_minus <- reference_neg_ll(fit$b[1] - h)
    ll_center <- reference_neg_ll(fit$b[1])
    ll_plus <- reference_neg_ll(fit$b[1] + h)
    # With only beta free, its variance is the reciprocal marginal curvature.
    expect_equal(fit$ssq_b_T, h^2 / (ll_plus - 2 * ll_center + ll_minus), tolerance = 2e-4)
    expect_lt(abs((ll_plus - ll_minus) / (2 * h)), 2e-5)
  }
})
