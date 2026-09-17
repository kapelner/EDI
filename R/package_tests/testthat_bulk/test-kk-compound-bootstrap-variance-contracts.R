library(testthat)
library(EDI)

test_that("KK compound bootstrap uses inverse variance weighting for each resampled column", {
	set.seed(20260918)
	n <- 160L
	B <- 128L
	w <- rep(c(1L, 0L), n / 2)
	m <- c(rep(1:40, each = 2), rep(0L, 80))
	w_mat <- matrix(rep(w, B), nrow = n)
	m_mat <- matrix(rep(m, B), nrow = n)
	y_mat <- matrix(rnorm(n * B), nrow = n)
	expected <- vapply(seq_len(B), function(b) {
		y <- y_mat[, b]
		paired <- y[seq(1, 79, 2)] - y[seq(2, 80, 2)]
		treated <- y[seq(81, 159, 2)]
		control <- y[seq(82, 160, 2)]
		pair_est <- mean(paired)
		reservoir_est <- mean(treated) - mean(control)
		pair_variance <- var(paired) / length(paired)
		reservoir_variance <- (var(treated) + var(control)) / length(treated)
		weighted.mean(c(pair_est, reservoir_est), 1 / c(pair_variance, reservoir_variance))
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_matching_compound_bootstrap_parallel_cpp(w_mat, m_mat, y_mat, cores), expected, tolerance = 1e-10)
	}
	# Different response columns must be evaluated individually, and common
	# response translation cannot alter either difference estimand.
	expect_equal(EDI:::compute_matching_compound_bootstrap_parallel_cpp(w_mat, m_mat, y_mat + 3, 2L), expected, tolerance = 1e-10)
})

test_that("KK compound bootstrap falls back to the component with estimable variance", {
	w <- matrix(rep(c(1L, 0L), 4), ncol = 1)
	mixed <- matrix(c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L), ncol = 1)
	call_kernel <- function(y, m = mixed) {
		EDI:::compute_matching_compound_bootstrap_parallel_cpp(w, m, matrix(as.numeric(y), ncol = 1), 2L)
	}
	# Matched differences 2,2 have zero variance; reservoir differences
	# compare treatment 5,9 with control 1,3 and estimate 5.
	expect_equal(call_kernel(c(3, 1, 6, 4, 5, 1, 9, 3)), 5)
	# Constant reservoir arms have zero variance; pairs estimate (3+7)/2.
	expect_equal(call_kernel(c(4, 1, 9, 2, 5, 1, 5, 1)), 5)
	# One pair cannot estimate its variance; the reservoir still estimates 4.
	one_pair <- matrix(c(1L, 1L, rep(0L, 6)), ncol = 1)
	expect_equal(call_kernel(c(10, 2, 3, 1, 7, 2, 9, 4), one_pair), 4)
	all_pairs <- matrix(rep(1:4, each = 2), ncol = 1)
	expect_equal(call_kernel(c(3, 1, 5, 1, 7, 1, 9, 1), all_pairs), 5)
	expect_equal(call_kernel(1:8, matrix(0L, nrow = 8, ncol = 1)), -1)
})

test_that("KK compound bootstrap returns matched-only or missing estimates for undersized reservoirs", {
	w <- cbind(c(1L, 0L, 1L, 0L, 1L, 0L, 0L, 0L), rep(0L, 8))
	m <- cbind(c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L), rep(0L, 8))
	y <- matrix(rep(c(4, 1, 9, 2, 5, 1, 6, 8), 2), nrow = 8)
	expect_equal(EDI:::compute_matching_compound_bootstrap_parallel_cpp(w, m, y, 2L), c(5, NA_real_))
})
