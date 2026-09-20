library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr's percentile-bootstrap CI helper and the validation
# that decides between the bootstrap interval and the Wald fallback: the type-8 percentile
# interval of the finite draws, instability guards (too few draws / absurd width), and the
# fallback rules (unusable ordinary interval, interval not containing the estimate, sign
# disagreement with a usable Wald interval, both unusable -> nonestimable).

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

test_that("percentile interval is unavailable with too few finite draws, absurd width, or a failing draw generator", {
	max_abs <- dc_fx()$p$dep_cens_bootstrap_ci_max_abs
	expect_true(is.finite(max_abs) && max_abs > 1)
	f <- dc_fx(); stub_draws(f, c(0.1, 0.2, NA))
	expect_true(all(is.na(f$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	expect_identical(f$inf$get_nonestimable_reason(), "dep_cens_transform_bootstrap_ci_unstable")
	g <- dc_fx(); stub_draws(g, seq(-2 * max_abs, 2 * max_abs, length.out = 50))
	expect_true(all(is.na(g$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	expect_true(g$inf$is_nonestimable("estimate"))
	h <- dc_fx()
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", h$inf)
	h$inf$approximate_bootstrap_distribution_beta_hat_T <- function(...) stop("boom")
	expect_true(all(is.na(h$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 10, FALSE))))
	k <- dc_fx(); stub_draws(k, c(0.1, 0.2, 0.3))
	expect_false(all(is.na(k$p$dep_cens_percentile_bootstrap_ci(0.05, 50L, 3, FALSE))))     # a lower minimum accepts three draws
})

test_that("validation keeps a sensible bootstrap interval that contains the estimate", {
	f <- dc_fx(); set_state(f, est = -0.3, se = 0.2)
	out <- f$p$dep_cens_validate_bootstrap_ci(c(-0.7, 0.1), alpha = 0.05)
	expect_equal(as.numeric(out), c(-0.7, 0.1))
})

test_that("validation falls back to the Wald interval for unusable or non-covering bootstrap intervals", {
	wald <- function(est, se, alpha = 0.05) est + c(-1, 1) * qnorm(1 - alpha / 2) * se
	max_abs <- dc_fx()$p$dep_cens_bootstrap_ci_max_abs
	for (bad in list(c(NA, 0.1), c(-0.7, Inf), c(0.5, 0.9), c(-0.9, -0.5), c(-5 * max_abs, 5 * max_abs))) {
		f <- dc_fx(); set_state(f, est = -0.3, se = 0.2)
		out <- f$p$dep_cens_validate_bootstrap_ci(bad, alpha = 0.05)
		expect_equal(as.numeric(out), wald(-0.3, 0.2), tolerance = 1e-10, info = paste(bad, collapse = ","))
		expect_equal(names(out), c("2.5%", "97.5%"))
	}
	# Uses the requested alpha.
	g <- dc_fx(); set_state(g, est = -0.3, se = 0.2)
	expect_equal(as.numeric(g$p$dep_cens_validate_bootstrap_ci(c(NA, NA), alpha = 0.1)), wald(-0.3, 0.2, 0.1), tolerance = 1e-10)
})

test_that("a bootstrap interval that excludes zero while a usable Wald interval covers it is replaced by the Wald interval", {
	f <- dc_fx(); set_state(f, est = 0.05, se = 0.2)                                     # Wald: contains 0
	out <- f$p$dep_cens_validate_bootstrap_ci(c(0.01, 0.4), alpha = 0.05)                # bootstrap: excludes 0, contains est
	expect_equal(as.numeric(out), 0.05 + c(-1, 1) * qnorm(0.975) * 0.2, tolerance = 1e-10)
	g <- dc_fx(); set_state(g, est = 0.5, se = 0.1)                                      # Wald excludes 0 too: bootstrap kept
	expect_equal(as.numeric(g$p$dep_cens_validate_bootstrap_ci(c(0.3, 0.7), alpha = 0.05)), c(0.3, 0.7))
})

test_that("when neither interval is usable the result is NA and the SE is flagged nonestimable", {
	f <- dc_fx(); set_state(f, est = -0.3, se = NA_real_)
	out <- f$p$dep_cens_validate_bootstrap_ci(c(NA, NA), alpha = 0.05)
	expect_true(all(is.na(out)))
	expect_identical(f$inf$get_nonestimable_reason(), "dep_cens_transform_bootstrap_ci_unstable")
	expect_true(f$inf$is_nonestimable("se"))
	# Without a usable point estimate the fallback is never consulted: a finite bootstrap interval is returned as given.
	g <- dc_fx(); set_state(g, est = NA_real_, se = 0.2)
	expect_equal(as.numeric(g$p$dep_cens_validate_bootstrap_ci(c(0.5, 0.9), alpha = 0.05)), c(0.5, 0.9))
})
