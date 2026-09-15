library(testthat)
library(EDI)

test_that("central gradient and marginal delta method match analytic results", {
  f <- function(theta) theta[1]^2 + 3 * theta[2]
  theta <- c(2, -1)
  grad <- EDI:::numerical_gradient_central(f, theta)
  expect_equal(grad, c(4, 3), tolerance = 1e-7)

  V <- matrix(c(0.25, 0.05, 0.05, 0.16), 2)
  got <- EDI:::marginal_estimand_delta_se(theta, V, f)
  expect_equal(got$estimate, f(theta))
  expect_equal(got$gradient, c(4, 3), tolerance = 1e-7)
  expect_equal(got$se, sqrt(drop(t(c(4, 3)) %*% V %*% c(4, 3))), tolerance = 1e-7)
})

test_that("marginal delta method returns diagnostic NA for invalid inputs", {
  bad_dim <- EDI:::marginal_estimand_delta_se(c(1, 2), diag(3), sum)
  expect_true(is.na(bad_dim$se))
  expect_true(all(is.na(bad_dim$gradient)))

  bad_function <- EDI:::marginal_estimand_delta_se(c(1, 2), diag(2), function(x) stop("boom"))
  expect_true(is.na(bad_function$estimate))
  expect_true(is.na(bad_function$se))
})

test_that("ZOIB response and softmax helpers respect boundaries and normalization", {
  expect_equal(EDI:::.sanitize_proportion_response(c(-1, 0.2, 2)), c(0, 0.2, 1))
  interior <- EDI:::.sanitize_proportion_response(c(0, 1), interior = TRUE)
  expect_true(all(interior > 0 & interior < 1))
  expect_length(EDI:::.sanitize_proportion_response(numeric()), 0L)

  probs <- EDI:::.softmax_three_from_logits(1000, 999)
  expect_true(all(is.finite(probs)))
  expect_equal(sum(probs), 1, tolerance = 1e-14)
  expect_true(all(probs >= 0 & probs <= 1))
})

test_that("ZOIB likelihood separates endpoint masses and beta interior", {
  X <- cbind(1, c(-1, 0, 1))
  y <- c(0.2, 0.5, 0.8)
  par <- c(0.1, -0.2, log(6), log(0.2), log(0.3))
  got <- EDI:::.neg_loglik_zoib(par, 2L, c(TRUE, FALSE, FALSE),
                                c(FALSE, TRUE, FALSE), y, X)
  expect_true(is.finite(got))

  expect_error(EDI:::.fit_zero_one_inflated_beta(c(0.2, 0.4), matrix(1, 3, 1)),
               "matching row counts")
  expect_error(EDI:::.fit_zero_one_inflated_beta(c(-0.1, 0.4), matrix(1, 2, 1)),
               "y in \\[0, 1\\]")
  expect_null(EDI:::.fit_zero_one_inflated_beta(c(0, 1), matrix(c(0, 1), 2, 1)))
})

test_that("survival math helpers remain finite at extreme times", {
  terms <- EDI:::.weibull_aft_margin_terms(c(0, 1, 1e300), c(0, 0, 0), 1)
  expect_true(all(is.finite(terms$H)))
  expect_true(all(is.finite(terms$log_f)))
  expect_equal(terms$H[2], 1)

  log_a <- EDI:::.clayton_copula_logA(c(1, 1e100), c(2, 2e100), 2)
  expect_true(all(is.finite(log_a)))
  expect_equal(log_a[1], log(exp(2) + exp(4) - 1), tolerance = 1e-12)
})

test_that("survival fit helpers reject uninformative and mismatched inputs", {
  X <- cbind(w = c(0, 1, 0))
  expect_null(EDI:::.fit_standard_weibull_aft_from_matrix(c(1, 2, 3), c(0, 0, 0), X))
  expect_error(EDI:::.fit_dep_cens_transform_model(c(1, 2), c(1, 0, 1), X),
               "matching row counts")
  expect_null(EDI:::.fit_dep_cens_transform_model(c(1, 2, 3), c(1, 1, 1), X))
})

test_that("robust survival regression handles collinear predictors", {
  skip_if_not_installed("survival")
  set.seed(20260918)
  n <- 45L
  x <- rnorm(n)
  y <- exp(1 + 0.3 * x + rnorm(n, sd = 0.35))
  dead <- rep(c(1, 1, 0), length.out = n)
  fit <- robust_survreg(y, dead, cbind(x = x, duplicate = x), num_max_iter = 2)
  expect_s3_class(fit, "survreg")
  expect_true(all(is.finite(coef(fit))))
})

test_that("lean GLM summary preserves coefficient inference", {
  fit <- glm(am ~ wt + hp, data = mtcars, family = binomial())
  lean <- EDI:::summary_glm_lean(fit)
  reference <- summary(fit)
  expect_equal(lean$coefficients, reference$coefficients, tolerance = 1e-12)
  expect_equal(lean$dispersion, reference$dispersion)
  expect_identical(lean$df.residual, reference$df.residual)
})

test_that("Turnbull helpers handle insufficient groups and compute contrasts", {
  expect_true(is.na(EDI:::turnbull_npmle_group_stat(c(1, NA), c(2, 3))))
  expect_true(is.na(EDI:::turnbull_npmle_stat_diff(c(1, 2), c(2, 3), c(1, 1))))
  skip_if_not_installed("interval")
  L <- c(1, 2, 3, 4, 2, 3, 4, 5)
  R <- L + 1
  w <- rep(c(0, 1), each = 4)
  med_diff <- EDI:::turnbull_npmle_stat_diff(L, R, w, "median")
  rm_diff <- EDI:::turnbull_npmle_stat_diff(L, R, w, "restricted_mean")
  expect_true(is.finite(med_diff))
  expect_true(is.finite(rm_diff))
  expect_gt(med_diff, 0)
})
