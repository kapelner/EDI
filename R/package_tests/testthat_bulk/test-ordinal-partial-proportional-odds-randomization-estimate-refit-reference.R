library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's compute_treatment_estimate_during_randomization_
# inference() (inference_ordinal_partial_proportional_odds.R) had no test reference anywhere.
#
# GOTCHA investigated and ruled OUT as a bug -- the same pattern already found and worked around for
# InferenceIncidKKModifiedPoisson earlier this session: shared(estimate_only = TRUE)'s early-return
# guard (`if (estimate_only && !is.null(cached_values$beta_hat_T)) return(...)`) skips
# re-populating private$best_X_colnames once compute_estimate() has already cached a point estimate,
# so calling this method directly on the SAME already-fitted instance after mutating private$w
# always falls through to compute_estimate()'s own stale cached value (confirmed empirically: the
# "permuted" estimate came back byte-identical to the pre-permutation one). The real randomization
# dispatch runs each permutation replicate on a fresh self$duplicate() worker clone instead (matching
# the ModifiedPoisson finding), which this file uses throughout.
#
#   1. On a duplicate() worker with no covariates (model_formula = ~1), the refit reduces to the same
#      estimate as the ordinary proportional-odds class, independently verified against
#      MASS::polr() -- the same "single-treatment-coefficient models agree" identity already
#      established for compute_estimate() in test-ordinal-classes-treatment-estimates-match-polr-and-
#      share-a-sign-convention-reference.R.
#   2. On a duplicate() worker with covariates, the refit on the SAME w matches compute_estimate()'s
#      own value (self-consistency: no simple independent reference package implements partial-
#      proportional-odds directly).
#   3. A fitter failure (fit_partial_proportional_odds_from_covariates() returns NULL, or a
#      non-finite beta) returns NA.

skip_if_not_installed("MASS")

ppo_no_cov_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, y = y, w = w)
}

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
	inf$num_cores <- 1L
	list(inf = inf, x = X$x, y = y, w = w)
}

test_that("on a duplicate() worker with no covariates, the refit matches MASS::polr() (single-treatment-coefficient identity)", {
	f <- ppo_no_cov_fixture()
	f$inf$compute_estimate()

	set.seed(9)
	w2 <- sample(f$w)
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	expect_null(pw$cached_values$beta_hat_T)
	pw$w <- w2

	est <- pw$compute_treatment_estimate_during_randomization_inference()
	Xd <- data.frame(y = factor(f$y, ordered = TRUE), w = w2)
	ref <- unname(coef(suppressWarnings(MASS::polr(y ~ w, data = Xd)))["w"])
	expect_equal(est, ref, tolerance = 5e-3)
})

test_that("on a duplicate() worker with covariates, the refit on the same w matches compute_estimate()'s own value", {
	f <- ppo_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))

	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	same_w_est <- pw$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-4)
})

test_that("a fitter failure (fit_partial_proportional_odds_from_covariates() returns NULL, or a non-finite beta) returns NA", {
	f <- ppo_fixture(seed = 6L)
	f$inf$compute_estimate()
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	unlockBinding("fit_partial_proportional_odds_from_covariates", pw)
	pw$fit_partial_proportional_odds_from_covariates <- function(...) NULL
	expect_true(is.na(pw$compute_treatment_estimate_during_randomization_inference()))

	worker2 <- f$inf$duplicate()
	pw2 <- worker2$.__enclos_env__$private
	unlockBinding("fit_partial_proportional_odds_from_covariates", pw2)
	pw2$fit_partial_proportional_odds_from_covariates <- function(...) list(beta = NA_real_)
	expect_true(is.na(pw2$compute_treatment_estimate_during_randomization_inference()))
})
