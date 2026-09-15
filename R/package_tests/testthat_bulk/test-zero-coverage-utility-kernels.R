library(testthat)
library(EDI)

test_that("column inspection and scaling kernels match R references", {
	X = cbind(
		constant = rep(4, 5),
		increasing = 1:5,
		alternating = c(0, 1, 0, 1, 0)
	)

	expect_identical(
		as.logical(EDI:::which_cols_vary_cpp(X)),
		c(FALSE, TRUE, TRUE)
	)
	expect_identical(
		as.logical(EDI:::which_cols_vary_cpp(X[1, , drop = FALSE])),
		rep(FALSE, ncol(X))
	)

	observed = EDI:::scale_columns_cpp(X)
	expect_equal(observed[, 1], rep(0, nrow(X)))
	expect_equal(observed[, 2], as.numeric(scale(X[, "increasing"])))
	expect_equal(observed[, 3], as.numeric(scale(X[, "alternating"])))
})

test_that("shuffle kernel returns a reproducible permutation", {
	expected = as.numeric(seq_len(20))
	set.seed(20260915)
	first = EDI:::shuffle_cpp(as.numeric(seq_len(20)))
	set.seed(20260915)
	second = EDI:::shuffle_cpp(as.numeric(seq_len(20)))

	expect_identical(first, second)
	expect_equal(sort(first), expected)
	expect_false(identical(first, expected))
})

test_that("fast special-function kernels match base R references", {
	positive = c(0.125, 0.5, 1, 2.5, 10, 100)
	a = c(0.2, 0.75, 1, 3, 12)
	b = c(0.4, 1.25, 2, 5, 20)
	counts = c(0, 1, 2, 7, 25)
	probs = c(1e-6, 0.01, 0.25, 0.5, 0.9, 1 - 1e-6)
	normal_x = c(-5, -3, -0.5, 0, 0.5, 3, 5)

	expect_equal(fast_digamma_vec_cpp(positive), digamma(positive), tolerance = 1e-10)
	expect_equal(fast_trigamma_vec_cpp(positive), trigamma(positive), tolerance = 1e-10)
	expect_equal(fast_lgamma_vec_cpp(positive), lgamma(positive), tolerance = 1e-10)
	expect_equal(fast_lbeta_vec_cpp(a, b), lbeta(a, b), tolerance = 1e-10)
	expect_equal(
		fast_dnbinom_mu_vec_cpp(counts, size = 2.5, mu = 4, return_log = FALSE),
		dnbinom(counts, size = 2.5, mu = 4),
		tolerance = 1e-10
	)
	expect_equal(
		fast_dnbinom_mu_vec_cpp(counts, size = 2.5, mu = 4, return_log = TRUE),
		dnbinom(counts, size = 2.5, mu = 4, log = TRUE),
		tolerance = 1e-10
	)
	expect_equal(fast_qnorm_vec_cpp(probs), qnorm(probs), tolerance = 2e-8)
	expect_equal(
		fast_log_pnorm_vec_cpp(normal_x),
		pnorm(normal_x, log.p = TRUE),
		tolerance = 1e-10
	)
	expect_equal(
		fast_log_dnorm_vec_cpp(normal_x),
		dnorm(normal_x, log = TRUE),
		tolerance = 1e-14
	)
})

test_that("fast special-function wrappers preserve empty vector shape", {
	empty = numeric()
	expect_identical(fast_digamma_vec_cpp(empty), empty)
	expect_identical(fast_trigamma_vec_cpp(empty), empty)
	expect_identical(fast_lgamma_vec_cpp(empty), empty)
	expect_identical(fast_lbeta_vec_cpp(empty, empty), empty)
	expect_identical(fast_dnbinom_mu_vec_cpp(empty, 2, 3, FALSE), empty)
	expect_identical(fast_qnorm_vec_cpp(empty), empty)
	expect_identical(fast_log_pnorm_vec_cpp(empty), empty)
	expect_identical(fast_log_dnorm_vec_cpp(empty), empty)
})
