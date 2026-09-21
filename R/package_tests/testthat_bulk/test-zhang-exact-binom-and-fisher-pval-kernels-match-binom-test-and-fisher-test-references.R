library(testthat)
library(EDI)

# zhang_exact_binom_pval_cpp(d_plus, d_minus, delta_0) and zhang_exact_fisher_pval_cpp(n11, n10, n01, n00, delta_0):
# two-sided exact p-values under H0: log OR = delta_0. References: stats::binom.test with p0 = plogis(delta_0), and
# stats::fisher.test(or = exp(delta_0)) (same 1 + 1e-7 relative tolerance rule for "as or more extreme").

Z <- function(x) get(x, envir = asNamespace("EDI"))
B <- Z("zhang_exact_binom_pval_cpp"); Fi <- Z("zhang_exact_fisher_pval_cpp")

test_that("binomial kernel equals binom.test at p0 = plogis(delta_0) across counts and shifts", {
	for (dp in c(0, 1, 3, 7, 12)) for (dm in c(0, 2, 5, 9)) {
		if (dp + dm == 0) next
		for (d in c(-1.5, 0, 0.4, 2)) {
			expect_equal(B(dp, dm, d), binom.test(dp, dp + dm, plogis(d))$p.value, tolerance = 1e-9, info = paste(dp, dm, d))
		}
	}
})

test_that("binomial kernel: symmetric under swapping counts and negating the shift; bounded in [0, 1]", {
	expect_equal(B(7, 3, 0.4), B(3, 7, -0.4), tolerance = 1e-12)
	expect_equal(B(5, 5, 0), 1)
	set.seed(1); for (i in 1:20) { p <- B(sample(0:20, 1), sample(1:20, 1), rnorm(1)); expect_true(p >= 0 && p <= 1) }
})

test_that("binomial kernel returns NA for no discordant pairs, negative counts, or non-finite shifts", {
	expect_true(is.na(B(0L, 0L, 0)))
	expect_true(is.na(B(-1L, 3L, 0)))
	expect_true(is.na(B(3L, -1L, 0)))
	expect_true(is.na(B(3L, 2L, NA_real_)))
	expect_true(is.na(B(3L, 2L, Inf)))
	expect_true(is.na(B(3L, 2L, -Inf)))
})

test_that("Fisher kernel equals fisher.test(or = exp(delta_0)) on 2x2 tables, including boundary and balanced tables", {
	tabs <- list(c(5, 2, 3, 7), c(0, 4, 4, 0), c(3, 3, 3, 3), c(10, 0, 0, 10), c(1, 8, 6, 2), c(12, 5, 4, 15))
	for (a in tabs) for (d in c(0, 0.7, -1.2, 2.5)) {
		ref <- fisher.test(matrix(a, 2, byrow = TRUE), or = exp(d))$p.value
		expect_equal(Fi(a[1], a[2], a[3], a[4], d), ref, tolerance = 1e-8, info = paste(a, collapse = ","), label = d)
	}
})

test_that("Fisher kernel table layout: [n11 n10; n01 n00] with the first row/column as the treated-success margins", {
	# swapping both margins (transposing) leaves the two-sided p-value unchanged
	expect_equal(Fi(5, 2, 3, 7, 0.3), Fi(5, 3, 2, 7, 0.3), tolerance = 1e-12)
	# a sign flip of delta with the table's columns swapped gives the same p-value
	expect_equal(Fi(5, 2, 3, 7, 0.9), Fi(2, 5, 7, 3, -0.9), tolerance = 1e-12)
})

test_that("Fisher kernel: degenerate margins give 1, invalid inputs give NA, extreme shifts underflow to 0", {
	expect_equal(Fi(0L, 0L, 3L, 4L, 0), 1)
	expect_equal(Fi(5L, 0L, 0L, 0L, 0), 1)
	expect_equal(Fi(0L, 0L, 0L, 0L, 0), 1)
	expect_true(is.na(Fi(-1L, 2L, 3L, 4L, 0)))
	expect_true(is.na(Fi(5L, 2L, 3L, 7L, Inf)))
	expect_true(is.na(Fi(5L, 2L, 3L, 7L, NA_real_)))
	expect_equal(Fi(5L, 2L, 3L, 7L, 800), 0)
	expect_equal(Fi(5L, 2L, 3L, 7L, -800), 0)
})

test_that("p-values are non-increasing as the null moves away from the MLE side and reach 1 near the conditional MLE", {
	ds <- seq(-3, 3, by = 0.25); ps <- vapply(ds, function(d) Fi(12L, 5L, 4L, 15L, d), 0)
	expect_gt(max(ps), 0.9)
	peak <- which.max(ps)
	expect_true(all(diff(ps[seq_len(peak)]) >= -1e-9)); expect_true(all(diff(ps[peak:length(ps)]) <= 1e-9))
})
