library(testthat)
library(EDI)

make_incid_kk_cond_logit_pathology_design = function() {
	X = data.frame(
		x1 = c(-2.0, -1.9, -1.0, -0.9, 0.9, 1.0, 1.9, 2.0),
		x2 = c(0, 0, 1, 1, 0, 0, 1, 1)
	)
	des = DesignFixedBinaryMatch$new(
		response_type = "incidence",
		n = nrow(X),
		m = rep(seq_len(nrow(X) / 2L), each = 2L),
		design_formula = ~ .,
		verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(c(1, 0, 0, 1, 1, 0, 0, 1))
	des$add_all_subject_responses(c(1, 0, 0, 1, 1, 0, 0, 1))
	des
}

mock_usable_logistic_result = function(X, beta_treatment, include_variance = FALSE) {
	j = match("beta_T", colnames(X))
	if (is.na(j)) j = min(2L, ncol(X))
	b = numeric(ncol(X))
	b[j] = beta_treatment
	information = diag(ncol(X))
	out = list(
		b = b,
		params = b,
		converged = TRUE,
		hit_iteration_cap = FALSE,
		gradient_norm = 0,
		fisher_information = information,
		XtWX = information,
		neg_ll = 1,
		neg_loglik = 1
	)
	if (include_variance) out$ssq_b_j = 1
	out
}

test_that("four comprehensive FixedBinaryMatch extreme estimates are rejected once", {
	# These are the four finite pathological treatment estimates observed in the
	# comprehensive pima/FixedBinaryMatch/model_formula=~./beta_T=0 contexts.
	extreme_beta = c(10.4600924490569, -10.841, 16.342, 18.095)
	current_beta = NA_real_
	testthat::local_mocked_bindings(
		fast_logistic_regression_cpp = function(X, y, ...) {
			mock_usable_logistic_result(X, current_beta)
		},
		.package = "EDI"
	)

	for (beta in extreme_beta) {
		current_beta = beta
		inf = InferenceIncidKKCondLogitOneLik$new(
			make_incid_kk_cond_logit_pathology_design(),
			model_formula = ~ .,
			verbose = FALSE
		)

		expect_true(is.na(inf$compute_estimate(estimate_only = TRUE)), info = beta)
		expect_true(inf$is_nonestimable("estimate"), info = beta)
		expect_identical(inf$get_nonestimable_stage(), "estimate", info = beta)
		expect_identical(
			inf$get_nonestimable_reason(),
			"kk_clogit_combined_extreme_treatment_coefficient",
			info = beta
		)

		for (testing_type in c("score", "gradient", "lik_ratio")) {
			inf$set_testing_type(testing_type)
			expect_true(is.na(inf$compute_asymp_two_sided_pval()), info = paste(beta, testing_type))
			expect_true(all(is.na(inf$compute_asymp_confidence_interval())), info = paste(beta, testing_type))
		}
		expect_true(is.na(inf$compute_rand_two_sided_pval(r = 5L, show_progress = FALSE)), info = beta)
		expect_true(is.na(inf$compute_lik_ratio_bootstrap_two_sided_pval(
			B = 5L,
			min_number_usable_samples = 5L,
			show_progress = FALSE
		)), info = beta)
	}
})

test_that("combined-logit acceptance predicate rejects every numerical pathology", {
	inf = InferenceIncidKKCondLogitOneLik$new(
		make_incid_kk_cond_logit_pathology_design(),
		model_formula = ~ .,
		verbose = FALSE
	)
	assess = inf$.__enclos_env__$private$assess_combined_fit
	base = mock_usable_logistic_result(
		matrix(0, nrow = 4L, ncol = 2L, dimnames = list(NULL, c("x1", "beta_T"))),
		beta_treatment = 0,
		include_variance = TRUE
	)

	expect_true(assess(base, 2L, require_variance = TRUE)$usable)
	bad = base; bad$converged = FALSE
	expect_identical(assess(bad, 2L)$reason, "not_converged")
	bad = base; bad$hit_iteration_cap = TRUE
	expect_identical(assess(bad, 2L)$reason, "iteration_cap_reached")
	bad = base; bad$gradient_norm = NA_real_
	expect_identical(assess(bad, 2L)$reason, "gradient_norm_nonfinite")
	bad = base; bad$fisher_information = matrix(c(1, 2, 2, 1), 2L)
	expect_identical(assess(bad, 2L)$reason, "information_not_positive_definite")
	bad = base; bad$fisher_information = diag(c(1, 1e-12))
	expect_identical(assess(bad, 2L)$reason, "information_ill_conditioned")
	bad = base; bad$ssq_b_j = NA_real_
	derived_variance = assess(bad, 2L, require_variance = TRUE)
	expect_true(derived_variance$usable)
	expect_equal(derived_variance$variance, 1)
})

test_that("weighted combined-logit refits use the same separation guard", {
	current_beta = 18.095
	testthat::local_mocked_bindings(
		fast_logistic_regression_weighted_cpp = function(X, y, weights, ...) {
			mock_usable_logistic_result(X, current_beta)
		},
		.package = "EDI"
	)
	inf = InferenceIncidKKCondLogitOneLik$new(
		make_incid_kk_cond_logit_pathology_design(),
		model_formula = ~ .,
		verbose = FALSE
	)
	weights = rep(c(0.5, 1.5), 4L)
	# One weight per subject row (not per matched pair) -- install an
	# identity row-to-unit context, matching the row-level weighting this
	# test exercises (see test-negbin-weighted.R for the same idiom on an
	# iid design). compute_estimate_with_bootstrap_weights() requires a
	# Bayesian-bootstrap context to already be installed; it does not
	# build one implicitly.
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context = list(
		row_to_unit = seq_along(weights),
		unit_group_id = rep(1L, length(weights)),
		n_units = length(weights)
	)
	expect_true(is.na(inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)))
	expect_true(inf$is_nonestimable("estimate"))
	expect_identical(
		inf$get_nonestimable_reason(),
		"kk_clogit_combined_weighted_extreme_treatment_coefficient"
	)
})

test_that("full and parametric-bootstrap combined-logit fits use the same guard", {
	testthat::local_mocked_bindings(
		fast_logistic_regression_with_var_cpp = function(X, y, ...) {
			mock_usable_logistic_result(X, beta_treatment = -10.841, include_variance = TRUE)
		},
		.package = "EDI"
	)
	inf = InferenceIncidKKCondLogitOneLik$new(
		make_incid_kk_cond_logit_pathology_design(),
		model_formula = ~ .,
		verbose = FALSE
	)
	expect_true(is.na(inf$compute_estimate(estimate_only = FALSE)))
	expect_identical(
		inf$get_nonestimable_reason(),
		"kk_clogit_combined_extreme_treatment_coefficient"
	)

	testthat::local_mocked_bindings(
		fast_logistic_regression_cpp = function(X, y, ...) {
			mock_usable_logistic_result(X, beta_treatment = 16.342)
		},
		.package = "EDI"
	)
	X = matrix(0, nrow = 8L, ncol = 2L, dimnames = list(NULL, c("intercept", "beta_T")))
	simulated = inf$.__enclos_env__$private$simulate_under_lik_null(
		spec = list(X = X, j = 2L),
		delta = 0,
		null_fit = list(b = c(0, 0))
	)
	expect_null(simulated)
})
