library(testthat)
library(EDI)

# v1.1.0-TODO-174: set_likelihood_test_variance("robust") on InferenceCountHurdlePoisson and
# InferenceCountZeroInflatedPoisson recalibrates the score, likelihood-ratio and gradient
# tests (and the intervals that invert them) by the sandwich variance of the tested
# coefficient at the null-restricted fit (Kent 1982; Boos 1992). With covariates omitted
# (`~ 1`) the model-based tests reject a true null about 17% of the time at 5%; the robust
# ones hold 5% (see the TODO for the simulation). Checks: the default and the supported
# classes; the hurdle robust statistics against an independent base-R computation (the
# zero-truncated Poisson count part has closed-form fits under `~ 1`); the intervals invert
# the robust tests; switching back restores the model-based answers; Wald and the
# configured-type dispatch.

rlt_design = local({
	cache = NULL
	function() {
		if (!is.null(cache)) return(cache)
		set.seed(17410)
		n = 160L
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		# Omitted prognostic covariates make the count part overdispersed under `~ 1`.
		y = rpois(n, exp(0.4 + 0.7 * X$x1 + 0.5 * X$x2))
		d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects()
		d$add_all_subject_responses(y)
		cache <<- d
		d
	}
})

# robust = TRUE / FALSE sets the variance explicitly; NULL keeps the class default.
rlt_new = function(cn, formula = ~ 1, robust = FALSE) {
	inf = suppressWarnings(get(cn, envir = asNamespace("EDI"))$new(rlt_design(), model_formula = formula, verbose = FALSE))
	if (isTRUE(robust)) inf$set_likelihood_test_variance("robust")
	if (isFALSE(robust)) inf$set_likelihood_test_variance("model")
	inf
}

test_that("HurdlePoisson defaults to robust, ZIP to model-based, and only those two accept robust", {
	# Owner decision 2026-11-26 (DECISION-v1.1.0-TODO-174): robust is HurdlePoisson's default;
	# ZIP's default is decided separately and stays model-based for now.
	defaults = c(InferenceCountHurdlePoisson = "robust", InferenceCountZeroInflatedPoisson = "model")
	for (cn in names(defaults)) {
		inf = rlt_new(cn, robust = NULL)
		expect_identical(inf$get_likelihood_test_variance(), defaults[[cn]], info = cn)
		expect_identical(inf$set_likelihood_test_variance("model")$get_likelihood_test_variance(), "model", info = cn)
		expect_identical(inf$set_likelihood_test_variance("robust")$get_likelihood_test_variance(), "robust", info = cn)
	}
	# The default p-value is the robust one for HurdlePoisson.
	expect_identical(rlt_new("InferenceCountHurdlePoisson", robust = NULL)$compute_score_two_sided_pval(0),
		rlt_new("InferenceCountHurdlePoisson", robust = TRUE)$compute_score_two_sided_pval(0))
	for (cn in c("InferenceCountZeroInflatedNegBin", "InferenceCountHurdleNegBin", "InferenceCountPoisson")) {
		inf = suppressWarnings(get(cn, envir = asNamespace("EDI"))$new(rlt_design(), verbose = FALSE))
		expect_identical(inf$get_likelihood_test_variance(), "model", info = cn)
		expect_error(inf$set_likelihood_test_variance("robust"), "does not support likelihood_test_variance", info = cn)
		expect_silent(inf$set_likelihood_test_variance("model"))
	}
	expect_error(rlt_new("InferenceCountHurdlePoisson")$set_likelihood_test_variance("sandwich"))
})

# Independent reference for the hurdle `~ 1` count part: a zero-truncated Poisson with an
# intercept and the treatment, fitted on the positive counts. Its MLE matches each arm's
# truncated mean m(lambda) = lambda / (1 - exp(-lambda)) to the arm's mean positive count;
# under the null (treatment coefficient 0) one lambda matches the pooled mean.
rlt_hurdle_reference = function(y, w, delta = 0) {
	pos = y > 0
	yp = y[pos]
	wp = w[pos]
	m_of = function(l) l / (1 - exp(-l))
	lambda_for_mean = function(m) stats::uniroot(function(l) m_of(l) - m, c(1e-8, 1e3), tol = 1e-14)$root
	loglik = function(lambda) sum(yp * log(lambda) - lambda - log1p(-exp(-lambda)))
	lam0 = lambda_for_mean(mean(yp))
	lam_c = lambda_for_mean(mean(yp[wp == 0]))
	lam_t = lambda_for_mean(mean(yp[wp == 1]))
	full_ll = sum(ifelse(wp == 1,
		yp * log(lam_t) - lam_t - log1p(-exp(-lam_t)),
		yp * log(lam_c) - lam_c - log1p(-exp(-lam_c))))
	null_ll = loglik(lam0)
	Xp = cbind(1, wp)
	m0 = m_of(lam0)
	v0 = m0 * (1 + lam0 - m0)
	A = crossprod(Xp) * v0
	S = Xp * (yp - m0)
	U = colSums(S)
	a = solve(A)[2, ]
	k = length(yp)
	V = k / (k - 2) * sum((S %*% a)^2)
	ratio = solve(A)[2, 2] / V
	est = log(lam_t) - log(lam_c)
	list(
		score = stats::pchisq(sum(a * U)^2 / V, 1, lower.tail = FALSE),
		lik_ratio = stats::pchisq(2 * (full_ll - null_ll) * ratio, 1, lower.tail = FALSE),
		gradient = stats::pchisq(max(U[2] * (est - delta), 0) * ratio, 1, lower.tail = FALSE),
		estimate = est
	)
}

test_that("hurdle robust score, LR and gradient p-values match an independent base-R computation", {
	des = rlt_design()
	ref = rlt_hurdle_reference(des$get_y(), des$get_w())
	inf = rlt_new("InferenceCountHurdlePoisson", robust = TRUE)
	expect_equal(inf$compute_estimate(), ref$estimate, tolerance = 1e-6)
	expect_equal(inf$compute_score_two_sided_pval(0), ref$score, tolerance = 1e-5)
	expect_equal(inf$compute_lik_ratio_two_sided_pval(0), ref$lik_ratio, tolerance = 1e-5)
	expect_equal(inf$compute_gradient_two_sided_pval(0), ref$gradient, tolerance = 1e-5)
	# The omitted covariates overdisperse the count part, so the robust p-values are larger.
	model = rlt_new("InferenceCountHurdlePoisson")
	for (tt in c("score", "lik_ratio", "gradient")) {
		f = paste0("compute_", tt, "_two_sided_pval")
		expect_gt(inf[[f]](0), model[[f]](0))
	}
})

test_that("robust intervals invert the robust tests and switching back restores the model-based answers", {
	for (cn in c("InferenceCountHurdlePoisson", "InferenceCountZeroInflatedPoisson")) {
		inf = rlt_new(cn)
		model_p = c(score = inf$compute_score_two_sided_pval(0), lik_ratio = inf$compute_lik_ratio_two_sided_pval(0))
		model_ci = inf$compute_lik_ratio_confidence_interval(0.05)
		wald_p = inf$compute_asymp_two_sided_pval(0)
		inf$set_likelihood_test_variance("robust")
		expect_equal(inf$compute_asymp_two_sided_pval(0), wald_p, info = cn)
		for (tt in c("score", "lik_ratio", "gradient")) {
			label = paste(cn, tt)
			ci = inf[[paste0("compute_", tt, "_confidence_interval")]](0.05)
			expect_true(all(is.finite(ci)) && ci[1] < ci[2], info = label)
			pv = inf[[paste0("compute_", tt, "_two_sided_pval")]]
			expect_equal(pv(ci[1]), 0.05, tolerance = 1e-3, info = label)
			expect_equal(pv(ci[2]), 0.05, tolerance = 1e-3, info = label)
		}
		robust_ci = inf$compute_lik_ratio_confidence_interval(0.05)
		expect_gt(diff(robust_ci), diff(model_ci))
		inf$set_testing_type("lik_ratio")
		expect_equal(inf$compute_asymp_two_sided_pval(0), inf$compute_lik_ratio_two_sided_pval(0), info = cn)
		expect_equal(as.numeric(inf$compute_asymp_confidence_interval(0.05)), as.numeric(robust_ci), info = cn)
		inf$set_likelihood_test_variance("model")
		expect_equal(inf$compute_score_two_sided_pval(0), model_p[["score"]], info = cn)
		expect_equal(inf$compute_lik_ratio_two_sided_pval(0), model_p[["lik_ratio"]], info = cn)
		expect_equal(as.numeric(inf$compute_lik_ratio_confidence_interval(0.05)), as.numeric(model_ci), tolerance = 1e-6, info = cn)
	}
})

test_that("with the covariates in the model the robust and model-based tests are close", {
	# Correctly specified count part: the sandwich and model variances agree up to noise
	# and the small-sample factor, so the p-values are of the same size.
	inf = rlt_new("InferenceCountHurdlePoisson", formula = ~ x1 + x2)
	model = rlt_new("InferenceCountHurdlePoisson", formula = ~ x1 + x2, robust = FALSE)
	inf$set_likelihood_test_variance("robust")
	for (tt in c("score", "lik_ratio", "gradient")) {
		f = paste0("compute_", tt, "_two_sided_pval")
		zr = stats::qnorm(inf[[f]](0) / 2)
		zm = stats::qnorm(model[[f]](0) / 2)
		expect_lt(abs(zr / zm - 1), 0.25, label = tt)
	}
})
