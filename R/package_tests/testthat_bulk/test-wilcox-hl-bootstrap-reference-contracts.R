library(testthat)
library(EDI)

# Two-core cases regress interrupt polling from HL median helpers inside workers.

walsh_median_reference <- function(d) {
	a <- outer(d, d, "+") / 2
	median(a[upper.tri(a, diag = TRUE)])
}

test_that("HL bootstrap compares resampled arms using the median of pairwise differences", {
	y <- c(1, 3, 4, 9, NA, Inf, 2, 8)
	w <- c(1L, 0L, 1L, 0L, 1L, 0L, 2L, 1L)
	indices <- cbind(0:7, c(7L, 0L, 0L, 1L, 3L, 8L, -1L, 6L), rep(0L, 8), rep(-1L, 8))
	storage.mode(indices) <- "integer"
	expected <- c(median(outer(c(1, 4, 8), c(3, 9), "-")), median(outer(c(8, 1, 1), c(3, 9), "-")), NA, NA)
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_wilcox_hl_bootstrap_parallel_cpp(w, y, indices, cores), expected)
	}
})

test_that("KK HL bootstrap respects remapped pairs and inverse variance weights", {
	y <- c(4, 1, 9, 2, 5, 1, 8, 3)
	w <- rep(c(1L, 0L), 4)
	original_m <- c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L)
	indices <- cbind(1:8, c(3L, 4L, 1L, 2L, 7L, 8L, 5L, 6L), 1:8)
	# Column two reverses sampled pairs; its IDs belong to the resampled
	# positions. Column three deliberately uses an entirely new matching.
	m <- cbind(original_m, original_m, rep(1:4, each = 2))
	walsh <- c(3, 5, 7)
	reservoir_diffs <- as.numeric(outer(c(5, 8), c(1, 3), "-"))
	expected_mixed <- weighted.mean(c(median(walsh), median(reservoir_diffs)), 1 / c(var(walsh) / 2, var(reservoir_diffs) / 4))
	expected_paired <- walsh_median_reference(c(3, 7, 4, 5))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_wilcox_matching_ivwc_bootstrap_parallel_cpp(w, y, original_m, indices, m, cores), c(expected_mixed, expected_mixed, expected_paired))
	}
})

test_that("KK HL bootstrap discards incomplete and same-arm pairs while retaining the reservoir", {
	y <- c(4, 1, 9, 2, 5, 1, 8, 3)
	w <- rep(c(1L, 0L), 4)
	indices <- cbind(c(1L, 3L, 0L, 0L, 5L, 6L, 7L, 8L), rep(1L, 8))
	# Pair one is treatment-treatment and pair two has invalid zero indices.
	m <- cbind(c(1L, 1L, 2L, 2L, 0L, 0L, 0L, 0L), rep(0L, 8))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_wilcox_matching_ivwc_bootstrap_parallel_cpp(w, y, integer(8), indices, m, cores), c(median(outer(c(5, 8), c(1, 3), "-")), NA))
	}
})

test_that("smoothed HL randomization bootstrap agrees with transformed pairwise medians", {
	y <- c(0, 1, .2, .8, .4, .6)
	i_mat <- cbind(1:6, c(6L, 1L, 3L, 3L, 5L, 2L))
	w_mat <- cbind(c(1L, 0L, 1L, 0L, 1L, 0L), c(0L, 1L, 0L, 1L, 0L, 1L))
	noise <- matrix(c(.03, -.04, .02, -.02, .01, -.01, -.05, .01, 0, .02, 0, -.03), nrow = 6)
	clamp <- .01
	for (delta in c(-.7, .7)) {
		expected <- vapply(seq_len(ncol(i_mat)), function(b) {
			z <- y[i_mat[, b]] + noise[, b]
			t <- z[w_mat[, b] == 1L]
			t <- pmin(1 - clamp, pmax(clamp, plogis(qlogis(pmin(1 - clamp, pmax(clamp, t))) + delta)))
			median(outer(t, z[w_mat[, b] == 0L], "-"))
		}, numeric(1))
		for (cores in c(1L, 2L)) {
			expect_equal(EDI:::compute_wilcox_hl_rand_bootstrap_parallel_cpp(y, i_mat, w_mat, delta, 2L, clamp, noise, cores), expected)
		}
	}
})

test_that("two-core HL medians above the materialization threshold match exact differences", {
	y <- sin(seq_len(160)) + seq_len(160) / 100
	w <- rep(c(1L, 0L), 80)
	indices <- cbind(0:159, 159:0, c(0:79, 0:79))
	expected <- vapply(seq_len(ncol(indices)), function(b) {
		sampled <- indices[, b] + 1L
		median(outer(y[sampled[w[sampled] == 1L]], y[sampled[w[sampled] == 0L]], "-"))
	}, numeric(1))
	# Each allocation has 80 * 80 = 6400 contrasts, exceeding the 4096 cutoff.
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_wilcox_hl_bootstrap_parallel_cpp(w, y, indices, cores), expected,
		             tolerance = 1e-12)
	}
	assignments <- cbind(w, 1L - w)
	expected_rand <- vapply(seq_len(ncol(assignments)), function(b) {
		median(outer(y[assignments[, b] == 1L], y[assignments[, b] == 0L], "-"))
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_wilcox_hl_distr_parallel_cpp(assignments, y, 0, 0L, 1e-8, cores),
		             expected_rand, tolerance = 1e-12)
	}
})
