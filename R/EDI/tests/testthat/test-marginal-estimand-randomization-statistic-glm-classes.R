# v1.0.6-TODO-189: under estimand = "marginal_mean_diff" (or "marginal_ratio") the
# randomization statistic (compute_treatment_estimate_during_randomization_inference)
# of InferencePropBetaRegr, InferenceCountPoisson / QuasiPoisson,
# InferenceCountHurdlePoisson, InferenceCountZeroInflatedPoisson and
# InferenceIncidLogRegr stayed the conditional coefficient, while compute_estimate()
# and the reused bootstrap worker return the g-computed marginal functional. The
# randomization test then compared a conditional observed statistic with marginal
# null draws on the worker path (InferenceIncidLogRegr rand p 0.02 vs 0.525 on the
# slow path), and the BRT slow path disagreed with the worker by 0.1-1.1. Same fix
# as v1.0.6-TODO-184 (ZOIB). Also: $capabilities() drops the randomization CIs,
# which are refused under a marginal estimand.

make_marginal_rand_stat_fixture = function(class_name, response_type, seed = 1L, n = 80L, zero_inflate = FALSE){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	ds = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	ds$add_all_subjects_to_experiment(X)
	ds$assign_w_to_all_subjects()
	w = ds$get_w()
	y = switch(response_type,
		proportion = plogis(-0.2 + 0.5 * X$x1 + 0.8 * w + rnorm(n, 0, 0.6)),
		count = rpois(n, exp(0.5 + 0.4 * X$x1 + 0.5 * w)),
		incidence = rbinom(n, 1, plogis(-0.2 + 0.5 * X$x1 + 0.8 * w))
	)
	# The ZIP inflation part is barely identified on plain Poisson data, which
	# makes worker and slow-path fits differ by optimizer path even under the
	# conditional estimand; give it real excess zeros.
	if (zero_inflate) y[runif(n) < 0.3] = 0
	ds$add_all_subject_responses(y)
	inf = get(class_name)$new(ds, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(seed)
	inf
}

marginal_rand_stat_specs = list(
	list(cl = "InferencePropBetaRegr", rt = "proportion", tr = "logit", zi = FALSE),
	list(cl = "InferenceCountPoisson", rt = "count", tr = "log", zi = FALSE),
	list(cl = "InferenceCountQuasiPoisson", rt = "count", tr = "log", zi = FALSE),
	list(cl = "InferenceCountHurdlePoisson", rt = "count", tr = "log", zi = FALSE),
	list(cl = "InferenceCountZeroInflatedPoisson", rt = "count", tr = "log", zi = TRUE),
	list(cl = "InferenceIncidLogRegr", rt = "incidence", tr = "none", zi = FALSE)
)

test_that("randomization statistic follows the estimand", {
	for (spec in marginal_rand_stat_specs) {
		for (estimand in c("conditional", "marginal_mean_diff")) {
			inf = make_marginal_rand_stat_fixture(spec$cl, spec$rt, zero_inflate = spec$zi)
			inf$set_estimand(estimand)
			est = inf$compute_estimate()
			stat = inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference()
			expect_true(is.finite(est), info = paste(spec$cl, estimand))
			expect_equal(stat, est, tolerance = 1e-3, info = paste(spec$cl, estimand))
		}
	}
})

test_that("randomization statistic follows marginal_ratio too", {
	for (cl in c("InferenceCountPoisson", "InferenceIncidLogRegr")) {
		rt = if (cl == "InferenceIncidLogRegr") "incidence" else "count"
		inf = make_marginal_rand_stat_fixture(cl, rt)
		inf$set_estimand("marginal_ratio")
		est = inf$compute_estimate()
		stat = inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference()
		expect_equal(stat, est, tolerance = 1e-6, info = cl)
	}
})

test_that("BRT slow path and reused worker agree under the marginal estimand", {
	for (spec in marginal_rand_stat_specs) {
		inf = make_marginal_rand_stat_fixture(spec$cl, spec$rt, zero_inflate = spec$zi)
		inf$set_estimand("marginal_mean_diff")
		inf$compute_estimate()
		priv = inf$.__enclos_env__$private
		set.seed(5)
		draws = priv$generate_rand_bootstrap_draws(8, materialize_w = TRUE)
		fast = inf$approximate_rand_bootstrap_distribution_beta_hat_T(
			B = 8, delta = 0, transform_responses = spec$tr,
			rand_bootstrap_draws = draws, show_progress = FALSE)
		slow = vapply(draws, function(d) priv$run_rand_bootstrap_iteration(d, 0, spec$tr, priv$y), numeric(1))
		expect_true(all(is.finite(fast)) && all(is.finite(slow)), info = spec$cl)
		# Were 0.13-1.1 apart (slow path on the conditional scale).
		expect_lt(max(abs(fast - slow)), 5e-3, label = spec$cl)
	}
})

test_that("randomization p-value under the marginal estimand is the same on the worker and slow paths", {
	for (spec in marginal_rand_stat_specs[c(2L, 6L)]) {
		worker = make_marginal_rand_stat_fixture(spec$cl, spec$rt)
		worker$set_estimand("marginal_mean_diff")
		set.seed(2)
		p_worker = worker$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
		slow = make_marginal_rand_stat_fixture(spec$cl, spec$rt)
		slow$set_estimand("marginal_mean_diff")
		slow$.__enclos_env__$private$reusable_bootstrap_worker_enabled = FALSE
		set.seed(2)
		p_slow = slow$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
		# InferenceIncidLogRegr was 0.02 (worker) vs 0.525 (slow).
		expect_equal(p_worker, p_slow, info = spec$cl)
	}
})

test_that("capabilities drop the randomization CIs under a marginal estimand", {
	inf = make_marginal_rand_stat_fixture("InferenceCountPoisson", "count")
	ci_caps = c("randomization_ci", "randomization_bootstrap_ci")
	expect_true(all(inf$supports(ci_caps)))
	inf$set_estimand("marginal_mean_diff")
	expect_false(any(inf$supports(ci_caps)))
	expect_true(all(inf$supports(c("randomization_test", "randomization_bootstrap"))))
	expect_error(
		inf$compute_rand_confidence_interval(r = 19, show_progress = FALSE),
		class = "edi_rand_ci_estimand_scale_mismatch_refused"
	)
	inf$set_estimand("conditional")
	expect_true(all(inf$supports(ci_caps)))
})
