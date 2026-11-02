library(testthat)
library(EDI)

# TODO-181 (c) (v1.0.5; owner decision 2026-10-31, consistent with the TODO-176 ruling):
# InferenceIncidBinomialIdentityRiskDiff, incidence calibration rep 23, `~.`: the constrained null
# MLE at the score-CI upper endpoint (delta = 0.2198793) has one subject with fitted probability on
# the boundary (mu ~ 1e-6, KKT-verified). The score is undefined there. Before, the score p-value
# was NA only by accident (the finite-difference score crossed the kernel's 1e-8 barrier: Inf /
# NaN) with the generic "no error message was recorded" reason; a boundary point a little further
# inside the margin would have produced a finite but meaningless score. Now the class returns NA
# deliberately, records a boundary reason for the score and gradient tests (quoted by the
# edi_lik_test_unavailable_warning), keeps the Wald state, and leaves the LR test untouched.
# edi_warn_binomial_mle_boundary_once() (TODO-128) is about the full-data MLE only and is not
# triggered here (the full fit is interior).

todo181_incidence_calibration_rep <- function(r) {
	# Seed formula of cal_run_rep() in R/package_tests/calibration/calibration_fast_tier_common.R
	# (cal_rt_index("incidence") = 2, n = 200, null effect, DesignFixedBernoulli).
	set.seed(1e6 * 2L + 7L * 200L + r)
	X <- data.frame(x1 = stats::rnorm(200), x2 = stats::rbinom(200, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = 200, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = stats::rbinom(200, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2)))
	des
}

delta_boundary <- 0.2198793

test_that("rep 23 `~.`: the null MLE at the boundary delta is a converged, KKT-verified boundary fit", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	f <- spec$fit_null(delta_boundary)
	expect_true(isTRUE(f$converged))
	expect_gte(f$n_active_bounds, 1L)
	expect_true(all(is.na(spec$score(f))))
	reasons <- o$.__enclos_env__$private$cached_values$likelihood_test_failure_reason
	expect_match(reasons[["score"]], "boundary of the parameter space")
	expect_match(reasons[["gradient"]], "boundary of the parameter space")
})

test_that("rep 23 `~.`: score p is NA with the boundary reason in the warning; LR and Wald stay finite", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	expect_no_warning(o$compute_estimate(), class = "edi_binomial_mle_boundary_warning")
	w <- NULL
	p <- withCallingHandlers(
		o$compute_score_two_sided_pval(delta_boundary),
		edi_lik_test_unavailable_warning = function(cond) { w <<- cond; invokeRestart("muffleWarning") }
	)
	expect_true(is.na(p))
	expect_false(is.null(w))
	expect_identical(w$testing_type, "score")
	expect_match(w$reason, "null-restricted MLE is on the boundary")
	expect_true(is.na(suppressWarnings(o$compute_gradient_two_sided_pval(delta_boundary))))
	expect_true(is.finite(o$compute_lik_ratio_two_sided_pval(delta_boundary)))
	expect_true(is.finite(o$compute_asymp_two_sided_pval(delta_boundary)))
	expect_false(o$is_nonestimable())
	# the boundary NA is local to that delta: an interior null still gives a score p-value
	expect_equal(o$compute_score_two_sided_pval(0), 0.1538565, tolerance = 1e-4)
})

test_that("rep 23 `~.`: the score CI still inverts (upper endpoint at the boundary delta)", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	ci <- suppressWarnings(o$compute_score_confidence_interval())
	expect_true(all(is.finite(ci)))
	expect_equal(unname(ci), c(-0.03460483, 0.21987934), tolerance = 1e-5)
})
