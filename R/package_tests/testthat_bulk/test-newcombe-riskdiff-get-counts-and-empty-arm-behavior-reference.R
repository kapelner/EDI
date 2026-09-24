library(testthat)
library(EDI)

# InferenceIncidNewcombeRiskDiff's private get_counts() (inference_incidence_newcombe_univ.R) --
# per-arm n/x/p computed directly from private$w/private$y, structurally identical to the already-
# tested InferenceIncidMiettinenNurminenRiskDiff sibling's own get_counts()
# (test-mn-riskdiff-get-counts-empty-arm-nonestimable-reason-and-mn-eps-reference.R) -- had no test
# calling it directly anywhere (confirmed via grep; only exercised indirectly through compute_estimate()
# in other files). Unlike its MN sibling, which explicitly calls cache_nonestimable_estimate(
# "miettinen_nurminen_fit_unavailable") when an arm is empty, this class's shared() does NOT call
# cache_nonestimable_estimate() at all on the empty-arm path -- beta_hat_T is simply left as the NA
# arithmetic result of counts$p_t - counts$p_c (one side NA). This test documents the CURRENT observable
# contract (NA estimate, but is_nonestimable()/get_nonestimable_reason() stay unflagged) rather than
# asserting it matches the MN sibling's richer contract -- the same kind of cross-sibling-class
# inconsistency already documented for InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik's fit-failure
# path in the immediately preceding iteration's test file; noted here, not fixed.
#   1. get_counts() returns the exact per-arm n/x/p computed directly from w and y.
#   2. An empty control arm: get_counts() reports n_c = 0 and p_c = NA; compute_estimate() returns NA,
#      but is_nonestimable("estimate") stays FALSE and get_nonestimable_reason() stays NULL.
#   3. The symmetric empty-treatment-arm case behaves the same way.

mk <- function(y, w) {
	n <- length(y)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("get_counts() returns the exact per-arm n/x/p computed directly from w and y", {
	set.seed(1); n <- 20L; w <- rep(c(0, 1), length.out = n); y <- rbinom(n, 1, 0.5)
	des <- mk(y, w)
	inf <- InferenceIncidNewcombeRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_t, sum(w == 1)); expect_equal(counts$n_c, sum(w == 0))
	expect_equal(counts$x_t, sum(y[w == 1])); expect_equal(counts$x_c, sum(y[w == 0]))
	expect_equal(counts$p_t, sum(y[w == 1]) / sum(w == 1)); expect_equal(counts$p_c, sum(y[w == 0]) / sum(w == 0))
})

test_that("an empty control arm: get_counts() reports n_c = 0, p_c = NA; compute_estimate() is NA but NOT flagged nonestimable", {
	set.seed(2); n <- 10L; y <- rbinom(n, 1, 0.5)
	des <- mk(y, rep(1, n))                                                          # every subject treated: control arm empty
	inf <- InferenceIncidNewcombeRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_c, 0L); expect_true(is.na(counts$p_c))
	expect_equal(counts$n_t, n); expect_equal(counts$p_t, sum(y) / n)

	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_false(inf$is_nonestimable("estimate"))
	expect_null(inf$get_nonestimable_reason())
})

test_that("the symmetric empty-treatment-arm case behaves the same way", {
	set.seed(3); n <- 8L; y <- rbinom(n, 1, 0.5)
	des <- mk(y, rep(0, n))
	inf <- InferenceIncidNewcombeRiskDiff$new(des)
	counts <- inf$.__enclos_env__$private$get_counts()
	expect_equal(counts$n_t, 0L); expect_true(is.na(counts$p_t))
	est <- inf$compute_estimate()
	expect_true(is.na(est))
	expect_false(inf$is_nonestimable("estimate"))
	expect_null(inf$get_nonestimable_reason())
})
