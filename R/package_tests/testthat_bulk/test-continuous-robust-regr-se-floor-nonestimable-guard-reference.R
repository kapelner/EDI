library(testthat)
library(EDI)

# InferenceContinRobustRegr$shared() (inference_continuous_robust_regr.R) floors the fitted treatment
# SE against sqrt(.Machine$double.eps) * sd(y) (or * 1 when y has zero/non-finite sd): a perfect or
# near-perfect (noise-free) linear fit collapses the robust-regression SE toward machine epsilon,
# which would otherwise report a spuriously zero-width CI with a finite p-value, so the estimate is
# instead marked nonestimable ("model_standard_error_unavailable") while still keeping the point
# estimate itself. This SE-floor guard -- present for both the use_rcpp = TRUE (fast_robust_
# regression_cpp) and use_rcpp = FALSE (MASS::rlm) backends -- had no test reference anywhere; every
# located InferenceContinRobustRegr reference test uses a genuinely noisy response.

robust_fixture <- function(seed = 1L, n = 40L, noise_sd = 0) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 3 + 2 * w + 0.5 * X$x1 + if (noise_sd > 0) rnorm(n, sd = noise_sd) else 0
	des$add_all_subject_responses(y)
	des
}

test_that("a noise-free (exact linear) response collapses the SE below the floor and is marked nonestimable, for both backends", {
	des <- robust_fixture()
	for (use_rcpp in c(TRUE, FALSE)) {
		inf <- InferenceContinRobustRegr$new(des, use_rcpp = use_rcpp, verbose = FALSE)
		est <- inf$compute_estimate()
		expect_equal(est, 2, tolerance = 1e-6, info = use_rcpp)  # the point estimate is still reported
		expect_identical(inf$get_nonestimable_reason(), "model_standard_error_unavailable", info = use_rcpp)
		expect_true(is.na(inf$.__enclos_env__$private$cached_values$s_beta_hat_T), info = use_rcpp)
	}
})

test_that("a genuinely noisy response stays estimable (the guard is not simply always-on)", {
	des <- robust_fixture(seed = 2L, noise_sd = 1)
	inf <- InferenceContinRobustRegr$new(des, use_rcpp = TRUE, verbose = FALSE)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
	expect_null(inf$get_nonestimable_reason())
	expect_true(is.finite(inf$.__enclos_env__$private$cached_values$s_beta_hat_T) &&
		inf$.__enclos_env__$private$cached_values$s_beta_hat_T > 0)
})
