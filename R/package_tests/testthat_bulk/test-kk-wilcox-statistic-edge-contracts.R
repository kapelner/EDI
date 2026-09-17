library(testthat)
library(EDI)

test_that("KK Wilcoxon combines centered paired and reservoir rank statistics", {
	# Pair differences are 3,-1,0; absolute ranks are 3,2,1 and the
	# zero contributes half its rank, giving W+ = 3.5 with null mean 3.
	y <- c(4, 1, 1, 2, 5, 5, 3, 1, 4, 2)
	w <- c(1L, 0L, 1L, 0L, 1L, 0L, 1L, 0L, 1L, 0L)
	m <- c(1L, 1L, 2L, 2L, 3L, 3L, 0L, 0L, 0L, 0L)
	w_mat <- cbind(w, 1L - w)
	m_mat <- cbind(m, m)
	# Reservoir treatment ranks 3,4 sum to 7, versus null mean 5.
	expected <- .5 / sqrt(3.5) + 2 / sqrt(5 / 3)
	for (fixed in c(TRUE, FALSE)) {
		expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(w_mat, m_mat, y, 0, 0L, 1e-8, fixed, 2L), c(expected, -expected))
	}
	# Common translation leaves ranks of differences and reservoir unchanged.
	expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(w_mat, m_mat, y + 100, 0, 0L, 1e-8, TRUE, 2L), c(expected, -expected))
})

test_that("KK Wilcoxon treats tied differences, all-zero pairs, and missing reservoirs explicitly", {
	w <- matrix(rep(c(1L, 0L), 3), ncol = 1)
	m <- matrix(rep(1:3, each = 2), ncol = 1)
	# Differences 2,2,-2 all have rank 2; positive rank sum is 4.
	for (fixed in c(TRUE, FALSE)) {
		expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(w, m, c(3, 1, 4, 2, 1, 3), 0, 0L, 1e-8, fixed, 2L), 1 / sqrt(3.5))
		expect_true(is.na(EDI:::compute_matching_wilcox_distr_parallel_cpp(w, m, rep(2, 6), 0, 0L, 1e-8, fixed, 2L)))
		# With no matches, this is the standardized two-sample rank sum.
		expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(w, matrix(0L, nrow = 6, ncol = 1), c(4, 1, 5, 2, 6, 3), 0, 0L, 1e-8, fixed, 2L), 4.5 / sqrt(21 / 4))
		expect_true(is.na(EDI:::compute_matching_wilcox_distr_parallel_cpp(matrix(0L, nrow = 6, ncol = 1), matrix(0L, nrow = 6, ncol = 1), 1:6, 0, 0L, 1e-8, fixed, 2L)))
	}
})

test_that("varying KK Wilcoxon matching ignores incomplete pairs rather than inventing responses", {
	w <- cbind(c(1L, 1L, 1L, 0L), c(1L, 0L, 0L, 0L))
	m <- matrix(rep(c(1L, 1L, 2L, 2L), 2), nrow = 4)
	# Each column has one valid pair with positive difference; a one-pair
	# signed statistic is (1 - .5)/.5 = 1 regardless of its magnitude.
	expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(w, m, c(4, 1, 3, 2), 0, 0L, 1e-8, FALSE, 2L), c(1, 1))
})

test_that("KK Wilcoxon sharp-null transformations agree with R rank scores", {
	y <- c(.1, .3, .8, .4, .9, .6, .2, .7, .3, .4, .6, .8)
	w <- rep(c(1L, 0L), 6)
	m <- c(rep(1:4, each = 2), rep(0L, 4))
	delta <- .35
	for (code in 0:4) {
		base <- if (code == 4L) y * 10 else y
		shifted <- base
		shifted[w == 1L] <- switch(as.character(code),
			"0" = base[w == 1L] + delta,
			"1" = base[w == 1L] * exp(delta),
			"2" = plogis(qlogis(base[w == 1L]) + delta),
			"3" = (base[w == 1L] + 1) * exp(delta) - 1,
			"4" = round(base[w == 1L] * exp(delta)))
		diffs <- shifted[seq(1, 7, 2)] - shifted[seq(2, 8, 2)]
		r <- rank(abs(diffs))
		pair_score <- (sum(r[diffs > 0]) + sum(r[diffs == 0]) / 2 - 5) / sqrt(7.5)
		reservoir_score <- (sum(rank(shifted[9:12])[c(1, 3)]) - 5) / sqrt(5 / 3)
		for (fixed in c(TRUE, FALSE)) {
			expect_equal(EDI:::compute_matching_wilcox_distr_parallel_cpp(matrix(w, ncol = 1), matrix(m, ncol = 1), base, delta, code, 1e-8, fixed, 2L), pair_score + reservoir_score)
		}
	}
})
