library(testthat)
library(EDI)

test_that("sandwich helpers agree with direct matrix algebra and reject malformed inputs", {
  X <- cbind(1, c(-1, 0, 1, 2))
  residuals <- c(-0.5, 0.2, 0.4, -0.1)
  meat <- EDI:::robust_sandwich_meat_from_residuals(X, residuals)
  expect_equal(meat, crossprod(X, X * residuals^2))
  bread <- solve(crossprod(X))
  vcov <- EDI:::robust_sandwich_vcov(bread, meat)
  expect_equal(vcov, bread %*% meat %*% bread)
  expect_equal(EDI:::robust_sandwich_variance(vcov, 2), vcov[2, 2])
  expect_equal(EDI:::robust_sandwich_variance_from_xtwx(X, residuals, crossprod(X), 2), vcov[2, 2])
  expect_null(EDI:::robust_sandwich_meat_from_residuals(X, residuals[-1]))
  expect_null(EDI:::robust_sandwich_vcov(diag(2), diag(3)))
  expect_true(is.na(EDI:::robust_sandwich_variance(vcov, 3)))
  expect_true(is.na(EDI:::robust_sandwich_variance_from_xtwx(X, residuals, matrix(0, 2, 2), 2)))
})

test_that("logit transforms clamp extremes and round-trip interior probabilities", {
  p <- c(0.1, 0.25, 0.8)
  expect_equal(inv_logit(logit(p)), p, tolerance = 1e-14)
  boundary <- logit(c(-Inf, 0, 1, Inf), zero_one_logit_clamp = 1e-8)
  expect_true(all(is.finite(boundary)))
  inverse <- inv_logit(c(-1e6, 0, 1e6), zero_one_logit_clamp = 1e-8)
  expect_equal(inverse, c(1e-8, 0.5, 1 - 1e-8))
})

test_that("sample mode preserves type and first-occurrence tie breaking", {
  expect_identical(sample_mode(c(2L, 1L, 1L, 2L)), 2L)
  expect_identical(sample_mode(c("b", "a", "a", "b")), "b")
  f <- factor(c("high", "low", "low", "high"), levels = c("low", "high"))
  mode_f <- sample_mode(f)
  expect_s3_class(mode_f, "factor")
  expect_identical(as.character(mode_f), "high")
})

test_that("model-matrix helpers remove intercepts, aliases, constants, and correlations", {
  dat <- data.frame(x = 1:5, duplicate = 1:5, group = factor(c("a", "b", "a", "b", "a")))
  mm <- EDI:::create_model_matrix_from_features(~ x + duplicate + group, dat)
  expect_false("(Intercept)" %in% colnames(mm))
  expect_equal(qr(mm)$rank, ncol(mm))
  empty <- EDI:::create_model_matrix_from_features(~ ., data.frame(row.names = 1:3))
  expect_equal(dim(empty), c(3L, 0L))

  reduced <- EDI:::drop_linearly_dependent_cols(cbind(x = 1:4, duplicate = 1:4))
  expect_equal(ncol(reduced$M), 1L)
  nonfinite <- cbind(x = c(1, NA), y = 1:2)
  expect_equal(EDI:::drop_linearly_dependent_cols(nonfinite)$M, nonfinite)
  correlated <- EDI:::drop_highly_correlated_cols(cbind(constant = 1, x = 1:5, near = (1:5) + 1e-8))
  expect_equal(ncol(correlated$M), 1L)
  expect_identical(correlated$js, 2L)
})

test_that("user C++ signature validation is whitespace and argument-name insensitive", {
  recorded <- c("const Eigen::MatrixXd & X", "const Eigen::VectorXd& w")
  expected <- c("const Eigen::MatrixXd&", "const Eigen::VectorXd&")
  expect_true(EDI:::user_cpp_xptr_args_match(recorded, expected))
  expect_false(EDI:::user_cpp_xptr_args_match(recorded[1], expected))
  expect_error(EDI:::normalize_user_cpp_fn(function(x) x, "objective", "design_objective"), "not an R function")
  expect_error(EDI:::normalize_user_cpp_fn(1, "objective", "design_objective"), "external pointer")
  expect_error(EDI:::normalize_user_cpp_fn(1, "objective", "missing_signature"), "Unknown user C\\+\\+ signature")
  expect_error(EDI:::assert_custom_objective_xptr(NULL), "custom_objective is required")
})

make_count_regression_design <- function(seed = 20260921L, n = 80L) {
  set.seed(seed)
  x <- rnorm(n)
  des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", seed = seed)
  for (i in seq_len(n)) {
    w <- des$add_one_subject_to_experiment_and_assign(data.frame(x = x[i]))
    des$add_one_subject_response(i, rnbinom(1, mu = exp(0.4 + 0.35 * w + 0.2 * x[i]), size = 3))
  }
  des
}

test_that("Poisson and negative-binomial public fits match established R implementations", {
  des <- make_count_regression_design()
  dat <- data.frame(y = des$get_y(), w = des$get_w(), x = des$get_X_raw()$x)

  pois <- InferenceCountPoisson$new(des, model_formula = ~ x)
  expect_equal(pois$compute_estimate(estimate_only = TRUE),
               unname(coef(glm(y ~ w + x, data = dat, family = poisson()))["w"]), tolerance = 1e-5)
  expect_true(is.finite(pois$compute_asymp_two_sided_pval()))

  skip_if_not_installed("MASS")
  nb <- InferenceCountNegBin$new(des, model_formula = ~ x)
  expect_equal(nb$compute_estimate(estimate_only = TRUE),
               unname(coef(MASS::glm.nb(y ~ w + x, data = dat))["w"]), tolerance = 2e-3)
  expect_true(is.finite(nb$compute_asymp_two_sided_pval()))
})

test_that("quasi and robust Poisson estimate-only caching remains stable", {
  des <- make_count_regression_design(seed = 20260922L, n = 60L)
  for (generator in list(InferenceCountRobustPoisson, InferenceCountQuasiPoisson)) {
    inf <- generator$new(des, model_formula = ~ x)
    first <- inf$compute_estimate(estimate_only = TRUE)
    second <- inf$compute_estimate(estimate_only = TRUE)
    expect_true(is.finite(first))
    expect_equal(second, first)
    expect_identical(inf$get_supported_testing_types(), "wald")
  }
})
