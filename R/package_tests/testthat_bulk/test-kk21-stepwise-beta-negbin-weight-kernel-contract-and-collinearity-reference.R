library(testthat)
library(EDI)

# kk21_stepwise_beta_weights_cpp / kk21_stepwise_negbin_weights_cpp (kk21_weights.cpp) are the
# vectorized greedy-forward-selection weight kernels DesignSeqOneByOneKK21Stepwise's LIVE
# compute_weights() dispatch calls directly for response_type = "proportion" (when proportion_use_
# speedup = FALSE) and response_type = "count" (when count_use_speedup = FALSE) respectively --
# design_seq_one_by_one_KK21_stepwise.R lines ~182/185. A codebase-wide grep across testthat_bulk/,
# R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms ZERO test references of any kind for
# either kernel by name; only their file-siblings kk21_stepwise_continuous_weights_cpp/_logistic_ are
# already tested (with an exact lm()/glm()-based reference, since those use closed-form OLS/logistic
# score statistics).
#
# Unlike those two siblings, kk21_stepwise_beta_weights_cpp/_negbin_ use a fast internal
# multivariate_beta_tstat()/multivariate_negbin_tstat() approximation rather than an iterative
# betareg()/glm.nb() refit at every candidate-covariate evaluation -- confirmed directly (a
# betareg()-per-step R reference disagrees by several percent, unlike the exact OLS/logistic
# siblings), so this file pins the verifiable structural invariants of the greedy selection
# procedure instead of an exact numeric reference: shape, positivity for well-conditioned data,
# perfectly-collinear-covariate handling (a redundant duplicate column gets weight exactly 0, not
# NA -- confirmed empirically below), determinism, and the p = 0 edge case.

K <- function(nm) get(nm, envir = asNamespace("EDI"))

fx <- function(seed = 97L, n = 100L) {
	set.seed(seed)
	X <- cbind(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	w <- rep(0:1, length.out = n)
	mu <- plogis(0.3 + 0.9 * X[, 1] + 0.4 * X[, 2] + 0.5 * w)
	y_prop <- rbeta(n, mu * 20, (1 - mu) * 20)
	y_count <- rpois(n, exp(0.5 + 0.3 * X[, 1] + 0.2 * X[, 2]))
	list(X = X, w = w, y_prop = y_prop, y_count = y_count)
}

test_that("kk21_stepwise_beta_weights_cpp returns a length-p vector, all covariates selected (no NA) and positive for well-conditioned data, deterministically", {
	d <- fx()
	out <- K("kk21_stepwise_beta_weights_cpp")(d$X, d$y_prop, d$w)
	expect_length(out, ncol(d$X))
	expect_false(anyNA(out))
	expect_true(all(out > 0))
	expect_identical(out, K("kk21_stepwise_beta_weights_cpp")(d$X, d$y_prop, d$w))
})

test_that("kk21_stepwise_negbin_weights_cpp returns a length-p vector, all covariates selected (no NA) and positive for well-conditioned data, deterministically", {
	d <- fx(seed = 98L)
	out <- K("kk21_stepwise_negbin_weights_cpp")(d$X, d$y_count, d$w)
	expect_length(out, ncol(d$X))
	expect_false(anyNA(out))
	expect_true(all(out > 0))
	expect_identical(out, K("kk21_stepwise_negbin_weights_cpp")(d$X, d$y_count, d$w))
})

test_that("a perfectly redundant duplicate column gets weight exactly 0 (not NA) once its twin is already selected, for both kernels", {
	d <- fx(seed = 99L)
	X_dup <- cbind(d$X[, 1], d$X[, 1], d$X[, 2])   # column 2 is an exact duplicate of column 1

	out_beta <- K("kk21_stepwise_beta_weights_cpp")(X_dup, d$y_prop, d$w)
	expect_false(anyNA(out_beta))
	expect_true(any(out_beta == 0))

	out_negbin <- K("kk21_stepwise_negbin_weights_cpp")(X_dup, d$y_count, d$w)
	expect_false(anyNA(out_negbin))
	expect_true(any(out_negbin == 0))
})

test_that("both kernels return an empty (length-0) vector when p == 0", {
	d <- fx(seed = 100L)
	X0 <- matrix(nrow = length(d$w), ncol = 0)
	expect_length(K("kk21_stepwise_beta_weights_cpp")(X0, d$y_prop, d$w), 0L)
	expect_length(K("kk21_stepwise_negbin_weights_cpp")(X0, d$y_count, d$w), 0L)
})
