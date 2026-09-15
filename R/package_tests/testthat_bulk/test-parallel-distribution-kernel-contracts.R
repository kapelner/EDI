library(testthat)
library(EDI)

wilcox_location_stat <- function(y, w, delta = 0) {
	y_shifted <- y + ifelse(w == 1L, delta, 0)
	r <- rank(y_shifted, ties.method = "average")
	mean(r[w == 1L]) - mean(r[w == 0L])
}

test_that("parallel OLS distribution agrees with separate lm fits", {
	y <- c(1, 4, 2, 7, 5, 9)
	X <- cbind(x = c(-2, -1, 0, 1, 2, 3))
	w_mat <- cbind(
		c(0L, 1L, 0L, 1L, 0L, 1L),
		c(1L, 0L, 0L, 1L, 1L, 0L),
		c(0L, 0L, 1L, 1L, 0L, 1L)
	)
	delta <- 0.35
	observed <- EDI:::compute_ols_distr_parallel_cpp(X, y, w_mat, delta, 2L)
	expected <- vapply(seq_len(ncol(w_mat)), function(j) {
		w <- w_mat[, j]
		unname(coef(lm((y + delta * w) ~ w + X[, 1]))[[2]])
	}, numeric(1))
	expect_equal(observed, expected, tolerance = 1e-10)
	expect_length(EDI:::compute_ols_distr_parallel_cpp(X, y, w_mat[, FALSE], 0, 1L), 0L)
	expect_error(EDI:::compute_ols_distr_parallel_cpp(X[-1, , drop = FALSE], y, w_mat, 0, 1L), "X rows")
	expect_error(EDI:::compute_ols_distr_parallel_cpp(X, y, w_mat[-1, ], 0, 1L), "w_mat rows")
})

test_that("parallel Wilcoxon matrix and list kernels agree with rank definition", {
	y <- c(1, 2, 2, 5, 8, 13)
	w_mat <- cbind(
		c(0L, 1L, 0L, 1L, 0L, 1L),
		c(1L, 1L, 0L, 0L, 1L, 0L),
		c(0L, 0L, 1L, 1L, 1L, 0L)
	)
	for (delta in c(0, 0.4)) {
		expected <- vapply(seq_len(ncol(w_mat)), function(j) wilcox_location_stat(y, w_mat[, j], delta), numeric(1))
		matrix_result <- EDI:::compute_wilcox_distr_parallel_cpp(w_mat, y, delta, 2L)
		list_result <- EDI:::compute_wilcox_distr_from_list_parallel_cpp(
			lapply(seq_len(ncol(w_mat)), function(j) list(w = w_mat[, j])), y, delta, 2L
		)
		expect_equal(matrix_result, expected)
		expect_equal(list_result, expected)
	}
	degenerate <- cbind(rep(0L, length(y)), rep(1L, length(y)))
	expect_true(all(is.na(EDI:::compute_wilcox_distr_parallel_cpp(degenerate, y, 0, 1L))))
})

test_that("parallel ridit kernel is stable across core counts and reference modes", {
	y <- c(1L, 2L, 2L, 3L, 1L, 4L, 3L, 4L)
	w_mat <- cbind(
		c(0L, 1L, 0L, 1L, 0L, 1L, 0L, 1L),
		c(1L, 1L, 0L, 0L, 1L, 0L, 0L, 1L),
		c(0L, 0L, 1L, 1L, 0L, 0L, 1L, 1L)
	)
	for (reference in c("pooled", "control")) {
		one <- EDI:::compute_ridit_distr_parallel_cpp(y, w_mat, reference, 1L)
		two <- EDI:::compute_ridit_distr_parallel_cpp(y, w_mat, reference, 2L)
		expect_equal(two, one)
		expect_length(one, ncol(w_mat))
		expect_true(all(is.finite(one)))
	}
	all_control <- matrix(0L, nrow = length(y), ncol = 1L)
	expect_true(is.na(EDI:::compute_ridit_distr_parallel_cpp(y, all_control, "pooled", 1L)))
})

test_that("KK Wilcoxon kernel covers fixed and varying matching paths", {
	y <- c(1, 4, 2, 8, 3, 7, 5, 6)
	w_mat <- cbind(
		c(1L, 0L, 0L, 1L, 1L, 0L, 0L, 1L),
		c(0L, 1L, 1L, 0L, 0L, 1L, 1L, 0L)
	)
	m_fixed <- matrix(rep(c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L), 2L), nrow = 8L)
	fixed <- EDI:::compute_matching_wilcox_distr_parallel_cpp(w_mat, m_fixed, y, 0, 0L, 1e-8, TRUE, 2L)
	varying <- EDI:::compute_matching_wilcox_distr_parallel_cpp(w_mat, m_fixed, y, 0, 0L, 1e-8, FALSE, 2L)
	expect_length(fixed, 2L)
	expect_true(all(is.finite(fixed)))
	expect_equal(varying, fixed)

	for (code in 0:4) {
		shifted <- EDI:::compute_matching_wilcox_distr_parallel_cpp(w_mat, m_fixed, y, 0.1, code, 1e-8, TRUE, 1L)
		expect_length(shifted, 2L)
		expect_true(all(is.finite(shifted)))
	}
})

test_that("random-block redraw balances each completed fixed-size block", {
	set.seed(20260915)
	keys <- rep(c("a", "b"), each = 8L)
	w <- EDI:::random_block_size_redraw_w_cpp(keys, 4L, 0.5)
	expect_length(w, length(keys))
	expect_true(all(w %in% 0:1))
	for (idx in split(seq_along(keys), keys)) {
		expect_equal(sum(w[idx[1:4]]), 2)
		expect_equal(sum(w[idx[5:8]]), 2)
	}

	set.seed(9)
	all_treated <- EDI:::random_block_size_redraw_w_cpp(rep("one", 5L), c(2L, 4L), 1)
	expect_equal(all_treated, rep(1, 5L))
})
