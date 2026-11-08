library(testthat)
library(EDI)

# TODO-177 (release_v1_0_5.md, fixed 2026-11-07). InferenceIncidBinomialIdentityRiskDiff, score CI,
# incidence calibration null reps (R/package_tests/calibration/calibration_fast_tier_common.R: n = 200,
# DesignFixedBernoulli, seed 1e6 * 2 + 7 * 200 + rep, y ~ Bernoulli(plogis(-0.5 + 0.5 x1 + 0.5 x2))).
# Two stacked bugs:
#   (A) fit_null passed the full fit's warm Fisher, which the identity-link IRLS uses as X'WX on
#       iteration 0; at the first bisection midpoint it was stale enough that every line-search step was
#       rejected (converged = FALSE), so the refit returned NULL although a fresh fit converges;
#   (B) make_warm_fit_null_wrapper then stored extract_start(NULL) = numeric(0) as the warm start, which
#       `start %||% ...` passed on, so EVERY later refit on the object failed: same-object p = NA at
#       10 of 12 deltas on rep 1 `~ 1`, and the upper CI endpoint was the fallback est + step
#       (p there 0.0476, not a root).
# Fixed by retrying a failed warm-started refit from start = NULL, never storing a failed / empty /
# non-finite start (both warm wrappers), and a no-warm-Fisher / cold fallback inside fit_null.

cal_like_design <- function(rep, n = 200L) {
	set.seed(1e6 * 2 + 7L * n + rep)
	X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(stats::rbinom(n, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2)))
	des
}

score_p <- function(obj, d) suppressWarnings(obj$compute_score_two_sided_pval(delta = d))

test_that("RiskDiff rep 1 ~1: the score CI endpoints are real roots and same-object p equals fresh p after the CI", {
	des <- cal_like_design(1L)
	obj <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~ 1)
	ci <- suppressWarnings(obj$compute_score_confidence_interval(alpha = 0.05))
	expect_true(all(is.finite(ci)))
	# the old code returned 0.138049 (fallback point, p = 0.0476); the true root is ~0.13652
	expect_equal(unname(ci[2]), 0.136518, tolerance = 1e-5)
	est <- obj$compute_estimate()
	# 0.13364 = the first bisection midpoint whose refit failed; 0.1292 was finite before the failure
	deltas <- c(0, ci, 0.13364, 0.1292, seq(est - 0.16, est + 0.16, length.out = 7))
	same <- vapply(deltas, function(d) score_p(obj, d), numeric(1))
	fresh <- vapply(deltas, function(d) score_p(InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~ 1), d), numeric(1))
	expect_true(all(is.finite(fresh)))
	expect_true(all(is.finite(same)))
	expect_equal(same, fresh, tolerance = 1e-6)
	expect_equal(unname(same[2:3]), c(0.05, 0.05), tolerance = 1e-3)
})

test_that("RiskDiff reps 2-4 ~1 and rep 3 ~.: same-object and fresh score p agree after the score CI", {
	for (cfg in list(list(2L, ~ 1), list(3L, ~ 1), list(4L, ~ 1), list(3L, ~ .))) {
		des <- cal_like_design(cfg[[1]])
		obj <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = cfg[[2]])
		ci <- suppressWarnings(obj$compute_score_confidence_interval(alpha = 0.05))
		expect_true(all(is.finite(ci)))
		deltas <- c(0, ci)
		same <- vapply(deltas, function(d) score_p(obj, d), numeric(1))
		fresh <- vapply(deltas, function(d) score_p(InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = cfg[[2]]), d), numeric(1))
		expect_true(all(is.finite(same)))
		expect_equal(same, fresh, tolerance = 1e-6)
		expect_equal(unname(same[2:3]), c(0.05, 0.05), tolerance = 1e-3)
	}
})

test_that("a failed refit never leaves an empty or non-finite warm start in the null warm cache", {
	des <- cal_like_design(1L)
	obj <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~ 1)
	suppressWarnings(obj$compute_score_confidence_interval(alpha = 0.05))
	st <- obj$.__enclos_env__$private$likelihood_null_warm_cache[["likelihood_test:score"]]$start
	expect_true(is.null(st) || (length(st) > 0L && all(is.finite(st))))
})

test_that("edi_fit_null_with_warm_retry: a failed warm-started refit is retried from start = NULL; success on the first try is unchanged", {
	retry <- EDI:::edi_fit_null_with_warm_retry
	priv <- new.env()
	priv$cached_values <- list()
	starts <- list()
	spec <- list(fit_null = function(delta, start = NULL) {
		starts[[length(starts) + 1L]] <<- list(start)
		if (!is.null(start)) return(list(b = start, converged = FALSE))
		list(b = c(1, delta), converged = TRUE)
	})
	fit <- retry(priv, spec, "likelihood_test:score", 0.3, start = c(5, 5), accepts_start = TRUE)
	expect_equal(fit$b, c(1, 0.3))
	expect_length(starts, 2L)
	expect_null(starts[[2]][[1]])
	# empty / non-finite starts are dropped before the call
	starts <- list()
	retry(priv, spec, "likelihood_test:score", 0.3, start = numeric(0), accepts_start = TRUE)
	retry(priv, spec, "likelihood_test:score", 0.3, start = c(NaN, 1), accepts_start = TRUE)
	expect_length(starts, 2L)
	expect_true(all(vapply(starts, function(s) is.null(s[[1]]), logical(1))))
	# a converged warm-started fit is returned as is, with no second call
	starts <- list()
	spec_ok <- list(fit_null = function(delta, start = NULL) { starts[[length(starts) + 1L]] <<- list(start); list(b = start, converged = TRUE) })
	fit <- retry(priv, spec_ok, "likelihood_test:score", 0.3, start = c(2, 0.3), accepts_start = TRUE)
	expect_equal(fit$b, c(2, 0.3))
	expect_length(starts, 1L)
	# an error on the warm attempt is not recorded when the retry succeeds
	spec_err <- list(fit_null = function(delta, start = NULL) { if (!is.null(start)) stop("boom"); list(b = c(0, delta)) })
	priv$cached_values <- list()
	fit <- retry(priv, spec_err, "likelihood_test:score", 0.1, start = c(1, 1), accepts_start = TRUE)
	expect_equal(fit$b, c(0, 0.1))
	expect_null(priv$cached_values$likelihood_test_failure_reason)
	expect_false(EDI:::edi_warm_start_usable(numeric(0)))
	expect_false(EDI:::edi_warm_start_usable(c(1, Inf)))
	expect_true(EDI:::edi_warm_start_usable(c(1, 2)))
	expect_false(EDI:::edi_null_refit_usable(NULL))
	expect_false(EDI:::edi_null_refit_usable(list(converged = FALSE)))
	expect_true(EDI:::edi_null_refit_usable(list(b = 1)))
})
