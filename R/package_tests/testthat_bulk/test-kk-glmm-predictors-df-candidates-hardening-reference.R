library(testthat)
library(EDI)

# inference_mixin_kk_glmm_shared.R's private glmm_predictors_df_candidates() (shared by every KK GLMM
# class: InferenceContinKKGLMM, InferenceCountKKGLMM, InferenceOrdinalKKGLMM, ...) had no direct test
# reference anywhere -- confirmed via grep. It's only ever exercised indirectly through the happy-path
# fit inside shared_glmm_tmb()/compute_estimate(), never asserted on directly. Unlike the sibling KK
# GEE mixin's gee_predictors_df_candidates() (a cheap, identity-fit_fun QR/correlation probe closed
# earlier this session), this one actually FITS a real glmmTMB model at each hardening attempt (its
# fit_fun calls private$fit_glmm_on_data(), fit_ok calls private$.is_usable_glmm_fit()) and returns a
# DIFFERENT shape: exactly ONE candidate (the possibly-reduced attempt$X), not the original-plus-
# reduced list gee_predictors_df_candidates() returns -- except when every column-dropping attempt
# fails to produce a usable fit, in which case it falls back to a w-only single-column candidate.
#   1. harden = FALSE, or a single-column (no-covariate) predictors_df, short-circuits to a length-1
#      list containing exactly glmm_predictors_df() itself.
#   2. With well-conditioned covariates, the fit succeeds on the first (full) attempt, so the single
#      returned candidate has the SAME columns and values as the original predictors_df -- no
#      reduction occurs.
#   3. With near-collinear covariates (real collinearity, since fit_with_hardened_qr_column_dropping's
#      own probe actually fits glmmTMB models here, unlike GEE's cheap identity probe), the collinear
#      column is dropped: exactly one candidate is returned, retaining "w" but with fewer columns than
#      the original.
#   4. When no column-dropping attempt ever produces a usable fit (.is_usable_glmm_fit() always
#      FALSE), attempt$fit is NULL and the fallback is exactly a single-column data.frame(w = ...).

kk_glmm_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountKKGLMM$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

# private$glmm_predictors_df()'s own upstream private$create_design_matrix() already applies its own
# collinearity handling, so overriding glmm_predictors_df() directly (post-construction, unlockBinding
# since it's a real, non-lazy component method) with a controlled data.frame isolates this method's
# own reduction logic from that upstream layer, exactly as for the GEE sibling test.
override_predictors_df <- function(priv, fixed_df) {
	unlockBinding("glmm_predictors_df", priv)
	priv$glmm_predictors_df <- function() fixed_df
	invisible(priv)
}

test_that("harden = FALSE short-circuits to a length-1 list containing exactly glmm_predictors_df()", {
	priv <- kk_glmm_fixture(1L)
	priv$harden <- FALSE
	pdf0 <- priv$glmm_predictors_df()
	cands <- priv$glmm_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_identical(cands[[1L]], pdf0)
})

test_that("a single-column (no-covariate) predictors_df short-circuits to a length-1 list, regardless of harden", {
	set.seed(2L); n <- 30
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountKKGLMM$new(des, model_formula = ~1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(priv$harden)
	cands <- priv$glmm_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_identical(colnames(cands[[1L]]), "w")
})

test_that("with well-conditioned covariates, the fit succeeds on the first attempt: one candidate, identical to the original predictors_df", {
	priv <- kk_glmm_fixture(3L)
	pdf0 <- priv$glmm_predictors_df()
	cands <- priv$glmm_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_identical(colnames(cands[[1L]]), colnames(pdf0))
	expect_equal(as.matrix(cands[[1L]]), as.matrix(pdf0), check.attributes = FALSE)
})

test_that("with near-collinear covariates, the collinear column is dropped: one candidate, retaining \"w\" but with fewer columns than the original", {
	priv <- kk_glmm_fixture(1L)
	w_real <- priv$w
	set.seed(1L); n <- length(w_real)
	x1 <- rnorm(n); x2 <- x1 + rnorm(n, sd = 0.0005)                                # near-perfectly collinear
	fixed_df <- data.frame(w = w_real, x1 = x1, x2 = x2)
	override_predictors_df(priv, fixed_df)

	cands <- priv$glmm_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_true("w" %in% colnames(cands[[1L]]))
	expect_lt(ncol(cands[[1L]]), ncol(fixed_df))
})

test_that("when no column-dropping attempt ever produces a usable fit, the fallback is exactly a single-column data.frame(w = ...)", {
	priv <- kk_glmm_fixture(6L)
	unlockBinding(".is_usable_glmm_fit", priv)
	priv$.is_usable_glmm_fit <- function(mod, se) FALSE

	pdf0 <- priv$glmm_predictors_df()
	cands <- priv$glmm_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_identical(colnames(cands[[1L]]), "w")
	expect_equal(cands[[1L]]$w, pdf0$w)
})
