library(testthat)
library(EDI)

# InferenceIncidKKGCompRiskDiff/InferenceIncidKKGCompRiskRatio pin compute_rand_two_sided_pval to
# InferenceRandCI's version (fix_inference_hierarchy.md, the KK GComp migration's Progress 2026-08-18
# entry): "compute_rand_two_sided_pval pin wrong on the first pass -- copied the non-KK sibling's
# InferenceRand pin without verifying it against this class's actual legacy resolution; an R6 ancestor
# walk showed the real legacy chain resolves to InferenceRandCI instead (which correctly handles
# incidence data; InferenceRand's version refuses it outright)." Unlike InferenceIncidExtendedRobins's
# analogous fix (already regression-guarded this session), this class's Zhang-eligible state IS
# reachable through its own real constructor: a KK matching-on-the-fly design gives has_match_
# structure = TRUE directly, no private-state injection needed. Despite 10 existing test files
# referencing this class (fitting/weighted-estimate/CI/bootstrap/jackknife paths), a codebase-wide grep
# confirmed none of them call compute_rand_two_sided_pval() at all, so this specific pin has never been
# exercised. Verified against an independent reference: InferenceIncidLogRegr (an already-correctly-
# pinned class) computes the bit-identical Zhang p-value on the same y/w/match-structure, since the
# Zhang exact test depends only on the data and match structure, never the calling class's own
# point estimator.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

test_that("InferenceIncidKKGCompRiskDiff on a real KK design is genuinely Zhang-eligible and compute_rand_two_sided_pval() matches an independent reference class exactly, across several deltas", {
	des <- fx(1L)
	inf_gc <- InferenceIncidKKGCompRiskDiff$new(des, verbose = FALSE)
	expect_true(inf_gc$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in c(0, 0.3, -0.4)) {
		pv_gc <- inf_gc$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv_gc))
		expect_equal(pv_gc, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})

test_that("InferenceIncidKKGCompRiskRatio (the risk-ratio sibling) is likewise Zhang-eligible and matches the same independent reference exactly", {
	des <- fx(2L)
	inf_gc <- InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	expect_true(inf_gc$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in c(0, 0.2, -0.3)) {
		pv_gc <- inf_gc$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv_gc))
		expect_equal(pv_gc, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})
