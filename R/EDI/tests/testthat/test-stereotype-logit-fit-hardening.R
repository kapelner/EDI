test_that("stereotype-logit class-local hardening rejects unstable fits", {
	private_methods = EDI:::OrdinalStereotypeLikelihoodSource$private
	estimate_is_usable = private_methods$stereotype_treatment_estimate_is_usable
	fit_is_usable = private_methods$stereotype_fit_is_usable

	good_fit = list(
		b = 0.5,
		converged = TRUE,
		fisher_information = diag(2L),
		ssq_b_j = 0.25
	)
	expect_true(estimate_is_usable(10))
	expect_false(estimate_is_usable(10 + .Machine$double.eps^0.25))
	expect_false(estimate_is_usable(NA_real_))
	expect_true(fit_is_usable(good_fit, require_standard_error = TRUE))

	nonconverged_fit = good_fit
	nonconverged_fit$converged = FALSE
	expect_false(fit_is_usable(nonconverged_fit))

	extreme_fit = good_fit
	extreme_fit$b = 10.01
	expect_false(fit_is_usable(extreme_fit))

	ill_conditioned_fit = good_fit
	ill_conditioned_fit$fisher_information = diag(c(1, .Machine$double.eps))
	expect_false(fit_is_usable(ill_conditioned_fit))

	missing_variance_fit = good_fit
	missing_variance_fit$ssq_b_j = NA_real_
	expect_false(fit_is_usable(missing_variance_fit, require_standard_error = TRUE))
})
