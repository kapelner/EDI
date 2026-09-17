library(testthat)
library(EDI)

test_that("negative-binomial likelihood agrees with the defining density", {
  X <- cbind(1, c(-1, 0, 1, 2))
  beta <- c(log(2), 0.2)
  y <- c(0L, 1L, 3L, 2L)
  theta <- 1.7

  got <- EDI:::neg_loglik_nb_cpp(theta, beta, X, y)
  expected <- -sum(dnbinom(y, size = theta, mu = exp(X %*% beta), log = TRUE))
  expect_equal(got, expected, tolerance = 1e-12)
})

test_that("beta helper kernels agree with R formulas and handle boundaries", {
  y <- c(0.15, 0.4, 0.8)
  mu <- c(0.2, 0.5, 0.7)
  phi <- 8
  wt <- c(1, 2, 0.5)
  ll_terms <- dbeta(y, mu * phi, (1 - mu) * phi, log = TRUE)

  expect_equal(EDI:::beta_loglik_cpp(y, mu, phi, wt), sum(wt * ll_terms),
               tolerance = 1e-10)
  expect_equal(EDI:::beta_dev_resids_cpp(y, mu, phi, wt), -2 * wt * ll_terms,
               tolerance = 1e-10)
  expect_equal(EDI:::beta_aic_cpp(y, mu, phi, wt),
               -2 * sum(wt * ll_terms) + 2 * (length(mu) + 1), tolerance = 1e-10)

  boundary <- EDI:::beta_dev_resids_cpp(c(0, 1), c(0, 1), phi, c(1, 1))
  expect_true(all(is.nan(boundary)))
  expect_equal(EDI:::beta_aic_cpp(c(0, 1), c(0, 1), phi, c(1, 1)), 6)
})

test_that("match-data speedup returns treatment-minus-control pair differences", {
  X <- matrix(c(1, 4, 2, 7, 10, 13, 20, 25), ncol = 2)
  y <- c(3, 8, 5, 12)
  w <- c(1L, 0L, 0L, 1L)
  matches <- c(1L, 1L, 2L, 2L)

  got <- EDI:::match_diffs_cpp(X, y, w, matches, 2L)
  expect_named(got, c("yTs_matched", "yCs_matched", "X_matched_diffs"))
  expect_equal(as.numeric(got$yTs_matched - got$yCs_matched), c(-5, 7))
  expect_equal(dim(got$X_matched_diffs), c(2L, 2L))
  expect_equal(got$X_matched_diffs[1, ], X[1, ] - X[2, ])
  expect_equal(got$X_matched_diffs[2, ], X[4, ] - X[3, ])
})

test_that("exact Jonckheere-Terpstra kernel covers ties and validation", {
  y <- c(1L, 1L, 2L, 3L)
  w <- c(0L, 1L, 0L, 1L)
  got <- EDI:::exact_jonckheere_terpstra_pval_cpp(y, w)
  expect_named(got, c("stat2", "n_treat", "n_control", "superiority",
                      "p_lower", "p_upper", "p_exact"))
  expect_equal(got$superiority, 0.625)
  expect_true(got$p_exact >= 0 && got$p_exact <= 1)
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(integer(), integer()), "empty input")
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(1:2, 1L), "dimension mismatch")
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(1:2, c(0L, 2L)), "must be 0/1")
  expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(1:2, c(1L, 1L)), "both treatment arms")
})

test_that("Jonckheere-Terpstra bootstrap handles ties, resampling, and empty arms", {
  y <- c(1, 2, 3, 4)
  indices <- matrix(rep(1:4, 3), nrow = 4)
  assignments <- cbind(c(0L, 0L, 1L, 1L), c(1L, 1L, 0L, 0L), rep(1L, 4))
  got <- EDI:::compute_jt_rand_bootstrap_parallel_cpp(y, indices, assignments, 1L)
  expect_equal(got[1:2], c(0.5, -0.5))
  expect_true(is.na(got[3]))
})

test_that("zero-one logit shift is stable at response boundaries", {
  y <- c(0, 0.2, 0.8, 1)
  assignments <- cbind(c(0L, 0L, 1L, 1L), c(1L, 0L, 1L, 0L))
  clamp <- 1e-8

  unchanged <- EDI:::compute_wilcox_hl_distr_parallel_cpp(
    assignments, y, delta = 0, transform_code = 2L,
    zero_one_logit_clamp = clamp, num_cores = 1L
  )
  shifted <- EDI:::compute_wilcox_hl_distr_parallel_cpp(
    assignments, y, delta = 0.7, transform_code = 2L,
    zero_one_logit_clamp = clamp, num_cores = 1L
  )
  expect_true(all(is.finite(unchanged)))
  expect_true(all(is.finite(shifted)))
  expect_length(shifted, ncol(assignments))
  expect_false(isTRUE(all.equal(unchanged, shifted)))
})

test_that("ordinal CLMM dispatches all supported links and validates bad links", {
  set.seed(410)
  groups <- rep(seq_len(24), each = 2)
  X <- cbind(rep(c(0, 1), 24), rnorm(48))
  latent <- 0.5 * X[, 1] - 0.25 * X[, 2] + rlogis(48)
  y <- as.integer(cut(latent, c(-Inf, -0.5, 0.6, Inf), labels = FALSE))

  for (link in c("logit", "probit", "cauchit", "cloglog")) {
    fit <- EDI:::fast_ordinal_clmm_cpp(X, y, groups, K = 3L, j_T = 0L,
                                       link = link, estimate_only = TRUE,
                                       n_gh = 8L, maxit = 100L)
    expect_length(fit$b, ncol(X))
    expect_length(fit$alpha, 2L)
    expect_true(is.finite(fit$neg_loglik))
  }
  expect_error(EDI:::fast_ordinal_clmm_cpp(X, y, groups, 3L, 0L, link = "bad"),
               "Unknown link")
})

test_that("stepwise survival weights return a complete covariate ordering", {
  set.seed(411)
  n <- 40
  # The full-rank contract does not apply to a column aliased with the intercept.
  X <- cbind(signal = rnorm(n), noise = rnorm(n))
  w <- rep(c(0, 1), length.out = n)
  y <- exp(1 + 0.7 * X[, 1] + 0.2 * w + rnorm(n, sd = 0.25))
  delta <- rep(c(1, 1, 0, 1), length.out = n)

  weights <- EDI:::kk21_stepwise_survival_weights_cpp(X, y, delta, w)
  expect_length(weights, ncol(X))
  expect_true(all(is.finite(weights)))
  expect_true(all(weights >= 0))
  expect_equal(length(unique(weights)), ncol(X))

  # Force the OLS fallback: an intercept-alias candidate must remain unselected.
  deficient <- EDI:::kk21_stepwise_survival_weights_cpp(
    cbind(X, constant = 1), y, rep(0, n), w
  )
  expect_true(all(is.finite(deficient[seq_len(ncol(X))])))
  expect_true(is.na(deficient[ncol(X) + 1L]))

  expect_true(all(is.na(EDI:::kk21_stepwise_survival_weights_cpp(
    matrix(numeric(), nrow = 0, ncol = 2), numeric(), numeric(), numeric()
  ))))
})
