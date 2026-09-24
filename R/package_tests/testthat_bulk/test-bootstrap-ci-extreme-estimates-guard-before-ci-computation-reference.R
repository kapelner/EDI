library(testthat)
library(EDI)

# InferenceNonParamBootstrap's compute_bootstrap_confidence_interval() (inference_all_abstract_non_
# param_boot.R:877-881) checks private$bootstrap_estimates_extreme(boot_distr, est = est) on the RAW
# bootstrap distribution BEFORE ever computing the interval itself -- distinct from the already-tested
# bootstrap_confidence_interval_extreme() guard (test-bootstrap-ci-extreme-interval-guard-reference.R),
# which instead flags the resulting CI's own width/magnitude AFTER computation. Under harden = TRUE
# this caches "bootstrap_extreme_finite_estimates" and returns c(NA, NA); under harden = FALSE it
# raises "Bootstrap estimates are numerically unstable." directly. bootstrap_estimates_extreme() itself
# is exercised elsewhere (via compute_bootstrap_two_sided_pval()'s own dispatch of the identical
# reason string, in test-bootstrap-two-sided-pval-nonestimable-guards-reference.R), but
# compute_bootstrap_confidence_interval()'s OWN dispatch -- both the harden = TRUE reason-caching path
# and the harden = FALSE raw message -- had zero test references anywhere, confirmed via codebase-wide
# grep. Reached by stubbing private$bootstrap_estimates_extreme() to force TRUE on
# InferenceAllSimpleAverageDiff, with the real (unstubbed) percentile bootstrap distribution otherwise
# -- the same technique already established in the sibling CI-guard file.

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnorm(n) + 0.5 * w + 0.3 * X$x1
	des$add_all_subject_responses(y)
	des
}

test_that("harden = TRUE: an extreme raw bootstrap distribution caches 'bootstrap_extreme_finite_estimates' and returns c(NA, NA), before the CI is ever computed", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(1L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_estimates_extreme", priv)
	priv$bootstrap_estimates_extreme <- function(...) TRUE

	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(inf$is_nonestimable("estimate"))
	expect_identical(inf$get_nonestimable_reason(), "bootstrap_extreme_finite_estimates")
})

test_that("harden = FALSE: the same extreme raw bootstrap distribution raises the raw error instead", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(2L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_estimates_extreme", priv)
	priv$bootstrap_estimates_extreme <- function(...) TRUE
	unlockBinding("harden", priv)
	priv$harden <- FALSE

	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE),
		"Bootstrap estimates are numerically unstable.",
		fixed = TRUE
	)
})

test_that("a genuinely well-behaved bootstrap distribution does not trigger this guard", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(3L), verbose = FALSE)
	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 100L, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_false(isTRUE(identical(inf$get_nonestimable_reason(), "bootstrap_extreme_finite_estimates")))
})
