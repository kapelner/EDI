library(testthat)
library(EDI)

# InferenceSurvivalKMDiff under left-/interval-censored data (has_general_censoring = TRUE): two convenience
# methods explicitly refuse to run rather than silently misusing right-censoring-only machinery --
# compute_estimate_with_bootstrap_weights() (interval::icfit() has no weights argument) and
# compute_asymp_log_rank_two_sided_pval_for_treatment_effect() (survival::survdiff() assumes ordinary
# right-censoring; interval-censored log-rank inference should go through InferenceSurvivalLogRank instead,
# which dispatches through interval::ictest()). Existing general-censoring coverage for this class
# (test-km-rmst-general-censoring.R) only exercises compute_estimate()/compute_asymp_two_sided_pval() under
# general censoring -- neither rejection guard had a test calling it.

ic_fx <- function(seed = 3006L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	des
}

test_that("under general censoring, compute_estimate_with_bootstrap_weights() is rejected with an informative error", {
	des <- ic_fx()
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$has_general_censoring)
	expect_error(
		inf$compute_estimate_with_bootstrap_weights(rep(1, des$get_n())),
		"Bayesian bootstrap is not yet supported for left-/interval-censored survival data"
	)
})

test_that("under general censoring, compute_asymp_log_rank_two_sided_pval_for_treatment_effect() is rejected, naming InferenceSurvivalLogRank as the alternative", {
	des <- ic_fx()
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_error(
		inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0),
		"InferenceSurvivalLogRank"
	)
	expect_error(
		inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0),
		"The log-rank p-value convenience method is not supported for left-/interval-censored"
	)
})

test_that("the nonzero-delta guard is checked before the general-censoring guard: a nonzero delta gives the delta message even under general censoring", {
	des <- ic_fx()
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_error(
		inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0.5),
		"not yet implemented"
	)
})

test_that("on an ordinary right-censored design, neither guard fires: compute_asymp_log_rank_two_sided_pval_for_treatment_effect matches an independent survival::survdiff() reference", {
	set.seed(1); n <- 40L
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceSurvivalKMDiff$new(des, verbose = FALSE)
	expect_false(inf$.__enclos_env__$private$has_general_censoring)
	pv <- inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0)
	ref <- survival::survdiff(survival::Surv(des$get_y(), des$get_effective_dead()) ~ w)
	ref_pv <- 1 - pchisq(ref$chisq, 1)
	expect_equal(pv, ref_pv, tolerance = 1e-8)
	expect_error(inf$compute_asymp_log_rank_two_sided_pval_for_treatment_effect(0.3), "not yet implemented")

	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	wt <- rep(1, n)
	expect_true(is.finite(inf$compute_estimate_with_bootstrap_weights(wt)))                  # not rejected here
})
