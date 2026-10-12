library(testthat)
library(EDI)

make_proportion_design_for_helpers = function(n = 12L, seed = 830L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "proportion", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = seq(-1, 1, length.out = n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(seq(0.1, 0.9, length.out = n))
	des
}

test_that("marginal estimand normalization and cache keys are canonical", {
	inf = InferencePropZeroOneInflatedBetaRegr$new(make_proportion_design_for_helpers())
	p = inf$.__enclos_env__$private
	expect_identical(inf$get_estimand(), "conditional")
	expect_setequal(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff"))
	expect_identical(p$normalize_estimand("MARGINAL_MEAN_DIFF"), "marginal_mean_diff")
	expect_identical(p$normalize_estimand(c("marginal_ratio", "conditional")), "marginal_ratio")
	expect_error(p$normalize_estimand("risk_difference"), "Unrecognized estimand")
	expect_error(inf$set_estimand("marginal_ratio"), "does not support")
	expect_identical(inf$get_estimand(), "conditional")
	expect_identical(inf$set_estimand("marginal_mean_diff"), inf)
	expect_identical(inf$get_estimand(), "marginal_mean_diff")
	expect_identical(p$marginal_estimand_cache_key(), "marginal_mean_diff")
})

test_that("proportion g-computation standardized effects match direct calculations", {
	inf = InferencePropGCompMeanDiff$new(make_proportion_design_for_helpers())
	p = inf$.__enclos_env__$private
	X = cbind(`(Intercept)` = 1, treatment = c(0, 1, 0), x = c(-1, 0, 1))
	b = c(`(Intercept)` = -0.2, treatment = 0.8, x = 0.3)
	components = p$compute_standardized_effect_components(X, b, 2L)
	X1 = X0 = X
	X1[, 2] = 1
	X0[, 2] = 0
	expect_equal(components$mean1_i, as.numeric(plogis(X1 %*% b)))
	expect_equal(components$mean0_i, as.numeric(plogis(X0 %*% b)))
	expect_equal(components$md, mean(plogis(X1 %*% b) - plogis(X0 %*% b)))

	clipped = p$compute_standardized_effect_components(X, c(-100, 200, 0), 2L, 0.01, 0.99)
	expect_true(all(clipped$mean1_i <= 0.99 & clipped$mean1_i >= 0.01))
	expect_true(all(clipped$mean0_i <= 0.99 & clipped$mean0_i >= 0.01))

	indefinite = matrix(c(1, 2, 2, 1), 2)
	stable = p$stabilize_covariance_matrix(indefinite)
	expect_true(all(eigen(stable, symmetric = TRUE)$values > 0))
	expect_null(p$stabilize_covariance_matrix(matrix(c(1, NA, NA, 1), 2)))
	inv = p$invert_information_matrix(indefinite)
	expect_true(all(eigen(inv, symmetric = TRUE)$values > 0))
	expect_null(p$invert_information_matrix(NULL))

	grad = p$finite_difference_md_gradient(X, b, 2L)
	expect_true(all(is.finite(grad)))
	expect_identical(names(grad), names(b))
	expect_true(is.finite(p$variance_from_gradient(grad, diag(3))))
	expect_true(is.na(p$variance_from_gradient(c(NA, 1), diag(2))))
})

test_that("zero-one-inflated beta mean helpers implement normalized mixture means", {
	inf = InferencePropZeroOneInflatedBetaRegr$new(make_proportion_design_for_helpers())
	p = inf$.__enclos_env__$private
	X = cbind(1, c(0, 1), c(-1, 1))
	XZ = cbind(1, c(0, 1))
	b_beta = c(0, 1, 0)
	# zoib_softmax_probabilities() is a 3-way softmax over (p0, p1, p_mid)
	# with an implicit 0 logit for p_mid: all-zero b_zero/b_one gives eta0 =
	# eta1 = 0, i.e. p0 = p1 = p_mid = 1/3, NOT p0 = p1 = 0.5 with zero
	# interior mass. A large common intercept on both gates (slope still 0,
	# so it's constant across subjects/treatment) instead pushes p_mid to
	# ~exp(-30) =~ 9e-14 while keeping p0 = p1 =~ 0.5, which is what this
	# test actually wants to exercise.
	b_zero = c(30, 0)
	b_one = c(30, 0)
	observed = p$zoib_mean_from_coefs(b_beta, b_zero, b_one, X, XZ)
	# p0 = p1 =~ 0.5 leaves ~zero interior mass after normalization.
	expect_equal(observed, rep(0.5, 2), tolerance = 1e-10)

	md = p$zoib_marginal_mean_diff_from_coefs(b_beta, b_zero, b_one, X, XZ)
	expect_equal(md, 0, tolerance = 1e-10)
	theta = c(b_beta, log(5), b_zero, b_one)
	expect_equal(p$zoib_marginal_mean_diff_functional(theta, X, XZ, 3L, 2L), md)
})

test_that("zero-one-inflated beta marginal g-computation matches an independent reference-category softmax oracle", {
	inf = InferencePropZeroOneInflatedBetaRegr$new(make_proportion_design_for_helpers())
	p = inf$.__enclos_env__$private
	X = cbind(`(Intercept)` = 1, treatment = c(0, 1, 0, 1), x = c(-1.2, -0.3, 0.4, 1.1))
	XZ = cbind(`(Intercept)` = 1, treatment = c(0, 1, 0, 1), z = c(0.7, -0.5, 1.3, -1.1))
	b_beta = c(-0.35, 0.75, 0.28)
	b_zero = c(-0.65, 0.50, -0.45)
	b_one = c(-0.15, -0.70, 0.35)

	# Keep this algebra independent of the private helper: the beta component
	# has reference logit zero, so pi0/ pi1/ pi_mid are exp(eta0),
	# exp(eta1), 1 divided by their common denominator.
	manual_mean = function(X_mean, X_mix){
		eta0 = drop(X_mix %*% b_zero)
		eta1 = drop(X_mix %*% b_one)
		denom = 1 + exp(eta0) + exp(eta1)
		pi1 = exp(eta1) / denom
		pimid = 1 / denom
		pi1 + pimid * plogis(drop(X_mean %*% b_beta))
	}
	X1 = X0 = X
	XZ1 = XZ0 = XZ
	X1[, "treatment"] = 1
	X0[, "treatment"] = 0
	XZ1[, "treatment"] = 1
	XZ0[, "treatment"] = 0
	expected = mean(manual_mean(X1, XZ1) - manual_mean(X0, XZ0))
	got = p$zoib_marginal_mean_diff_from_coefs(b_beta, b_zero, b_one, X, XZ)
	expect_equal(got, expected, tolerance = 1e-12)

	# The prior independent-logit normalization has a materially different
	# estimand on this non-symmetric fixture.
	legacy_mean = function(X_mean, X_mix){
		p0 = plogis(drop(X_mix %*% b_zero))
		p1 = plogis(drop(X_mix %*% b_one))
		pi1 = p1 / (p0 + p1)
		pimid = 1 - pi1
		pi1 + pimid * plogis(drop(X_mean %*% b_beta))
	}
	legacy = mean(legacy_mean(X1, XZ1) - legacy_mean(X0, XZ0))
	expect_gt(abs(got - legacy), 1e-4)
})

test_that("assigned gcomp and KK combined classes expose intended family contracts", {
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferenceOrdinalGCompMeanDiff$public_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferencePropGCompMeanDiff$public_methods))
	expect_true("compute_rr_subsampling_two_sided_pval" %in% names(EDI:::InferenceIncidKKGCompAbstract$private_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferencePropKKGEE$public_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferenceOrdinalKKGEE$public_methods))
	expect_true("get_likelihood_test_spec" %in% names(InferencePropKKGLMM$private_methods))
	expect_true("compute_estimate_with_bootstrap_weights" %in% names(InferenceOrdinalKKGLMM$public_methods))
})
