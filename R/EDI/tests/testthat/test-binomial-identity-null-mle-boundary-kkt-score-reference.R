library(testthat)
library(EDI)

# TODO-181 (c), revised 2026-11-08 (owner): InferenceIncidBinomialIdentityRiskDiff, incidence
# calibration rep 23, `~.`. The constrained null MLE at delta = 0.2198793 has one subject with
# fitted probability on the boundary (KKT-verified). The original 181(c) ruling made the score and
# gradient tests NA there, and the score CI's upper endpoint was pinned at that delta, which is not
# a root. The class now uses the Kuhn-Tucker terms shared with InferenceIncidLogBinomial
# (edi_binomial_bound_kkt_core()): the Lagrangian score and the information restricted to the
# binding face, i.e. the profile score test l_p'(delta)^2 / (-l_p''(delta)). It is NA with a
# recorded reason only where those terms are undefined, e.g. a y = 0 subject at fitted probability 1.

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

test_that("rep 23 `~.`: at the boundary null MLE the score is the profile score (finite, KKT)", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	f <- spec$fit_null(delta_boundary)
	expect_true(isTRUE(f$converged))
	expect_gte(f$n_active_bounds, 1L)
	s <- spec$score(f)
	info <- spec$information(f)
	expect_true(all(is.finite(s)))
	expect_true(all(is.finite(info)))
	j <- spec$j
	expect_equal(s[-j], rep(0, length(s) - 1L))  # nuisance part of the Lagrangian score
	# tested part = the profile log-likelihood's derivative and curvature (central differences)
	P <- function(d) spec$neg_loglik(spec$fit_null(d))
	h <- 1e-2
	lp1 <- -(P(delta_boundary + h) - P(delta_boundary - h)) / (2 * h)
	lp2 <- (P(delta_boundary + h) - 2 * P(delta_boundary) + P(delta_boundary - h)) / h^2
	expect_equal(abs(s[j]), abs(lp1), tolerance = 1e-3)
	expect_equal(info[j, j], lp2, tolerance = 1e-3)
	expect_null(o$.__enclos_env__$private$cached_values$likelihood_test_failure_reason[["score"]])
})

test_that("rep 23 `~.`: score, gradient and LR p-values at the boundary delta are finite and close", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	expect_no_warning(o$compute_estimate(), class = "edi_binomial_mle_boundary_warning")
	p_score <- o$compute_score_two_sided_pval(delta_boundary)
	p_grad <- o$compute_gradient_two_sided_pval(delta_boundary)
	p_lr <- o$compute_lik_ratio_two_sided_pval(delta_boundary)
	expect_equal(p_score, 0.04501851, tolerance = 1e-4)
	expect_equal(p_grad, 0.04583947, tolerance = 1e-4)
	expect_equal(p_lr, 0.04547538, tolerance = 1e-4)
	expect_true(is.finite(o$compute_asymp_two_sided_pval(delta_boundary)))
	expect_false(o$is_nonestimable())
	expect_equal(o$compute_score_two_sided_pval(0), 0.1538565, tolerance = 1e-4)
})

test_that("rep 23 `~.`: the score CI's upper endpoint is now a root (was pinned at 0.2198793)", {
	des <- todo181_incidence_calibration_rep(23L)
	o <- InferenceIncidBinomialIdentityRiskDiff$new(des)
	ci <- o$compute_score_confidence_interval()
	expect_equal(unname(ci), c(-0.03485922, 0.21697865), tolerance = 1e-5)
	for (d in ci) {
		expect_equal(InferenceIncidBinomialIdentityRiskDiff$new(des)$compute_score_two_sided_pval(d), 0.05, tolerance = 1e-3)
	}
})

test_that("Kuhn-Tucker terms are undefined (reason recorded) when a y = 0 subject has fitted probability 1", {
	o <- InferenceIncidBinomialIdentityRiskDiff$new(todo181_incidence_calibration_rep(23L))
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	b <- as.numeric(spec$fit_null(delta_boundary)$b)
	i0 <- which(spec$y < 0.5)[1L]
	b[1L] <- b[1L] + (1 - 1e-8 - sum(spec$X[i0, ] * b))
	kk <- EDI:::edi_binomial_identity_kkt_terms(spec$X, spec$y, b, spec$j)
	expect_match(kk$reason, "a subject with y = 0 has fitted probability 1")
	expect_true(all(is.na(spec$score(list(b = b)))))
	reasons <- o$.__enclos_env__$private$cached_values$likelihood_test_failure_reason
	expect_match(reasons[["score"]], "boundary of the parameter space")
	expect_match(reasons[["gradient"]], "boundary of the parameter space")
})
