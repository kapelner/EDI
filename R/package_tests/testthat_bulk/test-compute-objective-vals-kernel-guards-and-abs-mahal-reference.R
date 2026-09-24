library(testthat)
library(EDI)

# compute_objective_vals_cpp (rerandomization_helpers.cpp) evaluates, for each candidate treatment
# assignment row in indicTs, the covariate-balance objective used by DesignFixedRerandomization's
# greedy/parallel search: either the standardized absolute mean-difference sum ("abs_sum_diff",
# sum_j |diff_j / sd_j|) or the Mahalanobis distance ("mahal_dist", diff' Sinv diff) between the
# treatment- and control-arm covariate means. A codebase-wide grep across testthat_bulk/,
# R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms ZERO test references of any kind for
# this exported kernel, despite being the single production objective-evaluation call site in
# design_fixed_rerandomization.R. It has three independent input guards, none of which had a test
# reference:
#   1. `if (indicTs.ncol() != n) stop("indicTs must have ncol(indicTs) == nrow(X)")`.
#   2. `if (!abs_mode && !mahal_mode) stop("objective must be 'abs_sum_diff' or 'mahal_dist'")`.
#   3. `if (mahal_mode && inv_cov_X.isNull()) stop("inv_cov_X required for mahal_dist")`.
# Both objectives' numeric values are pinned against a from-scratch R reference.

f <- get("compute_objective_vals_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 5L, n = 20L, p = 3L, r = 6L) {
	set.seed(seed)
	X <- matrix(rnorm(n * p), n, p)
	indicTs <- matrix(sample(0:1, n * r, replace = TRUE), r, n)
	for (i in seq_len(r)) if (sum(indicTs[i, ]) %in% c(0L, n)) indicTs[i, 1] <- 1L   # avoid degenerate all-0/all-1 rows
	list(X = X, indicTs = indicTs)
}

test_that("indicTs with the wrong number of columns throws the dimension-mismatch error", {
	d <- fx()
	expect_error(f(d$X, d$indicTs[, 1:5, drop = FALSE], "abs_sum_diff"), "indicTs must have ncol\\(indicTs\\) == nrow\\(X\\)")
})

test_that("an unrecognized objective string throws the objective-name error", {
	d <- fx()
	expect_error(f(d$X, d$indicTs, "bogus"), "objective must be 'abs_sum_diff' or 'mahal_dist'")
})

test_that("mahal_dist without inv_cov_X throws the missing-inv_cov_X error", {
	d <- fx()
	expect_error(f(d$X, d$indicTs, "mahal_dist"), "inv_cov_X required for mahal_dist")
})

test_that("abs_sum_diff matches an independent standardized-mean-difference reference", {
	d <- fx(seed = 6L)
	sd_all <- apply(d$X, 2, sd)
	ref <- vapply(seq_len(nrow(d$indicTs)), function(row) {
		w <- d$indicTs[row, ]
		diff <- colMeans(d$X[w == 1, , drop = FALSE]) - colMeans(d$X[w == 0, , drop = FALSE])
		sum(abs(diff / sd_all))
	}, numeric(1))
	out <- f(d$X, d$indicTs, "abs_sum_diff")
	expect_equal(as.numeric(out), ref, tolerance = 1e-10)
})

test_that("mahal_dist matches an independent Mahalanobis-distance reference", {
	d <- fx(seed = 7L)
	S_inv <- solve(cov(d$X))
	ref <- vapply(seq_len(nrow(d$indicTs)), function(row) {
		w <- d$indicTs[row, ]
		diff <- colMeans(d$X[w == 1, , drop = FALSE]) - colMeans(d$X[w == 0, , drop = FALSE])
		as.numeric(t(diff) %*% S_inv %*% diff)
	}, numeric(1))
	out <- f(d$X, d$indicTs, "mahal_dist", S_inv)
	expect_equal(as.numeric(out), ref, tolerance = 1e-10)
})
