library(testthat)
library(EDI)

# v1.0.6-TODO-176: InferenceSurvivalDepCensTransformRegr's Bayesian bootstrap replaced each weighted draw with a
# weighted Cox fit, whose treatment coefficient is a log hazard ratio under independent censoring, while the class
# estimates a log time ratio under dependent censoring. The joint likelihood takes no observation weights, so the
# Bayesian-bootstrap methods are now unsupported like the class's jackknife and randomization methods: each warns
# (`edi_unsupported_procedure`), returns NA, records the reason, and leaves the point estimate and the nonestimable
# flag alone.

unsup <- function(expr) { val <- NULL; expect_warning(val <- expr, class = "edi_unsupported_procedure"); val }
unsup_reason <- function(inf) inf$.__enclos_env__$private$cached_values$unsupported_procedure_reason
reason <- "dep_cens_transform_bayesian_bootstrap_not_supported"

fx <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

test_that("compute_bayesian_bootstrap_two_sided_pval returns NA and records the reason", {
	inf <- fx()
	est <- inf$compute_estimate()
	expect_true(is.na(unsup(inf$compute_bayesian_bootstrap_two_sided_pval(B = 11, show_progress = FALSE))))
	expect_false(inf$is_nonestimable("any"))
	expect_identical(unsup_reason(inf), reason)
	expect_identical(inf$compute_estimate(), est)
})

test_that("compute_bayesian_bootstrap_confidence_interval returns an all-NA named CI", {
	inf <- fx(seed = 3L)
	ci <- unsup(inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.1, B = 11, show_progress = FALSE))
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_false(inf$is_nonestimable("any"))
	expect_identical(unsup_reason(inf), reason)
})

test_that("compute_estimate_with_bootstrap_weights returns NA even for non-constant weights and keeps the estimate", {
	inf <- fx(seed = 4L)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
	set.seed(1L)
	# the weighted hook restores the object's cached state afterwards, so only the warning carries the reason
	w <- NULL
	val <- withCallingHandlers(inf$compute_estimate_with_bootstrap_weights(rexp(60)),
		edi_unsupported_procedure = function(cnd) { w <<- cnd; invokeRestart("muffleWarning") })
	expect_true(is.na(val))
	expect_identical(w$reason, reason)
	expect_identical(inf$compute_estimate(), est)
})
