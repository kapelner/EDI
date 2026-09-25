library(testthat)
library(EDI)

# DesignFixedMatchingGreedyPairSwitching used to report is_matching_design() == FALSE and never set
# private$m, even though its own draw_bootstrap_indices() override was already correctly pair-aware --
# a latent, confirmed-real gap (fix_design_hierarchy.md TODO-26): code paths that query is_matching_
# design()/get_matching_cluster_ids() for OTHER purposes (jackknife unit selection, Bayesian-bootstrap
# unit selection) fell back to a per-subject unit instead of the pair, inconsistent with the design's
# own pair structure. Fixed by TODO-35: the class now composes MatchingStructure/BatchWPregeneration,
# advertises both matching_capable and blocking_capable, and materializes private$m from its own
# binary-pair matrix. A codebase-wide grep confirmed no existing test asserts is_matching_design() ==
# TRUE for this class, nor exercises the exact consequence the fix's own writeup calls out
# ("a real statistical-behavior change... would change jackknife/Bayesian-bootstrap SE output") --
# InferenceAllSimpleAverageDiff's compute_jackknife_std_error(unit = "auto") resolving to the pair
# unit, matching an explicit unit = "pair" request exactly, rather than falling back to a per-subject
# unit as it did before the fix.

fx <- function(seed = 404L, n = 12L) {
	skip_if_not_installed("nbpMatching")
	set.seed(seed)
	des <- DesignFixedMatchingGreedyPairSwitching$new("continuous", n = n, n_iter = 2, seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("is_matching_design() and is_blocking_design() are both TRUE, and private$m is materialized and matches get_matching_cluster_ids() exactly", {
	des <- fx()
	priv <- des$.__enclos_env__$private
	expect_true(des$is_matching_design())
	expect_true(des$is_blocking_design())
	expect_true(isTRUE(priv$matching_capable))
	expect_true(isTRUE(priv$blocking_capable))
	expect_false(is.null(priv$m))
	expect_identical(as.integer(priv$m), as.integer(des$get_matching_cluster_ids()))
})

test_that("resolve_jackknife_unit('auto') resolves to 'pair' (not the per-subject fallback), and compute_jackknife_std_error(unit = 'auto') matches an explicit unit = 'pair' request exactly", {
	des <- fx(seed = 405L)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	expect_identical(priv$resolve_jackknife_unit("auto"), "pair")

	se_auto <- inf$compute_jackknife_std_error(unit = "auto")
	se_pair <- inf$compute_jackknife_std_error(unit = "pair")
	expect_true(is.finite(se_auto))
	expect_identical(se_auto, se_pair)
})
