library(testthat)
library(EDI)

# InferenceOrdinalKKGEE's own shared_gee_dispatch() (inference_ordinal_KK_combined.R) -- distinct
# from the generic (non-ordinal) KK-GEE dispatch's own "kk_gee_fit_failed" guard closed earlier this
# session -- caches "ordinal_kk_gee_fit_unavailable" when fit_ordinal_gee_mod_with_fallback() itself
# returns NULL. This had no test reference anywhere (a repo-wide grep for the fitter's name itself
# returns nothing outside source). Reached by mocking the private fitter directly (unlockBinding),
# the same technique already used elsewhere in this suite for analogous unreachable-in-practice
# failure paths.

test_that("shared_gee_dispatch caches 'ordinal_kk_gee_fit_unavailable' when fit_ordinal_gee_mod_with_fallback() fails", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	inf <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_ordinal_gee_mod_with_fallback", p)
	p$fit_ordinal_gee_mod_with_fallback <- function(...) NULL

	p$shared_gee_dispatch(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "ordinal_kk_gee_fit_unavailable")
	expect_true(is.na(p$cached_values$beta_hat_T) || is.null(p$cached_values$beta_hat_T))
})
