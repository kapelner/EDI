# TODO-176: the stereotype full fit reached a non-MLE point with a saturated
# loading from its cold start, and a boundary MLE failed the usability check,
# so covariates were dropped (or the estimate was NA). Data: replicate 1 of the
# calibration pre-push check (ordinal, n = 200, Bernoulli, null).
stereotype_boundary_rep1 = function(){
	n = 200L
	set.seed(1e6 * 5 + 7L * n + 1L)
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des = DesignFixedBernoulli$new(n = n, response_type = "ordinal")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	lat = 0.5 * X$x1 + 0.5 * X$x2 + stats::rlogis(n)
	des$add_all_subject_responses(factor(cut(lat, c(-Inf, -1, 0, 1, Inf), labels = FALSE), levels = 1:4, ordered = TRUE))
	des
}

test_that("covariate-adjusted stereotype fit keeps its covariates at a boundary MLE", {
	skip_on_cran()
	des = stereotype_boundary_rep1()
	inf = InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~ .)
	est = inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	expect_setequal(priv$best_Xmm_colnames, c("x1", "x2"))
	# the adjacent-category two-stage start reaches the MLE (VGAM::rrvglm gives
	# neg-loglik 264.668, beta_T 0.391); the cold start stopped at 265.597, -0.27
	expect_equal(as.numeric(est), 0.3908, tolerance = 1e-3)
	expect_true(is.finite(priv$cached_values$s_beta_hat_T) && priv$cached_values$s_beta_hat_T > 0)
})

test_that("treatment-only stereotype fit at the loading boundary is non-estimable", {
	skip_on_cran()
	des = stereotype_boundary_rep1()
	inf = InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~ 1)
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason,
		"stereotype_treatment_only_fit_at_loading_boundary")
})

test_that("boundary-reduced information leaves a fit without flat loadings unchanged", {
	information = diag(c(5, 4, 3, 2, 1))
	red = EDI:::.stereotype_boundary_reduced_information(information, n_alpha = 2L, p = 1L)
	expect_identical(red$n_flat, 0L)
	expect_identical(red$information, information)
	information[5, 5] = 1e-9
	red = EDI:::.stereotype_boundary_reduced_information(information, n_alpha = 2L, p = 1L)
	expect_identical(red$n_flat, 1L)
	expect_equal(dim(red$information), c(4L, 4L))
})
