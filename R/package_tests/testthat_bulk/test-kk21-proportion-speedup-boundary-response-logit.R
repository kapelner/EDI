# Numerical-robustness review audit, 2026-11-17: With proportion_use_speedup = TRUE (the default),
# compute_weights passes log(ys / (1 - ys)) to the kernel without clamping. A single valid proportion
# response of exactly 0 or 1 becomes -Inf or +Inf, which makes every per-covariate t-statistic NaN or
# Inf. The kernel then returns machine epsilon for every covariate, so all outcome information is
# silently lost and matching becomes unweighted. The stepwise subclass clamps 0 and 1 for exactly
# this case (KK21_stepwise.R:272-274).
# Where: R/EDI/R/design_seq_one_by_one_KK21.R:380 (kind: log_zero).
# On commit 4fc58cd063bc this test failed with: Expected `max(w_out) > 1e-06` to be TRUE.
# Differences: `actual`: FALSE `expected`: TRUE
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("KK21 proportion speedup weights stay informative when a response is exactly 1", {
	skip("open a release TODO for this")
		set.seed(5)
		des = DesignSeqOneByOneKK21$new(n = 30, response_type = "proportion", verbose = FALSE)
		for (i in 1 : 25){
			x1 = rnorm(1)
			des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = rnorm(1)))
			y = if (i == 3) 1 else stats::plogis(1.5 * x1 + rnorm(1, sd = 0.2))
			des$add_one_subject_response(i, y)
		}
		priv = des$.__enclos_env__$private
		priv$all_subject_data_cache = list()
		asd = priv$compute_all_subject_data()
		w_out = priv$compute_weights(asd)
		expect_true(all(is.finite(w_out)))
		expect_true(max(w_out) > 1e-6)
})
