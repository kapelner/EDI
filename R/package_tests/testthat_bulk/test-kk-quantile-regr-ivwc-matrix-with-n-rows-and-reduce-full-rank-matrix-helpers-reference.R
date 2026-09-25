library(testthat)
library(EDI)

# InferenceAbstractKKQuantileRegrIVWC's private matrix_with_n_rows(X, n_rows)/reduce_full_rank_
# matrix(X, n_rows) helpers (inference_all_KK_quantile_regr_ivwc_abstract.R:155-170) had zero test
# references anywhere, completing the sweep of this file's shared quantile-regression private
# helpers (iqr_se()/qr_intercept_pairs()/qr_trt_coef_reservoir() closed the previous two
# iterations):
#   1. matrix_with_n_rows() normalizes X into a matrix with n_rows rows: NULL or a length-0 vector
#      becomes a 0-column matrix of the right row count; an already-dimensioned object (a matrix)
#      passes through as-is (via as.matrix()); a plain vector is reshaped into an n_rows x k matrix.
#   2. reduce_full_rank_matrix() drops linearly-dependent columns via the qr_reduce_full_rank_cpp()
#      kernel, returning both the reduced matrix and the kept column indices; a full-rank input
#      keeps every column.
# Exercised via direct private-method calls on a real InferenceContinKKQuantileRegrIVWC instance,
# independent reference values computed inline.

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
}

test_that("matrix_with_n_rows(): NULL or length-0 input gives a 0-column matrix with the requested row count", {
	skip_if_not_installed("quantreg")
	priv <- fx(1L)$.__enclos_env__$private
	expect_equal(dim(priv$matrix_with_n_rows(NULL, 5L)), c(5L, 0L))
	expect_equal(dim(priv$matrix_with_n_rows(numeric(0), 5L)), c(5L, 0L))
})

test_that("matrix_with_n_rows(): an already-dimensioned matrix passes through unchanged", {
	skip_if_not_installed("quantreg")
	priv <- fx(2L)$.__enclos_env__$private
	m <- matrix(1:6, 3, 2)
	expect_equal(priv$matrix_with_n_rows(m, 3L), m)
})

test_that("matrix_with_n_rows(): a plain vector is reshaped into an n_rows x k matrix", {
	skip_if_not_installed("quantreg")
	priv <- fx(3L)$.__enclos_env__$private
	res <- priv$matrix_with_n_rows(1:6, 3L)
	expect_equal(res, matrix(1:6, 3L))
})

test_that("reduce_full_rank_matrix(): a full-rank input keeps every column", {
	skip_if_not_installed("quantreg")
	priv <- fx(4L)$.__enclos_env__$private
	set.seed(40)
	X <- cbind(a = rnorm(10), b = rnorm(10))
	res <- priv$reduce_full_rank_matrix(X, 10L)
	expect_equal(res$keep, c(1L, 2L))
	expect_equal(ncol(res$X), 2L)
})

test_that("reduce_full_rank_matrix(): a rank-deficient input (a duplicated, rescaled column) drops the redundant column", {
	skip_if_not_installed("quantreg")
	priv <- fx(5L)$.__enclos_env__$private
	set.seed(50)
	a <- rnorm(10)
	X <- cbind(a = a, a2 = a * 2)
	res <- priv$reduce_full_rank_matrix(X, 10L)
	# which single column survives is a QR-pivoting implementation detail; only the
	# rank-deficiency outcome (exactly one column kept) is the documented contract
	expect_length(res$keep, 1L)
	expect_equal(ncol(res$X), 1L)
})
