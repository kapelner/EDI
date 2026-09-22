library(testthat)
library(EDI)

# InferenceNonParamBootstrap's compute_bootstrap_two_sided_pval()/compute_bootstrap_confidence_interval(): the
# very first guard in each, before any resampling happens, is "the ORIGINAL (non-bootstrap) point estimate
# itself must be finite" -- if self$compute_estimate() comes back non-finite, both methods short-circuit
# immediately. Under harden = TRUE (the default for essentially every concrete class) this caches
# "bootstrap_original_estimate_unavailable" and returns NA (pval) / an all-NA CI; under harden = FALSE the
# p-value path still returns NA silently but the CI path instead STOPS with an explicit error. This shared
# base-class guard, reached from every nonparametric-bootstrap-capable class, had zero test coverage anywhere
# in the suite despite the class composing into virtually every inference class.

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

test_that("under harden = TRUE (the default), an unusable original estimate makes the p-value NA with the shared reason, without ever resampling", {
	inf <- fx(); expect_true(inf$.__enclos_env__$private$harden)
	stub_na_estimate(inf)
	pv <- inf$compute_bootstrap_two_sided_pval(delta = 0, B = 20, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "bootstrap_original_estimate_unavailable")
	expect_true(inf$is_nonestimable("estimate"))
})

test_that("under harden = TRUE, an unusable original estimate makes the CI all-NA with the same reason, correctly-labelled alpha percentages", {
	inf <- fx()
	stub_na_estimate(inf)
	ci <- inf$compute_bootstrap_confidence_interval(alpha = 0.1, B = 20, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf$get_nonestimable_reason(), "bootstrap_original_estimate_unavailable")
	expect_true(inf$is_nonestimable("estimate"))
})

test_that("under harden = FALSE, the p-value guard is unaffected (still NA silently) but the CI guard escalates to an explicit error", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("harden", p); p$harden <- FALSE
	stub_na_estimate(inf)
	pv <- inf$compute_bootstrap_two_sided_pval(delta = 0, B = 20, show_progress = FALSE)
	expect_true(is.na(pv))

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	unlockBinding("harden", p2); p2$harden <- FALSE
	stub_na_estimate(inf2)
	expect_error(inf2$compute_bootstrap_confidence_interval(alpha = 0.05, B = 20, show_progress = FALSE), "Bootstrap confidence interval returned NA bounds")
})

test_that("a usable original estimate does not trip either guard", {
	inf <- fx()
	pv <- inf$compute_bootstrap_two_sided_pval(delta = 0, B = 200, type = "percentile", show_progress = FALSE)
	expect_true(is.finite(pv))
	expect_false(inf$is_nonestimable("any"))
})
