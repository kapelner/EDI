library(testthat)
library(EDI)

# InferenceIncidKKNewcombeRiskDiff's private shared_combined() (inference_incidence_KK_newcombe_ivwc_
# univ.R) has two branches the existing reference test (test-kk-newcombe-ivwc-compound-reference.R,
# both-usable and reservoir-only-fallback cases) never reaches:
#   1. !isTRUE(private$has_match_structure) -> cache_nonestimable_estimate("kk_design_required").
#      Structurally unreachable through the public constructor: initialize() already asserts
#      des_obj$is_a_kk_matching_capable() (which is exactly what sets has_match_structure at
#      inference_all_abstract.R:106), so any successfully-constructed instance always has it TRUE.
#      Reached via the established direct-private-state-injection pattern.
#   2. Neither the matched-pairs nor the reservoir component is usable (m == 0 and nRT/nRC not both
#      > 0) -> pool_estimates_ivwc() returns NA for both estimate and variance. Reached by directly
#      overwriting the cached KKstats with a degenerate combination after a real compute_basic_match_
#      data() call, the same technique test-kk-mean-diff-ivwc-shared-extreme-imbalance-branches-
#      reference.R already established for a sibling IVWC class's cache.
#
# Separately: this iteration also confirmed -- but per instructions does NOT act on further -- that
# this class's private weighted_empirical_risk_difference() (same file) has ZERO callers anywhere in
# the source (not shared_combined(), not any dynamic private$<name>-lookup dispatch like the KK
# passthrough-compound host's compute_weighted_estimate_ivwc hook); it is genuinely dead code, so no
# test is written for it, matching this project's established convention.

fx <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidKKNewcombeRiskDiff$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("has_match_structure = FALSE (direct private-state injection: no real class leaves this reachable otherwise) marks the estimate nonestimable with reason 'kk_design_required'", {
	f <- fx(1L)
	unlockBinding("has_match_structure", f$priv); on.exit(f$priv$has_match_structure <- TRUE, add = TRUE)
	f$priv$has_match_structure <- FALSE

	est <- f$inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(isTRUE(f$priv$cached_values$nonestimable))
	expect_identical(f$priv$cached_values$nonestimable_reason, "kk_design_required")
})

test_that("when neither the matched-pairs nor the reservoir component is usable, the estimate and SE are NA (pool_estimates_ivwc's 'neither' branch)", {
	f <- fx(2L)
	f$priv$compute_basic_match_data()
	KKstats <- f$priv$cached_values$KKstats
	KKstats$m <- 0L    # no matched pairs -> est_m/var_m stay NA
	KKstats$nRT <- 0L  # no treated reservoir subjects -> est_r/var_r stay NA too
	unlockBinding("cached_values", f$priv)
	f$priv$cached_values$KKstats <- KKstats

	est <- f$inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
})
