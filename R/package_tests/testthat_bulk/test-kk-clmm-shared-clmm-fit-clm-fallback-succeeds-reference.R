library(testthat)
library(EDI)

# InferenceAbstractKKOrdinalCLMM's private shared_clmm() (inference_ordinal_KK_clmm_abstract.R, the
# use_rcpp = FALSE dispatcher) has a two-tier fitter: ordinal::clmm() (random-intercept mixed model)
# first, falling back to fit_clm_fallback() (a fixed-effects ordinal::clm() fit, no random intercept)
# when clmm() fails or its standard error is unusable. test-kk-clmm-shared-clmm-fit-unavailable-and-
# nonestimable-guards-reference.R already covers the "BOTH fit_clmm() and fit_clm_fallback() return
# NULL" guard (both mocked to fail), but the actual fallback-genuinely-triggers-and-succeeds branch --
# fit_clmm() fails, fit_clm_fallback() is called and returns a usable fit that shared_clmm() then
# accepts -- had never been exercised, the same "black-box mocked wrapper, real fallback never
# reached" gap already closed for the KK-GEE fallback loops in the two preceding iterations.
# Reached by wrapping (not replacing) fit_clm_fallback(): forcing fit_clmm() to always fail while
# delegating fit_clm_fallback() to the real ordinal::clm() fitter.
# compute_treatment_estimate_during_randomization_inference()'s OWN independent fit_clmm()/fit_clm_
# fallback() call site (a different code path, use_rcpp = FALSE only) gets the same treatment.
#
# NOTE (real source bug, not fixed here): shared_clmm()'s own "private$best_X_colnames = setdiff(
# colnames(attempt$X_fit), ...)" line reads a field named `X_fit` off fit_with_hardened_qr_column_
# dropping()'s return value, but that function's actual return shape (inference_all_abstract.R) is
# always list(fit=, X=, keep=) -- there is no `X_fit` field. colnames(NULL) is NULL and setdiff(NULL,
# ...) is NULL (not character(0)), so private$best_X_colnames is silently left NULL after every
# shared_clmm() call, regardless of fit success. This means compute_treatment_estimate_during_
# randomization_inference()'s own "is.null(private$best_X_colnames)" check is always TRUE, so its
# fast reuse-the-original-design-columns path (the whole point of caching best_X_colnames) is
# unreachable in practice for use_rcpp = FALSE classes -- it always falls through to the slower
# self$compute_estimate(estimate_only=...) branch instead. The second test below manually sets
# private$best_X_colnames to isolate and verify the fit_clmm()/fit_clm_fallback() dispatch logic on
# its own merits, bypassing this unrelated bug rather than asserting the (currently unreachable)
# fast path actually gets used.

clmm_shared_fixture <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- InferenceOrdinalKKCLMM$new(des, use_rcpp = FALSE, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("shared_clmm(): when fit_clmm() fails, fit_clm_fallback() is genuinely called and its usable fit is accepted", {
	f <- clmm_shared_fixture(1L)
	calls <- character(0)
	unlockBinding("fit_clmm", f$priv)
	f$priv$fit_clmm <- function(X_fit) { calls <<- c(calls, "clmm"); NULL }
	unlockBinding("fit_clm_fallback", f$priv)
	orig_fallback <- f$priv$fit_clm_fallback
	f$priv$fit_clm_fallback <- function(full_X) { calls <<- c(calls, "clm_fallback"); orig_fallback(full_X) }

	f$priv$shared_clmm(estimate_only = FALSE)
	expect_true("clm_fallback" %in% calls)
	expect_false(f$inf$is_nonestimable("estimate"))
	expect_true(is.finite(f$priv$cached_values$beta_hat_T))
	expect_true(is.finite(f$priv$cached_values$s_beta_hat_T))
	expect_true(f$priv$cached_values$s_beta_hat_T > 0)
})

test_that("compute_treatment_estimate_during_randomization_inference(): the same fit_clmm()-fails/fit_clm_fallback()-succeeds path is reached and used", {
	f <- clmm_shared_fixture(2L)
	unlockBinding("best_X_colnames", f$priv)
	f$priv$best_X_colnames <- "x1"                                         # bypass the best_X_colnames-never-set bug noted above

	calls <- character(0)
	unlockBinding("fit_clmm", f$priv)
	f$priv$fit_clmm <- function(X_fit) { calls <<- c(calls, "clmm"); NULL }
	unlockBinding("fit_clm_fallback", f$priv)
	orig_fallback <- f$priv$fit_clm_fallback
	f$priv$fit_clm_fallback <- function(full_X) { calls <<- c(calls, "clm_fallback"); orig_fallback(full_X) }
	unlockBinding("use_rcpp", f$priv)
	f$priv$use_rcpp <- FALSE

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true("clm_fallback" %in% calls)
	expect_true(is.finite(est))
})
