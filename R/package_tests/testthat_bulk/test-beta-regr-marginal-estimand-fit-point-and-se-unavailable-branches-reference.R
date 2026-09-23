library(testthat)
library(EDI)

# InferencePropBetaRegr$compute_marginal_estimand_estimate() (inference_proportion_beta.R) has 4
# distinct nonestimable branches on the marginal_mean_diff estimand path. The existing reference
# test (test-beta-regr-marginal-estimand-delta-method.R) covers the success path and only one of the
# 4 -- "beta_regr_marginal_vcov_unavailable" (mod$vcov itself NULL, via a genuinely singular fit).
# The other 3 had no test reference anywhere:
#   1. "beta_regr_marginal_fit_unavailable": private$cached_mod (or its $b/$X) is NULL -- reached
#      by calling the private method before generate_mod()/shared() has ever populated it.
#   2. "beta_regr_marginal_point_unavailable": the functional itself evaluates to a non-finite point
#      estimate even though a fit exists.
#   3. "beta_regr_marginal_se_unavailable": mod$vcov IS available (unlike branch 4 above), but
#      marginal_estimand_delta_se() itself returns a non-finite or negative SE.
# Branches 2 and 3 are reached by mocking the exact private method / package function this method
# calls, the same techniques already used elsewhere in this suite for analogous
# unreachable-in-practice failure paths.

make_fixture <- function(n = 40L, seed = 42L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", seed = seed)
	x1 <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	mu <- plogis(-0.3 + 0.8 * w + 0.4 * x1)
	y <- pmin(pmax(rbeta(n, mu * 12, (1 - mu) * 12), 1e-6), 1 - 1e-6)
	des$add_all_subject_responses(y)
	des
}

test_that("compute_marginal_estimand_estimate() is nonestimable ('beta_regr_marginal_fit_unavailable') before any fit exists", {
	des <- make_fixture()
	inf <- InferencePropBetaRegr$new(des)
	inf$set_estimand("marginal_mean_diff")
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_mod)

	res <- p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "beta_regr_marginal_fit_unavailable")
})

test_that("a non-finite marginal functional value is nonestimable ('beta_regr_marginal_point_unavailable')", {
	des <- make_fixture(seed = 43L)
	inf <- InferencePropBetaRegr$new(des)
	inf$set_estimand("marginal_mean_diff")
	p <- inf$.__enclos_env__$private
	inf$compute_estimate()  # populate cached_mod with a real, successful fit
	expect_true(!is.null(p$cached_mod))

	unlockBinding("beta_regr_marginal_functional", p)
	p$beta_regr_marginal_functional <- function(...) NA_real_

	res <- p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "beta_regr_marginal_point_unavailable")
})

test_that("an available vcov but a non-finite delta-method SE is nonestimable ('beta_regr_marginal_se_unavailable')", {
	des <- make_fixture(seed = 44L)
	inf <- InferencePropBetaRegr$new(des)
	inf$set_estimand("marginal_mean_diff")
	p <- inf$.__enclos_env__$private
	pt_ref <- inf$compute_estimate()
	expect_true(!is.null(p$cached_mod$vcov))

	local_mocked_bindings(marginal_estimand_delta_se = function(...) list(se = NA_real_), .package = "EDI")
	res <- p$compute_marginal_estimand_estimate("marginal_mean_diff")

	expect_equal(res, pt_ref, tolerance = 1e-10)  # the point estimate survives even though the SE didn't
	expect_identical(inf$get_nonestimable_reason(), "beta_regr_marginal_se_unavailable")
	expect_true(is.na(p$cached_values$s_beta_hat_T))
})
