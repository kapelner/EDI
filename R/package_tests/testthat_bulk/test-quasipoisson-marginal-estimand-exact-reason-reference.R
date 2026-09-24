library(testthat)
library(EDI)

# InferenceCountQuasiPoisson's compute_marginal_estimand_estimate() delegates to the shared
# poisson_family_marginal_estimand_estimate() with reason_prefix = "quasipoisson". test-poisson-family-
# marginal-estimand-shared-helper.R already tests all four failure branches of the shared function
# generically (via a fake private environment), and separately tests reason_prefix = "quasipoisson"
# for the "fit_unavailable" branch only -- the "point_unavailable"/"vcov_unavailable"/"se_unavailable"
# branches were never exercised with the real "quasipoisson" prefix through this class's own real
# private$compute_marginal_estimand_estimate() wrapper (confirmed via a zero-hit grep for all three
# literal production strings). Reached by directly injecting a hand-built private$cached_mod (bypassing
# needing a genuinely degenerate GLM fit), the same technique already used elsewhere in this suite.
# The "vcov_unavailable" branch additionally requires bypassing this class's own refit-for-variance
# guard (compute_marginal_estimand_estimate() re-runs shared(estimate_only = FALSE) whenever the cached
# fit lacks vcov, which would otherwise silently replace the injected mod with a real, vcov-bearing
# one) -- done by stubbing private$shared() as a no-op so the injected mod survives untouched.

qp_fixture <- function(n = 40L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, lambda = exp(0.3 + 0.4 * w)))
	list(inf = InferenceCountQuasiPoisson$new(des, verbose = FALSE), w = w)
}

test_that("a non-finite functional caches 'quasipoisson_marginal_point_unavailable'", {
	f <- qp_fixture()
	priv <- f$inf$.__enclos_env__$private
	priv$cached_mod <- list(b = c(Inf, 0), X = cbind(1, f$w))
	p <- priv$compute_marginal_estimand_estimate("marginal_ratio", estimate_only = TRUE)
	expect_true(is.na(p))
	expect_identical(f$inf$get_nonestimable_reason(), "quasipoisson_marginal_point_unavailable")
})

test_that("a cached mod with no vcov (refit stubbed out) caches 'quasipoisson_marginal_vcov_unavailable' but keeps the point", {
	f <- qp_fixture(seed = 2L)
	priv <- f$inf$.__enclos_env__$private
	priv$cached_mod <- list(b = c(0.2, 0.3), X = cbind(1, f$w))
	unlockBinding("shared", priv)
	priv$shared <- function(estimate_only = FALSE) invisible(NULL)
	p <- priv$compute_marginal_estimand_estimate("marginal_mean_diff", estimate_only = FALSE)
	expect_true(is.finite(p))
	expect_identical(f$inf$get_nonestimable_reason(), "quasipoisson_marginal_vcov_unavailable")
})

test_that("a non-positive-definite vcov caches 'quasipoisson_marginal_se_unavailable' but keeps the point", {
	f <- qp_fixture(seed = 3L)
	priv <- f$inf$.__enclos_env__$private
	priv$cached_mod <- list(b = c(0.2, 0.3), X = cbind(1, f$w), vcov = diag(-1, 2))
	p <- priv$compute_marginal_estimand_estimate("marginal_mean_diff", estimate_only = FALSE)
	expect_true(is.finite(p))
	expect_identical(f$inf$get_nonestimable_reason(), "quasipoisson_marginal_se_unavailable")
})
