library(testthat)
library(EDI)

# InferenceIncidNewcombeRiskDiff had zero prior test references anywhere
# (verified via repo-wide grep). This validates its Newcombe "Method 10"
# hybrid Wilson-score CI and its numerically-inverted p-value against an
# independent from-scratch R implementation of the same closed-form formula
# documented in inference_incid_newcombe_univ.R's class docstring, plus the
# weighted-bootstrap point-estimate path.

wilson_ci_ref = function(x, n, alpha) {
	z = qnorm(1 - alpha / 2)
	phat = x / n
	denom = 1 + z^2 / n
	center = phat + z^2 / (2 * n)
	adj = z * sqrt(phat * (1 - phat) / n + z^2 / (4 * n^2))
	c((center - adj) / denom, (center + adj) / denom)
}

newcombe_ci_ref = function(x_t, n_t, x_c, n_c, alpha) {
	p_t = x_t / n_t
	p_c = x_c / n_c
	ci_t = wilson_ci_ref(x_t, n_t, alpha)
	ci_c = wilson_ci_ref(x_c, n_c, alpha)
	diff = p_t - p_c
	lo = diff - sqrt((p_t - ci_t[1])^2 + (ci_c[2] - p_c)^2)
	hi = diff + sqrt((ci_t[2] - p_t)^2 + (p_c - ci_c[1])^2)
	c(lo, hi)
}

newcombe_pval_ref = function(x_t, n_t, x_c, n_c, delta, beta_hat_T) {
	p_fn = function(a) {
		ci = newcombe_ci_ref(x_t, n_t, x_c, n_c, a)
		if (delta < beta_hat_T) ci[1] - delta else ci[2] - delta
	}
	res = tryCatch(stats::uniroot(p_fn, interval = c(1e-10, 1 - 1e-10))$root, error = function(e) NA_real_)
	if (!is.finite(res)) 1.0 else res
}

make_newcombe_fixture = function(n = 90L, seed = 20261001) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	w = integer(n)
	for (i in 1:n) {
		w[i] = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	y = ifelse(w == 1, rbinom(n, 1, 0.65), rbinom(n, 1, 0.35))
	for (i in 1:n) {
		des$add_one_subject_response(i, y[i])
	}
	list(des = des, w = w, y = y)
}

test_that("Newcombe hybrid Wilson-score CI matches an independent from-scratch reference", {
	f = make_newcombe_fixture()
	inf = InferenceIncidNewcombeRiskDiff$new(f$des)

	beta_hat_T = inf$compute_estimate()
	x_t = sum(f$y[f$w == 1]); n_t = sum(f$w == 1)
	x_c = sum(f$y[f$w == 0]); n_c = sum(f$w == 0)
	expect_equal(beta_hat_T, x_t / n_t - x_c / n_c)

	for (alpha in c(0.05, 0.10, 0.20)) {
		ci = inf$compute_asymp_confidence_interval(alpha = alpha)
		ref = newcombe_ci_ref(x_t, n_t, x_c, n_c, alpha)
		expect_equal(unname(ci), ref, tolerance = 1e-8)
	}
})

test_that("Newcombe two-sided p-value matches an independent CI-inversion reference", {
	f = make_newcombe_fixture(seed = 20261002)
	inf = InferenceIncidNewcombeRiskDiff$new(f$des)
	beta_hat_T = inf$compute_estimate()
	x_t = sum(f$y[f$w == 1]); n_t = sum(f$w == 1)
	x_c = sum(f$y[f$w == 0]); n_c = sum(f$w == 0)

	for (delta in c(0, beta_hat_T / 2, -0.05)) {
		pval = inf$compute_asymp_two_sided_pval(delta = delta)
		ref = newcombe_pval_ref(x_t, n_t, x_c, n_c, delta, beta_hat_T)
		expect_equal(pval, ref, tolerance = 1e-6)
	}

	# delta = beta_hat_T should land at (or very near) the boundary p-value of 0
	# for infinitesimally small alpha; the class returns 1.0 when uniroot can't
	# bracket a sign change, which independently verified happens at delta ~ 0.5
	# away from the estimate on this fixture.
	far_delta = beta_hat_T + 0.9
	expect_equal(inf$compute_asymp_two_sided_pval(delta = far_delta), 1.0)
})

install_bb_context = function(inf, n) {
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context = list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
}

test_that("weighted-bootstrap point estimate matches independent weighted proportions and leaves SE/df NA", {
	f = make_newcombe_fixture(seed = 20261003)
	inf = InferenceIncidNewcombeRiskDiff$new(f$des)
	inf$compute_estimate()
	install_bb_context(inf, length(f$w))

	n = length(f$w)
	weights = runif(n, 0.2, 3)
	i_t = f$w == 1; i_c = f$w == 0
	p_t_w = sum(weights[i_t] * f$y[i_t]) / sum(weights[i_t])
	p_c_w = sum(weights[i_c] * f$y[i_c]) / sum(weights[i_c])

	est = inf$compute_estimate_with_bootstrap_weights(weights)
	expect_equal(est, p_t_w - p_c_w, tolerance = 1e-10)
	expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
	expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$df))

	# Unit weights reproduce the unweighted estimate
	inf2 = InferenceIncidNewcombeRiskDiff$new(f$des)
	inf2$compute_estimate()
	install_bb_context(inf2, n)
	unit_est = inf2$compute_estimate_with_bootstrap_weights(rep(1, n))
	expect_equal(unit_est, inf2$compute_estimate(), tolerance = 1e-10)

	# Degenerate: one arm entirely zero-weighted -> NA
	deg_weights = weights
	deg_weights[i_t] = 0
	inf3 = InferenceIncidNewcombeRiskDiff$new(f$des)
	inf3$compute_estimate()
	install_bb_context(inf3, n)
	expect_true(is.na(inf3$compute_estimate_with_bootstrap_weights(deg_weights)))
})
