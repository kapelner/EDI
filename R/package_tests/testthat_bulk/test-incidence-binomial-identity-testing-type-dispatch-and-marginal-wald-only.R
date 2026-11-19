library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dfdd8a4b7 (InferenceIncidBinomialIdentityRiskDiff):
#   - compute_asymp_confidence_interval() / compute_asymp_two_sided_pval() are
#     dispatched by testing_type for the conditional estimand;
#   - under a marginal estimand testing_type is always "wald" (the only value
#     set_estimand() permits there).

identity_fixture <- function() {
	set.seed(11); n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.2 * w))
	des
}

test_that("binomial identity: asymp p-value and CI follow testing_type (score, gradient, lik_ratio)", {
	des <- identity_fixture()
	wald <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	p_wald <- wald$compute_asymp_two_sided_pval()
	for (tt in c("score", "gradient", "lik_ratio")) {
		inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
		inf$set_testing_type(tt)
		p <- inf$compute_asymp_two_sided_pval()
		ci <- inf$compute_asymp_confidence_interval()
		expect_true(is.finite(p), info = tt)
		expect_identical(p, inf[[paste0("compute_", tt, "_two_sided_pval")]](), info = tt)
		expect_identical(ci, inf[[paste0("compute_", tt, "_confidence_interval")]](), info = tt)
		expect_false(isTRUE(all.equal(p, p_wald)), info = tt)
	}
})

test_that("binomial identity: a marginal estimand allows only 'wald'", {
	des <- identity_fixture()
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	inf$set_testing_type("score")
	expect_error(inf$set_estimand("marginal_mean_diff"), "not supported under this estimand")

	fresh <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	expect_true(length(fresh$get_supported_testing_types()) > 1L)
	fresh$set_estimand("marginal_mean_diff")
	expect_identical(fresh$get_supported_testing_types(), "wald")
	expect_identical(fresh$get_testing_type(), "wald")
	expect_error(fresh$set_testing_type("lik_ratio"), "does not support testing_type")
	expect_true(is.finite(fresh$compute_asymp_two_sided_pval()))
})
