library(testthat)
library(EDI)

# docs-claims audit:
#   docs-claims-d7661f482 InferenceIncidWald: likelihood_tier "none", no
#     likelihood-ratio or parametric-bootstrap methods exposed.
#   docs-claims-de62ec080 InferenceIncidModifiedPoisson: only Wald inference;
#     get_supported_testing_types() is "wald" and score / lik_ratio / gradient
#     are refused by set_testing_type().

wald_only_fixture <- function(n = 30L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	des
}

test_that("InferenceIncidWald: likelihood_tier is 'none', no LR / parametric-bootstrap methods, Wald only", {
	expect_identical(get_inference_class_metadata("InferenceIncidWald")$likelihood_tier, "none")
	inf <- InferenceIncidWald$new(wald_only_fixture(), verbose = FALSE)
	expect_false(inf$.__enclos_env__$private$supports_lik_ratio_param_bootstrap())
	expect_identical(inf$get_supported_testing_types(), "wald")
	expect_length(grep("lik_ratio|score|gradient", names(inf), value = TRUE), 0L)
})

test_that("InferenceIncidModifiedPoisson exposes Wald only: score, lik_ratio and gradient are refused", {
	inf <- InferenceIncidModifiedPoisson$new(wald_only_fixture(), verbose = FALSE)
	expect_identical(inf$get_supported_testing_types(), "wald")
	for (tt in c("score", "lik_ratio", "gradient")) {
		expect_error(inf$set_testing_type(tt), "does not support testing_type", info = tt)
	}
	expect_no_error(inf$set_testing_type("wald"))
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
})
