library(testthat)
library(EDI)

test_that("bootstrap percentile and basic intervals follow their definitions", {
  draws <- 1:20
  alpha <- 0.1
  percentile <- EDI:::bootstrap_ci_from_distribution(draws, alpha, "PERCENTILE")
  expect_equal(percentile, quantile(draws, c(0.05, 0.95), names = FALSE, type = 8))
  expect_error(EDI:::bootstrap_ci_from_distribution(draws, alpha, "basic"), "require an estimate")
  basic <- EDI:::bootstrap_ci_from_distribution(draws, alpha, "basic", est = 7)
  expect_equal(basic, 14 - quantile(draws, c(0.95, 0.05), names = FALSE, type = 8))
})

test_that("studentized bootstrap filters unstable standard errors", {
  theta <- seq(-0.9, 0.9, length.out = 20)
  se <- rep(0.2, 20)
  pivots <- EDI:::bootstrap_studentized_pivots(theta, se, est = 0, se_hat = 0.2)
  expect_equal(pivots, theta / se)
  expect_error(EDI:::bootstrap_studentized_pivots(theta, rep(0, 20), 0, 0.2), "positive")
  expect_error(EDI:::bootstrap_studentized_pivots(theta, c(rep(NA, 15), rep(0.2, 5)), 0, 0.2), "too few")

  boot <- list(theta = theta, se = se)
  ci <- EDI:::bootstrap_ci_studentized(boot, 0.05, est = 0, se_hat = 0.2)
  sym <- EDI:::bootstrap_ci_symmetric_studentized(boot, 0.05, est = 0, se_hat = 0.2)
  expect_lt(ci[1], ci[2])
  expect_equal(sym[1], -sym[2])
  expect_false(EDI:::bootstrap_studentized_interval_scale_unstable(theta[1:4], ci = c(-100, 100)))
  expect_true(EDI:::bootstrap_studentized_interval_scale_unstable(theta, ci = c(-100, 100)))
})

test_that("optimizer normalization and beta-response sanitization cover boundary contracts", {
  expect_identical(EDI:::.normalize_optimizer_algorithm(NULL), "lbfgs")
  expect_identical(EDI:::.normalize_optimizer_algorithm(NULL, allow_irls = TRUE), "irls")
  expect_identical(EDI:::.normalize_optimizer_algorithm("newton"), "newton_raphson")
  expect_error(EDI:::.normalize_optimizer_algorithm("irls"), "should be one of")

  y <- EDI:::sanitize_beta_response(c(0, 0.5, 1))
  expect_true(all(y > 0 & y < 1))
  expect_equal(EDI:::sanitize_beta_response(0), .Machine$double.eps)
  expect_error(EDI:::sanitize_beta_response(c(0.2, Inf)), "finite")
})

make_count_mixture_design <- function(seed = 20260919L, n = 64L) {
  set.seed(seed)
  x <- rnorm(n)
  des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", seed = seed)
  for (i in seq_len(n)) {
    w <- des$add_one_subject_to_experiment_and_assign(data.frame(x = x[i]))
    structural <- runif(1) < plogis(-0.8 - 0.2 * w + 0.15 * x[i])
    y <- if (structural) 0L else rpois(1, exp(0.5 + 0.35 * w + 0.2 * x[i]))
    des$add_one_subject_response(i, y)
  }
  des
}

test_that("hurdle and zero-inflated Poisson estimands switch without stale cache values", {
  des <- make_count_mixture_design()
  for (generator in list(InferenceCountHurdlePoisson, InferenceCountZeroInflatedPoisson)) {
    inf <- generator$new(des, model_formula = ~ x, use_rcpp = TRUE)
    conditional <- inf$compute_estimate()
    expect_true(is.finite(conditional))
    expect_setequal(inf$get_supported_estimands(),
                    c("conditional", "marginal_mean_diff", "marginal_ratio"))

    inf$set_estimand("marginal_mean_diff")
    marginal <- inf$compute_estimate(estimate_only = TRUE)
    expect_true(is.finite(marginal))
    inf$set_estimand("conditional")
    expect_equal(inf$compute_estimate(estimate_only = TRUE), conditional, tolerance = 1e-10)
    expect_error(inf$set_estimand("unsupported"), "supported|estimand")
  }
})

test_that("composite count likelihood exposes only Wald asymptotic tests", {
  des <- make_count_mixture_design(seed = 20260920L, n = 48L)
  for (generator in list(InferenceCountQuasiPoisson, InferenceCountRobustPoisson)) {
    inf <- generator$new(des, model_formula = ~ x)
    expect_identical(inf$get_supported_testing_types(), "wald")
    expect_error(inf$set_testing_type("score"), "supported|testing")
    expect_error(inf$set_testing_type("gradient"), "supported|testing")
    expect_error(inf$set_testing_type("lik_ratio"), "supported|testing")
  }
})

test_that("KK combined count constructor validates formula and backend flag early", {
  expect_error(InferenceCountKKGLMM$new(NULL, model_formula = 2), "formula")
  expect_error(InferenceCountKKGLMM$new(NULL, use_rcpp = NA), "May not be NA")
})
