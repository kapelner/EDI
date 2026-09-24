library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's private fit_partial_proportional_odds()
# (inference_ordinal_partial_proportional_odds.R) had the SAME "attempt$X_fit" typo bug already found
# and fixed on 2026-09-06 in inference_mixin_kk_gee_shared.R (see that file's own comment), and also
# present in InferenceAbstractKKOrdinalCLMM's shared_clmm(): fit_with_hardened_qr_column_dropping()
# always returns list(fit=, X=, keep=) -- there is no `X_fit` field -- so
# `private$best_X_colnames = setdiff(colnames(attempt$X_fit), "treatment")` silently set
# best_X_colnames to NULL (colnames(NULL) is NULL, setdiff(NULL, ...) is NULL, not character(0)) after
# EVERY fit, success or failure. FIXED 2026-09-24 (attempt$X_fit -> attempt$X) in both this file and
# inference_ordinal_KK_clmm_abstract.R.
#
# This had a real consequence: test-ordinal-partial-proportional-odds-randomization-estimate-refit-
# reference.R's own header comment already investigated why
# compute_treatment_estimate_during_randomization_inference()'s "reuse the original design's covariate
# columns" fast path never activated on the same already-fitted instance, and attributed it entirely
# to shared(estimate_only = TRUE)'s early-return memoization guard skipping re-population -- true as
# far as it goes, but the deeper reason was that best_X_colnames was NEVER populated by a successful
# fit at all (not just skipped on a cache hit), so that fast path was unreachable in practice
# regardless of memoization. Now fixed; both tests below updated to reflect the corrected behavior.
#   1. fit_partial_proportional_odds() now correctly populates best_X_colnames immediately after a
#      genuinely successful fit (was previously always NULL; documents the fix).
#   2. compute_treatment_estimate_during_randomization_inference()'s fast path (now reachable without
#      any manual bypass) matches an independent direct call to
#      fit_partial_proportional_odds_from_covariates() on the same covariate subset.

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

test_that("fit_partial_proportional_odds() correctly populates best_X_colnames after a genuinely successful fit", {
	f <- ppo_fixture()
	fit <- f$priv$fit_partial_proportional_odds()
	expect_false(is.null(fit))
	expect_true(is.finite(fit$beta))
	expect_identical(f$priv$best_X_colnames, "x")
})

test_that("compute_treatment_estimate_during_randomization_inference()'s fast path matches an independent direct fit on the same covariate subset", {
	f <- ppo_fixture()
	X_cov <- f$priv$get_X()[, "x", drop = FALSE]
	direct <- f$priv$fit_partial_proportional_odds_from_covariates(X_cov)

	f$priv$fit_partial_proportional_odds()
	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(est, direct$beta, tolerance = 1e-4)
})
