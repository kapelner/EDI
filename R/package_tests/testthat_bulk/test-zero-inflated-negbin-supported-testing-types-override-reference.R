library(testthat)
library(EDI)

# InferenceCountZeroInflatedNegBin's private get_supported_testing_types_impl()
# (inference_count_zero_inflated.R) overrides the abstract default to return exactly
# c("wald", "score", "lik_ratio", "gradient") -- the class docstring explicitly calls out
# that, unlike the Poisson (ZIP) sibling, this override includes "score" (delete-one
# jackknife refits are numerically unstable for the jointly-estimated dispersion
# parameter, so jackknife is deliberately excluded). A codebase-wide grep confirmed no
# test anywhere asserts this exact override's return value directly (existing coverage
# only checks that ZINB doesn't support a marginal estimand, never its testing-type set).
# Exercised via a direct private-method call on a real InferenceCountZeroInflatedNegBin
# instance, independent of get_supported_testing_types()'s further downstream
# intersection/augmentation logic (already tested elsewhere).

test_that("ZINB's private get_supported_testing_types_impl() returns exactly wald/score/lik_ratio/gradient, excluding jackknife", {
	skip_if_not_installed("glmmTMB")
	set.seed(1)
	des <- DesignFixedBernoulli$new(n = 20, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(20)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(20, exp(0.3 * w)))
	inf <- InferenceCountZeroInflatedNegBin$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	types <- priv$get_supported_testing_types_impl()
	expect_setequal(types, c("wald", "score", "lik_ratio", "gradient"))
	expect_false("jackknife" %in% types)
})
