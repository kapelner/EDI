library(testthat)
library(EDI)

# InferenceIncidProbitRegr's private is_probit_fit_reasonable(mod) coefficient-plausibility guard
# (NULL/short/non-finite/beyond max_abs_reasonable_coef -> FALSE) and its wiring into generate_mod():
# an unreasonable fit is cached as nonestimable with reason "probit_regression_extreme_coefficients"
# by generate_mod() itself, but that specific reason string is immediately overwritten by the shared()
# template method (inference_all_abstract_asymp_lik_std_mod_cache.R) with the generic
# "model_fit_unavailable" whenever generate_mod() returns NULL -- so the specific reason is only ever
# observable by calling generate_mod() directly, never via the public compute_estimate() API. Existing
# coverage of this class exercises only well-behaved fits against stats::glm(family = binomial("probit"));
# the coefficient-plausibility guard itself, and this reason-overwrite behavior, were untested.

fx <- function(seed = 7L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.5 * w)))
	inf <- InferenceIncidProbitRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, des = des)
}

test_that("is_probit_fit_reasonable: NULL, too-short, non-finite and beyond-bound coefficients are unreasonable; the bound is inclusive", {
	f <- fx()
	expect_equal(f$p$max_abs_reasonable_coef, 10)
	expect_false(f$p$is_probit_fit_reasonable(NULL))
	expect_false(f$p$is_probit_fit_reasonable(list(b = c(1))))                       # fewer than 2 coefficients
	expect_false(f$p$is_probit_fit_reasonable(list(b = c(1, NA_real_))))              # non-finite
	expect_false(f$p$is_probit_fit_reasonable(list(b = c(1, 11))))                    # beyond the bound
	expect_false(f$p$is_probit_fit_reasonable(list(b = c(1, -10.01))))                # beyond the bound, negative side
	expect_true(f$p$is_probit_fit_reasonable(list(b = c(1, 10))))                     # exactly at the bound: still reasonable
	expect_true(f$p$is_probit_fit_reasonable(list(b = c(1, -10))))                    # exactly at the bound, negative side
	expect_true(f$p$is_probit_fit_reasonable(list(b = c(1, 2))))                      # ordinary case
})

test_that("a caller-supplied max_abs_reasonable_coef changes the bound", {
	f <- fx()
	f$p$max_abs_reasonable_coef <- 1
	expect_false(f$p$is_probit_fit_reasonable(list(b = c(0.5, 1.01))))
	expect_true(f$p$is_probit_fit_reasonable(list(b = c(0.5, 1))))
})

test_that("generate_mod() itself records the specific 'probit_regression_extreme_coefficients' reason when the fit is unreasonable", {
	f <- fx()
	unlockBinding("is_probit_fit_reasonable", f$p)
	f$p$is_probit_fit_reasonable <- function(mod) FALSE                              # force every candidate fit to be rejected
	out <- f$p$generate_mod(estimate_only = FALSE)
	expect_null(out)
	expect_identical(f$p$cached_values$nonestimable_reason, "probit_regression_extreme_coefficients")
	expect_identical(f$p$cached_values$nonestimable_stage, "estimate")
	expect_true(f$p$cached_values$nonestimable)
})

test_that("compute_estimate() surfaces NA and is_nonestimable('estimate') for an unreasonable fit, but the public reason is the generic shared() label, not generate_mod()'s specific one", {
	f <- fx()
	unlockBinding("is_probit_fit_reasonable", f$p)
	f$p$is_probit_fit_reasonable <- function(mod) FALSE
	est <- f$inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "model_fit_unavailable")       # generate_mod()'s own reason is overwritten by shared()
})

test_that("an ordinary, well-behaved fit is unaffected: is_probit_fit_reasonable(attempt$fit) is TRUE and matches stats::glm's coefficients", {
	f <- fx()
	est <- f$inf$compute_estimate()
	expect_true(is.finite(est))
	expect_false(f$inf$is_nonestimable("any"))
	ref <- stats::glm(y ~ w + x1, family = binomial("probit"), data = data.frame(y = f$des$get_y(), w = f$des$get_w(), x1 = f$des$get_X_raw()$x1))
	expect_equal(est, unname(coef(ref)["w"]), tolerance = 1e-5)
})
