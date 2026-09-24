library(testthat)
library(EDI)

# InferenceMixinKKGLMMShared's private fit_glmm_on_data() (inference_mixin_kk_glmm_shared.R) catches
# any error from the real glmmTMB::glmmTMB() call and emits message("GLMM FIT ERROR: ", e$message)
# before returning NULL. test-kk-glmm-fit-failed-guard-reference.R already covers the downstream
# "kk_glmm_fit_failed" nonestimable reason, but only by mocking fit_glmm() itself to return NULL --
# the genuine glmmTMB error path, and this specific message, were never exercised anywhere (confirmed
# via a zero-hit grep for its literal text; a sibling test elsewhere only asserts the message does
# NOT fire in a different, already-fixed scenario). Reached via InferenceCountKKGLMM (Poisson family)
# by directly overwriting private$y with negative values -- bypassing the design-level response
# validation that would otherwise reject a negative count response before this code is ever reached
# -- which makes glmmTMB itself refuse to fit a Poisson family, the same scenario already documented
# for the negative-regression test in R/EDI/tests/testthat/test-brt-smoothed-count-support.R.

test_that("fit_glmm_on_data() emits 'GLMM FIT ERROR: ...' and returns NULL when glmmTMB itself errors", {
	skip_if_not_installed("glmmTMB")
	set.seed(1L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * des$get_w())))
	inf <- InferenceCountKKGLMM$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_identical(priv$glmm_family()$family, "poisson")

	priv$y <- rep(-1, n)                                            # invalid for a Poisson family
	pred_df <- data.frame(w = priv$w)
	expect_message(
		mod <- priv$fit_glmm_on_data(pred_df, se = TRUE),
		"GLMM FIT ERROR: negative values not allowed for the 'Poisson' family"
	)
	expect_null(mod)
})
