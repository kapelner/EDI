library(testthat)
library(EDI)

# fast_gaussian_lmm.cpp's shared LMMData constructor -- the single group-building entry point every
# exported kernel in this file passes through (fast_gaussian_lmm_cpp, fast_gaussian_lmm_gls_cpp,
# get_gaussian_lmm_score_cpp, get_gaussian_lmm_fisher_cpp) -- validates that no group_id group has
# more than 2 members: `if (grps.back().size > 2) throw std::invalid_argument("fast_gaussian_lmm:
# group %d has more than 2 observations; only matched pairs (size 2) and reservoir singletons (size
# 1) are supported.")`. The source's own comment explains why this guard exists: this model is a
# closed-form solution specific to KK-design matched-pair/reservoir-singleton groups, and a group of
# size > 2 would, uncaught, corrupt memory downstream rather than failing cleanly. A codebase-wide
# grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms this guard
# had no test reference anywhere across all 4 kernels that reach it (the 3 existing reference files
# that call into this file always use real KK matched-pair/reservoir group structures).

fx <- function(seed = 11L, n = 9L) {
	set.seed(seed)
	X <- cbind(1, rnorm(n))
	y <- rnorm(n)
	list(X = X, y = y, bad_group_id = c(1L, 1L, 1L, 2L, 2L, 3L, 4L, 4L, 5L))   # group 1 has 3 members
}
pattern <- "fast_gaussian_lmm: group \\d+ has more than 2 observations"

test_that("fast_gaussian_lmm_cpp rejects a group with more than 2 observations", {
	d <- fx()
	f <- get("fast_gaussian_lmm_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id), pattern)
})

test_that("fast_gaussian_lmm_gls_cpp rejects a group with more than 2 observations", {
	d <- fx(seed = 12L)
	f <- get("fast_gaussian_lmm_gls_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id, 0, 0), pattern)
})

test_that("get_gaussian_lmm_score_cpp rejects a group with more than 2 observations", {
	d <- fx(seed = 13L)
	f <- get("get_gaussian_lmm_score_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id, c(0.1, 0.2, 0, 0)), pattern)
})

test_that("get_gaussian_lmm_fisher_cpp rejects a group with more than 2 observations", {
	d <- fx(seed = 14L)
	f <- get("get_gaussian_lmm_fisher_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id, c(0.1, 0.2, 0, 0)), pattern)
})

test_that("well-formed groups (all size 1 or 2) do not trigger the guard on any of the 4 kernels", {
	d <- fx(seed = 15L)
	good_group_id <- c(1L, 1L, 2L, 2L, 3L, 4L, 4L, 5L, 5L)   # matched pairs and one singleton
	par <- c(0.1, 0.2, 0, 0)

	r1 <- get("fast_gaussian_lmm_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id)
	expect_true(r1$converged)

	r2 <- get("fast_gaussian_lmm_gls_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id, 0, 0)
	expect_true(all(is.finite(r2)))

	r3 <- get("get_gaussian_lmm_score_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id, par)
	expect_true(all(is.finite(r3)))

	r4 <- get("get_gaussian_lmm_fisher_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id, par)
	expect_true(all(is.finite(r4)))
})
