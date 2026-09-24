library(testthat)
library(EDI)

# fast_ordinal_glmm_cpp (fast_ordinal_glmm.cpp, the actual fitter, not the score/hessian/neg_loglik
# evaluators already closed this stretch in test-ordinal-glmm-score-hessian-neg-loglik-input-guards-
# reference.R) validates its inputs through fast_ordinal_glmm_internal() with 4 independent guards,
# each with its own distinct message -- a different, earlier set of checks than the evaluators'
# single combined "invalid ordinal GLMM evaluation inputs" message:
#   1. `if (n <= 0 || p <= 0 || y.size() != n || group_id.size() != n) throw std::invalid_argument(
#      "ordinal GLMM requires non-empty, row-aligned X, y, and group_id")`.
#   2. `if (K < 2 || j_T < 0 || j_T >= p) throw std::invalid_argument("ordinal GLMM requires K >= 2
#      and a valid zero-based j_T")`.
#   3. `if (!isfinite(max_abs_log_sigma) || max_abs_log_sigma <= 0 || !isfinite(eps_g) || eps_g <= 0
#      || maxit <= 0 || n_gh <= 0) throw std::invalid_argument("ordinal GLMM numerical controls must
#      be finite and positive")`.
#   4. `if (y[i] < 1 || y[i] > K || group_id[i] == INT_MIN) throw std::invalid_argument("ordinal GLMM
#      y/group_id contains an invalid value")`.
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms none of these 4 fitter-level guards had a test reference anywhere -- the existing
# InferenceOrdinalKKGLMM reference/guard files (test-ordinal-kk-glmm-rcpp-failed-and-variance-
# nonestimable-guards-reference.R etc.) exercise real fit-failure/nonestimable-estimate scenarios,
# never these hard input-validation guards directly.

f <- get("fast_ordinal_glmm_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 11L, G = 10L, m = 4L) {
	set.seed(seed)
	n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(rnorm(n))
	y <- as.integer(cut(X[, 1] + rnorm(n), c(-Inf, -0.5, 0.5, Inf)))   # K = 3 categories
	list(X = X, y = y, g = as.integer(g), K = 3L, j_T = 0L)
}

test_that("mismatched X/y/group_id row counts (or an empty input) throw the non-empty/row-aligned error", {
	d <- fx()
	expect_error(f(d$X, d$y[1:10], d$g, d$K, d$j_T), "ordinal GLMM requires non-empty, row-aligned X, y, and group_id")
	expect_error(f(matrix(nrow = 0, ncol = 1), integer(0), integer(0), d$K, d$j_T), "ordinal GLMM requires non-empty, row-aligned X, y, and group_id")
})

test_that("K < 2 or an out-of-range j_T throws the K/j_T validity error", {
	d <- fx(seed = 12L)
	expect_error(f(d$X, d$y, d$g, 1L, d$j_T), "ordinal GLMM requires K >= 2 and a valid zero-based j_T")
	expect_error(f(d$X, d$y, d$g, d$K, ncol(d$X)), "ordinal GLMM requires K >= 2 and a valid zero-based j_T")
	expect_error(f(d$X, d$y, d$g, d$K, -1L), "ordinal GLMM requires K >= 2 and a valid zero-based j_T")
})

test_that("a non-finite or non-positive numerical control throws the numerical-controls error", {
	d <- fx(seed = 13L)
	expect_error(f(d$X, d$y, d$g, d$K, d$j_T, max_abs_log_sigma = -1), "ordinal GLMM numerical controls must be finite and positive")
	expect_error(f(d$X, d$y, d$g, d$K, d$j_T, n_gh = 0L), "ordinal GLMM numerical controls must be finite and positive")
	expect_error(f(d$X, d$y, d$g, d$K, d$j_T, maxit = 0L), "ordinal GLMM numerical controls must be finite and positive")
})

test_that("an out-of-range y value throws the y/group_id validity error", {
	d <- fx(seed = 14L)
	y_bad <- d$y
	y_bad[1] <- d$K + 2L
	expect_error(f(d$X, y_bad, d$g, d$K, d$j_T), "ordinal GLMM y/group_id contains an invalid value")
})

test_that("well-formed inputs do not trigger any of the 4 guards and the fit converges", {
	d <- fx(seed = 15L)
	r <- f(d$X, d$y, d$g, d$K, d$j_T)
	expect_true(r$converged)
})
