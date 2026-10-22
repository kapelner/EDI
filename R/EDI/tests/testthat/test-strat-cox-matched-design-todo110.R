# TODO-110: StratCoxPHRegr warns on matched designs; the KK stratified Cox
# bootstrap refit uses the same shared reservoir stratum as the point estimate.

make_kk14_survival_design_todo110 = function(n = 30L) {
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
		des$add_one_subject_response(i, rexp(1))
	}
	des
}

test_that("InferenceSurvivalStratCoxPHRegr warns on matching-capable designs only", {
	set.seed(4)
	des = make_kk14_survival_design_todo110()
	expect_warning(InferenceSurvivalStratCoxPHRegr$new(des), "InferenceSurvivalKKStratCoxPHOneLik")

	des_bern = DesignSeqOneByOneBernoulli$new(n = 12, response_type = "survival", verbose = FALSE)
	for (i in 1:12) {
		des_bern$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		des_bern$add_one_subject_response(i, rexp(1))
	}
	expect_no_warning(InferenceSurvivalStratCoxPHRegr$new(des_bern))
})

test_that("KK strat Cox bootstrap refit with unit weights reproduces the point estimate (shared reservoir stratum)", {
	set.seed(4)
	n = 30L
	des = make_kk14_survival_design_todo110(n)
	inf = InferenceSurvivalKKStratCoxPHOneLik$new(des, verbose = FALSE)
	b = inf$compute_estimate()
	expect_true(any(inf$.__enclos_env__$private$m == 0L))  # has reservoir subjects
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context = list(n_units = n, row_to_unit = seq_len(n))
	# bypass the constant-weights shortcut so the weighted refit itself is exercised
	testthat::local_mocked_bindings(weights_are_effectively_constant = function(...) FALSE)
	b_boot = inf$compute_estimate_with_bootstrap_weights(rep(1, n))
	expect_equal(b_boot, b, tolerance = 1e-5)
})
