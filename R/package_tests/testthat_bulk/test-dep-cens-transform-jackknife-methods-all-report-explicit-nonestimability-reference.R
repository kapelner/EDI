library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr's five compute_jackknife_*() overrides (estimate, bias_estimate,
# std_error, wald_two_sided_pval, wald_confidence_interval): leave-one-out bias correction is documented as
# unstable for this model's likelihood, so every one of these always short-circuits to NA and flags
# "dep_cens_transform_jackknife_not_supported" -- but unlike the analogous always-refuse jackknife clusters
# on InferenceCountNegBin/InferenceCountHurdleNegBin (covered elsewhere), each of THESE five first calls
# self$compute_estimate(estimate_only = TRUE) as a side effect (wrapped in its own tryCatch), so the ordinary
# point estimate ends up cached even though the jackknife call itself still reports non-estimable and
# returns NA. No test anywhere called any of these five methods.

fx <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

# TODO-116: unsupported-procedure stubs signal a classed `edi_unsupported_procedure` warning, return NA, record
# cached_values$unsupported_procedure_reason, and leave is_nonestimable() and the Wald caches untouched.
unsup <- function(expr) { val <- NULL; expect_warning(val <- expr, class = "edi_unsupported_procedure"); val }
unsup_reason <- function(inf) inf$.__enclos_env__$private$cached_values$unsupported_procedure_reason

test_that("every jackknife method returns NA (or an all-NA CI) and records the same unsupported-procedure reason", {
	inf <- fx()
	expect_true(is.na(unsup(inf$compute_jackknife_estimate())))
	expect_identical(unsup_reason(inf), "dep_cens_transform_jackknife_not_supported")
	expect_false(inf$is_nonestimable("se"))

	inf2 <- fx()
	expect_true(is.na(unsup(inf2$compute_jackknife_bias_estimate())))
	expect_identical(unsup_reason(inf2), "dep_cens_transform_jackknife_not_supported")

	inf3 <- fx()
	expect_true(is.na(unsup(inf3$compute_jackknife_std_error())))
	expect_identical(unsup_reason(inf3), "dep_cens_transform_jackknife_not_supported")

	inf4 <- fx()
	expect_true(is.na(unsup(inf4$compute_jackknife_wald_two_sided_pval(delta = 0.3))))
	expect_identical(unsup_reason(inf4), "dep_cens_transform_jackknife_not_supported")

	inf5 <- fx()
	ci <- unsup(inf5$compute_jackknife_wald_confidence_interval(alpha = 0.1))
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(unsup_reason(inf5), "dep_cens_transform_jackknife_not_supported")
})

test_that("the alpha argument controls the returned CI's percentage labels even though the bounds are always NA", {
	inf <- fx()
	ci <- unsup(inf$compute_jackknife_wald_confidence_interval(alpha = 0.2))
	expect_identical(names(ci), c("10%", "90%"))
	expect_true(all(is.na(ci)))
})

test_that("unlike the trivial-refusal jackknife pattern elsewhere, each call has the side effect of computing and caching the ordinary point estimate, even though the jackknife result itself is NA/non-estimable", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_values$beta_hat_T)                            # nothing cached yet
	out <- unsup(inf$compute_jackknife_estimate())
	expect_true(is.na(out))
	expect_true(is.finite(p$cached_values$beta_hat_T))                 # but the estimate_only fit ran and cached beta_hat_T
	expect_equal(p$cached_values$beta_hat_T, inf$compute_estimate(estimate_only = TRUE))
})
