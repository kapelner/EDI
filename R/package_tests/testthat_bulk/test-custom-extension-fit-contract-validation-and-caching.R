library(testthat)
library(EDI)

# inference_custom_extensions.R's InferenceCustomAsymp/Rand/Boot compute_estimate()
# methods validate the fit()-supplied result list and cache it. Existing coverage
# (test-custom-extension-contract.R) only ever exercises the well-formed happy
# path; the validation errors, nonestimable_reason propagation, the se<=0
# nonestimable branch, and InferenceCustomAsymp's private run_custom_fit()
# caching short-circuit (skip re-fitting once beta_hat_T/s_beta_hat_T are
# already populated) have zero test references anywhere -- confirmed via
# repo-wide grep for the exact error strings and reason codes.

make_custom_asymp_fixture = function(fit_fn) {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceCustomAsymp = getFromNamespace("InferenceCustomAsymp", "EDI")
	ext_env$fit_fn = fit_fn
	evalq({
		Cls = R6Class("Cls", inherit = InferenceCustomAsymp, lock_objects = FALSE,
			public = list(fit = function(estimate_only = FALSE) fit_fn(estimate_only)))
	}, envir = ext_env)

	des = DesignFixedBernoulli$new(n = 20, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
	des$add_all_subject_responses(c(1:10, 12:21))
	ext_env$Cls$new(des, verbose = FALSE)
}

test_that("compute_estimate() errors when fit() returns something other than a list", {
	inf = make_custom_asymp_fixture(function(estimate_only) 5)
	expect_error(inf$compute_estimate(), "must return a named list")
})

test_that("compute_estimate() errors when fit()'s list is missing a scalar 'estimate'", {
	inf_missing = make_custom_asymp_fixture(function(estimate_only) list(se = 1))
	expect_error(inf_missing$compute_estimate(), "must include numeric scalar 'estimate'")

	inf_vector = make_custom_asymp_fixture(function(estimate_only) list(estimate = c(1, 2)))
	expect_error(inf_vector$compute_estimate(), "must include numeric scalar 'estimate'")
})

test_that("a non-finite estimate is recorded nonestimable with the default reason when none supplied", {
	inf = make_custom_asymp_fixture(function(estimate_only) list(estimate = NA_real_))
	expect_true(is.na(suppressWarnings(inf$compute_estimate())))
	expect_true(inf$is_nonestimable())
	expect_equal(inf$get_nonestimable_reason(), "custom_estimate_unavailable")
})

test_that("a non-finite estimate propagates a caller-supplied nonestimable_reason instead of the default", {
	inf = make_custom_asymp_fixture(function(estimate_only) {
		list(estimate = NaN, nonestimable_reason = "my_custom_reason")
	})
	suppressWarnings(inf$compute_estimate())
	expect_true(inf$is_nonestimable())
	expect_equal(inf$get_nonestimable_reason(), "my_custom_reason")
})

test_that("a finite estimate with a non-finite or non-positive se is recorded se-nonestimable, not estimate-nonestimable", {
	inf_na_se = make_custom_asymp_fixture(function(estimate_only) {
		list(estimate = 3, se = NA_real_, df = 5)
	})
	# compute_estimate()'s default estimate_only=FALSE already runs the full
	# fit internally (run_custom_fit(estimate_only=FALSE)), so the se-nonestimable
	# state is set on this very first call, not deferred to a later CI call.
	expect_equal(inf_na_se$compute_estimate(), 3)
	expect_true(inf_na_se$is_nonestimable())
	expect_equal(inf_na_se$get_nonestimable_reason(), "custom_standard_error_unavailable")

	inf_zero_se = make_custom_asymp_fixture(function(estimate_only) {
		list(estimate = 3, se = 0, df = 5)
	})
	suppressWarnings(inf_zero_se$compute_asymp_confidence_interval())
	expect_true(inf_zero_se$is_nonestimable())
	expect_equal(inf_zero_se$get_nonestimable_reason(), "custom_standard_error_unavailable")
})

test_that("run_custom_fit()'s caching short-circuit skips re-invoking fit() once cached", {
	call_count = 0
	inf = make_custom_asymp_fixture(function(estimate_only) {
		call_count <<- call_count + 1
		list(estimate = 7, se = 1, df = 10)
	})

	# estimate_only=TRUE path caches beta_hat_T and should not refit on a second
	# estimate_only=TRUE call.
	expect_equal(inf$compute_estimate(estimate_only = TRUE), 7)
	expect_equal(call_count, 1L)
	expect_equal(inf$compute_estimate(estimate_only = TRUE), 7)
	expect_equal(call_count, 1L)

	# The first full (estimate_only=FALSE) fit is a genuinely new call since
	# s_beta_hat_T was never populated by the estimate_only path.
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_equal(call_count, 2L)
	# Once s_beta_hat_T is cached, a further full-fit-requiring call is also
	# short-circuited.
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_equal(call_count, 2L)
})
