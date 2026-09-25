library(testthat)
library(EDI)

# Completes the sweep of the InferenceRandCI compute_rand_two_sided_pval pin (the same fix family
# closed this session for InferenceIncidExtendedRobins, InferenceIncidKKGCompRiskDiff/RiskRatio, and
# InferenceIncidWald/InferenceIncidCMH): a systematic audit of every remaining class pinning
# compute_rand_two_sided_pval = InferenceRandCI$public_methods$compute_rand_two_sided_pval (confirmed
# via `grep -rlF` across R/EDI/R/*.R) whose own response type is "incidence" (the only response type
# the Zhang dispatch applies to -- continuous/proportion classes with the same pin, e.g.
# InferenceAllSimpleAverageDiff/InferencePropFractionalLogit, use it for an unrelated reason and are
# out of scope here). Six classes had zero test references anywhere calling compute_rand_two_sided_
# pval() successfully (as opposed to only checking a refusal/guard message):
# InferenceIncidProbitRegr, InferenceIncidBinomialIdentityRiskDiff, InferenceIncidModifiedPoisson
# (all Zhang-eligible via a plain DesignFixedBernoulli) and InferenceIncidKKCondLogitOneLik/IVWC,
# InferenceIncidKKNewcombeRiskDiff (all Zhang-eligible via a real KK14 matching design). Verified
# against an independent reference: InferenceIncidLogRegr (an already-correctly-pinned class) computes
# the bit-identical Zhang p-value on the same y/w/match-structure, since the Zhang exact test depends
# only on the data and match structure, never the calling class's own point estimator.

bernoulli_fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

kk_fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

check_against_reference <- function(cls_name, des, deltas) {
	inf <- get(cls_name)$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())
	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in deltas) {
		pv <- inf$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv))
		expect_equal(pv, pv_ref, tolerance = 1e-12, info = paste(cls_name, "delta =", delta))
	}
}

test_that("InferenceIncidProbitRegr, InferenceIncidBinomialIdentityRiskDiff, InferenceIncidModifiedPoisson: Zhang-eligible via a plain Bernoulli design, all match the independent reference exactly", {
	des <- bernoulli_fx(1L)
	for (cls in c("InferenceIncidProbitRegr", "InferenceIncidBinomialIdentityRiskDiff", "InferenceIncidModifiedPoisson")) {
		check_against_reference(cls, des, c(0, 0.3, -0.4))
	}
})

test_that("InferenceIncidKKCondLogitOneLik, InferenceIncidKKCondLogitIVWC, InferenceIncidKKNewcombeRiskDiff: Zhang-eligible via a real KK14 matching design, all match the independent reference exactly", {
	des <- kk_fx(2L)
	for (cls in c("InferenceIncidKKCondLogitOneLik", "InferenceIncidKKCondLogitIVWC", "InferenceIncidKKNewcombeRiskDiff")) {
		check_against_reference(cls, des, c(0, 0.2, -0.3))
	}
})
