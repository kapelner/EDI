library(testthat)
library(EDI)

test_that("clustered Cox covariance uses free-parameter Breslow score sandwiches", {
  X <- cbind(rep(c(0, 1, 1, 0), 6), sin(seq_len(24) * .7))
  y <- rep(c(1, 3, 2, 2, 5, 4, 3, 6, 4, 1, 5, 7), 2)
  dead <- rep(c(1, 0, 1, 1, 0, 1), 4)
  sandwich <- function(beta, cluster, free) {
    eta <- drop(X %*% beta)
    weight <- exp(eta - max(eta))
    scores <- matrix(0, nrow(X), ncol(X))
    information <- matrix(0, ncol(X), ncol(X))
    for (time in unique(y[dead == 1])) {
      events <- which(y == time & dead == 1)
      risk <- which(y >= time)
      probability <- weight[risk] / sum(weight[risk])
      mean_x <- drop(crossprod(X[risk, , drop = FALSE], probability))
      centered <- sweep(X[risk, , drop = FALSE], 2, mean_x)
      scores[events, ] <- scores[events, , drop = FALSE] +
        sweep(X[events, , drop = FALSE], 2, mean_x)
      scores[risk, ] <- scores[risk, , drop = FALSE] -
        length(events) * centered * probability
      information <- information + length(events) * crossprod(centered, centered * probability)
    }
    cluster_scores <- rowsum(scores[, free, drop = FALSE], cluster, reorder = FALSE)
    inverse <- solve(information[free, free, drop = FALSE])
    inverse %*% crossprod(cluster_scores) %*% inverse
  }
  clusters <- list(seq_len(nrow(X)), rep(c(-9L, 17L, 2L, 31L), 6))
  for (fixed in c(FALSE, TRUE)) {
    free <- if (fixed) 2L else 1:2
    for (algorithm in c("newton_raphson", "lbfgs")) {
      common <- list(X = X, y = y, dead = dead, warm_start_beta = c(0, 0),
                     smart_cold_start = FALSE, maxit = 500L, tol = 1e-10,
                     optimization_alg = algorithm)
      if (fixed) {
        common$fixed_idx <- 1L
        common$fixed_values <- .2
      }
      model <- do.call(EDI:::fast_coxph_regression_cpp, common)
      for (cluster in clusters) {
        args <- common
        args$cluster <- as.integer(cluster)
        actual <- do.call(EDI:::fast_coxph_regression_cpp, args)
        expected <- sandwich(as.numeric(actual$coefficients), cluster, free)
        expect_true(actual$converged, info = algorithm)
        expect_equal(actual$coefficients, model$coefficients, tolerance = 1e-10)
        expect_equal(actual$neg_ll, model$neg_ll, tolerance = 1e-10)
        expect_equal(actual$fisher_information, model$fisher_information, tolerance = 1e-10)
        expect_true(all(is.finite(actual$vcov[free, free, drop = FALSE])))
        expect_equal(actual$vcov[free, free, drop = FALSE], expected, tolerance = 1e-8)
        if (fixed) {
          expect_identical(as.numeric(actual$coefficients)[1], .2)
          expect_true(all(is.na(actual$vcov[1, ])))
          expect_true(all(is.na(actual$vcov[, 1])))
        }
        # Cluster IDs refer to input subjects, including censored subjects,
        # so shuffling tied and untied rows must preserve the sandwich.
        order <- c(seq(24, 2, -2), seq(1, 23, 2))
        shuffled_args <- args
        shuffled_args$X <- X[order, ]
        shuffled_args$y <- y[order]
        shuffled_args$dead <- dead[order]
        shuffled_args$cluster <- as.integer(cluster[order])
        shuffled <- do.call(EDI:::fast_coxph_regression_cpp, shuffled_args)
        expect_equal(shuffled$vcov[free, free, drop = FALSE], expected, tolerance = 1e-8)
      }
    }
  }
})
