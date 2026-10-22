test_that("weighted_cox_bootstrap_surrogate_fit fast path matches the coxph() formula path", {
  fn = get("weighted_cox_bootstrap_surrogate_fit", envir = asNamespace("EDI"))
  set.seed(7)
  n = 120
  X = cbind(treatment = rbinom(n, 1, 0.5), x1 = rnorm(n), x2 = rnorm(n))
  time = round(rexp(n, exp(0.4 * X[, 1] + 0.3 * X[, 2])), 1) + 0.1  # ties
  dead = rbinom(n, 1, 0.8)
  w = as.numeric(rgamma(n, 1)); w = w / mean(w)
  fast = fn(time, dead, X, w)
  ref = suppressWarnings(survival::coxph(
    survival::Surv(time, dead) ~ treatment + x1 + x2,
    data = as.data.frame(X), weights = w))
  expect_equal(fast$beta_hat, unname(coef(ref)[["treatment"]]), tolerance = 1e-8)
  expect_equal(unname(fast$coefficients), unname(coef(ref)), tolerance = 1e-8)
  # warm start gives the same optimum
  fast_ws = fn(time, dead, X, w, warm_start_beta = coef(ref))
  expect_equal(fast_ws$beta_hat, fast$beta_hat, tolerance = 1e-8)
  # zero weights are dropped
  w0 = w; w0[1:10] = 0
  ref0 = suppressWarnings(survival::coxph(
    survival::Surv(time, dead) ~ treatment + x1 + x2,
    data = as.data.frame(X), weights = w0, subset = w0 > 0))
  expect_equal(fn(time, dead, X, w0)$beta_hat, unname(coef(ref0)[["treatment"]]), tolerance = 1e-8)
})

test_that("stratified fit still takes the formula path", {
  fn = get("weighted_cox_bootstrap_surrogate_fit", envir = asNamespace("EDI"))
  set.seed(8)
  n = 100
  X = cbind(treatment = rbinom(n, 1, 0.5), x1 = rnorm(n))
  time = rexp(n); dead = rbinom(n, 1, 0.8); w = rgamma(n, 1)
  st = rep(1:2, length.out = n)
  r = fn(time, dead, X, w, strata = st)
  expect_true(is.finite(r$beta_hat))
  expect_s3_class(r$fit, "coxph")
})
