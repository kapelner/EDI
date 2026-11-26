# Numerical-robustness review audit, 2026-11-19: run_all_inference_combine_pvalues() counts a row as
# usable when it has a finite weight, even if that weight is zero. Under combined_evidence_weighting
# = "custom" (non-negative weights; unnamed classes get 0), the usable rows can all carry weight 0.
# cct_combine_pvalues_full() then computes weights / sum(weights) = 0/0, and the combined p-value is
# NaN. With exactly one positive weight, it reports that single p-value as a 'combined' result, which
# breaks the documented fewer-than-2 -> NA contract.
# Where: R/EDI/R/inference_suite.R:4059 (kind: near_zero_division).
# On commit 0231668c948b this test failed with: Expected `is.nan(res0$pval)` to be FALSE.
# Differences: `actual`: TRUE `expected`: FALSE
# Regression for v1.0.7-TODO-88.

test_that("combined evidence returns NA, not NaN or a single p-value, when fewer than two rows carry positive weight", {
	combine = EDI:::run_all_inference_combine_pvalues
	pvals = c(0.01, 0.2, 0.5)
	expect_identical(combine(pvals, c(0, 0, 0)), list(pval = NA_real_, stat = NA_real_, n_used = 0L))
	expect_identical(combine(pvals, c(1, 0, 0)), list(pval = NA_real_, stat = NA_real_, n_used = 1L))

	res2 = combine(pvals, c(0, 1, 3))
	stat = tan((0.5 - 0.2) * pi) / 4
	expect_identical(res2$n_used, 2L)
	expect_equal(res2$stat, stat)
	expect_equal(res2$pval, 0.5 - atan(stat) / pi)
})

test_that("InferenceSuite reports only positively weighted classes as contributors", {
	set.seed(88)
	n = 30L
	des = EDI::DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = EDI::InferenceSuite$new(des)
	classes = c("InferenceContinOLS", "InferenceContinLin")
	invisible(capture.output(result <- suite$run_all_inference(
		classes = classes, methods = "wald", plots = FALSE,
		combined_evidence_weighting = "custom", combined_evidence_weights = c(InferenceContinOLS = 1)
	)))
	expect_identical(sort(result$results_table$inference_class), sort(classes))
	expect_true(all(is.finite(result$results_table$pval)))
	combined = result$combined_evidence
	expect_identical(combined$classes_used, "InferenceContinOLS")
	expect_identical(combined$n_classes_used, 1L)
	expect_identical(combined$pval, NA_real_)
})
