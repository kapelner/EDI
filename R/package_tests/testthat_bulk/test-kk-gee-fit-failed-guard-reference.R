library(testthat)
library(EDI)

# InferenceCountPoissonKKGEE$shared_gee_default() (inference_mixin_kk_gee_shared.R, the shared GEE
# dispatch every non-ordinal KK-GEE daughter composes) caches "kk_gee_fit_failed" when
# fit_gee_with_fallback() itself returns NULL. This had no test reference anywhere. Reached via
# InferenceCountPoissonKKGEE by mocking the private fitter directly (unlockBinding), the same
# technique already used elsewhere in this suite for analogous unreachable-in-practice failure
# paths.
#
# Note (investigated, not tested here): the sibling "kk_gee_estimate_unavailable" and
# "kk_gee_standard_error_unavailable" guards look reachable from reading shared_gee_default() in
# isolation (post-fit gee_treatment_index()/extract_gee_treatment_se() giving an invalid result),
# but both of those same private helpers are ALSO called from inside fit_gee_with_fallback() itself
# (its own retry/fallback ladder uses them to judge fit quality), so overriding either one to force
# an invalid result instead makes every fitting attempt look bad and the fallback ladder exhausts,
# landing on "kk_gee_fit_failed" instead of the intended downstream guard. Not pursued further to
# avoid a fragile, call-order-dependent mock.

test_that("shared_gee_default caches 'kk_gee_fit_failed' when fit_gee_with_fallback() fails", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rpois(n, exp(0.3 * X$x1 + 0.5 * des$get_w() + 1)))

	inf <- InferenceCountPoissonKKGEE$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("fit_gee_with_fallback", p)
	p$fit_gee_with_fallback <- function(...) NULL

	res <- inf$compute_estimate(estimate_only = TRUE)
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "kk_gee_fit_failed")
})
