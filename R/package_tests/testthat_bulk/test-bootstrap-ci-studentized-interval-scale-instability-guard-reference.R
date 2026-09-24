library(testthat)
library(EDI)

# InferenceNonParamBootstrap's compute_bootstrap_confidence_interval() (inference_all_abstract_non_
# param_boot.R) has its OWN post-hoc studentized-interval-instability check, distinct from the
# similarly-named guard already closed in test-bootstrap-studentized-unstable-standard-errors-guard-
# reference.R (which covers compute_bootstrap_two_sided_pval()'s SEPARATE call site under the reason
# "bootstrap_unstable_studentized_standard_errors"). This method's own check, after a studentized/
# bootstrap-t/symmetric-percentile-t CI has already been successfully computed, calls private$
# studentized_interval_scale_unstable() on the final interval; if it flags the interval as implausibly
# wide, under harden = TRUE it caches "bootstrap_unstable_studentized_interval" (a nonestimable SE) and
# returns c(NA, NA); under harden = FALSE it raises "Studentized bootstrap interval is numerically
# unstable." directly. A codebase-wide grep confirmed BOTH the harden = TRUE reason string and the
# harden = FALSE raw message had zero test references anywhere -- genuinely distinct from the
# already-covered sibling guard despite the near-identical name and shared underlying
# studentized_interval_scale_unstable() predicate (that predicate's own arithmetic is independently
# tested in test-bootstrap-studentized-pivot-filtering-ci-formulas-and-interval-scale-instability-
# reference.R). Reached the same way as the sibling pval guard: mocking approximate_bootstrap_
# statistics_beta_hat_T() to return a well-formed theta/se pair (so CI computation itself succeeds)
# and studentized_interval_scale_unstable() directly to force TRUE, on InferenceAllSimpleAverageDiff.

smd_boot_fixture <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- w + rnorm(n, sd = 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("harden = TRUE: an unstable studentized interval caches 'bootstrap_unstable_studentized_interval' and returns c(NA, NA)", {
	f <- smd_boot_fixture(seed = 123L)
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(20, mean = 0.5, sd = 0.2), se = rep(0.2, 20))
	}
	unlockBinding("studentized_interval_scale_unstable", f$priv)
	f$priv$studentized_interval_scale_unstable <- function(...) TRUE

	ci <- f$inf$compute_bootstrap_confidence_interval(type = "studentized", show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(f$inf$is_nonestimable("se"))
	expect_identical(f$inf$get_nonestimable_reason(), "bootstrap_unstable_studentized_interval")
})

test_that("harden = FALSE: the same unstable studentized interval raises the raw error instead", {
	f <- smd_boot_fixture(seed = 7L)
	unlockBinding("approximate_bootstrap_statistics_beta_hat_T", f$priv)
	f$priv$approximate_bootstrap_statistics_beta_hat_T <- function(...) {
		list(theta = rnorm(20, mean = 0.5, sd = 0.2), se = rep(0.2, 20))
	}
	unlockBinding("studentized_interval_scale_unstable", f$priv)
	f$priv$studentized_interval_scale_unstable <- function(...) TRUE
	unlockBinding("harden", f$priv)
	f$priv$harden <- FALSE

	expect_error(
		f$inf$compute_bootstrap_confidence_interval(type = "studentized", show_progress = FALSE),
		"Studentized bootstrap interval is numerically unstable.",
		fixed = TRUE
	)
})

test_that("a genuinely stable studentized interval does not trigger the guard", {
	f <- smd_boot_fixture(seed = 42L)
	ci <- f$inf$compute_bootstrap_confidence_interval(type = "studentized", B = 100L, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_false(isTRUE(identical(f$inf$get_nonestimable_reason(), "bootstrap_unstable_studentized_interval")))
})
