library(testthat)
library(EDI)

# kk21_beta_weights_cpp / kk21_negbin_weights_cpp (kk21_weights.cpp) are the vectorized
# per-covariate weight kernels DesignSeqOneByOneKK21's LIVE compute_weights() dispatch calls
# directly for response_type = "proportion" (when proportion_use_speedup = FALSE) and
# response_type = "count" (when count_use_speedup = FALSE) respectively -- design_seq_one_by_one_
# KK21.R lines ~353/356. A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms ZERO test references of any kind for either kernel by name.
#
# These are distinct from (and NOT the same statistic as) the file's already-tested older
# per-covariate legacy methods compute_weight_KK21_proportion()/compute_weight_KK21_count()
# (test-kk21-design-proportion-weight-beta-regression-fallback-reference.R /
# test-kk21-design-count-weight-glm-nb-error-fallback-reference.R): those are reachable only through
# a "should not reach here for current types" fallback loop, per the source's own comment, while
# these two vectorized kernels ARE the live dispatch path. (Confirmed directly: the vectorized
# kernels' numeric values do not match the legacy per-covariate methods' values on the same inputs --
# different internal univariate-t-statistic formulas -- so they cannot be cross-checked against each
# other as an independent reference; this file instead pins the verifiable structural contract.)

f_beta <- get("kk21_beta_weights_cpp", envir = asNamespace("EDI"))
f_negbin <- get("kk21_negbin_weights_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 91L, n = 40L, p = 3L) {
	set.seed(seed)
	list(X = matrix(rnorm(n * p), n, p), y_prop = plogis(rnorm(n)), y_count = rpois(n, 3))
}

test_that("kk21_beta_weights_cpp returns a length-p vector of positive, finite weights for well-conditioned data, deterministically", {
	d <- fx()
	out <- f_beta(d$X, d$y_prop)
	expect_length(out, ncol(d$X))
	expect_true(all(is.finite(out) & out > 0))
	expect_identical(out, f_beta(d$X, d$y_prop))   # no RNG involved: exactly reproducible without set.seed()
})

test_that("kk21_negbin_weights_cpp returns a length-p vector of positive, finite weights for well-conditioned data, deterministically", {
	d <- fx(seed = 92L)
	out <- f_negbin(d$X, d$y_count)
	expect_length(out, ncol(d$X))
	expect_true(all(is.finite(out) & out > 0))
	expect_identical(out, f_negbin(d$X, d$y_count))
})

test_that("both kernels fall back to the epsilon floor when n < 3, regardless of p", {
	X2 <- matrix(1:4, 2, 2)
	y2 <- c(0.3, 0.7)
	out_beta <- f_beta(X2, y2)
	out_negbin <- f_negbin(X2, c(1, 2))
	expect_true(all(out_beta == .Machine$double.eps))
	expect_true(all(out_negbin == .Machine$double.eps))
})

test_that("both kernels return an empty (length-0) vector when p == 0", {
	d <- fx(seed = 93L)
	X0 <- matrix(nrow = nrow(d$X), ncol = 0)
	expect_length(f_beta(X0, d$y_prop), 0L)
	expect_length(f_negbin(X0, d$y_count), 0L)
})
