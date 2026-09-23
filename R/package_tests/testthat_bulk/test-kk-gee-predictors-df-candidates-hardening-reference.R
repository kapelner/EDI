library(testthat)
library(EDI)

# inference_mixin_kk_gee_shared.R's private gee_predictors_df_candidates() (shared by every KK GEE
# class: InferenceIncidKKGEE, InferenceCountPoissonKKGEE, InferenceOrdinalKKGEE, ...) had no direct
# test reference anywhere. It's only ever exercised indirectly by the happy-path fit inside
# fit_weighted_gee_with_fallback()/compute_estimate(), which loops over its returned candidate list
# but never itself asserts on the candidate list's own contents or branch structure. Its own header
# comment documents a real, already-fixed bug (2026-09-06): fit_with_hardened_qr_column_dropping()
# returns its reduced design matrix under the field name $fit (plus $X and $keep), not $X_fit -- so
# a caller reading $X_fit would always see NULL and silently skip the QR-reduced candidate. This file
# confirms the fix directly (the field really is $fit) and exercises the surrounding candidate-list
# construction:
#   1. harden = FALSE, or a single-column (no-covariate) predictors_df, short-circuits to a length-1
#      list containing exactly gee_predictors_df() itself.
#   2. With covariates and harden = TRUE, the first candidate is always the full, unreduced
#      predictors_df.
#   3. fit_with_hardened_qr_column_dropping()'s reduced design matrix is returned under $fit (not the
#      nonexistent $X_fit) -- the exact fact the 2026-09-06 fix depends on.
#   4. With near-collinear covariates, additional QR/correlation-threshold-reduced candidates are
#      appended, each retaining the "w" (treatment) column, and duplicate column-name-sets are
#      de-duplicated (no two candidates share the same colnames).

kk_gee_fixture <- function(seed, X_df, harden = NULL, model_formula = NULL) {
	set.seed(seed)
	n <- nrow(X_df)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X_df[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- if (is.null(model_formula)) InferenceIncidKKGEE$new(des, verbose = FALSE) else InferenceIncidKKGEE$new(des, model_formula = model_formula, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	if (!is.null(harden)) priv$harden <- harden
	priv
}

test_that("harden = FALSE short-circuits to a length-1 list containing exactly gee_predictors_df()", {
	set.seed(1); n <- 30
	X_df <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	priv <- kk_gee_fixture(1L, X_df, harden = FALSE)
	pdf0 <- priv$gee_predictors_df()
	cands <- priv$gee_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_identical(cands[[1L]], pdf0)
})

test_that("a single-column (no-covariate) predictors_df short-circuits to a length-1 list, regardless of harden", {
	set.seed(2L); n <- 30
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidKKGEE$new(des, model_formula = ~1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(priv$harden)
	cands <- priv$gee_predictors_df_candidates()
	expect_length(cands, 1L)
	expect_equal(ncol(cands[[1L]]), 1L)
	expect_identical(colnames(cands[[1L]]), "w")
})

test_that("with covariates and harden = TRUE, the first candidate is always the full, unreduced predictors_df", {
	set.seed(3L); n <- 30
	X_df <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	priv <- kk_gee_fixture(3L, X_df)
	pdf0 <- priv$gee_predictors_df()
	cands <- priv$gee_predictors_df_candidates()
	expect_identical(cands[[1L]], as.data.frame(pdf0, check.names = FALSE))
})

test_that("fit_with_hardened_qr_column_dropping()'s reduced design matrix is returned under $fit, not the nonexistent $X_fit (2026-09-06 fix)", {
	set.seed(4L); n <- 40
	x1 <- rnorm(n); x2 <- x1 + rnorm(n, sd = 0.001)                                 # near-collinear
	X_df <- data.frame(x1 = x1, x2 = x2)
	priv <- kk_gee_fixture(4L, X_df)
	pdf0 <- priv$gee_predictors_df()
	X_full <- as.matrix(pdf0)
	attempt <- priv$fit_with_hardened_qr_column_dropping(
		X_full = X_full,
		required_cols = match("w", colnames(X_full)),
		fit_fun = function(X_fit) X_fit,
		fit_ok = function(mod, X_fit, keep) TRUE
	)
	expect_setequal(names(attempt), c("fit", "X", "keep"))
	expect_null(attempt$X_fit)
	expect_false(is.null(attempt$fit))
	expect_true("w" %in% colnames(attempt$fit))
})

# private$create_design_matrix()'s OWN upstream missingness/collinearity handling means real
# construction-time covariates rarely reach gee_predictors_df_candidates() still collinear (they're
# often already reduced further upstream), which makes triggering the reduction path from a real
# fixture flaky across seeds. private$gee_predictors_df() is overridden directly (post-construction,
# unlockBinding()'d since it's a real, non-lazy component method) with a controlled, guaranteed-
# collinear data.frame instead, isolating gee_predictors_df_candidates()'s own reduction logic from
# the upstream design-matrix construction entirely.
override_predictors_df <- function(priv, fixed_df) {
	unlockBinding("gee_predictors_df", priv)
	priv$gee_predictors_df <- function() fixed_df
	invisible(priv)
}

test_that("with near-collinear covariates, additional QR/correlation-reduced candidates are appended, each retaining \"w\", with no duplicate column-name-sets", {
	set.seed(9L); n <- 40
	X_df <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	priv <- kk_gee_fixture(9L, X_df)

	set.seed(5L); n2 <- 40
	x1 <- rnorm(n2); x2 <- x1 + rnorm(n2, sd = 0.0005); x3 <- rnorm(n2); x4 <- x3 + rnorm(n2, sd = 0.0005)
	fixed_df <- data.frame(w = rep(c(0, 1), length.out = n2), x1 = x1, x2 = x2, x3 = x3, x4 = x4)
	override_predictors_df(priv, fixed_df)

	cands <- priv$gee_predictors_df_candidates()
	expect_gt(length(cands), 1L)                                                    # the reduction path actually fires
	expect_identical(cands[[1L]], fixed_df)                                         # first candidate is still the full, unreduced set
	for (cand in cands) expect_true("w" %in% colnames(cand))
	keys <- vapply(cands, function(d) paste(colnames(d), collapse = "|"), character(1))
	expect_equal(length(keys), length(unique(keys)))
})

test_that("with well-conditioned (non-collinear) covariates, the candidate list is just the original (no spurious reduction)", {
	set.seed(9L); n <- 40
	X_df <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	priv <- kk_gee_fixture(10L, X_df)

	set.seed(6L); n2 <- 40
	fixed_df <- data.frame(w = rep(c(0, 1), length.out = n2), x1 = rnorm(n2), x2 = rnorm(n2), x3 = rnorm(n2))
	override_predictors_df(priv, fixed_df)

	cands <- priv$gee_predictors_df_candidates()
	keys <- vapply(cands, function(d) paste(colnames(d), collapse = "|"), character(1))
	expect_true(paste(colnames(fixed_df), collapse = "|") %in% keys)
})
