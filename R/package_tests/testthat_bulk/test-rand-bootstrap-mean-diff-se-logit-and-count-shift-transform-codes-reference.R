library(testthat)
library(EDI)

# compute_rand_bootstrap_mean_diff_se_parallel_cpp (rand_bootstrap_mean_diff_parallel.cpp) is the
# batch mean-diff-plus-Welch-SE sibling of compute_rand_bootstrap_mean_diff_parallel_cpp: it applies
# the same brt_apply_shift sharp-null shift to the treated arm before computing both statistics. The
# existing reference test (test-average-diff-brt-null-statistics-with-se-serial-path-and-kernel-
# layout-reference.R) only calls it with delta = 0 and transform_code = 0L, so its own call site of
# the logit (transform_code 2, proportion) and count-rounding (transform_code 4, count) shift
# branches had no test reference anywhere -- distinct coverage from the identically-shaped call site
# in the no-SE point-estimate kernel (already closed separately).

f <- get("compute_rand_bootstrap_mean_diff_se_parallel_cpp", envir = asNamespace("EDI"))

brt_logit_ref <- function(x, clamp) { x <- pmin(pmax(x, clamp), 1 - clamp); log(x / (1 - x)) }
brt_inv_logit_ref <- function(x, clamp) pmin(pmax(plogis(x), clamp), 1 - clamp)
shift_logit_ref <- function(y, delta, clamp) brt_inv_logit_ref(brt_logit_ref(y, clamp) + delta, clamp)

test_that("transform_code = 2 (logit) shifts the treated arm before computing mean-diff and Welch SE", {
	set.seed(1); n <- 20L
	y0 <- runif(n, 0.05, 0.95)
	w <- rep(0:1, length.out = n)
	i_mat <- matrix(1:n, n, 1); w_mat <- matrix(w, n, 1)
	clamp <- 1e-6

	for (delta in c(0.5, -0.8, 1.3)) {
		got <- f(y0, i_mat, w_mat, delta, 2L, clamp, 1L)
		yT <- shift_logit_ref(y0[w == 1], delta, clamp); yC <- y0[w == 0]
		ref_mean <- mean(yT) - mean(yC)
		ref_se <- sqrt(var(yT) / length(yT) + var(yC) / length(yC))
		expect_equal(got[1, 1], ref_mean, tolerance = 1e-10, info = delta)
		expect_equal(got[2, 1], ref_se, tolerance = 1e-10, info = delta)
	}
})

test_that("transform_code = 4 (count) shifts the treated arm, rounds, and computes mean-diff and Welch SE", {
	set.seed(2); n <- 30L
	y0 <- rpois(n, 5)
	w <- rep(0:1, length.out = n)
	i_mat <- matrix(1:n, n, 1); w_mat <- matrix(w, n, 1)

	for (delta in c(0.4, -0.6, 0.9)) {
		got <- f(y0, i_mat, w_mat, delta, 4L, 1e-6, 1L)
		yT <- round(y0[w == 1] * exp(delta)); yC <- y0[w == 0]
		ref_mean <- mean(yT) - mean(yC)
		ref_se <- sqrt(var(yT) / length(yT) + var(yC) / length(yC))
		expect_equal(got[1, 1], ref_mean, tolerance = 1e-10, info = delta)
		expect_equal(got[2, 1], ref_se, tolerance = 1e-10, info = delta)
	}
})
