library(testthat)
library(EDI)

# InferenceContinKKGLMM$shared_glmm_tmb() (inference_mixin_kk_glmm_shared.R, the shared glmmTMB
# dispatch every KK-GLMM daughter -- InferenceContinKKGLMM, InferenceCountKKCombined,
# InferenceOrdinalKKCombined -- composes) caches "kk_glmm_fit_failed" when fit_glmm() itself returns
# NULL. This had no test reference anywhere. Reached via InferenceContinKKGLMM by mocking the
# private fitter directly (unlockBinding), the same technique already used elsewhere in this suite
# for analogous unreachable-in-practice failure paths (including this session's identically-shaped
# "kk_gee_fit_failed" guard on the sibling GEE mixin).

test_that("shared_glmm_tmb caches 'kk_glmm_fit_failed' when fit_glmm() fails", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())

	inf <- InferenceContinKKGLMM$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_glmm", p)
	p$fit_glmm <- function(...) NULL

	p$shared_glmm_tmb(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "kk_glmm_fit_failed")
	expect_true(is.na(p$cached_values$beta_hat_T))
})
