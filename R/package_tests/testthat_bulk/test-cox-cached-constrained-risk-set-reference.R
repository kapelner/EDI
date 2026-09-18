library(testthat)
library(EDI)

test_that("cached Cox fits preserve constrained Breslow risk sets and free covariance", {
  X <- cbind(rep(c(0, 1, 1, 0), 6), sin(seq_len(24) * .7))
  y <- rep(c(1, 3, 2, 2, 5, 4, 3, 6, 4, 1, 5, 7), 2)
  dead <- rep(c(1, 0, 1, 1, 0, 1), 4)
  labels <- rep(c(-3L, 17L), 12)
  reference <- function(beta, strata) {
    eta <- drop(X %*% beta)
    nll <- 0
    information <- matrix(0, 2L, 2L)
    for (label in unique(strata)) {
      rows <- which(strata == label)
      for (time in unique(y[rows][dead[rows] == 1])) {
        event <- rows[y[rows] == time & dead[rows] == 1]
        risk <- rows[y[rows] >= time]
        weight <- exp(eta[risk] - max(eta[risk]))
        probability <- weight / sum(weight)
        mean_x <- drop(crossprod(X[risk, , drop = FALSE], probability))
        nll <- nll - sum(eta[event]) + length(event) *
          (max(eta[risk]) + log(sum(weight)))
        information <- information + length(event) *
          (crossprod(X[risk, , drop = FALSE], X[risk, , drop = FALSE] * probability) -
             tcrossprod(mean_x))
      }
    }
    list(nll = nll, information = information)
  }
  for (stratified in c(FALSE, TRUE)) {
    strata <- if (stratified) labels else rep(1L, length(y))
    cache <- if (stratified) EDI:::build_stratified_cox_data_cache_cpp(X, y, dead, strata) else
      EDI:::build_cox_data_cache_cpp(X, y, dead)
    for (fixed in c(FALSE, TRUE)) {
      expected <- if (fixed) {
        optimizer <- optimize(function(value) reference(c(.2, value), strata)$nll,
                              c(-5, 5), tol = 1e-11)
        c(.2, optimizer$minimum)
      } else {
        optimizer <- optim(c(0, 0), function(beta) reference(beta, strata)$nll,
                           method = "BFGS", control = list(reltol = 1e-12, maxit = 2000L))
        expect_identical(optimizer$convergence, 0L)
        optimizer$par
      }
      for (algorithm in c("newton_raphson", "lbfgs")) {
        common <- list(warm_start_beta = c(0, 0), smart_cold_start = FALSE,
                       maxit = 500L, tol = 1e-10, optimization_alg = algorithm)
        if (fixed) {
          common$fixed_idx <- 1L
          common$fixed_values <- .2
        }
        direct_args <- c(list(X = X, y = y, dead = dead), common)
        if (stratified) direct_args$strata <- strata
        direct <- do.call(if (stratified) EDI:::fast_stratified_coxph_regression_cpp else
                            EDI:::fast_coxph_regression_cpp, direct_args)
        cached_args <- c(list(cox_data_xptr = cache), common)
        cached <- do.call(EDI:::fast_coxph_regression_prebuilt_cpp, cached_args)
        for (actual in list(direct, cached)) {
          parameters <- as.numeric(actual$coefficients)
          expected_at_fit <- reference(parameters, strata)
          expect_true(actual$converged, info = algorithm)
          expect_equal(parameters, expected, tolerance = 1e-4)
          expect_equal(actual$neg_ll, expected_at_fit$nll, tolerance = 1e-10)
          expect_lt(abs(actual$neg_ll - reference(expected, strata)$nll), 1e-7)
          expect_equal(actual$fisher_information, expected_at_fit$information, tolerance = 1e-9)
          free <- if (fixed) 2L else 1:2
          expect_equal(actual$vcov[free, free, drop = FALSE],
                       solve(expected_at_fit$information[free, free, drop = FALSE]), tolerance = 1e-8)
          if (fixed) {
            expect_identical(parameters[1], .2)
            expect_true(all(is.na(actual$vcov[1, ])))
            expect_true(all(is.na(actual$vcov[, 1])))
          }
        }
        expect_equal(cached$coefficients, direct$coefficients, tolerance = 1e-10)
        expect_equal(cached$vcov, direct$vcov, tolerance = 1e-10)
        if (stratified) {
          order <- c(seq(24, 2, -2), seq(1, 23, 2))
          shuffled_args <- direct_args
          shuffled_args$X <- X[order, ]
          shuffled_args$y <- y[order]
          shuffled_args$dead <- dead[order]
          shuffled_args$strata <- strata[order]
          shuffled <- do.call(EDI:::fast_stratified_coxph_regression_cpp, shuffled_args)
          expect_equal(shuffled$coefficients, direct$coefficients, tolerance = 1e-9)
          expect_equal(shuffled$neg_ll, direct$neg_ll, tolerance = 1e-10)
          expect_equal(shuffled$fisher_information, direct$fisher_information, tolerance = 1e-9)
          expect_equal(shuffled$vcov, direct$vcov, tolerance = 1e-9)
          shuffled_cache <- EDI:::build_stratified_cox_data_cache_cpp(
            X[order, ], y[order], dead[order], strata[order])
          shuffled_cached_args <- cached_args
          shuffled_cached_args$cox_data_xptr <- shuffled_cache
          shuffled_cached <- do.call(EDI:::fast_coxph_regression_prebuilt_cpp, shuffled_cached_args)
          expect_equal(shuffled_cached$coefficients, direct$coefficients, tolerance = 1e-9)
          expect_equal(shuffled_cached$vcov, direct$vcov, tolerance = 1e-9)
        }
        cached_args$estimate_only <- TRUE
        estimate_only <- do.call(EDI:::fast_coxph_regression_prebuilt_cpp, cached_args)
        expect_equal(as.numeric(estimate_only$coefficients), expected, tolerance = 1e-4)
        expect_equal(estimate_only$neg_ll,
                     reference(as.numeric(estimate_only$coefficients), strata)$nll, tolerance = 1e-10)
        expect_false("vcov" %in% names(estimate_only))
      }
    }
  }
})
