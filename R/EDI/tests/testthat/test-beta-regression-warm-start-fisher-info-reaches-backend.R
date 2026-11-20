# Audit decision rd-d3554783c: fast_beta_regression_with_var() documented
# warm_start_fisher_info but did not forward it to
# fast_beta_regression_with_var_cpp(), so the C++ fitter never saw it.
# These tests pin that the matrix reaches the backend and that a correct warm
# start reproduces the cold fit.

make_beta_warm_start_data <- function(n = 160L, seed = 7311L, phi = 12) {
  set.seed(seed)
  X <- cbind(1, matrix(rnorm(n * 2L), n, 2L))
  mu <- plogis(drop(X %*% c(-0.2, 0.5, -0.4)))
  y <- rbeta(n, mu * phi, (1 - mu) * phi)
  y <- pmin(pmax(y, 1e-6), 1 - 1e-6)
  list(X = X, y = y)
}

test_that("fast_beta_regression_with_var forwards warm_start_fisher_info to the C++ fitter", {
  dat <- make_beta_warm_start_data()
  H <- diag(ncol(dat$X) + 1L) * 3
  seen <- new.env()
  real_cpp <- EDI:::fast_beta_regression_with_var_cpp
  testthat::local_mocked_bindings(
    fast_beta_regression_with_var_cpp = function(X, y, ...) {
      args <- list(...)
      seen$fisher <- args$warm_start_fisher_info
      seen$has_fisher_arg <- "warm_start_fisher_info" %in% names(args)
      real_cpp(X, y, ...)
    },
    .package = "EDI"
  )
  EDI:::fast_beta_regression_with_var(dat$X, dat$y, warm_start_fisher_info = H)
  expect_true(isTRUE(seen$has_fisher_arg))
  expect_identical(seen$fisher, H)
})

test_that("a wrongly sized warm_start_fisher_info is rejected by the backend, not ignored", {
  dat <- make_beta_warm_start_data()
  bad_H <- diag(2L)  # backend requires (ncol(X) + 1) x (ncol(X) + 1) = 4 x 4
  warnings_seen <- character()
  res <- withCallingHandlers(
    EDI:::fast_beta_regression_with_var(dat$X, dat$y, warm_start_fisher_info = bad_H),
    warning = function(w) {
      warnings_seen <<- c(warnings_seen, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("fast_beta_regression_with_var_cpp failed", warnings_seen, fixed = TRUE)))
  expect_true(any(grepl("warm_start_fisher_info", warnings_seen, fixed = TRUE)))
  expect_true(is.list(res))
})

test_that("a correct warm start matches the cold fit", {
  dat <- make_beta_warm_start_data()
  cold <- EDI:::fast_beta_regression_with_var_cpp(dat$X, dat$y)
  cold_w <- EDI:::fast_beta_regression_with_var(dat$X, dat$y)
  warm_w <- EDI:::fast_beta_regression_with_var(
    dat$X, dat$y,
    warm_start_beta = cold$coefficients,
    warm_start_fisher_info = cold$fisher_information
  )
  expect_equal(warm_w$b, cold_w$b, tolerance = 1e-4)
  expect_equal(warm_w$phi, cold_w$phi, tolerance = 1e-3)
  expect_equal(warm_w$ssq_b_j, cold_w$ssq_b_j, tolerance = 1e-3)
  expect_equal(warm_w$ssq_b_2, cold_w$ssq_b_2, tolerance = 1e-3)
})
