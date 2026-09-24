library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's private fit_partial_proportional_odds()
# (inference_ordinal_partial_proportional_odds.R) has the SAME "attempt$X_fit" typo bug already found
# and fixed on 2026-09-06 in inference_mixin_kk_gee_shared.R (see that file's own comment) and already
# documented, not fixed, for InferenceAbstractKKOrdinalCLMM's shared_clmm() in the immediately
# preceding iteration: fit_with_hardened_qr_column_dropping() always returns list(fit=, X=, keep=) --
# there is no `X_fit` field -- so `private$best_X_colnames = setdiff(colnames(attempt$X_fit),
# "treatment")` silently sets best_X_colnames to NULL (colnames(NULL) is NULL, setdiff(NULL, ...) is
# NULL, not character(0)) after EVERY fit, success or failure. This is a THIRD unfixed instance of the
# 2026-09-06 bug, in a completely different file.
#
# This has a real, previously-mischaracterized consequence: test-ordinal-partial-proportional-odds-
# randomization-estimate-refit-reference.R's own header comment already investigated why
# compute_treatment_estimate_during_randomization_inference()'s "reuse the original design's covariate
# columns" fast path never activates on the same already-fitted instance, and attributed it entirely
# to shared(estimate_only = TRUE)'s early-return memoization guard skipping re-population -- true as
# far as it goes, but the deeper reason is that best_X_colnames is NEVER populated by a successful fit
# at all (not just skipped on a cache hit), so that fast path is unreachable in practice regardless of
# memoization. Not fixed here, per this job's standing instruction; only documented and tested.
#   1. fit_partial_proportional_odds() leaves best_X_colnames NULL even immediately after a genuinely
#      successful fit (documents the bug precisely).
#   2. compute_treatment_estimate_during_randomization_inference()'s intended fast path (reached only
#      by manually populating best_X_colnames, bypassing the bug) matches an independent direct call
#      to fit_partial_proportional_odds_from_covariates() on the same covariate subset -- the genuinely
#      untested code the bug makes unreachable through the public API.

ppo_fixture <- function(seed = 5L, n = 200L) {
	set.seed(seed)
	X <- data.frame(x = rnorm(n))
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + 0.3 * X$x + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, x = X$x, w = w)
}

test_that("fit_partial_proportional_odds() leaves best_X_colnames NULL even after a genuinely successful fit", {
	f <- ppo_fixture()
	fit <- f$priv$fit_partial_proportional_odds()
	expect_false(is.null(fit))
	expect_true(is.finite(fit$beta))
	expect_null(f$priv$best_X_colnames)
})

test_that("compute_treatment_estimate_during_randomization_inference()'s intended fast path matches an independent direct fit on the same covariate subset (only reachable by bypassing the bug)", {
	f <- ppo_fixture()
	X_cov <- f$priv$get_X()[, "x", drop = FALSE]
	direct <- f$priv$fit_partial_proportional_odds_from_covariates(X_cov)

	f$priv$best_X_colnames <- "x"
	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(est, direct$beta, tolerance = 1e-4)
})
