library(testthat)
library(EDI)

# compute_rand_bootstrap_mean_diff_parallel_cpp (rand_bootstrap_mean_diff_parallel.cpp) applies a
# sharp-null shift to the treated arm's resampled outcomes before differencing means; brt_apply_shift
# dispatches on transform_code: 0 = additive, 1 = multiplicative-log, 2 = logit (proportion
# responses, clamped to [clamp, 1-clamp] both before and after the shift), 4 = multiplicative-log
# with rounding to the nearest count (count responses). The existing reference test
# (test-average-diff-brt-null-statistics-with-se-serial-path-and-kernel-layout-reference.R) never
# passes a nonzero delta with transform_code 2 or 4, so brt_logit/brt_inv_logit/brt_apply_shift's
# logit and count-rounding branches had no test reference anywhere -- only the additive default was
# exercised.

f <- get("compute_rand_bootstrap_mean_diff_parallel_cpp", envir = asNamespace("EDI"))

brt_logit_ref <- function(x, clamp) { x <- pmin(pmax(x, clamp), 1 - clamp); log(x / (1 - x)) }
brt_inv_logit_ref <- function(x, clamp) pmin(pmax(plogis(x), clamp), 1 - clamp)
shift_logit_ref <- function(y, delta, clamp) brt_inv_logit_ref(brt_logit_ref(y, clamp) + delta, clamp)

test_that("transform_code = 2 (logit) shifts only the treated arm, matching an independent logit-shift reference", {
	set.seed(1); n <- 20L
	y0 <- runif(n, 0.05, 0.95)
	w <- rep(0:1, length.out = n)
	i_mat <- matrix(1:n, n, 1); w_mat <- matrix(w, n, 1)
	clamp <- 1e-6

	for (delta in c(0.5, -0.8, 1.3)) {
		got <- f(y0, i_mat, w_mat, delta, 2L, clamp, NULL, 1L)
		ref <- mean(shift_logit_ref(y0[w == 1], delta, clamp)) - mean(y0[w == 0])
		expect_equal(as.numeric(got), ref, tolerance = 1e-10, info = delta)
	}
	# delta = 0 skips the shift call entirely (untransformed treated mean)
	got0 <- f(y0, i_mat, w_mat, 0, 2L, clamp, NULL, 1L)
	expect_equal(as.numeric(got0), mean(y0[w == 1]) - mean(y0[w == 0]), tolerance = 1e-12)
})

test_that("logit shift clamps extreme post-shift probabilities into [clamp, 1 - clamp]", {
	n <- 6L
	y0 <- c(0.99, 0.99, 0.99, 0.01, 0.01, 0.01)
	w <- c(1L, 1L, 1L, 0L, 0L, 0L)
	i_mat <- matrix(1:n, n, 1); w_mat <- matrix(w, n, 1)
	clamp <- 1e-4
	got <- f(y0, i_mat, w_mat, 20, 2L, clamp, NULL, 1L)  # huge positive delta pushes every treated row to the upper clamp
	ref <- mean(shift_logit_ref(y0[w == 1], 20, clamp)) - mean(y0[w == 0])
	expect_equal(as.numeric(got), ref, tolerance = 1e-10)
	expect_equal(as.numeric(shift_logit_ref(y0[w == 1], 20, clamp)), rep(1 - clamp, 3), tolerance = 1e-10)
})

test_that("transform_code = 4 (count) shifts only the treated arm and rounds to the nearest count", {
	set.seed(2); n <- 30L
	y0 <- rpois(n, 5)
	w <- rep(0:1, length.out = n)
	i_mat <- matrix(1:n, n, 1); w_mat <- matrix(w, n, 1)

	for (delta in c(0.4, -0.6, 0.9)) {
		got <- f(y0, i_mat, w_mat, delta, 4L, 1e-6, NULL, 1L)
		ref <- mean(round(y0[w == 1] * exp(delta))) - mean(y0[w == 0])
		expect_equal(as.numeric(got), ref, tolerance = 1e-10, info = delta)
	}
})
