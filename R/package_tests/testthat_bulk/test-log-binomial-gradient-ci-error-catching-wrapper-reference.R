library(testthat)
library(EDI)

# InferenceIncidLogBinomial$compute_gradient_confidence_interval(): the exact same message-filtered error-catching
# wrapper shape already covered for this class's compute_score_confidence_interval() sibling
# (test-log-binomial-score-ci-and-binomial-identity-lik-ratio-ci-error-catching-wrapper-reference.R) -- only
# intercepts a bad 'names' attribute or a replacement-length-mismatch error from
# compute_gradient_confidence_interval_impl(), re-throwing anything else, and falls back the same way when the
# _impl call succeeds but returns a non-finite/too-short result. Had no test calling it at all.

fx <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.2 * w))
	InferenceIncidLogBinomial$new(des, verbose = FALSE)
}

test_that("a bad 'names' attribute error from _impl is caught and converted to a nonestimable all-NA CI", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_gradient_confidence_interval_impl", p)
	p$compute_gradient_confidence_interval_impl <- function(alpha) stop("bad 'names' attribute on replacement")
	ci <- inf$compute_gradient_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "gradient_confidence_interval_unavailable")
	expect_true(inf$is_nonestimable("se"))
})

test_that("a replacement-length-mismatch error from _impl is caught the same way", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_gradient_confidence_interval_impl", p)
	p$compute_gradient_confidence_interval_impl <- function(alpha) stop("replacement must be the same length as the vector")
	ci <- inf$compute_gradient_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "gradient_confidence_interval_unavailable")
})

test_that("an UNRELATED error from _impl propagates instead of being swallowed", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_gradient_confidence_interval_impl", p)
	p$compute_gradient_confidence_interval_impl <- function(alpha) stop("some unrelated failure")
	expect_error(inf$compute_gradient_confidence_interval(0.05), "some unrelated failure")
})

test_that("a non-error but non-finite/too-short _impl result is also nonestimable (the second fallback)", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_gradient_confidence_interval_impl", p)
	p$compute_gradient_confidence_interval_impl <- function(alpha) c(NA_real_, NA_real_)
	ci <- inf$compute_gradient_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "gradient_confidence_interval_unavailable")

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	unlockBinding("compute_gradient_confidence_interval_impl", p2)
	p2$compute_gradient_confidence_interval_impl <- function(alpha) 0.5              # length 1: too short
	ci2 <- inf2$compute_gradient_confidence_interval(0.05)
	expect_true(all(is.na(ci2)))
	expect_identical(inf2$get_nonestimable_reason(), "gradient_confidence_interval_unavailable")
})

test_that("the ordinary successful path is unaffected", {
	inf <- fx()
	ci <- inf$compute_gradient_confidence_interval(0.05)
	expect_true(all(is.finite(ci)))
	expect_false(inf$is_nonestimable("any"))
})
