library(testthat)
library(EDI)

adjacent_randomization_reference <- function(X, y, w, delta) {
  shifted <- y + delta * w
  category <- match(shifted, sort(unique(shifted)))
  K <- max(category)
  Z <- cbind(w, X)
  nll <- function(params) {
    alpha <- params[seq_len(K - 1L)]
    eta <- drop(Z %*% params[-seq_len(K - 1L)])
    intercepts <- c(rev(cumsum(rev(alpha))), 0)
    logits <- outer(rep(1, length(y)), intercepts) - outer(eta, (K - 1L):0L)
    logp <- logits - apply(logits, 1L, max)
    logp <- logp - log(rowSums(exp(logp)))
    -sum(logp[cbind(seq_along(y), category)])
  }
  fit <- optim(rep(0, K - 1L + ncol(Z)), nll, method = "BFGS",
               control = list(maxit = 2000L, reltol = 1e-12))
  stopifnot(fit$convergence == 0L)
  fit$par[K]
}

test_that("adjacent-category randomization draws agree with independent multinomial fits", {
  y <- rep(c(-2, 1, 5), each = 12L)
  i <- seq_along(y)
  draws <- cbind(as.integer(i %% 2 == 0), as.integer(i %% 5 < 2),
                 as.integer((i + 1) %% 7 < 3))
  for (X in list(matrix(numeric(), length(y), 0L), matrix(sin(i), ncol = 1L))) {
    for (delta in c(0, 0.5)) {
      expected <- apply(draws, 2L, function(w) adjacent_randomization_reference(X, y, w, delta))
      actual <- EDI:::compute_adj_cat_logit_distr_parallel_cpp(X, y, draws, delta, 1L)
      expect_true(all(is.finite(actual)))
      expect_equal(as.numeric(actual), expected, tolerance = 2e-4)
      expect_equal(as.numeric(EDI:::compute_adj_cat_logit_distr_parallel_cpp(
        X, y, draws[, 3:1, drop = FALSE], delta, 1L)), rev(as.numeric(actual)), tolerance = 1e-10)
    }
  }
})

test_that("adjacent-category randomization reports absent response variation", {
  X <- matrix(numeric(), 8L, 0L)
  draws <- cbind(rep(c(0L, 1L), 4L), rep(c(1L, 0L), 4L))
  expect_true(all(is.na(EDI:::compute_adj_cat_logit_distr_parallel_cpp(X, rep(4, 8), draws, 0, 1L))))
  expect_identical(as.numeric(EDI:::compute_adj_cat_logit_distr_parallel_cpp(
    X, rep(1:2, 4), matrix(integer(), 8L, 0L), 0, 1L)), numeric())
})
