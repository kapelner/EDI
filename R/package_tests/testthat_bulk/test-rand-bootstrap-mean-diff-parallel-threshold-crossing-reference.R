library(testthat)
library(EDI)

# compute_rand_bootstrap_mean_diff_parallel_cpp / compute_rand_bootstrap_mean_diff_se_parallel_cpp
# (rand_bootstrap_mean_diff_parallel.cpp) gate their OpenMP-parallel dispatch on should_parallelize_
# replicates(nsim, n, num_cores): TRUE only when num_cores > 1 AND nsim >= 128 AND n * nsim >= 20000.
# Both existing reference tests for these kernels (test-rand-bootstrap-mean-diff-logit-and-count-shift-
# transform-codes-reference.R and its *-se-* sibling) always call with num_cores = 1L, so use_parallel
# is always FALSE there -- the omp_set_num_threads()/`#pragma omp ... if(use_parallel)` branch itself
# had no test reference anywhere (flagged explicitly in coverage_gap_registry.csv's notes for this
# file: "the remaining gap is ... the OpenMP thread-setting under should_parallelize_replicates").
# should_parallelize_replicates() only inspects the REQUESTED num_cores, nsim and n -- not actual
# hardware core count -- so requesting num_cores = 2L with nsim/n large enough reliably takes the
# use_parallel = TRUE path even on a single-core sandbox; the loop body itself is embarrassingly
# parallel (each replicate b only reads its own i_mat/w_mat column and writes its own output slot),
# so this is safe and fast to exercise directly. Verified against independent R references.

f <- get("compute_rand_bootstrap_mean_diff_parallel_cpp", envir = asNamespace("EDI"))
f_se <- get("compute_rand_bootstrap_mean_diff_se_parallel_cpp", envir = asNamespace("EDI"))

mk <- function(seed, n = 200L, nsim = 150L) {
	set.seed(seed)
	list(
		y0 = rnorm(n),
		i_mat = matrix(sample.int(n, n * nsim, replace = TRUE), n, nsim),
		w_mat = matrix(sample(0:1, n * nsim, replace = TRUE), n, nsim),
		n = n, nsim = nsim
	)
}

ref_mean_diff <- function(f, delta, transform) {
	yv <- f$y0[f$i_mat[, 1]]
	wv <- f$w_mat[, 1]
	yv[wv == 1] <- transform(yv[wv == 1])
	mean(yv[wv == 1]) - mean(yv[wv == 0])
}

test_that("requesting num_cores > 1 with nsim/n large enough (crossing the 128-replicate / 20000-total-work parallel threshold) gives results identical to num_cores = 1, matching an independent R reference for every replicate", {
	f_x <- mk(1L)
	stopifnot(f_x$nsim * f_x$n >= 20000L, f_x$nsim >= 128L)  # sanity-check the fixture actually crosses the threshold
	delta <- 0.4

	got_serial <- f(f_x$y0, f_x$i_mat, f_x$w_mat, delta, 1L, 1e-6, NULL, 1L)
	got_parallel <- f(f_x$y0, f_x$i_mat, f_x$w_mat, delta, 1L, 1e-6, NULL, 2L)
	expect_equal(got_parallel, got_serial)  # embarrassingly parallel: bit-identical regardless of thread count

	ref <- vapply(seq_len(f_x$nsim), function(b) {
		yv <- f_x$y0[f_x$i_mat[, b]]; wv <- f_x$w_mat[, b]
		yv[wv == 1] <- yv[wv == 1] * exp(delta)
		mean(yv[wv == 1]) - mean(yv[wv == 0])
	}, numeric(1))
	expect_equal(as.numeric(got_parallel), ref, tolerance = 1e-9)
})

test_that("the parallel-threshold path also works correctly for the logit (transform_code = 2) and count-rounding (transform_code = 4) shift branches", {
	f_x <- mk(2L)
	for (tc in list(list(code = 2L, fn = function(y) pmin(pmax(plogis(qlogis(pmin(pmax(y, 1e-6), 1 - 1e-6)) + 0.5), 1e-6), 1 - 1e-6), delta = 0.5, clamp = 1e-6),
	                 list(code = 4L, fn = function(y) round(y * exp(-0.3)), delta = -0.3, clamp = 1e-6))) {
		got <- f(f_x$y0, f_x$i_mat, f_x$w_mat, tc$delta, tc$code, tc$clamp, NULL, 2L)
		ref <- vapply(seq_len(f_x$nsim), function(b) {
			yv <- f_x$y0[f_x$i_mat[, b]]; wv <- f_x$w_mat[, b]
			yv[wv == 1] <- tc$fn(yv[wv == 1])
			mean(yv[wv == 1]) - mean(yv[wv == 0])
		}, numeric(1))
		expect_equal(as.numeric(got), ref, tolerance = 1e-8, info = paste("transform_code", tc$code))
	}
})

test_that("the SE-returning parallel kernel crosses the same threshold and matches independent t0/se0 references", {
	f_x <- mk(3L)
	delta <- -0.3
	got <- f_se(f_x$y0, f_x$i_mat, f_x$w_mat, delta, 4L, 1e-6, 2L)
	ref_t0 <- numeric(f_x$nsim); ref_se0 <- numeric(f_x$nsim)
	for (b in seq_len(f_x$nsim)) {
		yv <- f_x$y0[f_x$i_mat[, b]]; wv <- f_x$w_mat[, b]
		yv[wv == 1] <- round(yv[wv == 1] * exp(delta))
		ref_t0[b] <- mean(yv[wv == 1]) - mean(yv[wv == 0])
		ref_se0[b] <- sqrt(stats::var(yv[wv == 1]) / sum(wv == 1) + stats::var(yv[wv == 0]) / sum(wv == 0))
	}
	expect_equal(got[1, ], ref_t0, tolerance = 1e-8)
	expect_equal(got[2, ], ref_se0, tolerance = 1e-8)

	got_serial <- f_se(f_x$y0, f_x$i_mat, f_x$w_mat, delta, 4L, 1e-6, 1L)
	expect_equal(got, got_serial)
})

test_that("just below the threshold (nsim = 127) falls back to the serial branch and still agrees with the reference", {
	f_x <- mk(4L, n = 200L, nsim = 127L)
	got <- f(f_x$y0, f_x$i_mat, f_x$w_mat, 0.2, 1L, 1e-6, NULL, 2L)
	ref <- vapply(seq_len(f_x$nsim), function(b) {
		yv <- f_x$y0[f_x$i_mat[, b]]; wv <- f_x$w_mat[, b]
		yv[wv == 1] <- yv[wv == 1] * exp(0.2)
		mean(yv[wv == 1]) - mean(yv[wv == 0])
	}, numeric(1))
	expect_equal(as.numeric(got), ref, tolerance = 1e-9)
})
