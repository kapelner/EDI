library(testthat)
library(EDI)

# inference_proportion_beta.R's marginal_mean_diff estimand path
# (compute_marginal_estimand_estimate/beta_regr_marginal_functional/
# marginal_estimand_delta_se, wired via generate_mod()'s mean-submodel-only
# vcov) was previously exercised only for its public get/set_estimand
# contract (test-proportion-count-family-contracts.R) -- never for the
# actual point estimate, delta-method SE, CI, or p-value it computes.

make_beta_marginal_design = function(n = 40L, seed = 42L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "proportion", seed = seed)
	x1 = rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	mu = plogis(-0.3 + 0.8 * w + 0.4 * x1)
	y = rbeta(n, mu * 12, (1 - mu) * 12)
	y = pmin(pmax(y, 1e-6), 1 - 1e-6)
	des$add_all_subject_responses(y)
	list(des = des, w = w, x1 = x1, y = y)
}

betareg_marginal_delta_reference = function(y, w, x1) {
	fit = betareg::betareg(y ~ w + x1, data = data.frame(y = y, w = w, x1 = x1), link = "logit")
	b = coef(fit)[c("(Intercept)", "w", "x1")]
	V = vcov(fit, phi = FALSE)[c("(Intercept)", "w", "x1"), c("(Intercept)", "w", "x1")]
	X = cbind(1, w, x1)
	functional = function(beta) {
		X1 = X; X1[, 2] = 1
		X0 = X; X0[, 2] = 0
		mean(plogis(X1 %*% beta)) - mean(plogis(X0 %*% beta))
	}
	h = 1e-6
	grad = vapply(seq_along(b), function(j) {
		bp = b; bp[j] = bp[j] + h
		bm = b; bm[j] = bm[j] - h
		(functional(bp) - functional(bm)) / (2 * h)
	}, numeric(1))
	list(point = functional(b), se = sqrt(as.numeric(t(grad) %*% V %*% grad)))
}

test_that("marginal_mean_diff point estimate and delta-method SE match an independent betareg reference", {
	skip_if_not_installed("betareg")
	f = make_beta_marginal_design()
	ref = betareg_marginal_delta_reference(f$y, f$w, f$x1)

	inf = InferencePropBetaRegr$new(f$des)
	inf$set_estimand("marginal_mean_diff")
	pt = inf$compute_estimate()
	se = inf$.__enclos_env__$private$cached_values$s_beta_hat_T

	expect_equal(pt, ref$point, tolerance = 1e-3)
	expect_equal(se, ref$se, tolerance = 5e-3)
	expect_true(is.infinite(inf$.__enclos_env__$private$cached_values$df))

	# CI/p-value dispatch resolves to the direct z-based Wald path (finite SE
	# short-circuits the testing_type switch in both methods) and agrees with
	# a hand-rolled z formula using the package's own point estimate/SE.
	alpha = 0.05
	z = qnorm(1 - alpha / 2)
	expected_ci = pt + c(-1, 1) * z * se
	expect_equal(unname(inf$compute_asymp_confidence_interval(alpha)), expected_ci, tolerance = 1e-8)
	expected_pval = 2 * pnorm(-abs(pt / se))
	expect_equal(unname(inf$compute_asymp_two_sided_pval(0)), expected_pval, tolerance = 1e-8)

	# The fit is a pure post-fit transform: switching back to "conditional"
	# reuses the same cached_mod object (no refit) and recovers the ordinary
	# conditional log-odds-ratio coefficient exactly.
	mod_ref = inf$.__enclos_env__$private$cached_mod
	inf$set_estimand("conditional")
	expect_identical(inf$.__enclos_env__$private$cached_mod, mod_ref)
	expect_equal(inf$compute_estimate(), as.numeric(mod_ref$b[2L]))
})

test_that("marginal_mean_diff degenerates to a documented nonestimable reason under a singular fit", {
	des = DesignFixedBernoulli$new(n = 6L, response_type = "proportion", seed = 7L)
	des$add_all_subjects_to_experiment(data.frame(x1 = rep(0, 6L)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rep(0.5, 6L))

	inf = InferencePropBetaRegr$new(des)
	inf$set_estimand("marginal_mean_diff")
	pt = inf$compute_estimate()

	expect_true(is.finite(pt))
	expect_equal(inf$get_nonestimable_reason(), "beta_regr_marginal_vcov_unavailable")
	expect_true(is.na(inf$.__enclos_env__$private$cached_values$s_beta_hat_T))
	expect_true(all(is.na(inf$compute_asymp_confidence_interval())))
	expect_true(is.na(inf$compute_asymp_two_sided_pval(0)))
})

test_that("set_estimand()/set_testing_type() enforce the documented wald-only restriction symmetrically", {
	f = make_beta_marginal_design(seed = 43L)

	# Switching to marginal_mean_diff first, then attempting a non-wald
	# testing_type, is rejected by the base (conditional-only) testing-type
	# validator.
	inf1 = InferencePropBetaRegr$new(f$des)
	expect_setequal(inf1$get_supported_testing_types(), c("wald", "score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx"))
	inf1$set_estimand("marginal_mean_diff")
	expect_identical(inf1$get_supported_testing_types(), "wald")
	expect_error(inf1$set_testing_type("score"), "does not support testing_type")

	# The reverse order: a non-wald testing_type already configured under
	# "conditional" blocks the switch to marginal_mean_diff, erroring loudly
	# and leaving the estimand unchanged rather than silently desyncing state.
	inf2 = InferencePropBetaRegr$new(f$des)
	inf2$set_testing_type("score")
	expect_error(
		inf2$set_estimand("marginal_mean_diff"),
		"cannot set estimand.*testing_type = \"score\""
	)
	expect_identical(inf2$get_estimand(), "conditional")
})
