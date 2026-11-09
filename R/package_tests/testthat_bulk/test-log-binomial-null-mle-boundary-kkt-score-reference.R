library(testthat)
library(EDI)

# TODO-181 LogBinomial leftover (v1.0.5): score / gradient tests of InferenceIncidLogBinomial at a
# null-restricted MLE on the exp(X b) <= 1 boundary (incidence calibration seeds, n = 200, `~.`).
# Only y = 1 rows reach mu = 1 and their log-likelihood term y * eta is linear, so the analytic
# score / observed information are finite there; the finite-difference ones (h = 1e-6 / 1e-4)
# stepped past the kernel's -1e-8 barrier (-Inf / NaN): score p NA with "no error message was
# recorded", and Wald-fallback score / LR CIs. At the boundary the nuisance score is the
# Kuhn-Tucker multiplier, not zero, so the tested component of the raw score is not the profile
# derivative once a treated row binds. The class now uses the Lagrangian score
# (s - X_A' lambda) and the information restricted to the binding face, i.e. the profile score
# test l_p'(delta)^2 / (-l_p''(delta)).

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

new_logbin <- function(r) InferenceIncidLogBinomial$new(todo181_incidence_calibration_rep(r), model_formula = ~ .)

quiet <- function(expr) suppressWarnings(expr, classes = "edi_binomial_mle_boundary_warning")

test_that("rep 4 `~.`: the null MLE at delta = 0 is a KKT boundary fit and the score test is finite", {
	o <- new_logbin(4L)
	quiet(o$compute_estimate())
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	f <- spec$fit_null(0)
	expect_true(isTRUE(f$converged))
	eta <- as.numeric(spec$X %*% f$b)
	expect_gt(max(eta), -1e-4)  # within the finite-difference stencil's reach of the bound
	expect_true(all(is.finite(spec$score(f))))
	expect_true(all(is.finite(spec$information(f))))
	# was NA (finite-difference score / Hessian crossed the barrier)
	expect_no_warning(p <- quiet(o$compute_score_two_sided_pval(0)), class = "edi_lik_test_unavailable_warning")
	expect_equal(p, 0.83246, tolerance = 1e-4)  # 0.83250 after a CI call (warm-start history, < 5e-5)
	expect_equal(o$compute_lik_ratio_two_sided_pval(0), 0.8243701533, tolerance = 1e-7)  # unchanged
	expect_equal(o$compute_gradient_two_sided_pval(0), 0.8201867737, tolerance = 1e-7)   # unchanged
	expect_false(o$is_nonestimable())
})

test_that("rep 11 `~.`, delta = 0.4 (a treated row binds): the score is the profile-likelihood derivative", {
	o <- new_logbin(11L)
	quiet(o$compute_estimate())
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	j <- spec$j
	g <- spec$score(spec$fit_null(0.4))
	expect_equal(g[-j], rep(0, length(g) - 1L))  # Lagrangian score: no nuisance part
	lp <- function(d) -spec$neg_loglik(spec$fit_null(d))
	h <- 1e-3
	slope <- (lp(0.4 + h) - lp(0.4 - h)) / (2 * h)
	expect_equal(g[[j]], slope, tolerance = 1e-3)  # raw tested score component is -7.12 here
	expect_equal(quiet(o$compute_score_two_sided_pval(0.4)), 0.04717879779, tolerance = 1e-6)
})

test_that("reps 2 / 4 `~.`: score, gradient and LR CIs invert at genuine roots (no Wald fallback)", {
	cases <- list(
		list(r = 2L, method = "score",     ci = c(-0.3807636809, 0.2363537329)),
		list(r = 4L, method = "score",     ci = c(-0.2208010688, 0.2147510522)),
		list(r = 4L, method = "gradient",  ci = c(-0.2751986564, 0.2597012612)),  # upper was 6.997 (p 2e-67)
		list(r = 4L, method = "lik_ratio", ci = c(-0.2519986180, 0.2349526915))   # was the Wald fallback
	)
	for (cs in cases) {
		o <- new_logbin(cs$r)
		ci <- expect_no_warning(quiet(switch(cs$method,
			score = o$compute_score_confidence_interval(),
			gradient = o$compute_gradient_confidence_interval(),
			lik_ratio = o$compute_lik_ratio_confidence_interval())), class = "edi_lik_ci_wald_fallback")
		expect_equal(unname(ci), cs$ci, tolerance = 1e-5)
		o2 <- new_logbin(cs$r)
		pfun <- switch(cs$method,
			score = o2$compute_score_two_sided_pval,
			gradient = o2$compute_gradient_two_sided_pval,
			lik_ratio = o2$compute_lik_ratio_two_sided_pval)
		for (d in ci) expect_equal(quiet(pfun(d)), 0.05, tolerance = 1e-3)
	}
})

test_that("a y = 0 subject at mu = 1 is genuinely undefined: NA with a recorded reason", {
	X <- cbind(1, c(0, 0, 1, 1))
	kkt <- EDI:::edi_log_binomial_kkt_terms(X, y = c(0, 1, 1, 0), b = c(0, -0.5), j = 2L)
	expect_match(kkt$reason, "y = 0 is on it")
	# an interior fit far from the bound is left to the finite-difference path
	expect_null(EDI:::edi_log_binomial_kkt_terms(X, y = c(0, 1, 1, 0), b = c(-1, -0.5), j = 2L))
})

test_that("interior control (rep 1 `~.`, no row near the bound): values unchanged", {
	o <- new_logbin(1L)
	# 1e-7, not 1e-9: Linux CI's BLAS/compiler moves these by ~2e-9 (bulk run
	# 42638595069); a real change to the interior path moves them far more.
	expect_equal(o$compute_estimate(), -0.004658453139, tolerance = 1e-7)
	expect_equal(o$compute_score_two_sided_pval(0), 0.975450830601, tolerance = 1e-7)
	expect_equal(o$compute_gradient_two_sided_pval(0), 0.975452687456, tolerance = 1e-7)
	expect_equal(unname(o$compute_score_confidence_interval()), c(-0.2957914445, 0.2845605486), tolerance = 1e-7)
})
