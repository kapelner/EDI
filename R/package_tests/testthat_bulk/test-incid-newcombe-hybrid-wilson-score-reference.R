library(testthat)
library(EDI)

# InferenceIncidNewcombeRiskDiff had zero prior test references anywhere
# (verified via repo-wide grep). This validates its Newcombe "Method 10"
# hybrid Wilson-score CI and its numerically-inverted p-value against an
# independent from-scratch R implementation of the same closed-form formula
# documented in inference_incid_newcombe_univ.R's class docstring, plus the
# weighted-bootstrap point-estimate path.

wilson_ci_ref = function(x, n, alpha) {
	# The upper-tail form remains finite when alpha is too small for
	# 1 - alpha / 2 to differ from one in double precision.
	z = qnorm(alpha / 2, lower.tail = FALSE)
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
	alpha_floor = 1e-300
	alpha_ceiling = 1 - .Machine$double.eps
	at_floor = p_fn(alpha_floor)
	at_ceiling = p_fn(alpha_ceiling)
	is_lower_boundary = delta < beta_hat_T
	outside_at_floor = if (is_lower_boundary) at_floor >= 0 else at_floor <= 0
	inside_at_ceiling = if (is_lower_boundary) at_ceiling <= 0 else at_ceiling >= 0
	if (outside_at_floor) return(alpha_floor)
	if (inside_at_ceiling) return(1.0)
	exp(stats::uniroot(
		function(log_alpha) p_fn(exp(log_alpha)),
		interval = log(c(alpha_floor, alpha_ceiling)), tol = 1e-12
	)$root)
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

	# The point estimate remains inside every non-degenerate CI, so its p-value
	# is one. A null outside even the alpha floor instead has a p-value at that
	# floor, rather than being misclassified as one by a failed bracket.
	far_delta = beta_hat_T + 0.9
	expect_equal(
		inf$compute_asymp_two_sided_pval(delta = far_delta),
		newcombe_pval_ref(x_t, n_t, x_c, n_c, far_delta, beta_hat_T),
		tolerance = 1e-12
	)
})

make_newcombe_fixed_counts_fixture = function(x_t, n_t, x_c, n_c) {
	n = n_t + n_c
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n)))
	des$overwrite_all_subject_assignments(c(rep(1L, n_t), rep(0L, n_c)))
	des$add_all_subject_responses(c(rep(c(1, 0), c(x_t, n_t - x_t)), rep(c(1, 0), c(x_c, n_c - x_c))))
	InferenceIncidNewcombeRiskDiff$new(des)
}

test_that("Newcombe p-value resolves strong and small effects on a log-alpha scale", {
	strong = make_newcombe_fixed_counts_fixture(90L, 100L, 10L, 100L)
	strong_p = strong$compute_asymp_two_sided_pval()
	strong_ref = newcombe_pval_ref(90, 100, 10, 100, 0, 0.8)
	expect_equal(strong_p, strong_ref, tolerance = 1e-10)
	expect_lt(strong_p, 1e-10)

	precise = make_newcombe_fixed_counts_fixture(75L, 100L, 40L, 100L)
	precise_p = precise$compute_asymp_two_sided_pval()
	precise_ref = newcombe_pval_ref(75, 100, 40, 100, 0, 0.35)
	expect_equal(precise_p, precise_ref, tolerance = 1e-10)
	expect_lt(precise_p, 1e-5)
})

test_that("Newcombe p-value agrees with prop.test in order of magnitude (independent of newcombe_pval_ref)", {
	# prop.test(correct = FALSE) is a different statistic (pooled-variance score test), so this is a
	# loose log10 band, not equality; it pins the old failure (p collapsing to 1 or to the alpha
	# floor) without reusing the reference function. Observed: Newcombe 3.95e-33 vs prop.test 1.12e-29
	# (strong), 4.35e-7 vs 5.55e-7 (moderate).
	strong = make_newcombe_fixed_counts_fixture(90L, 100L, 10L, 100L)$compute_asymp_two_sided_pval()
	strong_prop = prop.test(c(90, 10), c(100, 100), correct = FALSE)$p.value
	expect_lt(strong, strong_prop)
	expect_gt(strong, 1e-40)

	moderate = make_newcombe_fixed_counts_fixture(75L, 100L, 40L, 100L)$compute_asymp_two_sided_pval()
	moderate_prop = prop.test(c(75, 40), c(100, 100), correct = FALSE)$p.value
	expect_lt(abs(log10(moderate) - log10(moderate_prop)), 0.5)
})

test_that("Newcombe p-value rejects a missing null value", {
	f = make_newcombe_fixture(seed = 20261002)
	inf = InferenceIncidNewcombeRiskDiff$new(f$des)
	expect_error(inf$compute_asymp_two_sided_pval(delta = NA_real_), "Contains missing values")
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
