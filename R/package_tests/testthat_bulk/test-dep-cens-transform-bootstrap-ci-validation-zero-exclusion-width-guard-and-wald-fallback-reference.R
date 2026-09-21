library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr private bootstrap-CI validators: dep_cens_ci_excludes_zero(ci), dep_cens_ci_too_wide(ci)
# (limit dep_cens_bootstrap_ci_max_abs = 2) and dep_cens_validate_bootstrap_ci(ci, alpha) (keep a sane bootstrap interval; otherwise
# fall back to the Wald interval est +/- z*se when that is itself usable, else NA + a nonestimable flag). Cache values are injected.

mk <- function(est = 0.3, se = 0.1, df = Inf) {
	set.seed(1); n <- 40L
	d <- DesignFixedBernoulli$new(response_type = "survival", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(ys = rexp(n) + 0.1, y_Ls = rep(NA, n), y_Rs = rep(NA, n))
	inf <- InferenceSurvivalDepCensTransformRegr$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
	p$cached_values$beta_hat_T <- est; p$cached_values$s_beta_hat_T <- se; p$cached_values$df <- df
	list(inf = inf, p = p)
}
f <- mk()
wald <- 0.3 + c(-1, 1) * qnorm(0.975) * 0.1

test_that("width limit is 2 on the absolute bound; excludes-zero looks at strict sign of both bounds", {
	expect_equal(f$p$dep_cens_bootstrap_ci_max_abs, 2)
	tw <- f$p$dep_cens_ci_too_wide
	expect_false(tw(c(-2, 2))); expect_true(tw(c(-2.01, 1))); expect_true(tw(c(0, 2.01)))
	expect_true(tw(c(NA, 1))); expect_true(tw(c(1, Inf))); expect_true(tw(1))                         # non-finite or short: treated as too wide
	ez <- f$p$dep_cens_ci_excludes_zero
	expect_true(ez(c(0.1, 0.5))); expect_true(ez(c(-0.5, -0.1))); expect_true(ez(c(0.5, 0.1)))       # order-agnostic
	expect_false(ez(c(-0.1, 0.5))); expect_false(ez(c(0, 0.5))); expect_false(ez(c(-0.5, 0)))
	expect_false(ez(c(NA, 0.5)))
})

test_that("a sane bootstrap interval that contains the estimate and does not conflict with the Wald interval is returned unchanged", {
	expect_identical(f$p$dep_cens_validate_bootstrap_ci(c(0.1, 0.5), 0.05), c(0.1, 0.5))
	expect_identical(f$p$dep_cens_validate_bootstrap_ci(c(-0.2, 0.9), 0.05), c(-0.2, 0.9))
})

test_that("intervals that miss the estimate, are non-finite, or are too wide fall back to the Wald interval with percent names", {
	for (bad in list(c(0.4, 0.9), c(-0.5, 0.2), c(NA, 1), c(0.1), c(-1e9, 1e9), c(-3, 3))) {
		out <- f$p$dep_cens_validate_bootstrap_ci(bad, 0.05)
		expect_equal(unname(out), wald, tolerance = 1e-10, info = paste(bad, collapse = ","))
		expect_identical(names(out), c("2.5%", "97.5%"))
	}
	expect_equal(unname(f$p$dep_cens_validate_bootstrap_ci(c(0.4, 0.9), 0.1)), 0.3 + c(-1, 1) * qnorm(0.95) * 0.1, tolerance = 1e-10)
})

test_that("a bootstrap interval excluding zero while the Wald interval covers zero is replaced by the Wald interval", {
	g <- mk(est = 0.05, se = 0.1)                                        # Wald: (-0.146, 0.246) covers zero
	out <- g$p$dep_cens_validate_bootstrap_ci(c(0.01, 0.4), 0.05)
	expect_equal(unname(out), 0.05 + c(-1, 1) * qnorm(0.975) * 0.1, tolerance = 1e-10)
	h <- mk(est = 0.5, se = 0.1)                                         # Wald excludes zero as well: the bootstrap interval stands
	expect_identical(h$p$dep_cens_validate_bootstrap_ci(c(0.2, 0.9), 0.05), c(0.2, 0.9))
})

test_that("when the fallback is unusable too (no SE, too wide, or missing estimate) the result is NA and flagged nonestimable", {
	for (g in list(mk(se = NA_real_), mk(se = 5), mk(est = NA_real_))) {
		out <- g$p$dep_cens_validate_bootstrap_ci(c(NA, NA), 0.05)
		expect_true(all(is.na(out))); expect_identical(names(out), c("2.5%", "97.5%"))
		expect_true(isTRUE(g$inf$is_nonestimable("se")))
	}
})

test_that("studentized bootstrap CI collapses to NA when the underlying basic interval excludes zero or is too wide", {
	g <- mk(); unlockBinding("compute_bootstrap_confidence_interval_basic", g$inf)
	g$inf$compute_bootstrap_confidence_interval_basic <- function(...) c(0.1, 0.5)
	out <- g$inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05)
	expect_true(all(is.na(out))); expect_identical(names(out), c("2.5%", "97.5%")); expect_true(isTRUE(g$inf$is_nonestimable("se")))
	h <- mk(); unlockBinding("compute_bootstrap_confidence_interval_basic", h$inf)
	h$inf$compute_bootstrap_confidence_interval_basic <- function(...) c(-0.4, 0.6)
	expect_identical(h$inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05), c(-0.4, 0.6))
	k <- mk(); unlockBinding("compute_bootstrap_confidence_interval_basic", k$inf)
	k$inf$compute_bootstrap_confidence_interval_basic <- function(...) stop("boom")
	expect_true(all(is.na(k$inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05))))
})
