library(testthat)
library(EDI)

# fast_poisson_glmm_cpp (fast_poisson_glmm.cpp, the actual fitter, not the score/hessian evaluators
# already closed this stretch in test-poisson-glmm-score-hessian-input-guards-reference.R and the
# fitter-level guards already closed for its ordinal-GLMM sibling in test-ordinal-glmm-fitter-cpp-
# input-guards-reference.R) validates its inputs with its own 2 independent guards before dispatching
# to fast_poisson_glmm_internal():
#   1. `if (X_r.rows() != y_r.size() || X_r.rows() != group_id_r.size()) Rcpp::stop("Dimension
#      mismatch: X_r has %d rows, y_r has %d elements, group_id_r has %d elements", ...)`.
#   2. `if (row_weights.has_value() && row_weights->size() != X_r.rows()) Rcpp::stop("row_weights
#      length (%d) must equal nrow(X) (%d)", ...)`.
# A codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/
# confirms neither of these two fitter-level guards had a test reference anywhere -- the existing
# InferenceCountKKGLMM reference/golden files exercise real fit-failure/nonestimable scenarios,
# never these hard input-validation guards directly.

f <- get("fast_poisson_glmm_cpp", envir = asNamespace("EDI"))

fx <- function(seed = 21L, G = 12L, m = 5L) {
	set.seed(seed)
	n <- G * m
	g <- rep(seq_len(G), each = m)
	X <- cbind(1, rnorm(n))
	y <- as.numeric(rpois(n, exp(0.3 + 0.2 * X[, 2])))
	list(X = X, y = y, g = as.integer(g))
}

test_that("mismatched y length throws the dimension-mismatch error", {
	d <- fx()
	expect_error(f(d$X, d$y[1:10], d$g, 0L), "Dimension mismatch: X_r has \\d+ rows, y_r has \\d+ elements, group_id_r has \\d+ elements")
})

test_that("mismatched group_id length throws the same dimension-mismatch error", {
	d <- fx(seed = 22L)
	expect_error(f(d$X, d$y, d$g[1:10], 0L), "Dimension mismatch: X_r has \\d+ rows, y_r has \\d+ elements, group_id_r has \\d+ elements")
})

test_that("row_weights of the wrong length throws the row_weights-length error", {
	d <- fx(seed = 23L)
	expect_error(f(d$X, d$y, d$g, 0L, row_weights = rep(1, 10)), "row_weights length \\(\\d+\\) must equal nrow\\(X\\) \\(\\d+\\)")
})

test_that("well-formed inputs, including correctly-sized row_weights, do not trigger either guard", {
	d <- fx(seed = 24L)
	r <- f(d$X, d$y, d$g, 0L, row_weights = rep(1, length(d$y)))
	expect_true(r$converged)
})
