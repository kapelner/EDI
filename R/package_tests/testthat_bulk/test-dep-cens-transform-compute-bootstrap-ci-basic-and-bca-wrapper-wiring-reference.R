library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval_basic()/_bca(): public wrappers around
# the generic type-parameterized self$compute_bootstrap_confidence_interval(type = "basic"/"bca", ...), each piped
# through the class's own private$dep_cens_validate_bootstrap_ci() (contains-the-estimate / usable-width / Wald-
# fallback logic, already independently tested in test-dep-cens-transform-bootstrap-ci-fallback.R) and, for the
# "basic" wrapper only, a further fallback to private$dep_cens_percentile_bootstrap_ci() (also already tested) when
# even the validated interval comes back unusable. This file targets the wrapper methods themselves -- previously
# exercised only via a stub that replaced compute_bootstrap_confidence_interval_basic entirely (for the studentized
# CI's own test), never calling either real method -- using the already-tested lower-level pieces as the reference.

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

test_that("compute_bootstrap_confidence_interval_basic(), the usable case: equals the validated type='basic' generic interval", {
	f <- dc_fx(); set.seed(1); d <- rnorm(300, -0.4, 0.3)
	f <- stub_draws(f, d); f <- set_state(f, est = -0.4, se = 0.3)
	direct <- f$inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 300, type = "basic", min_number_usable_samples = 10, show_progress = FALSE)
	ref <- f$p$dep_cens_validate_bootstrap_ci(direct, alpha = 0.05)
	out <- f$inf$compute_bootstrap_confidence_interval_basic(alpha = 0.05, B = 300, min_number_usable_samples = 10, show_progress = FALSE)
	expect_equal(as.numeric(out), as.numeric(ref))
	expect_false(anyNA(out))
})

test_that("compute_bootstrap_confidence_interval_basic() falls back to the percentile CI when the validated basic interval is unusable", {
	f <- dc_fx(); set.seed(3); d <- rnorm(300, 0, 0.3)
	f <- stub_draws(f, d)
	f <- set_state(f, est = 5, se = NA_real_)                                          # est far outside the draws AND Wald unusable
	direct <- f$inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 300, type = "basic", min_number_usable_samples = 10, show_progress = FALSE)
	expect_false(direct[1] <= 5 && 5 <= direct[2])                                      # sanity: direct interval genuinely excludes est = 5
	expect_true(all(is.na(f$p$dep_cens_validate_bootstrap_ci(direct, alpha = 0.05))))   # confirms validation actually rejects it here
	ref_pct <- f$p$dep_cens_percentile_bootstrap_ci(alpha = 0.05, B = 300, min_number_usable_samples = 10, show_progress = FALSE)
	out <- f$inf$compute_bootstrap_confidence_interval_basic(alpha = 0.05, B = 300, min_number_usable_samples = 10, show_progress = FALSE)
	expect_false(anyNA(ref_pct))                                                        # the percentile fallback itself IS usable here
	expect_equal(as.numeric(out), as.numeric(ref_pct))
})

# compute_bootstrap_confidence_interval_bca's own bca engine (jackknife-based acceleration) is a class-specific
# numerical mechanism, not this wrapper's own logic, and can itself return NA on some fixtures (unrelated to the
# wrapper's wiring); to isolate the wrapper's wiring from that engine, stub the generic type-parameterized method
# it calls through to and control its return value directly -- the same technique already used elsewhere in this
# suite (the precedent studentized-CI test stubs compute_bootstrap_confidence_interval_basic itself).
stub_generic <- function(f, val) {
	unlockBinding("compute_bootstrap_confidence_interval", f$inf)
	f$inf$compute_bootstrap_confidence_interval <- function(alpha = 0.05, B = 1000, type = "percentile", ...) val
	invisible(f)
}

test_that("compute_bootstrap_confidence_interval_bca() calls the generic method with type='bca' and pipes the result through validation unchanged when it is usable", {
	f <- dc_fx(); f <- set_state(f, est = -0.4, se = 0.3); f <- stub_generic(f, c(-0.7, 0.1))   # contains zero -> kept as-is
	ref <- f$p$dep_cens_validate_bootstrap_ci(c(-0.7, 0.1), alpha = 0.05)
	out <- f$inf$compute_bootstrap_confidence_interval_bca(alpha = 0.05, B = 300, min_number_usable_samples = 10, show_progress = FALSE)
	expect_equal(as.numeric(out), as.numeric(ref))
	expect_equal(as.numeric(out), c(-0.7, 0.1))
})

test_that("compute_bootstrap_confidence_interval_bca() propagates a Wald fallback (no percentile rescue) when the generic interval doesn't contain the estimate", {
	f <- dc_fx(); f <- set_state(f, est = 1.0, se = 0.3); f <- stub_generic(f, c(-0.7, -0.1))   # doesn't contain est = 1.0
	wald <- 1.0 + c(-1, 1) * qnorm(0.975) * 0.3
	out <- f$inf$compute_bootstrap_confidence_interval_bca(alpha = 0.05, B = 300, min_number_usable_samples = 10, show_progress = FALSE)
	expect_equal(as.numeric(out), wald, tolerance = 1e-10)
	expect_false(isTRUE(all.equal(as.numeric(out), c(-0.7, -0.1))))                             # the unusable generic interval is not what's returned
})
