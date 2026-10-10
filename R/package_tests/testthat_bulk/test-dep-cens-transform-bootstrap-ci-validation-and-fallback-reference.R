library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr's percentile-bootstrap CI helper and the validation
# that preserves a finite bootstrap interval irrespective of its sign, width, or
# relation to the Wald interval. Only unavailable numerical output is rejected.

dc_fx <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	inf <- InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, n = n)
}

stub_draws <- function(f, draws) {
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", f$inf)
	f$inf$approximate_bootstrap_distribution_beta_hat_T <- function(B, show_progress = FALSE, ...) draws
	invisible(f)
}

set_state <- function(f, est, se, df = Inf) {
	f$p$cached_values$beta_hat_T <- est; f$p$cached_values$s_beta_hat_T <- se; f$p$cached_values$df <- df
	invisible(f)
}

test_that("percentile interval: type-8 quantiles of the finite draws with alpha labels", {
	f <- dc_fx()
	set.seed(1); d <- c(rnorm(300, -0.4, 0.3), NA, Inf, NaN)
	stub_draws(f, d)
	ci <- f$p$dep_cens_percentile_bootstrap_ci(alpha = 0.1, B = 303L, min_number_usable_samples = 10, show_progress = FALSE)
	expect_equal(as.numeric(ci), quantile(d[is.finite(d)], c(0.05, 0.95), names = FALSE, type = 8))
	expect_equal(names(ci), c("5%", "95%"))
	expect_false(f$inf$is_nonestimable("any"))
})

test_that("percentile interval is unavailable with too few finite draws or a failing draw generator", {
	f <- dc_fx(); stub_draws(f, c(0.1, 0.2, NA))
	expect_true(all(is.na(f$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	expect_identical(f$inf$get_nonestimable_reason(), "dep_cens_transform_bootstrap_ci_unstable")
	g <- dc_fx(); stub_draws(g, seq(-100, 100, length.out = 50))
	expect_true(all(is.finite(g$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	h <- dc_fx()
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", h$inf)
	h$inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) stop("boom")
	expect_true(all(is.na(h$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	k <- dc_fx(); stub_draws(k, c(0.1, 0.2, 0.3))
	expect_false(all(is.na(k$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 3, FALSE))))     # a lower minimum accepts three draws
})

test_that("validation retains finite bootstrap intervals independent of Wald agreement", {
	f <- dc_fx(); set_state(f, est = -0.3, se = 0.2)
	for (ci in list(c(-0.7, 0.1), c(0.5, 0.9), c(-10, 12), c(0.01, 0.4))) {
		expect_identical(f$p$dep_cens_validate_bootstrap_ci(ci, alpha = 0.05), ci)
	}
})

test_that("non-finite bootstrap output is unavailable and does not substitute a Wald interval", {
	f <- dc_fx(); set_state(f, est = -0.3, se = NA_real_)
	out <- f$p$dep_cens_validate_bootstrap_ci(c(NA, NA), alpha = 0.05)
	expect_true(all(is.na(out)))
	expect_identical(f$inf$get_nonestimable_reason(), "dep_cens_transform_bootstrap_ci_unstable")
	expect_true(f$inf$is_nonestimable("se"))
	# A finite interval does not require a usable Wald point estimate.
	g <- dc_fx(); set_state(g, est = NA_real_, se = 0.2)
	expect_equal(as.numeric(g$p$dep_cens_validate_bootstrap_ci(c(0.5, 0.9), alpha = 0.05)), c(0.5, 0.9))
})
