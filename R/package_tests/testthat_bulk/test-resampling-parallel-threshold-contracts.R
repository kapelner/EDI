library(testthat)
library(EDI)

# 128 columns * 160 subjects exceeds both should_parallelize_replicates
# gates (128 replicates and 20,000 total work), while staying a small shard.
make_threshold_resampling_fixture <- function() {
	set.seed(20260916)
	n <- 160L
	B <- 128L
	list(
		X = cbind(x = rnorm(n)), y = rnorm(n),
		y_ord = sample(1:5, n, replace = TRUE),
		w = rep(0:1, n / 2L),
		w_mat = replicate(B, sample(rep(0:1, n / 2L))),
		indices = replicate(B, sample.int(n, n, replace = TRUE))
	)
}

threshold_ridit_reference <- function(y, w, reference) {
	target <- y[w == 1L]
	ref <- switch(reference, pooled = y, control = y[w == 0L], treatment = target)
	if (!length(target) || !length(ref)) return(NA_real_)
	levels <- sort(unique(ref))
	scores <- vapply(levels, function(z) mean(ref < z) + mean(ref == z) / 2, numeric(1))
	# The kernel interpolates scores for categories absent from the reference.
	mapped <- approx(levels, scores, xout = target, rule = 1)$y
	mapped[target < min(levels)] <- 0
	mapped[target > max(levels)] <- 1
	mean(mapped) - .5
}

test_that("OLS bootstrap parallel dispatch preserves zero-based sample indices", {
	f <- make_threshold_resampling_fixture()
	indices0 <- f$indices - 1L
	expected <- vapply(seq_len(ncol(indices0)), function(b) {
		i <- f$indices[, b]
		unname(lm.fit(cbind(1, f$w[i], f$X[i, , drop = FALSE]), f$y[i])$coefficients[2])
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0, cores), expected, tolerance = 1e-10)
	}
	indices0[1, 1] <- -1L
	expect_true(is.na(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0, 2L)[1]))
	short <- indices0[1:40, 2:4, drop = FALSE]
	expected_short <- vapply(seq_len(ncol(short)), function(b) {
		i <- short[, b] + 1L
		unname(lm.fit(cbind(1, f$w[i], f$X[i, , drop = FALSE]), f$y[i])$coefficients[2])
	}, numeric(1))
	expect_equal(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, short, 0L), expected_short, tolerance = 1e-10)
	expect_length(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w, indices0[, FALSE], 2L), 0L)
	expect_error(EDI:::compute_ols_bootstrap_parallel_cpp(f$X, f$y, f$w[-1], indices0, 1L), "length must match")
})

test_that("ridit bootstrap kernels agree with empirical reference scores above the parallel gate", {
	f <- make_threshold_resampling_fixture()
	for (reference in c("pooled", "control", "treatment")) {
		expected_boot <- vapply(seq_len(ncol(f$indices)), function(b) {
			i <- f$indices[, b]
			threshold_ridit_reference(f$y_ord[i], f$w[i], reference)
		}, numeric(1))
		expected_rand <- vapply(seq_len(ncol(f$indices)), function(b) {
			threshold_ridit_reference(f$y_ord[f$indices[, b]], f$w_mat[, b], reference)
		}, numeric(1))
		for (cores in c(1L, 2L)) {
			expect_equal(EDI:::compute_ridit_bootstrap_parallel_cpp(f$w, f$y_ord, f$indices, reference, cores), expected_boot)
			expect_equal(EDI:::compute_ridit_rand_bootstrap_parallel_cpp(f$y_ord, f$indices, f$w_mat, reference, cores), expected_rand)
		}
	}
	indices <- f$indices
	indices[1, 1] <- -1L
	expect_true(is.na(EDI:::compute_ridit_bootstrap_parallel_cpp(f$w, f$y_ord, indices, "control", 2L)[1]))
})

test_that("randomization bootstrap OLS shifts resampled noisy responses before fitting", {
	f <- make_threshold_resampling_fixture()
	noise <- matrix(sin(seq_along(f$indices)) / 10, nrow = nrow(f$indices))
	delta <- .4
	expected <- vapply(seq_len(ncol(f$indices)), function(b) {
		i <- f$indices[, b]
		w <- f$w_mat[, b]
		unname(lm.fit(cbind(1, w, f$X[i, , drop = FALSE]), f$y[i] + noise[, b] + delta * w)$coefficients[2])
	}, numeric(1))
	for (cores in c(1L, 2L)) {
		expect_equal(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, f$indices, f$w_mat, delta, noise, cores), expected, tolerance = 1e-10)
	}
	degenerate_w <- cbind(rep(0L, length(f$y)), rep(1L, length(f$y)))
	expect_true(all(is.na(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, f$indices[, 1:2], degenerate_w, delta, NULL, 2L))))
	# Three observations cannot identify intercept, treatment, and covariate
	# with residual degrees of freedom; the kernel leaves this replicate NA.
	expect_true(is.na(EDI:::compute_rand_bootstrap_ols_parallel_cpp(f$y, f$X, matrix(1:3, ncol = 1), matrix(c(0L, 1L, 0L), ncol = 1), delta, NULL, 1L)))
})

test_that("OLS and tied-rank randomization distributions agree with R above the parallel gate", {
	f <- make_threshold_resampling_fixture()
	for (delta in c(0, .35)) {
		expected_ols <- vapply(seq_len(ncol(f$w_mat)), function(b) {
			w <- f$w_mat[, b]
			unname(lm.fit(cbind(1, w, f$X), f$y + delta * w)$coefficients[2])
		}, numeric(1))
		expected_rank <- vapply(seq_len(ncol(f$w_mat)), function(b) {
			w <- f$w_mat[, b]
			r <- rank(f$y_ord + delta * w)
			mean(r[w == 1L]) - mean(r[w == 0L])
		}, numeric(1))
		expect_equal(EDI:::compute_ols_distr_parallel_cpp(f$X, f$y, f$w_mat, delta, 2L), expected_ols, tolerance = 1e-10)
		expect_equal(EDI:::compute_wilcox_distr_parallel_cpp(f$w_mat, as.numeric(f$y_ord), delta, 2L), expected_rank)
		expect_equal(EDI:::compute_wilcox_distr_from_list_parallel_cpp(lapply(seq_len(ncol(f$w_mat)), function(b) list(w = f$w_mat[, b])), as.numeric(f$y_ord), delta, 2L), expected_rank)
	}
})

test_that("bisection nonfinite midpoints move the conservative search boundary", {
	# Missing midpoints are rejected on both tails of a two-sided p-value.
	# The lower and upper searches must still find their .6 and 1.4 crossings.
	pval <- function(r, delta, transform_responses, num_cores) {
		if (delta %in% c(.5, 1.5)) NA_real_ else min(delta, 2 - delta)
	}
	expect_equal(EDI:::bisection_ci_single_bound_cpp(pval, 1L, 0, 1, .6, .01, "none", TRUE, 2L), .6, tolerance = .01)
	expect_equal(EDI:::bisection_ci_parallel_cpp(pval, 1L, 0, 1, 1, 2, .6, .01, "none", 2L), c(.6, 1.4), tolerance = .01)
})
