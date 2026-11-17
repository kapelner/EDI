# Numerical-robustness review audit, 2026-11-17: With sequential Monte Carlo enabled and
# mc_batch_size below 10 (a positive count that normalize_randomization_ci_search_control accepts),
# the first batch's prefix has fewer than the 10 finite draws that
# compute_two_sided_randomization_pval_from_t0s requires. That function returns NA, and
# compute_two_sided_pval_with_sequential_mc returns that NA at once instead of drawing the next
# batch. So the randomization p-value is NA even though the requested r draws (all finite) would
# define it.
# Where: R/EDI/R/inference_all_abstract_rand.R:938 (kind: na_where_defined).
# On commit 4fc58cd063bc this test failed with: Expected `is.finite(p)` to be TRUE. Differences:
# `actual`: FALSE `expected`: TRUE
# Tracked by v1.0.6-TODO-55; remove the skip() when that fix lands.

test_that("sequential-MC randomization p-value is finite when mc_batch_size is below the 10-draw minimum", {
	skip("known bug, v1.0.6-TODO-55")
		set.seed(1)
		n = 20L
		des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 1L)
		des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
		des$assign_w_to_all_subjects()
		w = des$get_w()
		des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
		inf = InferenceAllSimpleAverageDiff$new(des)
		priv = inf$.__enclos_env__$private
		priv$randomization_mc_control = list(
			mc_enable = TRUE,
			mc_batch_size = 5L,
			mc_min_draws = 5L,
			mc_conf_level = 0.99,
			mc_stop_threshold = 0.05
		)
		p = inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE)
		expect_true(is.finite(p))
})
