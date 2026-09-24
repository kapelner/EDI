library(testthat)
library(EDI)

# InferenceNonParamBootstrap's private compute_bootstrap_confidence_interval() (inference_all_
# abstract_non_param_boot.R) checks, after computing the bootstrap CI, whether both bounds came out
# identical (`if (isTRUE(all(ci[1:2] == ci[1L])))`) -- a degenerate interval, which happens when the
# bootstrap replicate distribution has zero variance. Under harden = TRUE (the default for most
# concrete classes) this is caught and converted to `missing_bootstrap_ci(alpha,
# "bootstrap_degenerate_confidence_interval", stage = "se")` (caching a nonestimable SE, not
# estimate, and returning c(NA, NA)); under harden = FALSE it instead raises `stop("Degenerate
# bootstrap confidence interval")` directly. A codebase-wide grep confirms neither the harden = TRUE
# reason string nor the harden = FALSE raw error message had any test reference anywhere (distinct
# from the file's already-tested sibling guards for too-few-finite-estimates, extreme estimates, and
# NA bounds). Reached by unlockBinding-replacing the public approximate_bootstrap_distribution_
# beta_hat_T() with a stub returning a constant vector (zero variance by construction), on
# InferenceAllSimpleAverageDiff (a simple, non-hardening-required class), independent of the real
# bootstrap-resampling machinery (already tested elsewhere).

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

test_that("harden = TRUE: a degenerate (zero-variance) bootstrap distribution caches the documented nonestimable SE reason and returns c(NA, NA)", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(1L), verbose = FALSE)
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", inf)
	inf$approximate_bootstrap_distribution_beta_hat_T <- function(B, show_progress = TRUE) rep(0.5, B)

	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_true(inf$is_nonestimable("se"))
	expect_equal(inf$get_nonestimable_reason(), "bootstrap_degenerate_confidence_interval")
})

test_that("harden = FALSE: the same degenerate bootstrap distribution raises the raw error instead", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(2L), verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("harden", priv)
	priv$harden <- FALSE
	unlockBinding("approximate_bootstrap_distribution_beta_hat_T", inf)
	inf$approximate_bootstrap_distribution_beta_hat_T <- function(B, show_progress = TRUE) rep(0.5, B)

	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "percentile", B = 50L, show_progress = FALSE),
		"Degenerate bootstrap confidence interval"
	)
})

test_that("a genuinely varying bootstrap distribution does not trigger the guard", {
	inf <- InferenceAllSimpleAverageDiff$new(fx(3L), verbose = FALSE)
	ci <- inf$compute_bootstrap_confidence_interval(type = "percentile", B = 100L, show_progress = FALSE)
	expect_true(all(is.finite(ci)))
	expect_false(isTRUE(identical(inf$get_nonestimable_reason(), "bootstrap_degenerate_confidence_interval")))
})
