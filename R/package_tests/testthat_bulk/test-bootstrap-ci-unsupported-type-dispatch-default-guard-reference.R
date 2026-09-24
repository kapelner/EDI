library(testthat)
library(EDI)

# InferenceNonParamBootstrap's compute_bootstrap_confidence_interval() (inference_all_abstract_non_
# param_boot.R) dispatches on `type` to one of several CI-construction branches (percentile, basic,
# studentized family, bca, calibrated family, smoothed); its `type` argument is validated up front via
# `assertChoice(type, private$bootstrap_ci_types)`, and private$bootstrap_ci_types's current 10 values
# are ALL handled by the dispatch's if-chain -- so the chain's final `else { stop("Unsupported
# bootstrap CI type: ", type) }` default arm is genuinely unreachable via the public API as things
# stand today (every legal type value is handled), but it is real, directly-reachable code once
# private$bootstrap_ci_types itself is extended with an entry the if-chain doesn't recognize (verified
# this doesn't require any Rcpp/C++ change -- a plain private-field append). Under harden = TRUE
# (default), the error is caught by the surrounding tryCatch and converted to the
# "bootstrap_ci_unavailable" nonestimable reason via missing_bootstrap_ci(); under harden = FALSE, the
# raw error propagates. A codebase-wide grep confirmed the raw message had zero test references
# anywhere.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	des
}

test_that("harden = TRUE: an unrecognized (but assertChoice-legal) bootstrap CI type is caught and cached as 'bootstrap_ci_unavailable', returning c(NA, NA)", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(1L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_ci_types", priv)
	priv$bootstrap_ci_types <- c(priv$bootstrap_ci_types, "bogus_type")

	ci <- inf$compute_bootstrap_confidence_interval(type = "bogus_type", B = 30L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "bootstrap_ci_unavailable")
})

test_that("harden = FALSE: the same unrecognized type raises the raw 'Unsupported bootstrap CI type' error instead", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(2L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("bootstrap_ci_types", priv)
	priv$bootstrap_ci_types <- c(priv$bootstrap_ci_types, "bogus_type")
	unlockBinding("harden", priv)
	priv$harden <- FALSE

	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "bogus_type", B = 30L, show_progress = FALSE),
		"Unsupported bootstrap CI type: bogus_type",
		fixed = TRUE
	)
})

test_that("a legal, recognized bootstrap CI type never triggers the guard", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(3L), verbose = FALSE)
	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 100L, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_false(isTRUE(identical(inf$get_nonestimable_reason(), "bootstrap_ci_unavailable")))
})
