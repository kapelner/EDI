make_survival_fit_guard_design = function(n = 12L) {
	set.seed(20260824)
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n) / n))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(
		ys = seq_len(n),
		y_Ls = rep(NA_real_, n),
		y_Rs = rep(NA_real_, n)
	)
	des
}

test_that("stratified Cox accepts a converged strong finite treatment effect", {
	des = make_survival_fit_guard_design()

	testthat::local_mocked_bindings(
		compute_survival_strata_ids_cpp = function(X) {
			list(strata_id = rep.int(1L, nrow(X)), selected_cols = integer(0), num_strata = 1L)
		},
		build_cox_data_cache_cpp = function(...) list(mock_cache = TRUE),
		fast_coxph_regression_prebuilt_cpp = function(...) {
			list(
				coefficients = c(w = -1.25, x = 0.1),
				vcov = diag(c(0.04, 0.01)),
				fisher_information = diag(c(25, 100)),
				neg_ll = 10,
				converged = TRUE
			)
		},
		.package = "EDI"
	)

	inf = InferenceSurvivalStratCoxPHRegr$new(des, verbose = FALSE)
	expect_equal(inf$compute_estimate(), -1.25)
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0.2)
	expect_false(inf$is_nonestimable("estimate"))
})

test_that("dependent-censoring transform accepts a converged strong finite treatment effect", {
	des = make_survival_fit_guard_design()

	testthat::local_mocked_bindings(
		fast_dep_cens_transform_optim_cpp = function(X, ...) {
			p = ncol(X)
			n_params = 2L * p + 3L
			b = numeric(n_params)
			b[2L] = 1.25
			variances = rep(0.01, n_params)
			variances[2L] = 0.04
			list(
				b = b,
				vcov = diag(variances),
				fisher_information = diag(c(25, rep(100, n_params - 1L))),
				neg_loglik = 10,
				converged = TRUE
			)
		},
		.package = "EDI"
	)

	inf = InferenceSurvivalDepCensTransformRegr$new(des, model_formula = ~1, verbose = FALSE)
	expect_equal(inf$compute_estimate(), 1.25)
	expect_equal(inf$.__enclos_env__$private$cached_values$s_beta_hat_T, 0.2)
	expect_false(inf$is_nonestimable("estimate"))
})
