library(testthat)
library(EDI)

make_proportion_family_design = function(n = 16L, seed = 990L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "proportion", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = seq(-1, 1, length.out = n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(seq(0.05, 0.95, length.out = n))
	des
}

test_that("beta-regression marginal mean helpers match direct inverse-link calculations", {
	inf = InferencePropBetaRegr$new(make_proportion_family_design())
	p = inf$.__enclos_env__$private
	X = cbind(`(Intercept)` = 1, treatment = c(0, 1, 0), x = c(-1, 0, 1))
	b = c(`(Intercept)` = -0.4, treatment = 0.9, x = 0.2)
	expect_equal(p$beta_regr_mean_from_coefs(b, X), as.numeric(plogis(X %*% b)))
	X1 = X0 = X
	X1[, 2] = 1
	X0[, 2] = 0
	expect_equal(
		p$beta_regr_marginal_functional(b, X),
		mean(plogis(X1 %*% b)) - mean(plogis(X0 %*% b))
	)
	expect_setequal(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff"))
	expect_identical(inf$set_estimand("marginal_mean_diff"), inf)
	expect_identical(inf$get_estimand(), "marginal_mean_diff")
})

test_that("fractional-logit and quantile proportion classes validate public contracts", {
	des = make_proportion_family_design(seed = 991L)
	fl = InferencePropFractionalLogit$new(des)
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferencePropFractionalLogit$public_methods))
	expect_true("build_design_matrix" %in% names(InferencePropFractionalLogit$private_methods))
	expect_true(fl$supports("likelihood_tests"))

	qr = InferencePropQuantileRegr$new(des, tau = 0.25)
	expect_equal(qr$.__enclos_env__$private$tau, 0.25)
	expect_error(InferencePropQuantileRegr$new(des, tau = 0), "tau")
	expect_error(InferencePropQuantileRegr$new(des, tau = 1), "tau")
	expect_true("reduce_design_matrix_for_quantile" %in% names(InferencePropQuantileRegr$private_methods))
	expect_true("compute_fast_randomization_distr" %in% names(InferencePropQuantileRegr$private_methods))
})

test_that("proportion KK quantile generators preserve tau and weighted-estimate hooks", {
	expect_true("tau" %in% names(InferencePropKKQuantileRegrIVWC$private_fields))
	expect_true("tau" %in% names(InferencePropKKQuantileRegrOneLik$private_fields))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferencePropKKQuantileRegrIVWC$public_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferencePropKKQuantileRegrOneLik$public_methods))
	expect_true("compute_basic_match_data" %in% names(InferencePropKKQuantileRegrIVWC$private_methods))
	expect_true("compute_basic_match_data" %in% names(InferencePropKKQuantileRegrOneLik$private_methods))
})

test_that("count KK GEE and conditional-Poisson families expose response and likelihood contracts", {
	expect_true("gee_response_type" %in% names(InferenceCountPoissonKKGEE$private_methods))
	expect_true("shared_gee_dispatch" %in% names(InferenceCountPoissonKKGEE$private_methods))
	expect_true("compute_fast_randomization_distr" %in% names(InferenceCountKKHurdlePoissonIVWC$private_methods))
	expect_true("fit_hurdle_for_matched_pairs" %in% names(InferenceCountKKHurdlePoissonIVWC$private_methods))
	expect_true("fit_poisson_for_reservoir" %in% names(InferenceCountKKHurdlePoissonIVWC$private_methods))
	expect_true("combined_hurdle_neg_loglik" %in% names(InferenceCountKKHurdlePoissonOneLik$private_methods))
	expect_true("combined_hurdle_score" %in% names(InferenceCountKKHurdlePoissonOneLik$private_methods))
	expect_true("combined_hurdle_hessian" %in% names(InferenceCountKKHurdlePoissonOneLik$private_methods))
	expect_true("simulate_under_lik_null" %in% names(InferenceCountKKHurdlePoissonOneLik$private_methods))
})
