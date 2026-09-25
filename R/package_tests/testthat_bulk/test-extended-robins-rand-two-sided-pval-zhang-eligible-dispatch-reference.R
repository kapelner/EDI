library(testthat)
library(EDI)

# InferenceIncidExtendedRobins pins compute_rand_two_sided_pval = InferenceRandCI$public_methods$
# compute_rand_two_sided_pval (inference_incidence_extended_robins.R), not InferenceRand's version
# (which refuses incidence outright): a 2026-09-xx fix (same bug as InferenceIncidWald/InferenceIncidCMH,
# fixed alongside them) correcting a stale InferenceRand pin left over from before this class was
# migrated to independently compose the same components as InferenceAllSimpleAverageDiff. The source's
# own comment explicitly flags that this fix has never actually been exercised: "this class's own
# golden test's design doesn't happen to trigger the Zhang-eligible path that would have caught it."
# That's structural, not incidental -- confirmed here: InferenceIncidExtendedRobins's own constructor
# REQUIRES a blocking design (design_compatibility_reason() rejects anything else), but Zhang
# eligibility (should_use_zhang_incidence_randomization(), inference_all_abstract_rand.R) requires
# is_bernoulli_design() || has_match_structure -- a plain blocking design is neither, so this class can
# never reach a Zhang-eligible state through its own public constructor at all. Reached instead via the
# established direct-private-state-injection pattern (forcing has_match_structure = TRUE on a real
# instance), the same technique already used elsewhere in this suite for similarly config-gated
# invariants. Verified against an independent reference: InferenceIncidLogRegr (a class already
# correctly pinned to InferenceRandCI and well-tested) computes the bit-identical Zhang p-value on the
# same y/w/match-structure, since the Zhang exact test depends only on the data and match structure,
# never on the calling class's own point estimator.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBlocking$new(n = n, response_type = "incidence", verbose = FALSE, equal_block_sizes = TRUE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

force_match_structure <- function(inf) {
	priv <- inf$.__enclos_env__$private
	unlockBinding("has_match_structure", priv)
	priv$has_match_structure <- TRUE
	inf
}

test_that("InferenceIncidExtendedRobins's constructor genuinely refuses a design lacking blocking structure -- the fixture used below is real, not the disallowed direct route", {
	des <- fx(1L)
	expect_error(
		InferenceIncidExtendedRobins$new(DesignFixedBernoulli$new(n = 20L, response_type = "incidence", verbose = FALSE), verbose = FALSE),
		"requires a blocking design"
	)
	expect_silent(InferenceIncidExtendedRobins$new(des, verbose = FALSE))
})

test_that("a plain (unforced) blocking-design instance is NOT Zhang-eligible, confirming the gap is structural", {
	des <- fx(2L)
	inf <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$is_bernoulli_design())
	expect_false(priv$has_match_structure)
	expect_false(priv$should_use_zhang_incidence_randomization())
})

test_that("with has_match_structure forced TRUE, compute_rand_two_sided_pval() dispatches through the Zhang exact path and matches an independent reference class exactly, across several deltas", {
	des <- fx(3L)
	inf_er <- force_match_structure(InferenceIncidExtendedRobins$new(des, verbose = FALSE))
	expect_true(inf_er$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- force_match_structure(InferenceIncidLogRegr$new(des, verbose = FALSE))

	for (delta in c(0, 0.3, -0.5)) {
		pv_er <- inf_er$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv_er))
		expect_equal(pv_er, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})
