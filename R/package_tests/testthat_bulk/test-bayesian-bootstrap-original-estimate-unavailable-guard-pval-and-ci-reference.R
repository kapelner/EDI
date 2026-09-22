library(testthat)
library(EDI)

# InferenceBayesianBootstrap's compute_bayesian_bootstrap_two_sided_pval()/compute_bayesian_bootstrap_confidence_interval():
# the very first guard in each, before any resampling happens, is "the ORIGINAL (non-bootstrap) point estimate itself
# must be finite" -- if self$compute_estimate() comes back non-finite, both methods short-circuit immediately. The
# p-value method gates the "bayesian_bootstrap_original_estimate_unavailable" cache behind harden (silent NA either
# way, but the reason is only recorded under harden = TRUE) -- mirroring the analogous nonparametric-bootstrap guard
# (test-nonparam-bootstrap-original-estimate-unavailable-guard-pval-and-ci-reference.R). The CONFIDENCE INTERVAL
# method here is genuinely DIFFERENT from its nonparametric-bootstrap sibling: it calls private$missing_bootstrap_ci()
# UNCONDITIONALLY, with no harden check at all, so the reason is always recorded and no error is ever thrown (contrast
# the nonparametric-bootstrap CI method, which stops with an explicit error when harden = FALSE). This shared base-
# class guard had zero test coverage anywhere in the suite despite the class composing into most inference classes.

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
}

stub_na_estimate <- function(inf) {
	unlockBinding("compute_estimate", inf)
	inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	invisible(inf)
}

test_that("under harden = TRUE (the default), an unusable original estimate makes the p-value NA with the shared reason", {
	inf <- fx(); expect_true(inf$.__enclos_env__$private$harden)
	expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap())
	stub_na_estimate(inf)
	pv <- inf$compute_bayesian_bootstrap_two_sided_pval(delta = 0, B = 20, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "bayesian_bootstrap_original_estimate_unavailable")
	expect_true(inf$is_nonestimable("estimate"))
})

test_that("under harden = TRUE, an unusable original estimate makes the CI all-NA with the same reason, correctly-labelled alpha percentages", {
	inf <- fx()
	stub_na_estimate(inf)
	ci <- inf$compute_bayesian_bootstrap_confidence_interval(alpha = 0.1, B = 20, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf$get_nonestimable_reason(), "bayesian_bootstrap_original_estimate_unavailable")
})

test_that("under harden = FALSE, the p-value guard silently returns NA without recording a reason, but the CI guard still records the reason (no error, unlike nonparametric bootstrap)", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("harden", p); p$harden <- FALSE
	stub_na_estimate(inf)
	pv <- inf$compute_bayesian_bootstrap_two_sided_pval(delta = 0, B = 20, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_null(inf$get_nonestimable_reason())                        # not recorded when harden = FALSE

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	unlockBinding("harden", p2); p2$harden <- FALSE
	stub_na_estimate(inf2)
	ci <- inf2$compute_bayesian_bootstrap_confidence_interval(alpha = 0.1, B = 20, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(inf2$get_nonestimable_reason(), "bayesian_bootstrap_original_estimate_unavailable")   # unconditional, no error
})

test_that("a usable original estimate does not trip either guard", {
	inf <- fx()
	pv <- inf$compute_bayesian_bootstrap_two_sided_pval(delta = 0, B = 200, type = "percentile", show_progress = FALSE)
	expect_true(is.finite(pv))
	expect_false(inf$is_nonestimable("any"))
})
