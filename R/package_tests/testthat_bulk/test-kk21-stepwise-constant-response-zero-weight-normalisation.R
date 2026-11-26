# Numerical-robustness review audit, 2026-11-17: When every response collected so far is identical
# (e.g. a count trial whose first responses are all 0, so log(y + 1) is constant),
# kk21_stepwise_continuous_weights_cpp finds sigma2 = 0 for every candidate and returns all NA. na0()
# turns these into all-zero raw weights. KK21's assign_wt then normalizes them as 0/0 = NaN, so the
# weighted distances are NaN and the next assignment errors in stats::quantile (or leaves NaN
# covariate weights).
# Where: R/EDI/R/design_seq_one_by_one_KK21.R:270 (kind: near_zero_division).
# On commit 4fc58cd063bc this test failed with: Expected `err` to be NULL. Differences: `actual` is a
# character vector ('missing values and NaN\'s not allowed if \'na.rm\' is FALSE') `expected` is NULL
# Tracked by v1.0.6-TODO-27; fixed together with v1.0.6-TODO-74 (equal-weight fallback in assign_wt).

test_that("KK21 stepwise design keeps assigning with finite weights when all count responses so far are zero", {
		set.seed(11)
		des = DesignSeqOneByOneKK21stepwise$new(n = 30, response_type = "count", verbose = FALSE)
		err = tryCatch({
			for (i in 1 : 30){
				des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
				des$add_one_subject_response(i, 0)
			}
			NULL
		}, error = function(e) conditionMessage(e))
		expect_null(err)
		cw = des$get_covariate_weights()
		expect_false(is.null(cw))
		expect_true(all(is.finite(cw)))
})
