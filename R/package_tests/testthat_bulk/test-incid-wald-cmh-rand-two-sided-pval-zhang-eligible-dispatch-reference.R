library(testthat)
library(EDI)

# InferenceIncidWald and InferenceIncidCMH both pin compute_rand_two_sided_pval to InferenceRandCI's
# version (inference_incid_wald.R / inference_incidence_cmh.R), the SAME fix InferenceIncidExtendedRobins
# got -- fix_inference_hierarchy.md's InferenceIncidExtendedRobins entry says explicitly "same bug as
# InferenceIncidWald/InferenceIncidCMH, fixed alongside them". Unlike InferenceIncidExtendedRobins
# (regression-guarded earlier this session via private-state injection, since its own constructor
# structurally forbids a Zhang-eligible design), both these classes' Zhang-eligible path IS reachable
# through a real, ordinary DesignFixedBernoulli constructor -- neither restricts itself to blocking-only
# designs the way ExtendedRobins does. Despite that, existing test coverage only reaches the REFUSAL
# branch: test-coin-cross-validation-location.R explicitly documents and tests that InferenceIncidCMH
# under a non-Zhang-eligible DesignFixedBlocking design refuses with "Randomization tests are not
# supported for incidence", but a codebase-wide grep confirmed no test anywhere calls compute_rand_two_
# sided_pval() successfully for either class on a Zhang-eligible design. Verified against an independent
# reference: InferenceIncidLogRegr (an already-correctly-pinned class) computes the bit-identical Zhang
# p-value on the same y/w, since the Zhang exact test depends only on the data, never the calling
# class's own point estimator.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

test_that("InferenceIncidWald on a real Bernoulli design is genuinely Zhang-eligible and compute_rand_two_sided_pval() matches an independent reference class exactly, across several deltas", {
	des <- fx(1L)
	inf <- InferenceIncidWald$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in c(0, 0.3, -0.4)) {
		pv <- inf$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv))
		expect_equal(pv, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})

test_that("InferenceIncidCMH on a real (non-blocking) Bernoulli design is genuinely Zhang-eligible and compute_rand_two_sided_pval() matches the same independent reference exactly", {
	des <- fx(2L)
	inf <- InferenceIncidCMH$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())

	inf_ref <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	for (delta in c(0, 0.2, -0.3)) {
		pv <- inf$compute_rand_two_sided_pval(delta = delta)
		pv_ref <- inf_ref$compute_rand_two_sided_pval(delta = delta)
		expect_true(is.finite(pv))
		expect_equal(pv, pv_ref, tolerance = 1e-12, info = paste("delta =", delta))
	}
})
