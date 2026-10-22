library(testthat)

# TODO-116 (likelihood-test stage, 2026-10-22): a failed score / gradient / LR / Bartlett test or
# test-inversion CI is a failure of THAT test, not of the primary fit. It used to call
# cache_nonestimable_se()/cache_nonestimable_estimate(), wiping a valid Wald SE (or estimate) and
# flipping is_nonestimable(). It now goes through edi_record_procedure_failure(): the Wald
# estimate/SE/p-value/CI are untouched, is_nonestimable() stays FALSE and the reason lands in
# cached_values$procedure_failure_reason[[<testing_type>]]. A failure on an already-invalid primary
# fit, and a failed Wald test, keep the old nonestimable behaviour. When the Wald fallback
# (TODO-115/121, edi_lik_test_wald_fallback) happens is unchanged.

lik_wald_fixture <- function(seed = 2L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * x)))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

wald_snapshot <- function(inf) {
	list(
		est = inf$compute_estimate(),
		se = inf$.__enclos_env__$private$cached_values$s_beta_hat_T,
		p = inf$compute_wald_two_sided_pval(0),
		ci = inf$compute_wald_confidence_interval(alpha = 0.05)
	)
}

test_that("a failed likelihood-test p-value keeps the Wald state for every testing type", {
	for (tt in c("score", "gradient", "lik_ratio", "lik_ratio_bartlett_approx", "lik_ratio_bartlett_exact")) {
		f <- lik_wald_fixture()
		before <- wald_snapshot(f$inf)
		expect_true(all(is.finite(unlist(before))), info = tt)
		unlockBinding("get_memoized_likelihood_test_pval", f$priv)
		f$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_
		pv <- suppressWarnings(f$priv$compute_likelihood_test_two_sided_pval(0, tt))
		expect_true(is.na(pv), info = tt)
		expect_false(f$inf$is_nonestimable(), info = tt)
		expect_null(f$inf$get_nonestimable_reason(), info = tt)
		expect_identical(f$priv$cached_values$procedure_failure_reason[[tt]], paste0(tt, "_test_unavailable"), info = tt)
		expect_equal(wald_snapshot(f$inf), before, info = tt)
	}
})

test_that("a failed test-inversion CI (no usable Wald fallback) keeps the Wald state", {
	f <- lik_wald_fixture(seed = 3L)
	before <- wald_snapshot(f$inf)
	# finalize_inverted_ci() with an unusable inverted CI AND an unusable Wald fallback is the
	# "give up" branch; on a valid primary fit it is now a score procedure failure.
	ci <- f$priv$finalize_inverted_ci(numeric(0), 0.05, before$est, c(NA_real_, NA_real_),
		"test_inversion_confidence_interval_unavailable", testing_type = "score")
	expect_true(all(is.na(ci)))
	expect_false(f$inf$is_nonestimable())
	expect_identical(f$priv$cached_values$procedure_failure_reason$score, "test_inversion_confidence_interval_unavailable")
	expect_equal(wald_snapshot(f$inf), before)

	# p-value at the estimate unavailable during CI inversion
	g <- lik_wald_fixture(seed = 4L)
	before_g <- wald_snapshot(g$inf)
	unlockBinding("get_memoized_likelihood_test_pval", g$priv)
	g$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_
	ci_g <- suppressWarnings(g$priv$invert_test_pval_confidence_interval(0.05, "lik_ratio"))
	expect_true(all(is.na(ci_g)))
	expect_false(g$inf$is_nonestimable())
	expect_identical(g$priv$cached_values$procedure_failure_reason$lik_ratio, "lik_ratio_test_unavailable")
	expect_equal(wald_snapshot(g$inf), before_g)
})

test_that("a NULL likelihood spec on a valid Wald fit is a procedure failure, not a primary one", {
	f <- lik_wald_fixture(seed = 5L)
	before <- wald_snapshot(f$inf)
	unlockBinding("get_likelihood_test_spec", f$priv)
	f$priv$get_likelihood_test_spec <- function(...) NULL
	pv <- suppressWarnings(f$priv$compute_likelihood_test_two_sided_pval(0, "gradient"))
	expect_true(is.na(pv))
	expect_false(f$inf$is_nonestimable())
	expect_identical(f$priv$cached_values$procedure_failure_reason$gradient, "likelihood_test_spec_unavailable")
	expect_equal(wald_snapshot(f$inf), before)
})

test_that("the Wald fallback still happens exactly as before and records no procedure failure", {
	f <- lik_wald_fixture(seed = 6L)
	before <- wald_snapshot(f$inf)
	ci <- NULL
	expect_warning(
		ci <- f$priv$finalize_inverted_ci(numeric(0), 0.05, before$est, before$ci,
			"test_inversion_confidence_interval_unavailable", testing_type = "score"),
		class = "edi_lik_ci_wald_fallback"
	)
	expect_equal(as.numeric(ci), as.numeric(before$ci))
	expect_null(f$priv$cached_values$procedure_failure_reason$score)
	expect_false(f$inf$is_nonestimable())
})

test_that("primary-fit failures keep the old nonestimable behaviour", {
	# A failed Wald "inversion" is the primary fit failing: no procedure name, old path.
	f <- lik_wald_fixture(seed = 7L)
	est <- f$inf$compute_estimate()
	ci <- f$priv$finalize_inverted_ci(numeric(0), 0.05, est, c(NA_real_, NA_real_),
		"test_inversion_confidence_interval_unavailable", testing_type = "wald")
	expect_true(all(is.na(ci)))
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "test_inversion_confidence_interval_unavailable")

	# A lik-test failure on an already-nonestimable object does not mask the primary reason.
	g <- lik_wald_fixture(seed = 8L)
	g$priv$cache_nonestimable_estimate("some_primary_failure")
	unlockBinding("get_memoized_likelihood_test_pval", g$priv)
	g$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_
	expect_true(is.na(suppressWarnings(g$priv$compute_likelihood_test_two_sided_pval(0, "score"))))
	expect_true(g$inf$is_nonestimable())
	expect_identical(g$inf$get_nonestimable_reason(), "some_primary_failure")
	expect_null(g$priv$cached_values$procedure_failure_reason$score)
})
