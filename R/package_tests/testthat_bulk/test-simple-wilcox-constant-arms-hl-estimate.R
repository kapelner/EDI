# Numerical-robustness review audit, 2026-11-17: When each arm is constant (e.g. every treated y = 2
# and every control y = 1), stats::wilcox.test(conf.int = TRUE) stops with 'cannot compute confidence
# interval when all observations are tied'. shared() catches the error and calls
# cache_nonestimable_estimate("wilcox_fit_unavailable"), so compute_estimate() returns NA. The
# Hodges-Lehmann estimate is still defined (here it is 1), and the estimate_only path returns it
# correctly.
# Where: R/EDI/R/inference_all_simple_wilcox.R:337 (kind: na_where_defined).
# On commit 4fc58cd063bc this test failed with: Expected `inf$compute_estimate()` to equal 1.
# Differences: 1/1 mismatches [1] NA - 1 == NA
# Tracked by v1.0.6-TODO-59; remove the skip() when that fix lands.

test_that("Hodges-Lehmann estimate is returned when each arm is constant", {
	skip("known bug, v1.0.6-TODO-59")
		set.seed(1)
		n = 20L
		des = DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
		des$assign_w_to_all_subjects()
		w = des$get_w()
		expect_true(any(w == 1) && any(w == 0))
		des$add_all_subject_responses(ifelse(w == 1, 2, 1))
		inf = InferenceAllSimpleWilcox$new(des, verbose = FALSE)
		# every pairwise treated-minus-control difference is 1, so the HL estimate is 1
		expect_equal(inf$compute_estimate(), 1)
})
