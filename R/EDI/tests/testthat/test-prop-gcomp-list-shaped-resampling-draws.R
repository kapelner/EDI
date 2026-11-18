# v1.0.6-TODO-127: InferencePropGCompMeanDiff's load_bootstrap_sample_into_worker()
# called as.integer() on the whole draw. Blocked/matched jackknife deletions and every
# exchangeable-unit draw (subsampling, m-out-of-n, on any design) arrive as
# list(i_b = rows, m_vec_b = multiplicities), so as.integer() gave NA rows and every
# replicate was NA: leave-one-block-out / leave-one-pair-out jackknife, BCa on blocked
# designs (it needs that jackknife), subsampling and m-out-of-n all returned NA.

prop_gcomp_list_draw_design = function(kind, n = 60L, seed = 1L){
	set.seed(seed)
	X = data.frame(
		x1 = rnorm(n),
		x2 = rnorm(n),
		stratum = rep(c("a", "b", "c", "d", "e", "f"), length.out = n)
	)
	if (identical(kind, "bernoulli")) {
		des = DesignFixedBernoulli$new(response_type = "proportion", n = n, verbose = FALSE)
		des$add_all_subjects_to_experiment(X[, c("x1", "x2")])
		des$assign_w_to_all_subjects()
	} else if (identical(kind, "blocking")) {
		des = DesignFixedBlocking$new(strata_cols = "stratum", response_type = "proportion", n = n, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
	} else {
		des = DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, c("x1", "x2")])
	}
	w = des$get_w()
	des$add_all_subject_responses(plogis(-0.3 + 0.5 * w + 0.4 * X$x1 + rnorm(n, 0, 0.5)))
	des
}

test_that("the worker loader reads the row indices out of a list-shaped draw", {
	des = prop_gcomp_list_draw_design("bernoulli")
	inf = InferencePropGCompMeanDiff$new(des, model_formula = ~ .)
	priv = inf$.__enclos_env__$private
	idx = c(3L, 3L, 7L, 1L, seq(10L, 50L))
	ws_vec = priv$create_bootstrap_worker_state()
	ws_list = priv$create_bootstrap_worker_state()
	priv$load_bootstrap_sample_into_worker(ws_vec, idx)
	priv$load_bootstrap_sample_into_worker(ws_list, list(i_b = idx, m_vec_b = NULL))
	expect_identical(ws_list$runtime$current_X_full, ws_vec$runtime$current_X_full)
	expect_false(anyNA(ws_list$runtime$current_X_full))
	est_vec = priv$compute_bootstrap_worker_estimate(ws_vec)
	expect_true(is.finite(est_vec))
	expect_identical(priv$compute_bootstrap_worker_estimate(ws_list), est_vec)
})

test_that("leave-one-block-out and leave-one-pair-out jackknives are finite", {
	for (kind in c("blocking", "kk")) {
		for (fm in list(~ ., ~ 1)) {
			inf = InferencePropGCompMeanDiff$new(prop_gcomp_list_draw_design(kind), model_formula = fm)
			jk = inf$approximate_jackknife_distribution_beta_hat_T()
			expect_gt(length(jk), 2L)
			expect_true(all(is.finite(jk)), info = paste(kind, deparse(fm)))
			expect_true(is.finite(inf$compute_jackknife_estimate()), info = paste(kind, deparse(fm)))
			expect_true(all(is.finite(inf$compute_jackknife_wald_confidence_interval())), info = paste(kind, deparse(fm)))
		}
	}
})

test_that("subsampling and m-out-of-n intervals are finite on Bernoulli and blocked designs", {
	for (kind in c("bernoulli", "blocking")) {
		des = prop_gcomp_list_draw_design(kind)
		inf = InferencePropGCompMeanDiff$new(des, model_formula = ~ .)
		set.seed(2)
		expect_true(all(is.finite(inf$compute_subsampling_confidence_interval(B = 61, show_progress = FALSE))), info = kind)
		set.seed(2)
		expect_true(is.finite(inf$compute_subsampling_two_sided_pval(B = 61, show_progress = FALSE)), info = kind)
		set.seed(2)
		expect_true(all(is.finite(inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 61, show_progress = FALSE))), info = kind)
		set.seed(2)
		expect_true(is.finite(inf$compute_m_out_of_n_bootstrap_two_sided_pval(B = 61, show_progress = FALSE)), info = kind)
	}
})
