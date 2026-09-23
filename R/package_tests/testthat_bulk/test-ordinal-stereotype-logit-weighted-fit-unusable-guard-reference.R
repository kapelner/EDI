library(testthat)
library(EDI)

# InferenceOrdinalStereotypeLogitRegr$compute_estimate_with_bootstrap_weights()
# (inference_ordinal_stereotype_logit.R) caches "stereotype_logit_weighted_fit_unusable" when
# weighted_ordinal_bootstrap_surrogate_fit() returns NULL (or its estimate fails the
# stereotype_treatment_estimate_is_usable() check). This had no test reference anywhere. The public
# method runs isolated (the isolation-wrapper mechanism documented in inference_all_abstract.R and
# already used by several of this session's other weighted-refit reference tests), so
# private$weighted_refit_impl() is called directly, and the surrogate fitter is mocked to always
# return NULL (local_mocked_bindings(..., .package = "EDI")) -- the same techniques already used
# elsewhere in this suite for analogous unreachable-in-practice failure paths.

test_that("weighted refit caches 'stereotype_logit_weighted_fit_unusable' when the surrogate fit fails", {
	set.seed(1); n <- 30L
	des <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	local_mocked_bindings(weighted_ordinal_bootstrap_surrogate_fit = function(...) NULL, .package = "EDI")

	res <- p$weighted_refit_impl(rep(1, n))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "stereotype_logit_weighted_fit_unusable")
	expect_true(is.na(p$cached_values$df))
})
