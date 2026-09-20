library(testthat)
library(EDI)

# InferenceNonParamBootstrap's CI drivers with no direct references:
# ci_from_boot_distribution() (percentile / basic against type-8 quantiles, empty-input
# guard, default estimate), ci_smoothed_bootstrap() and ci_calibrated_bootstrap().
# The calibrated driver's inner/outer resampling is replaced by deterministic stubs
# so the alpha search and the interval type can be checked in closed form.

np_fx <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private)
}

q8 <- function(x, p) stats::quantile(x, probs = p, names = FALSE, type = 8)

stub_priv <- function(p, name, fn) { unlockBinding(name, p); assign(name, fn, envir = p) }

test_that("ci_from_boot_distribution: percentile and basic intervals from type-8 quantiles, default estimate, empty guard", {
	f <- np_fx(); p <- f$p
	set.seed(1); d <- rnorm(200, 0.4, 0.3)
	expect_equal(p$ci_from_boot_distribution(d, 0.1, "percentile", est = 0.4), q8(d, c(0.05, 0.95)))
	expect_equal(p$ci_from_boot_distribution(d, 0.1, "basic", est = 0.5), 2 * 0.5 - q8(d, c(0.95, 0.05)))
	est <- f$inf$compute_estimate()
	expect_equal(p$ci_from_boot_distribution(d, 0.1, "basic"), 2 * est - q8(d, c(0.95, 0.05)))   # est defaults to the point estimate
	expect_error(p$ci_from_boot_distribution(numeric(0), 0.1, "percentile"), "returned NA bounds")
	withr::local_options(edi.run_asserts = FALSE)
	expect_length(p$ci_from_boot_distribution(d, 0.1, "percentile", est = 0.4), 2L)
})

test_that("smoothed driver takes the percentile interval of the finite smoothed draws, and needs >= 10 of them", {
	f <- np_fx(); p <- f$p
	set.seed(2); theta <- c(rnorm(100, 1, 0.2), NA, Inf, NaN)
	seen <- NULL
	stub_priv(p, "approximate_bootstrap_statistics_beta_hat_T", function(B, show_progress = TRUE, na.rm = TRUE, ...) {
		seen <<- list(B = B, dots = list(...)); list(theta = theta)
	})
	ci <- p$ci_smoothed_bootstrap(0.1, 103L, est = 1)
	expect_equal(ci, q8(theta[is.finite(theta)], c(0.05, 0.95)))
	expect_equal(seen$B, 103L)
	expect_true(isTRUE(seen$dots$smooth))
	stub_priv(p, "approximate_bootstrap_statistics_beta_hat_T", function(...) list(theta = c(1, 2, 3, NA)))
	expect_error(p$ci_smoothed_bootstrap(0.1, 10L, est = 1), "too few finite bootstrap draws")
})

calib_setup <- function() {
	f <- np_fx(); p <- f$p
	set.seed(3); outer_theta <- rnorm(300, 0.4, 0.3)
	inner_calls <- 0L
	stub_priv(p, "bootstrap_sample_indices", function(n) list(i_b = seq_len(n)))
	stub_priv(p, "bootstrap_subset_inference", function(idx, smooth = FALSE) {
		list(approximate_bootstrap_distribution_beta_hat_T = function(B, show_progress = FALSE, debug = FALSE) {
			inner_calls <<- inner_calls + 1L
			seq(0.4 - 0.3, 0.4 + 0.3, length.out = B)                 # symmetric about the estimate
		})
	})
	stub_priv(p, "approximate_bootstrap_statistics_beta_hat_T", function(B, show_progress = TRUE, na.rm = TRUE, smooth = FALSE) {
		list(theta = outer_theta, smooth = smooth)
	})
	list(f = f, p = p, outer = outer_theta, calls = function() inner_calls)
}

test_that("calibrated driver: inner intervals centred on the estimate always cover it, so the smallest grid alpha (alpha / 4) is chosen", {
	s <- calib_setup()
	ci <- s$p$ci_calibrated_bootstrap(0.05, B = 200L, type = "calibrated", est = 0.4)
	expect_equal(ci, q8(s$outer, c(0.05 / 4 / 2, 1 - 0.05 / 4 / 2)))
	# Work done: 5 grid alphas x 101 outer replicates (B is capped at 101 outer / 51 inner draws).
	expect_equal(s$calls(), 5L * 101L)
})

test_that("the interval type selects percentile (calibrated / prepivoted / smoothed) or basic (double-bootstrap)", {
	a <- 0.05 / 4
	s <- calib_setup()
	pct <- q8(s$outer, c(a / 2, 1 - a / 2))
	basic <- 2 * 0.4 - q8(s$outer, c(1 - a / 2, a / 2))
	expect_equal(s$p$ci_calibrated_bootstrap(0.05, 200L, "prepivoted", est = 0.4), pct)
	expect_equal(s$p$ci_calibrated_bootstrap(0.05, 200L, "smoothed", est = 0.4), pct)
	expect_equal(s$p$ci_calibrated_bootstrap(0.05, 200L, "double-bootstrap", est = 0.4), basic)
	# The outer draw asks for smoothing only for the smoothed type.
	seen <- list()
	stub_priv(s$p, "approximate_bootstrap_statistics_beta_hat_T", function(B, show_progress = TRUE, na.rm = TRUE, smooth = FALSE) {
		seen[[length(seen) + 1L]] <<- smooth; list(theta = s$outer)
	})
	s$p$ci_calibrated_bootstrap(0.05, 200L, "smoothed", est = 0.4)
	s$p$ci_calibrated_bootstrap(0.05, 200L, "calibrated", est = 0.4)
	expect_equal(unlist(seen), c(TRUE, FALSE))
})

test_that("calibrated driver: too few finite outer draws is an error; replicates with no usable inner draws are skipped", {
	s <- calib_setup()
	stub_priv(s$p, "approximate_bootstrap_statistics_beta_hat_T", function(...) list(theta = c(1, 2, NA)))
	expect_error(s$p$ci_calibrated_bootstrap(0.05, 200L, "calibrated", est = 0.4), "too few finite bootstrap draws")
	# Failed subset inference (NULL) contributes no coverage information; the driver still returns an interval.
	t <- calib_setup()
	stub_priv(t$p, "bootstrap_subset_inference", function(idx, smooth = FALSE) NULL)
	ci <- suppressWarnings(t$p$ci_calibrated_bootstrap(0.05, 200L, "calibrated", est = 0.4))
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
})
