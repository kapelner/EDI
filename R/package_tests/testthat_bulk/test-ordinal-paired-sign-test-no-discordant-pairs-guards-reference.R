library(testthat)
library(EDI)

# InferenceOrdinalPairedSignTest (inference_ordinal_paired_sign_test.R) has 3 distinct sites that
# cache "ordinal_paired_sign_test_no_discordant_pairs" when there are no usable (untied) pair
# differences, none of which had a test reference anywhere:
#   1. shared() (unweighted), harden = TRUE: all matched pairs are tied (n_eff == 0) -- the estimate
#      is still reported as 0 (p_hat = 0.5), but cache_nonestimable_SE() flags the SE as unavailable
#      (there's no usable variance information from an all-tied sample).
#   2. shared() (unweighted), harden = FALSE (or no pair differences at all): the same all-tied
#      condition instead calls cache_nonestimable_ESTIMATE(), leaving beta_hat_T itself NA too --
#      the harden flag genuinely changes which of estimate/SE gets marked non-estimable, not just
#      whether a fallback estimate is offered.
#   3. compute_estimate_with_bootstrap_weights(): no matched pairs exist at all (pair_ids is empty,
#      distinct from "pairs exist but are all tied") -- always cache_nonestimable_ESTIMATE()
#      regardless of harden.
# Reached via a constant ordinal response (every matched pair tied) for sites 1-2, and via directly
# overwriting the private match-id vector m to all-reservoir (unlockBinding) for site 3 -- the same
# private-state-injection technique already used elsewhere in this suite.

paired_sign_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rep(2L, n))  # constant response -> every matched pair is tied
	des
}

test_that("harden = TRUE: an all-tied sample reports beta_hat_T = 0 but flags the SE as non-estimable", {
	des <- paired_sign_fixture()
	inf <- InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$harden)

	res <- inf$compute_estimate()
	expect_equal(res, 0)
	expect_identical(inf$get_nonestimable_reason(), "ordinal_paired_sign_test_no_discordant_pairs")
})

test_that("harden = FALSE: the same all-tied sample instead reports the estimate itself as non-estimable", {
	des <- paired_sign_fixture(seed = 2L)
	inf <- InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
	inf$.__enclos_env__$private$harden <- FALSE

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "ordinal_paired_sign_test_no_discordant_pairs")
})

test_that("compute_estimate_with_bootstrap_weights() is non-estimable when no matched pairs exist at all", {
	des <- paired_sign_fixture(seed = 3L)
	inf <- InferenceOrdinalPairedSignTest$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	ctx <- p$build_bayesian_bootstrap_context()
	p$current_bayesian_bootstrap_context <- ctx
	unlockBinding("m", p)
	p$m <- rep(0L, 20L)  # every subject is "reservoir"; no pair ids at all

	res <- p$weighted_refit_impl(rep(1, ctx$n_units))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "ordinal_paired_sign_test_no_discordant_pairs")
})
