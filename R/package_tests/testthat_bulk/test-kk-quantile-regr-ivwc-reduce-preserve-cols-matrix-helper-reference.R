library(testthat)
library(EDI)

# InferenceAbstractKKQuantileRegrIVWC's private reduce_preserve_cols_matrix(X, required_cols)
# (inference_all_KK_quantile_regr_ivwc_abstract.R:173-183) drops linearly-dependent columns via the
# qr_reduce_preserve_cols_cpp() kernel like reduce_full_rank_matrix() (closed the previous
# iteration), but is guaranteed to keep the caller-specified required_cols (the treatment-column
# index, j_treat, at both of this method's two call sites) even when rank reduction must drop
# something else instead. This completes the sweep of this file's shared private helpers -- a
# codebase-wide grep confirmed reduce_preserve_cols_matrix() had zero test references anywhere.
# Exercised via direct private-method calls on a real InferenceContinKKQuantileRegrIVWC instance.

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	InferenceContinKKQuantileRegrIVWC$new(des, verbose = FALSE)
}

test_that("a full-rank input keeps every column, including required_cols", {
	skip_if_not_installed("quantreg")
	priv <- fx(1L)$.__enclos_env__$private
	set.seed(40)
	X <- cbind(a = rnorm(10), trt = rbinom(10, 1, 0.5))
	res <- priv$reduce_preserve_cols_matrix(X, 2L)
	expect_equal(res$keep, c(1L, 2L))
	expect_equal(ncol(res$X), 2L)
})

test_that("a rank-deficient input (a duplicated, rescaled column) drops the redundant column but always keeps required_cols", {
	skip_if_not_installed("quantreg")
	priv <- fx(2L)$.__enclos_env__$private
	set.seed(50)
	a <- rnorm(10)
	trt <- rbinom(10, 1, 0.5)
	X <- cbind(a = a, trt = trt, a2 = a * 2)
	res <- priv$reduce_preserve_cols_matrix(X, 2L)
	expect_true(2L %in% res$keep)
	expect_length(res$keep, 2L)
	expect_equal(ncol(res$X), 2L)
})

test_that("a zero-column input returns an empty keep vector and a 0-column matrix", {
	skip_if_not_installed("quantreg")
	priv <- fx(3L)$.__enclos_env__$private
	res <- priv$reduce_preserve_cols_matrix(matrix(numeric(0), 10L, 0L), integer(0))
	expect_length(res$keep, 0L)
	expect_equal(ncol(res$X), 0L)
})
