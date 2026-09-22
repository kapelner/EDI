library(testthat)
library(EDI)

# kk21_continuous_weights_cpp(X, y) / kk21_logistic_weights_cpp(X, y) / kk21_ordinal_weights_cpp(X, y): per-covariate weights = |t| (or |z|) of the treatment-free
# UNIVARIATE fit of y on one covariate column at a time (not the multiple regression). References: summary(lm(y ~ x_j)), summary(glm(y ~ x_j, binomial)),
# and -- for the ordinal kernel -- |b / sqrt(ssq_b_j)| of fast_ordinal_regression_with_var_cpp on the single column.
# Degenerate inputs (constant column, n <= 2, empty design) give .Machine$double.eps.
# REGRESSION (fixed 2026-09-22): kk21_ordinal_weights_cpp (and kk21_stepwise_ordinal_weights_cpp, which shares the same
# multivariate_ordinal_tstat() helper) used to read res["ssq_b_2"] from fast_ordinal_regression_with_var_cpp, which only
# ever returns ssq_b_j; the resulting exception was swallowed by try/catch, so every ordinal covariate weight collapsed
# to .Machine$double.eps (kk21_ordinal_weights_cpp) or the stepwise selection broke on its first step, leaving every
# weight at its NA_real_ initial value (kk21_stepwise_ordinal_weights_cpp), and the KK21 ordinal design's covariate
# weights collapsed to equal (1 / p) after normalisation. Fixed by reading the correct "ssq_b_j" key.

K <- function(nm) get(nm, envir = asNamespace("EDI"))
eps <- .Machine$double.eps
set.seed(1); n <- 120L
X <- cbind(x1 = rnorm(n), x2 = rnorm(n), x3 = rbinom(n, 1, 0.5))

test_that("continuous weights are the univariate |t| of y ~ x_j for each column (not the multiple-regression t)", {
	y <- 1 + 0.8 * X[, 1] + rnorm(n)
	got <- K("kk21_continuous_weights_cpp")(X, y)
	ref <- vapply(1:3, function(j) abs(summary(lm(y ~ X[, j]))$coefficients[2, 3]), numeric(1))
	expect_equal(got, ref, tolerance = 1e-8)
	multi <- abs(summary(lm(y ~ X))$coefficients[-1, 3])
	expect_gt(max(abs(got - multi)), 1e-3)                                            # the multiple-regression |t| is a different number
	expect_equal(K("kk21_continuous_weights_cpp")(X * 5 + 3, y * 2 - 1), got, tolerance = 1e-8)   # affine invariance of |t|
})

test_that("logistic weights are the univariate Wald |z| of glm(y ~ x_j, binomial) (IRLS to 1e-8)", {
	yb <- rbinom(n, 1, plogis(X[, 1]))
	got <- K("kk21_logistic_weights_cpp")(X, yb)
	ref <- vapply(1:3, function(j) abs(summary(glm(yb ~ X[, j], family = binomial))$coefficients[2, 3]), numeric(1))
	expect_equal(got, ref, tolerance = 1e-4)
	expect_gt(got[1], 2)                                                              # the informative covariate is largest
	expect_equal(which.max(got), 1L)
	expect_false(isTRUE(all.equal(K("kk21_logistic_weights_cpp")(X, yb, maxit = 1L), got, tolerance = 1e-3)))   # maxit is honoured
})

test_that("degenerate inputs return the eps weight: constant column, tiny n, empty design", {
	y <- rnorm(n)
	Xc <- cbind(a = rep(1, n), b = X[, 1])
	expect_equal(K("kk21_continuous_weights_cpp")(Xc, y)[1], eps)
	expect_gt(K("kk21_continuous_weights_cpp")(Xc, y)[2], eps)
	expect_equal(K("kk21_continuous_weights_cpp")(X[1:2, ], y[1:2]), rep(eps, 3))
	expect_length(K("kk21_continuous_weights_cpp")(matrix(numeric(0), n, 0), y), 0L)
	expect_equal(K("kk21_logistic_weights_cpp")(matrix(numeric(0), 0, 2), numeric(0)), rep(eps, 2))
})

test_that("ordinal weights equal |b / sqrt(ssq_b_j)| of the univariate fit on each column (regression: the ssq_b_2/ssq_b_j key bug is fixed)", {
	lat <- X[, 1] * 0.9 + rlogis(n); yo <- as.numeric(cut(lat, c(-Inf, -1, 0.3, 1.2, Inf)))
	got <- K("kk21_ordinal_weights_cpp")(X, yo)
	ref <- vapply(1:3, function(j) {
		fit <- K("fast_ordinal_regression_with_var_cpp")(X[, j, drop = FALSE], yo)
		abs(fit$b[length(fit$b)] / sqrt(fit$ssq_b_j))
	}, numeric(1))
	expect_equal(got, ref, tolerance = 1e-8)
	expect_false(isTRUE(all.equal(got, rep(eps, 3))))                                 # no longer collapses to eps
	expect_equal(which.max(got), 1L)                                                  # the informative covariate is largest
	expect_gt(got[1], 2)
})

test_that("stepwise ordinal weights are no longer all-NA (the shared multivariate_ordinal_tstat() helper had the same key bug)", {
	lat <- X[, 1] * 0.9 + rlogis(n); yo <- as.numeric(cut(lat, c(-Inf, -1, 0.3, 1.2, Inf)))
	w <- rbinom(n, 1, 0.5)
	got <- K("kk21_stepwise_ordinal_weights_cpp")(X, yo, w)
	expect_false(anyNA(got))
	expect_equal(which.max(got), 1L)                                                  # the informative covariate is selected first (largest weight)
})
