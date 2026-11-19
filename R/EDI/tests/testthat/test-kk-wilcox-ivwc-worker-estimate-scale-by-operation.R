# v1.0.6-TODO-217 (3): InferenceAllKKWilcoxIVWC's reusable-worker hook returns the
# standardized W statistic, the scale of its randomization tests (2026-10-12 fix). On a
# sequential KK design only the randomization operations reach that hook, but on a
# non-sequential matched design (DesignFixedBinaryMatch) the m-out-of-n bootstrap,
# subsampling and the jackknife distribution reach it too, and got W statistics (replicate
# means 1.47 / 1.52 / 2.44 for an HL estimate of 0.63). Only the randomization operations
# use the W scale now; every other operation gets the Hodges-Lehmann IVWC estimate.

kk_wilcox_fixed_match_inference = function(seed = 1L, n = 40L){
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(0.5 * des$get_w() + rnorm(n))
	inf = InferenceAllKKWilcoxIVWC$new(des, verbose = FALSE)
	inf$num_cores = 1L
	inf
}

test_that("KK Wilcox IVWC worker: estimate scale for bootstrap-type operations, W scale for randomization", {
	skip_if_not_installed("nbpMatching")
	inf = kk_wilcox_fixed_match_inference()
	est = inf$compute_estimate()
	p = inf$.__enclos_env__$private
	expect_true(isTRUE(p$use_reusable_bootstrap_worker()))
	ws = p$create_reusable_bootstrap_worker()
	set.seed(2)
	draw = p$bootstrap_sample_indices(40L)
	p$load_bootstrap_sample_into_worker(ws, draw)
	theta_slow = p$bootstrap_subset_inference(draw)$compute_estimate(estimate_only = TRUE)
	w_stat = ws$worker$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
	expect_false(isTRUE(all.equal(theta_slow, w_stat)))
	for (op in c("non_param_boot", "m_out_of_n_boot", "subsampling", "jackknife", "bayesian_boot")) {
		p$active_resampling_operation = op
		expect_equal(p$compute_bootstrap_worker_estimate(ws), theta_slow, tolerance = 1e-12, info = op)
	}
	for (op in c("rand", "rand_bootstrap")) {
		p$active_resampling_operation = op
		expect_equal(p$compute_bootstrap_worker_estimate(ws), w_stat, tolerance = 1e-12, info = op)
	}
	p$active_resampling_operation = NULL
})

test_that("KK Wilcox IVWC on a fixed matched design: m-out-of-n, subsampling and jackknife replicates centre on the estimate", {
	skip_if_not_installed("nbpMatching")
	inf = kk_wilcox_fixed_match_inference()
	est = inf$compute_estimate()
	set.seed(2)
	mn = suppressWarnings(inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(B = 50, show_progress = FALSE))
	set.seed(2)
	ss = suppressWarnings(inf$approximate_subsampling_distribution_beta_hat_T(B = 50, show_progress = FALSE))
	jk = suppressWarnings(inf$approximate_jackknife_distribution_beta_hat_T())
	# W-scale replicates averaged 1.47, 1.52 and 2.44 here.
	expect_lt(abs(mean(mn, na.rm = TRUE) - est), 0.3)
	expect_lt(abs(mean(ss, na.rm = TRUE) - est), 0.3)
	expect_lt(abs(mean(jk, na.rm = TRUE) - est), 0.1)
})
