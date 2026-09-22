library(testthat)
library(EDI)

# InferenceSurvivalWeibullRegr under left-/interval-censored data (has_general_censoring = TRUE): four operations
# that assume ordinary right-censoring internals explicitly refuse to run rather than silently misbehaving --
# compute_estimate_with_bootstrap_weights() (weighted_weibull_bootstrap_surrogate_fit() assumes right-censoring),
# compute_bayesian_bootstrap_two_sided_pval() (same reason), compute_lik_ratio_bartlett_approx_two_sided_pval()
# (its parametric-bootstrap null simulator only knows how to re-censor against a single right-censoring
# threshold), and compute_rand_two_sided_pval() with a nonzero null shift (randomization under interval censoring
# with delta != 0 is not yet supported). None of these four guards -- all reached only past a constant-weights
# short-circuit or other setup -- had a test calling them; existing general-censoring coverage for this class
# only exercises the ordinary estimate/asymp CI dispatch.

ic_fx <- function(seed = 3L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	yL <- runif(n, 0, 3); yR <- yL + runif(n, 0.5, 3)
	des$add_all_subject_responses(ys = rep(NA_real_, n), y_Ls = yL, y_Rs = yR)
	des
}

rc_fx <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	des
}

test_that("general censoring rejects compute_estimate_with_bootstrap_weights() for genuinely non-constant weights (a constant-weights call short-circuits to the ordinary estimate first)", {
	des <- ic_fx()
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_true(p$has_general_censoring)
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	set.seed(9); wt <- runif(des$get_n(), 0.5, 2)
	expect_error(
		inf$compute_estimate_with_bootstrap_weights(wt),
		"Bayesian-bootstrap weighted re-estimation is not yet supported for left-/interval-censored"
	)
	inf2 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	p2 <- inf2$.__enclos_env__$private
	p2$current_bayesian_bootstrap_context <- p2$build_bayesian_bootstrap_context()
	est <- inf2$compute_estimate_with_bootstrap_weights(rep(1, des$get_n()))              # constant: no error
	expect_true(is.finite(est))
})

test_that("general censoring rejects compute_bayesian_bootstrap_two_sided_pval()", {
	des <- ic_fx()
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_error(
		inf$compute_bayesian_bootstrap_two_sided_pval(delta = 0, B = 10, show_progress = FALSE),
		"Bayesian bootstrap is not yet supported for left-/interval-censored survival data"
	)
})

test_that("general censoring rejects compute_lik_ratio_bartlett_approx_two_sided_pval()", {
	des <- ic_fx()
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_error(
		inf$compute_lik_ratio_bartlett_approx_two_sided_pval(delta = 0, B = 10),
		"Parametric-bootstrap likelihood-ratio calibration \\(Bartlett correction\\) is not yet supported for left-/interval-censored"
	)
})

test_that("general censoring rejects compute_rand_two_sided_pval() only for a nonzero delta; delta = 0 still runs", {
	des <- ic_fx()
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_error(
		inf$compute_rand_two_sided_pval(delta = 0.3, r = 15, show_progress = FALSE),
		"Randomization tests with a nonzero null shift \\(delta != 0\\) are not yet supported for left-/interval-censored"
	)
	inf2 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	pv0 <- inf2$compute_rand_two_sided_pval(delta = 0, r = 15, show_progress = FALSE)
	expect_true(is.finite(pv0))
})

test_that("none of the four guards fire on an ordinary right-censored design", {
	des <- rc_fx()
	inf1 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_false(inf1$.__enclos_env__$private$has_general_censoring)

	p1 <- inf1$.__enclos_env__$private
	p1$current_bayesian_bootstrap_context <- p1$build_bayesian_bootstrap_context()
	set.seed(2); wt <- runif(des$get_n(), 0.5, 2)
	expect_true(is.finite(inf1$compute_estimate_with_bootstrap_weights(wt)))

	inf2 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_true(is.finite(inf2$compute_bayesian_bootstrap_two_sided_pval(delta = 0, B = 15, show_progress = FALSE)))

	inf3 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_true(is.finite(inf3$compute_lik_ratio_bartlett_approx_two_sided_pval(delta = 0, B = 15)))

	inf4 <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	expect_true(is.finite(inf4$compute_rand_two_sided_pval(delta = 0.3, r = 15, show_progress = FALSE)))
})
