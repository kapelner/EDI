library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr's compute_rand_two_sided_pval()/compute_rand_confidence_interval()
# (inference_survival_dep_cens_transform.R) are documented as always unavailable for this model --
# each randomization draw would require a full dependent-censoring likelihood refit and isn't
# stable enough for the comprehensive suite -- so both unconditionally short-circuit to NA (or an
# all-NA CI) and flag "dep_cens_transform_randomization_not_supported". Like the analogous jackknife
# cluster on the same class (already covered), each first calls
# self$compute_estimate(estimate_only = TRUE) as a side effect (wrapped in its own tryCatch), so the
# ordinary point estimate ends up cached even though the randomization call itself still reports
# non-estimable. No test anywhere called either method.

fx <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

test_that("compute_rand_two_sided_pval always returns NA and flags 'dep_cens_transform_randomization_not_supported'", {
	inf <- fx()
	expect_true(is.na(inf$compute_rand_two_sided_pval()))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_randomization_not_supported")
	# the point estimate is still cached as a documented side effect
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$beta_hat_T))
})

test_that("compute_rand_confidence_interval always returns an all-NA CI and flags the same reason", {
	inf <- fx(seed = 3L)
	ci <- inf$compute_rand_confidence_interval(alpha = 0.1)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_randomization_not_supported")
})
