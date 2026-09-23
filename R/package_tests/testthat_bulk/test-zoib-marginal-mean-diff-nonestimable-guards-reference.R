library(testthat)
library(EDI)

# InferencePropZeroOneInflatedBetaRegr's compute_marginal_mean_diff_estimate()
# (inference_proportion_zero_one_inflated_beta.R) has four nonestimable guards, none of which had a
# test reference anywhere (the existing zoib-marginal-estimand test files only exercise the
# successful/finite path against independent references):
#   1. "zoib_marginal_mean_diff_fit_unavailable": private$cached_mod (or its params/X/X_zero_one) is
#      unavailable.
#   2. "zoib_marginal_mean_diff_point_unavailable": the mean-difference functional is non-finite on
#      an otherwise-usable cached fit.
#   3. "zoib_marginal_mean_diff_vcov_unavailable": the point estimate is usable but mod$vcov is NULL.
#   4. "zoib_marginal_mean_diff_se_unavailable": vcov is available but marginal_estimand_delta_se()
#      itself returns a non-finite/negative SE.
# Reached entirely via direct private$cached_mod injection (never calling the real
# fast_zero_one_inflated_beta_cpp() fitter, which this session's Avoid list flags as intermittently
# crash-prone) -- the same cached_mod-injection fixture pattern already used for the sibling
# zero-augmented-Poisson/beta-regr marginal-estimand guards closed earlier this session.

zoib_fx <- function(seed = 1L, n = 50L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "proportion", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(plogis(rnorm(n) + 0.5 * des$get_w()))
	inf <- InferencePropZeroOneInflatedBetaRegr$new(des, verbose = FALSE)
	Xc <- cbind(`(Intercept)` = 1, treatment = des$get_w(), x1 = X$x1)
	list(inf = inf, p = inf$.__enclos_env__$private, Xc = Xc)
}

test_that("'zoib_marginal_mean_diff_fit_unavailable' fires when cached_mod/params/X/X_zero_one are unavailable", {
	f1 <- zoib_fx()
	f1$p$cached_mod <- NULL
	expect_true(is.na(f1$p$compute_marginal_mean_diff_estimate()))
	expect_identical(f1$inf$get_nonestimable_reason(), "zoib_marginal_mean_diff_fit_unavailable")

	f2 <- zoib_fx(seed = 2L)
	f2$p$cached_mod <- list(params = NULL, X = f2$Xc, X_zero_one = f2$Xc)
	expect_true(is.na(f2$p$compute_marginal_mean_diff_estimate()))
	expect_identical(f2$inf$get_nonestimable_reason(), "zoib_marginal_mean_diff_fit_unavailable")
})

test_that("'zoib_marginal_mean_diff_point_unavailable' fires when the functional is non-finite", {
	f <- zoib_fx(seed = 3L)
	theta <- c(0.3, 0.5, 0.2, 0, -2, -0.2, 0.4, -2, 0.1, 0.3)  # p=3, log_phi=1, q=3, q=3
	f$p$cached_mod <- list(params = theta, X = f$Xc, X_zero_one = f$Xc, vcov = diag(0.01, length(theta)))
	unlockBinding("zoib_marginal_mean_diff_functional", f$p)
	f$p$zoib_marginal_mean_diff_functional <- function(...) NaN

	expect_true(is.na(f$p$compute_marginal_mean_diff_estimate()))
	expect_identical(f$inf$get_nonestimable_reason(), "zoib_marginal_mean_diff_point_unavailable")
})

test_that("'zoib_marginal_mean_diff_vcov_unavailable' fires when the point is usable but vcov is NULL", {
	f <- zoib_fx(seed = 4L)
	theta <- c(0.3, 0.5, 0.2, 0, -2, -0.2, 0.4, -2, 0.1, 0.3)
	f$p$cached_mod <- list(params = theta, X = f$Xc, X_zero_one = f$Xc, vcov = NULL)

	point <- f$p$compute_marginal_mean_diff_estimate()
	expect_true(is.finite(point))
	expect_identical(f$inf$get_nonestimable_reason(), "zoib_marginal_mean_diff_vcov_unavailable")
})

test_that("'zoib_marginal_mean_diff_se_unavailable' fires when the delta-method SE is unusable", {
	f <- zoib_fx(seed = 5L)
	theta <- c(0.3, 0.5, 0.2, 0, -2, -0.2, 0.4, -2, 0.1, 0.3)
	f$p$cached_mod <- list(params = theta, X = f$Xc, X_zero_one = f$Xc, vcov = diag(0.01, length(theta)))
	local_mocked_bindings(marginal_estimand_delta_se = function(...) list(se = NA_real_), .package = "EDI")

	point <- f$p$compute_marginal_mean_diff_estimate()
	expect_true(is.finite(point))
	expect_identical(f$inf$get_nonestimable_reason(), "zoib_marginal_mean_diff_se_unavailable")
})
