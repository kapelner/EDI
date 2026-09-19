library(testthat)
library(EDI)

# InferenceContinQuantileRegr (inference_continuous_quantile_regr.R, 311 lines) was previously
# only smoke-tested for finiteness (test-regression-rank-and-stratified-cox-contracts.R): no
# assertion ever checked the point estimate, SE, CI or p-value against an independent quantreg
# reference, and compute_estimate_with_bootstrap_weights() was never called at all (grepped
# testthat/testthat_bulk for InferenceContinQuantileRegr; only the one smoke-test hit found).

make_quantile_regr_design <- function(y, x1, w) {
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

quantile_regr_fixture <- function(seed = 20260918L, n = 40L) {
	set.seed(seed)
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	y <- 2 + 1.5 * w + 0.8 * x1 + rt(n, df = 5)
	list(des = make_quantile_regr_design(y, x1, w), y = y, x1 = x1, w = w)
}

test_that("compute_estimate/SE/CI/p-value match an independent quantreg::rq fit exactly", {
	skip_if_not_installed("quantreg")
	f <- quantile_regr_fixture()
	inf <- InferenceContinQuantileRegr$new(f$des, model_formula = ~x1, tau = 0.5, verbose = FALSE)

	est <- inf$compute_estimate()
	ci <- inf$compute_asymp_confidence_interval(alpha = 0.1)
	pval <- inf$compute_asymp_two_sided_pval()

	y <- f$y; w <- f$w; x1 <- f$x1
	ref <- suppressWarnings(quantreg::rq(y ~ w + x1, tau = 0.5))
	ref_summ <- suppressWarnings(summary(ref, se = "nid"))
	ref_row <- ref_summ$coefficients["w", ]

	expect_equal(est, unname(coef(ref)["w"]), tolerance = 1e-8)
	expect_equal(unname(pval), unname(ref_row["Pr(>|t|)"]), tolerance = 1e-8)

	df <- length(f$y) - 3L
	crit <- qt(1 - 0.1 / 2, df)
	se <- unname(ref_row["Std. Error"])
	expect_equal(as.numeric(ci), c(est - crit * se, est + crit * se), tolerance = 1e-8)

	# estimate_only=TRUE skips SE/CI machinery but returns the identical point estimate
	inf2 <- InferenceContinQuantileRegr$new(f$des, model_formula = ~x1, tau = 0.5, verbose = FALSE)
	expect_equal(inf2$compute_estimate(estimate_only = TRUE), est, tolerance = 1e-8)
})

test_that("compute_estimate_with_bootstrap_weights matches an independent weighted quantreg::rq fit", {
	skip_if_not_installed("quantreg")
	f <- quantile_regr_fixture()
	inf <- InferenceContinQuantileRegr$new(f$des, model_formula = ~x1, tau = 0.5, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()

	set.seed(20260918L + 1L)
	y <- f$y; w <- f$w; x1 <- f$x1
	wts <- sample(c(0.5, 1, 1.5), length(y), replace = TRUE)

	actual_est <- inf$compute_estimate_with_bootstrap_weights(wts)
	ref_w <- suppressWarnings(quantreg::rq(y ~ w + x1, tau = 0.5, weights = wts))
	expect_equal(actual_est, unname(coef(ref_w)["w"]), tolerance = 1e-6)

	# estimate_only=FALSE additionally populates a weighted-fit SE matching the independent reference
	actual_est_full <- inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)
	se_actual <- private$cached_values$s_beta_hat_T
	ref_w_summ <- suppressWarnings(summary(ref_w, se = "nid"))
	expect_equal(actual_est_full, actual_est, tolerance = 1e-6)
	expect_equal(se_actual, unname(ref_w_summ$coefficients["w", "Std. Error"]), tolerance = 1e-6)

	# unit weights reproduce the unweighted point estimate exactly (same underlying solver call)
	expect_equal(inf$compute_estimate_with_bootstrap_weights(rep(1, length(y))),
		inf$compute_estimate(estimate_only = TRUE), tolerance = 1e-8)
})

test_that("rank-deficient covariates are dropped before fitting, matching a manually-reduced quantreg fit", {
	skip_if_not_installed("quantreg")
	set.seed(20260918L + 2L)
	n <- 20L
	x1 <- rnorm(n)
	x2 <- 2 * x1 # exactly collinear with x1
	w <- rep(0:1, n / 2L)
	y <- 2 + 1.2 * w + 0.6 * x1 + rt(n, df = 5)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)

	inf <- InferenceContinQuantileRegr$new(des, model_formula = ~ x1 + x2, tau = 0.5, verbose = FALSE)
	est <- inf$compute_estimate()

	ref <- suppressWarnings(quantreg::rq(y ~ w + x1, tau = 0.5)) # x2 manually dropped
	expect_equal(est, unname(coef(ref)["w"]), tolerance = 1e-6)
})

test_that("too few residual degrees of freedom is reported as a clean NA, not an error", {
	skip_if_not_installed("quantreg")
	des <- DesignFixediBCRD$new(n = 3L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = c(0.1, 0.2, 0.3)))
	des$overwrite_all_subject_assignments(c(0, 1, 0))
	des$add_all_subject_responses(c(1, 2, 3))
	inf <- InferenceContinQuantileRegr$new(des, model_formula = ~x1, tau = 0.5, verbose = FALSE)
	expect_true(is.na(inf$compute_estimate()))
	expect_true(all(is.na(inf$compute_asymp_confidence_interval())))
	expect_true(is.na(inf$compute_asymp_two_sided_pval()))
})

test_that("tau must lie strictly inside (0, 1)", {
	skip_if_not_installed("quantreg")
	f <- quantile_regr_fixture()
	expect_error(InferenceContinQuantileRegr$new(f$des, tau = 0, verbose = FALSE), "tau")
	expect_error(InferenceContinQuantileRegr$new(f$des, tau = 1, verbose = FALSE), "tau")
})
