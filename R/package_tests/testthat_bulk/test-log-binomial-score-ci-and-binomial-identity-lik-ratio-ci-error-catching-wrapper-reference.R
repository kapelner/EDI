library(testthat)
library(EDI)

# InferenceIncidLogBinomial$compute_score_confidence_interval() and
# InferenceIncidBinomialIdentityRiskDiff$compute_lik_ratio_confidence_interval(): both are thin wrappers around
# their own "_impl" method (InferenceAsympLik's private CI-inversion machinery), added when composed classes lost
# their super$ chain to that base class (fix_inference_hierarchy.md "Base Deletion"). Each wrapper catches an error
# from the _impl call and converts it into a nonestimable all-NA CI -- but the two catch different things:
# LogBinomial's score-CI wrapper only intercepts two SPECIFIC known-message error classes (a bad `'names'` attribute,
# or a replacement-length mismatch) and re-throws anything else, while BinomialIdentityRiskDiff's lik-ratio-CI wrapper
# catches ANY error unconditionally. Neither wrapper -- nor the non-error "the _impl result itself came back
# non-finite/too-short" fallback both also have -- had a test calling them; existing coverage only exercises the
# ordinary (successful) CI computation path.

fx <- function(seed = 1L, n = 80L, class = InferenceIncidLogBinomial) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.2 * w))
	class$new(des, verbose = FALSE)
}

test_that("LogBinomial score CI: a bad 'names' attribute error from _impl is caught and converted to a nonestimable all-NA CI", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_confidence_interval_impl", p)
	p$compute_score_confidence_interval_impl <- function(alpha) stop("bad 'names' attribute on replacement")
	ci <- inf$compute_score_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "score_confidence_interval_unavailable")
	expect_true(inf$is_nonestimable("se"))
})

test_that("LogBinomial score CI: a replacement-length-mismatch error from _impl is caught the same way", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_confidence_interval_impl", p)
	p$compute_score_confidence_interval_impl <- function(alpha) stop("replacement must be the same length as the vector")
	ci <- inf$compute_score_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "score_confidence_interval_unavailable")
})

test_that("LogBinomial score CI: an UNRELATED error from _impl propagates instead of being swallowed", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_confidence_interval_impl", p)
	p$compute_score_confidence_interval_impl <- function(alpha) stop("some unrelated failure")
	expect_error(inf$compute_score_confidence_interval(0.05), "some unrelated failure")
})

test_that("LogBinomial score CI: a non-error but non-finite/too-short _impl result is also nonestimable (the second fallback)", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_confidence_interval_impl", p)
	p$compute_score_confidence_interval_impl <- function(alpha) c(NA_real_, NA_real_)
	ci <- inf$compute_score_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "score_confidence_interval_unavailable")

	inf2 <- fx()
	p2 <- inf2$.__enclos_env__$private
	unlockBinding("compute_score_confidence_interval_impl", p2)
	p2$compute_score_confidence_interval_impl <- function(alpha) 0.5                    # length 1: too short
	ci2 <- inf2$compute_score_confidence_interval(0.05)
	expect_true(all(is.na(ci2)))
	expect_identical(inf2$get_nonestimable_reason(), "score_confidence_interval_unavailable")
})

test_that("LogBinomial score CI: the ordinary successful path is unaffected", {
	inf <- fx()
	ci <- inf$compute_score_confidence_interval(0.05)
	expect_true(all(is.finite(ci)))
	expect_false(inf$is_nonestimable("any"))
})

test_that("BinomialIdentityRiskDiff lik-ratio CI: ANY error from _impl is caught (unconditional, unlike LogBinomial's message-filtered catch)", {
	inf <- fx(class = InferenceIncidBinomialIdentityRiskDiff)
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_lik_ratio_confidence_interval_impl", p)
	p$compute_lik_ratio_confidence_interval_impl <- function(alpha) stop("literally anything")
	ci <- inf$compute_lik_ratio_confidence_interval(0.1)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_confidence_interval_unavailable")
})

test_that("BinomialIdentityRiskDiff lik-ratio CI: the ordinary successful path is unaffected", {
	inf <- fx(class = InferenceIncidBinomialIdentityRiskDiff)
	ci <- inf$compute_lik_ratio_confidence_interval(0.05)
	expect_true(all(is.finite(ci)))
	expect_false(inf$is_nonestimable("any"))
})
