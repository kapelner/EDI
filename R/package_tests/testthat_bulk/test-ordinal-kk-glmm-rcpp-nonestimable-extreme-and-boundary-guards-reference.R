library(testthat)
library(EDI)

# InferenceOrdinalKKGLMM's private shared_rcpp() (inference_ordinal_KK_combined.R, use_rcpp = TRUE
# dispatcher) has a third nonestimable guard, "kk_glmm_rcpp_nonestimable", distinct from the two
# already covered in test-ordinal-kk-glmm-rcpp-failed-and-variance-nonestimable-guards-reference.R
# ("kk_glmm_rcpp_failed" for a failed/non-converged solver call, "kk_glmm_rcpp_variance_nonestimable"
# for an otherwise-successful fit with no usable SE). This third guard fires on a SUCCESSFULLY
# converged fit whose point estimate itself is unusable, via any of three independent OR'd conditions:
# a non-finite fitted parameter anywhere (alpha/b/log_sigma), a treatment coefficient beyond
# max_abs_reasonable_coef, or the random-effect variance (log_sigma) sitting at its optimizer upper
# boundary (>= 8 - 1e-4) -- none of which had a test reference anywhere. Reached the same way as the
# sibling guard tests: mocking fast_ordinal_glmm_cpp() directly on InferenceOrdinalKKGLMM (use_rcpp =
# TRUE).
#   1. A treatment coefficient beyond max_abs_reasonable_coef triggers the guard.
#   2. log_sigma at (or past) the upper variance boundary triggers the guard, even with an otherwise
#      well-behaved coefficient.
#   3. A non-finite fitted parameter elsewhere (alpha) triggers the guard.
#   4. A well-behaved fit (finite parameters, reasonable coefficient, log_sigma away from the
#      boundary) is NOT nonestimable via this guard.

ordinal_kk_glmm_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	InferenceOrdinalKKGLMM$new(des, use_rcpp = TRUE, verbose = FALSE)
}

mock_fit <- function(b1, log_sigma, alpha1 = 0) {
	function(X, y, group_id, K, j_T, ...) {
		list(
			converged = TRUE, hit_iteration_cap = FALSE, gradient_norm = 0.001,
			alpha = c(alpha1, rep(0, K - 2)), b = c(b1, rep(0, ncol(X) - 1)), log_sigma = log_sigma,
			ssq_b_T = 0.1, fisher_information = diag(ncol(X) + K)
		)
	}
}

test_that("a treatment coefficient beyond max_abs_reasonable_coef triggers 'kk_glmm_rcpp_nonestimable'", {
	inf <- ordinal_kk_glmm_fixture(1L)
	p <- inf$.__enclos_env__$private
	expect_equal(p$max_abs_reasonable_coef, 10000)
	local_mocked_bindings(fast_ordinal_glmm_cpp = mock_fit(b1 = 1e6, log_sigma = -3), .package = "EDI")
	p$shared_rcpp(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_rcpp_nonestimable")
})

test_that("log_sigma at (or past) the upper variance boundary triggers 'kk_glmm_rcpp_nonestimable', even with a reasonable coefficient", {
	inf <- ordinal_kk_glmm_fixture(2L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_ordinal_glmm_cpp = mock_fit(b1 = 0.3, log_sigma = 9), .package = "EDI")
	p$shared_rcpp(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_rcpp_nonestimable")
})

test_that("a non-finite fitted parameter elsewhere (alpha) triggers 'kk_glmm_rcpp_nonestimable'", {
	inf <- ordinal_kk_glmm_fixture(3L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_ordinal_glmm_cpp = mock_fit(b1 = 0.3, log_sigma = -3, alpha1 = NA_real_), .package = "EDI")
	p$shared_rcpp(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_rcpp_nonestimable")
})

test_that("a well-behaved fit is NOT nonestimable via this guard", {
	inf <- ordinal_kk_glmm_fixture(4L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_ordinal_glmm_cpp = mock_fit(b1 = 0.3, log_sigma = -3), .package = "EDI")
	p$shared_rcpp(estimate_only = TRUE)
	expect_false(inf$is_nonestimable("estimate"))
	expect_equal(p$cached_values$beta_hat_T, 0.3)
})
