library(testthat)
library(EDI)

# InferenceOrdinalKKGEE's own fit_ordinal_gee_mod_with_fallback() (inference_ordinal_KK_combined.R)
# iterates over gee_predictors_df_candidates() (a QR-hardened sequence of rank-reduced design matrices),
# calling fit_ordinal_gee_mod() on each in turn and returning the first fit whose coefficients
# gee_coefficients_are_usable(). Existing coverage
# (test-ordinal-kk-gee-fit-unavailable-guard-reference.R,
# test-ordinal-kk-gee-randomization-estimate-refit-reference.R) only mocks the WHOLE wrapper to return
# NULL directly -- the wrapper's own loop-and-continue-to-the-next-candidate logic (the actual reason
# this wrapper exists, per its own header comment: a real "diamonds"-shaped rank-deficient covariate
# matrix caused ordLORgee() to fail on the raw predictors and needed a QR-hardened retry) had never
# been exercised at all. Reached by mocking gee_predictors_df_candidates() to return two synthetic
# candidates and fit_ordinal_gee_mod() to fail on the first (by column names) and delegate to the real
# fitter on the second -- the same "wrap, don't replace, to prove a fallback is genuinely reached"
# technique already used elsewhere in this suite for analogous multi-candidate search loops.

test_that("fit_ordinal_gee_mod_with_fallback() advances to the second candidate when the first fails, and returns its fit", {
	set.seed(1); n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	cand_fails <- data.frame(w = priv$w, x1 = X$x1)
	cand_succeeds <- data.frame(w = priv$w)
	unlockBinding("gee_predictors_df_candidates", priv)
	priv$gee_predictors_df_candidates <- function() list(cand_fails, cand_succeeds)

	calls <- list()
	unlockBinding("fit_ordinal_gee_mod", priv)
	orig_fit <- priv$fit_ordinal_gee_mod
	priv$fit_ordinal_gee_mod <- function(bstart = NULL, predictors_df = NULL) {
		calls[[length(calls) + 1]] <<- colnames(predictors_df)
		if (identical(colnames(predictors_df), c("w", "x1"))) return(NULL)   # first candidate: forced failure
		orig_fit(bstart = bstart, predictors_df = predictors_df)             # second candidate: real fit
	}

	mod <- priv$fit_ordinal_gee_mod_with_fallback()
	expect_length(calls, 2L)
	expect_identical(calls[[1L]], c("w", "x1"))
	expect_identical(calls[[2L]], "w")
	expect_false(is.null(mod))

	beta <- stats::coef(mod)
	expect_true(priv$gee_coefficients_are_usable(beta))

	# The same fit reached directly on the second candidate alone is identical -- confirms the
	# fallback path genuinely used that candidate's real fit, not some other value.
	direct <- orig_fit(predictors_df = cand_succeeds)
	expect_equal(as.numeric(stats::coef(mod)), as.numeric(stats::coef(direct)))
})

test_that("if every candidate fails or is unusable, fit_ordinal_gee_mod_with_fallback() returns NULL", {
	set.seed(2); n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	unlockBinding("gee_predictors_df_candidates", priv)
	priv$gee_predictors_df_candidates <- function() list(data.frame(w = priv$w, x1 = X$x1), data.frame(w = priv$w))
	unlockBinding("fit_ordinal_gee_mod", priv)
	priv$fit_ordinal_gee_mod <- function(bstart = NULL, predictors_df = NULL) NULL

	expect_null(priv$fit_ordinal_gee_mod_with_fallback())
})
