# v1.0.6-TODO-126: zero-inflated and hurdle count classes on a rank-deficient resample.
# (1) The reusable bootstrap/jackknife worker restored the full-data best_X_colnames /
#     best_Xzi_colnames on every draw. On a leave-one-block-out draw of a blocking design
#     whose formula names the strata, the dropped stratum's dummy is constant, the hardened
#     X_full drops it, and record_zero_augmented_fit_summary() failed with "NAs are not
#     allowed in subscripted assignments", so every replicate was NA. generate_mod() now
#     reduces afresh when the cached set is not inside the hardened X_full.
# (2) The slow-path subset refit (bootstrap_subset_inference()) kept the parent's n-row
#     za_X_cov_all / za_Xzi_cov_all caches, which build_component_matrix() cbind()ed
#     against the subset's w (silently recycled), so the "refit on the same rows" fitted
#     the wrong rows. Those caches are now cleared on the subset.

zero_augmented_rank_deficient_classes = c("InferenceCountZeroInflatedPoisson", "InferenceCountZeroInflatedNegBin",
	"InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin")

zero_augmented_strata_design = function(n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), s = factor(rep(c("a", "b", "c"), each = n / 3)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = "count", n = n, seed = 1,
		design_formula = ~ x + s, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.5 + 0.4 * des$get_w())))
	des
}

zero_augmented_rare_covariate_kk_design = function(n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), r = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE, design_formula = ~ x + r)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, rpois(1L, exp(0.5 + 0.4 * w_i)))
	}
	des
}

expect_zero_augmented_worker_equals_refit = function(inf, draw){
	p = inf$.__enclos_env__$private
	full_before = suppressWarnings(inf$compute_estimate())
	ws = p$create_reusable_bootstrap_worker()
	p$load_bootstrap_sample_into_worker(ws, draw)
	theta_worker = suppressWarnings(p$compute_bootstrap_worker_estimate(ws))
	sub = p$bootstrap_subset_inference(draw)
	theta_slow = suppressWarnings(sub$compute_estimate())
	sub_p = sub$.__enclos_env__$private
	for (m in list(sub_p$za_X_cov_all, sub_p$za_Xzi_cov_all)) {
		if (!is.null(m)) expect_identical(nrow(m), length(draw$i_b))
	}
	expect_true(is.finite(theta_worker))
	expect_true(is.finite(theta_slow))
	expect_equal(theta_worker, theta_slow, tolerance = 1e-6)
	expect_identical(suppressWarnings(inf$compute_estimate()), full_before)
}

for (cls in zero_augmented_rank_deficient_classes) local({
	cls = cls
	test_that(paste0(cls, ": every leave-one-block-out worker replicate equals the subset refit"), {
		inf = suppressWarnings(get(cls)$new(zero_augmented_strata_design(), verbose = FALSE))
		draws = inf$.__enclos_env__$private$build_jackknife_deletion_draws(unit = "block")
		expect_length(draws, 3L)
		for (d in draws) expect_zero_augmented_worker_equals_refit(inf, d)
	})

	test_that(paste0(cls, ": a bootstrap draw that drops a rare covariate equals the subset refit"), {
		inf = suppressWarnings(get(cls)$new(zero_augmented_rare_covariate_kk_design(), verbose = FALSE))
		p = inf$.__enclos_env__$private
		set.seed(3)
		draw = NULL
		for (k in 1:500) {
			d = p$bootstrap_sample_indices(60L)
			if (!any(d$i_b %in% c(1L, 2L))) {
				draw = d
				break
			}
		}
		expect_false(is.null(draw))
		expect_zero_augmented_worker_equals_refit(inf, draw)
	})

	test_that(paste0(cls, ": the public jackknife still says why it returns NA"), {
		inf = suppressWarnings(get(cls)$new(zero_augmented_strata_design(), verbose = FALSE))
		expect_warning(se <- inf$compute_jackknife_std_error(unit = "block"), "not supported")
		expect_true(is.na(se))
	})
})
