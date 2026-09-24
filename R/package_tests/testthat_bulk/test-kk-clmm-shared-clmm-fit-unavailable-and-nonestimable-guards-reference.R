library(testthat)
library(EDI)

# InferenceAbstractKKOrdinalCLMM's private shared_clmm() (inference_ordinal_KK_clmm_abstract.R --
# the use_rcpp = FALSE dispatcher, ordinal::clmm()/clm()-fallback-based, distinct from shared_rcpp())
# has two nonestimable-reason guards that had zero test reference anywhere:
# "kk_clmm_fit_unavailable" and "kk_clmm_nonestimable". test-ordinal-kk-clmm-rcpp-shared-failure-
# reasons-caching-and-ri-estimate-reference.R covers the analogous-sounding but DISTINCT
# "kk_clmm_rcpp_failed"/"kk_clmm_rcpp_nonestimable" reasons on the rcpp dispatcher, and
# test-ordinal-kk-clmm-use-rcpp-false-and-nonzero-delta.R only exercises shared_clmm()'s happy path.
#   1. When both fit_clmm() and its fit_clm_fallback() return NULL, the result is nonestimable with
#      reason "kk_clmm_fit_unavailable".
#   2. When the fitted treatment coefficient exceeds max_abs_reasonable_coef, the result is
#      nonestimable with reason "kk_clmm_nonestimable" (via a hand-constructed fake fit object with
#      coef()/summary() S3 methods, since the fast-vs-plausible-coefficient check only inspects those
#      two generic accessors, not the model class itself).

clmm_shared_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKCLMM$new(des, use_rcpp = FALSE, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("when both fit_clmm() and fit_clm_fallback() return NULL, the result is nonestimable ('kk_clmm_fit_unavailable')", {
	f <- clmm_shared_fixture(1L)
	unlockBinding("fit_clmm", f$priv)
	unlockBinding("fit_clm_fallback", f$priv)
	f$priv$fit_clmm <- function(full_X) NULL
	f$priv$fit_clm_fallback <- function(full_X) NULL

	f$priv$shared_clmm(estimate_only = TRUE)
	expect_true(is.na(f$priv$cached_values$beta_hat_T) || is.null(f$priv$cached_values$beta_hat_T))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_clmm_fit_unavailable")

	f$priv$shared_clmm(estimate_only = FALSE)
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})

test_that("when the fitted treatment coefficient exceeds max_abs_reasonable_coef, the result is nonestimable ('kk_clmm_nonestimable')", {
	f <- clmm_shared_fixture(2L)

	coef.kk_clmm_fake_fit <- function(object, ...) c(w = 1e6, x1 = 0.1)
	summary.kk_clmm_fake_fit <- function(object, ...) {
		tbl <- matrix(c(1e6, 0.1, 100, 0.2), nrow = 2, dimnames = list(c("w", "x1"), c("Estimate", "Std. Error")))
		list(coefficients = tbl)
	}
	assign("coef.kk_clmm_fake_fit", coef.kk_clmm_fake_fit, envir = .GlobalEnv)
	assign("summary.kk_clmm_fake_fit", summary.kk_clmm_fake_fit, envir = .GlobalEnv)
	on.exit({
		rm(list = c("coef.kk_clmm_fake_fit", "summary.kk_clmm_fake_fit"), envir = .GlobalEnv)
	}, add = TRUE)
	fake_mod <- structure(list(), class = "kk_clmm_fake_fit")

	unlockBinding("fit_clmm", f$priv)
	f$priv$fit_clmm <- function(full_X) fake_mod

	f$priv$shared_clmm(estimate_only = TRUE)
	expect_equal(f$inf$get_nonestimable_reason(), "kk_clmm_nonestimable")
	expect_true(f$inf$is_nonestimable("estimate"))
})
