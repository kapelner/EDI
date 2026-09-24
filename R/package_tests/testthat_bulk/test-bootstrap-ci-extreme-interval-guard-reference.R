library(testthat)
library(EDI)

# InferenceNonParamBootstrap's compute_bootstrap_confidence_interval() (inference_all_abstract_non_
# param_boot.R) has a general "the resulting interval is implausibly extreme" guard, applying to ANY
# bootstrap CI type (not just studentized -- see private$bootstrap_confidence_interval_extreme(ci, est
# = est)): under harden = TRUE it caches "bootstrap_extreme_confidence_interval" (staged "se" for
# studentized-family types, "estimate" otherwise) and returns c(NA, NA); under harden = FALSE it raises
# "Bootstrap confidence interval is numerically unstable." directly. A codebase-wide grep confirmed
# both the harden = TRUE reason string and the harden = FALSE raw message had zero test references
# anywhere. bootstrap_confidence_interval_extreme() itself (the underlying magnitude/scaled-width/
# absolute-width predicate) is already independently tested in test-non-param-boot-extreme-guards-and-
# replication-stats-reference.R, and missing_bootstrap_ci() (the generic NA-plus-cache helper) is
# tested generically elsewhere, but compute_bootstrap_confidence_interval()'s OWN dispatch combining
# them under this specific reason was never exercised -- a sibling gap to the studentized-interval-
# instability guard closed the previous iteration in test-bootstrap-ci-studentized-interval-scale-
# instability-guard-reference.R (same method, the very next branch). Reached by stubbing private$
# bootstrap_confidence_interval_extreme() to force TRUE on InferenceAllSimpleAverageDiff, with the
# real (unstubbed) percentile bootstrap distribution otherwise.

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

test_that("harden = TRUE: a flagged-extreme interval caches 'bootstrap_extreme_confidence_interval' at stage 'estimate' for percentile CIs, and returns c(NA, NA)", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(1L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_confidence_interval_extreme", priv)
	priv$bootstrap_confidence_interval_extreme <- function(...) TRUE

	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(inf$is_nonestimable("estimate"))
	expect_identical(inf$get_nonestimable_reason(), "bootstrap_extreme_confidence_interval")
})

test_that("harden = FALSE: the same flagged-extreme interval raises the raw error instead", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(2L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_confidence_interval_extreme", priv)
	priv$bootstrap_confidence_interval_extreme <- function(...) TRUE
	unlockBinding("harden", priv)
	priv$harden <- FALSE

	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE),
		"Bootstrap confidence interval is numerically unstable.",
		fixed = TRUE
	)
})

test_that("a genuinely well-behaved interval does not trigger the guard", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(3L), verbose = FALSE)
	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 100L, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_false(isTRUE(identical(inf$get_nonestimable_reason(), "bootstrap_extreme_confidence_interval")))
})
