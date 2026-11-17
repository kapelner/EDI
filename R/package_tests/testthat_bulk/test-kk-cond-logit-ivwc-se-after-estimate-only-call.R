# Numerical-robustness review audit, 2026-11-17: InferenceIncidKKCondLogitIVWC$shared(estimate_only =
# TRUE) returns before setting s_beta_hat_T when both the matched and reservoir components are usable
# (line 880). A later shared(estimate_only = FALSE) then exits early at line 854 because beta_hat_T
# is cached. So after compute_estimate(estimate_only = TRUE), the Wald CI, p-value and SE are NA,
# although the same object gives finite values when fresh.
# Where: R/EDI/R/inference_incidence_KK_cond_logit.R:854 (kind: na_where_defined).
# On commit 48765322fe90 this test failed with: Expected `ci` to equal `ci_ref`. Differences: 2/2
# mismatches (average diff: NaN) [1] NA - -0.258 == NA [2] NA - 1.350 == NA
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("KK cond-logit IVWC Wald CI after an estimate-only call matches a fresh object", {
	skip("open a release TODO for this")
		set.seed(20261117)
		n = 100L
		X = data.frame(x1 = rnorm(n))
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
		for (i in seq_len(n)) {
			w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, stats::rbinom(1L, 1L, stats::plogis(-0.2 + 0.8 * w_i + 0.5 * X$x1[i])))
		}
		ref = InferenceIncidKKCondLogitIVWC$new(des)
		ci_ref = as.numeric(ref$compute_asymp_confidence_interval())
		inf = InferenceIncidKKCondLogitIVWC$new(des)
		inf$compute_estimate(estimate_only = TRUE)
		ci = as.numeric(inf$compute_asymp_confidence_interval())
		expect_equal(ci, ci_ref, tolerance = 1e-10)
})
