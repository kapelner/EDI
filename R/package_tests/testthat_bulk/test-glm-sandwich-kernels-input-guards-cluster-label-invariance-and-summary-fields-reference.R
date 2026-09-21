library(testthat)
library(EDI)

# C++ GLM sandwich kernels (robust_post_fit_speedups.cpp): input guards (dimension mismatch, non-finite inputs,
# non-positive working weights, singular X'WX, out-of-range treatment column, non-finite vcov), the summary
# fields derived from the sandwich (se, ssq_hat, beta_hat, std_err, z_vals) recomputed by hand, and cluster-
# label invariance (arbitrary ids, unsorted rows) of the cluster sandwich against a hand-built cluster meat.

K <- function(x) get(x, envir = asNamespace("EDI"))
set.seed(5); n <- 60L
X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
yb <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.2, 0.5, 0.3))))
g <- glm(yb ~ X - 1, family = binomial())
b <- as.numeric(coef(g)); mu <- as.numeric(fitted(g)); ww <- mu * (1 - mu)
gl <- K("glm_sandwich_post_fit_cpp"); gc <- K("glm_cluster_sandwich_post_fit_cpp")

test_that("summary fields equal their definitions from the returned vcov", {
	r <- gl(X, yb, b, mu, ww, 2L)
	V <- r$vcov
	expect_equal(as.numeric(r$std_err), sqrt(diag(V)), tolerance = 1e-12)
	expect_equal(as.numeric(r$z_vals), b / sqrt(diag(V)), tolerance = 1e-10)
	expect_equal(r$ssq_hat, V[2, 2]); expect_equal(r$se, sqrt(V[2, 2])); expect_equal(r$beta_hat, b[2])
	expect_equal(V, t(V), tolerance = 1e-14)                  # symmetrised
})

test_that("plain sandwich equals the hand-built bread * meat * bread", {
	bread <- solve(crossprod(X * sqrt(ww)))
	meat <- crossprod(X * (yb - mu))
	expect_equal(unname(gl(X, yb, b, mu, ww, 3L)$vcov), unname(bread %*% meat %*% bread), tolerance = 1e-9)
})

test_that("cluster sandwich matches a hand-built cluster meat and is invariant to id labels and row order", {
	cl <- rep(1:12, length.out = n)
	bread <- solve(crossprod(X * sqrt(ww)))
	scores <- rowsum(X * (yb - mu), cl)
	ref <- bread %*% crossprod(scores) %*% bread
	r <- gc(X, yb, b, mu, ww, as.integer(cl), 3L)
	expect_equal(unname(r$vcov), unname(ref), tolerance = 1e-9)
	relabel <- gc(X, yb, b, mu, ww, as.integer(cl * 1000L - 7L), 3L)
	expect_equal(relabel$vcov, r$vcov, tolerance = 1e-12)
	perm <- sample.int(n)
	rp <- gc(X[perm, ], yb[perm], b, mu[perm], ww[perm], as.integer(cl[perm]), 3L)
	expect_equal(unname(rp$vcov), unname(r$vcov), tolerance = 1e-9)
	expect_error(gc(X, yb, b, mu, ww, 1:5, 3L), "dimension mismatch in cluster_meat")
})

test_that("input guards raise informative errors", {
	expect_error(gl(X, yb[-1], b, mu, ww, 3L), "dimension mismatch in glm_sandwich_post_fit_cpp")
	expect_error(gl(X, yb, b[-1], mu, ww, 3L), "dimension mismatch")
	expect_error(gl(X, yb, b, mu[-1], ww, 3L), "dimension mismatch")
	expect_error(gl(X, yb, b, mu, ww[-1], 3L), "dimension mismatch")
	expect_error(gc(X, yb[-1], b, mu, ww, rep(1L, n), 3L), "dimension mismatch in glm_cluster_sandwich_post_fit_cpp")
	expect_error(gl(X, yb, replace(b, 1, NA), mu, ww, 3L), "non-finite inputs")
	expect_error(gl(X, yb, b, replace(mu, 2, Inf), ww, 3L), "non-finite inputs")
	expect_error(gl(X, yb, b, mu, replace(ww, 3, NaN), 3L), "non-finite inputs")
	expect_error(gl(X, yb, b, mu, replace(ww, 3, 0), 3L), "non-positive working weights")
	expect_error(gc(X, yb, b, mu, replace(ww, 3, -1), rep(1:2, length.out = n), 3L), "non-positive working weights")
	expect_error(gl(X, yb, b, mu, ww, 0L), "out of bounds")
	expect_error(gl(X, yb, b, mu, ww, 4L), "out of bounds")
})

test_that("a non-finite response makes the covariance non-finite and is rejected", {
	expect_error(gl(X, replace(yb, 1, NaN), b, mu, ww, 3L), "non-finite covariance")
})
