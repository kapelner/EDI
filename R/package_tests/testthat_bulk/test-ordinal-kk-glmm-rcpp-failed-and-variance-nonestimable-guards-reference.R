library(testthat)
library(EDI)

# InferenceOrdinalKKGLMM's private shared_rcpp() (inference_ordinal_KK_combined.R, the use_rcpp =
# TRUE dispatch's own fitter, distinct from InferenceOrdinalKKGEE's/the shared generic KK-GLMM
# mixin's already-covered "kk_glmm_fit_failed") has two distinct nonestimable guards, neither of
# which had a test reference anywhere:
#   1. "kk_glmm_rcpp_failed": fast_ordinal_glmm_cpp() itself fails -- returns NULL, doesn't converge,
#      hits the iteration cap, or gives a non-finite gradient norm.
#   2. "kk_glmm_rcpp_variance_nonestimable": the fit succeeds (converged, finite coefficients), but
#      neither the direct ssq_b_T estimate nor the Fisher-information-inverse fallback gives a
#      usable (finite, positive, within-threshold) standard error.
# Reached via InferenceOrdinalKKGLMM (use_rcpp = TRUE) by mocking fast_ordinal_glmm_cpp() directly,
# the same local_mocked_bindings(..., .package = "EDI") technique already used elsewhere in this
# suite for analogous unreachable-in-practice failure paths.

ordinal_kk_glmm_fixture <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	InferenceOrdinalKKGLMM$new(des, use_rcpp = TRUE, verbose = FALSE)
}

test_that("'kk_glmm_rcpp_failed' fires when fast_ordinal_glmm_cpp() itself fails", {
	inf <- ordinal_kk_glmm_fixture()
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(fast_ordinal_glmm_cpp = function(...) NULL, .package = "EDI")

	p$shared_rcpp(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_rcpp_failed")
})

test_that("'kk_glmm_rcpp_variance_nonestimable' fires when the fit succeeds but no usable SE can be derived", {
	inf <- ordinal_kk_glmm_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	local_mocked_bindings(
		fast_ordinal_glmm_cpp = function(X, y, group_id, K, j_T, ...) {
			list(
				converged = TRUE, hit_iteration_cap = FALSE, gradient_norm = 0.001,
				alpha = rep(0, K - 1), b = c(0.5, rep(0, ncol(X) - 1)), log_sigma = -3,
				ssq_b_T = NA_real_, fisher_information = matrix(NA_real_, ncol(X) + K, ncol(X) + K)
			)
		},
		.package = "EDI"
	)

	p$shared_rcpp(estimate_only = FALSE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_rcpp_variance_nonestimable")
})
