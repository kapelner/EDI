library(testthat)
library(EDI)

# InferenceIncidLogBinomial pins compute_rand_two_sided_pval to InferenceRandCI's version (inference_
# incidence_log_binomial.R), one of the 19 classes sharing this exact pin (the same fix family this
# session closed for InferenceIncidExtendedRobins, InferenceIncidKKGCompRiskDiff/RiskRatio, InferenceIncid
# Wald/CMH, and a six-class sweep of InferenceIncidProbitRegr/InferenceIncidBinomialIdentityRiskDiff/
# InferenceIncidModifiedPoisson/InferenceIncidKKCondLogitOneLik/IVWC/InferenceIncidKKNewcombeRiskDiff).
# This class was missed by that sweep's own enumeration and is closed here to complete it. A codebase-
# wide grep confirmed no test anywhere calls compute_rand_two_sided_pval() successfully for this class
# (as opposed to only checking a refusal/guard message). Zhang-eligible via a plain DesignFixedBernoulli
# design. Verified against an independent reference: InferenceIncidLogRegr (an already-correctly-pinned
# class) computes the bit-identical Zhang p-value on the same y/w, since the Zhang exact test depends
# only on the data, never the calling class's own point estimator.

test_that("InferenceIncidLogBinomial on a real Bernoulli design is genuinely Zhang-eligible and compute_rand_two_sided_pval() matches an independent reference class exactly, across several deltas", {
	set.seed(1L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	inf <- InferenceIncidLogBinomial$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in c(0, 0.3, -0.4)) {
		pv <- inf$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv))
		expect_equal(pv, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})
