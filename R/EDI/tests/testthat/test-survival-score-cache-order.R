library(testthat)
library(EDI)

interval_score_cache_design <- function() {
	set.seed(3L)
	n <- 40L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	y_L <- runif(n, 0, 3)
	y_R <- y_L + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = y_L, y_Rs = y_R)
	des
}

check_score_cache_order <- function(des) {
	for (class in list(InferenceSurvivalLogRank, InferenceSurvivalGehanWilcox)) {
		ordered <- class$new(des, verbose = FALSE)
		fresh <- class$new(des, verbose = FALSE)
		private <- ordered$.__enclos_env__$private
		est <- suppressWarnings(ordered$compute_estimate(estimate_only = TRUE))
		expect_null(private$cached_values$s_beta_hat_T)
		ci <- suppressWarnings(ordered$compute_asymp_confidence_interval(0.05))
		fresh_ci <- suppressWarnings(fresh$compute_asymp_confidence_interval(0.05))
		expect_true(is.finite(private$cached_values$s_beta_hat_T) && private$cached_values$s_beta_hat_T > 0)
		expect_equal(est, suppressWarnings(fresh$compute_estimate()), tolerance = 1e-8)
		expect_equal(as.numeric(ci), as.numeric(fresh_ci), tolerance = 1e-8)
		expect_equal(suppressWarnings(ordered$compute_estimate()), est, tolerance = 1e-8)
		expect_equal(as.numeric(suppressWarnings(ordered$compute_asymp_confidence_interval(0.05))),
		             as.numeric(ci), tolerance = 1e-8)
	}
}

test_that("survival score estimates fill their SE after an estimate-only interval-censored call", {
	skip_if_not_installed("interval")
	check_score_cache_order(interval_score_cache_design())
})
