# v1.0.6-TODO-217 (2): InferenceSurvivalKKRankRegrIVWC seeds each aftsrr ISMB multiplier
# bootstrap from a hash of the data it fits. cbind() with a covariate matrix carries that
# matrix's row names into the data frame, and a bootstrap draw whose model matrix is rebuilt
# (a rare covariate dropped) had character row names in the slow subset refit and automatic
# ones in the reusable worker. The two paths then drew different ISMB multipliers from the
# same data (matched variance 0.144 vs 0.097, estimate off by 0.28 on draw 4 below). The seed
# now ignores row names.

kk_rr_rare_design = function(seed = 3L, n = 80L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), b = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, design_formula = ~ x1 + x2 + b)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = 0.5 * w + 0.6 * X$x1[i] - 0.3 * X$x2[i] + 0.4 * X$b[i]
		t_i = rexp(1, exp(-eta))
		if (i %% 6L == 0L) des$add_one_subject_response(i, y_L = t_i, y_R = Inf) else des$add_one_subject_response(i, t_i)
	}
	des
}

test_that("the aftsrr seed depends on the data's values, not its row names", {
	dat = data.frame(y = c(1, 2, 3), dead = c(1, 0, 1), w = c(0, 1, 1))
	dat_named = dat
	rownames(dat_named) = c("12", "12.1", "40")
	s = .kk_rank_regr_aftsrr_seed(NULL, "matched", "f", dat)
	expect_identical(.kk_rank_regr_aftsrr_seed(NULL, "matched", "f", dat_named), s)
	dat_changed = dat
	dat_changed$y[1] = 1.5
	expect_false(identical(.kk_rank_regr_aftsrr_seed(NULL, "matched", "f", dat_changed), s))
})

test_that("KK RankRegr IVWC: reusable worker equals the slow-path refit on rare-covariate bootstrap draws", {
	skip_if_not_installed("aftgee")
	inf = InferenceSurvivalKKRankRegrIVWC$new(kk_rr_rare_design(), verbose = FALSE)
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	expect_true(isTRUE(p$use_reusable_bootstrap_worker()))
	ws = p$create_reusable_bootstrap_worker()
	set.seed(103)
	for (k in 1:5) {
		draw = p$bootstrap_sample_indices(80L)
		p$load_bootstrap_sample_into_worker(ws, draw)
		theta_worker = suppressWarnings(p$compute_bootstrap_worker_estimate(ws))
		ssq_worker = ws$worker$.__enclos_env__$private$cached_values$ssq_beta_T_matched
		sub = p$bootstrap_subset_inference(draw)
		theta_slow = suppressWarnings(sub$compute_estimate())
		expect_equal(theta_worker, theta_slow, tolerance = 1e-10, info = paste("draw", k))
		expect_equal(ssq_worker, sub$.__enclos_env__$private$cached_values$ssq_beta_T_matched, tolerance = 1e-10, info = paste("draw", k))
	}
})
