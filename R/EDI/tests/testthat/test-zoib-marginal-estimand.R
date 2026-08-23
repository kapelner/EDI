# marginal_estimand_report.md TODO-4: InferencePropZeroOneInflatedBetaRegr's
# "marginal_mean_diff" estimand (set_estimand()).

simulate_zoib_design = function(seed = 1L, n = 250L, beta_T = 0.6){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	lin = 0.3 + beta_T * w + 0.4 * x1
	mu = plogis(lin)
	p0 = plogis(-2 - 0.2 * w)
	p1 = plogis(-2 + 0.1 * w)
	u = runif(n)
	y = numeric(n)
	for (i in seq_len(n)) {
		if (u[i] < p0[i]) {
			y[i] = 0
		} else if (u[i] < p0[i] + p1[i]) {
			y[i] = 1
		} else {
			y[i] = rbeta(1L, mu[i] * 8, (1 - mu[i]) * 8)
		}
	}
	seq_des$add_all_subject_responses(y)
	seq_des
}

test_that("default estimand is conditional and supported estimands include the new value", {
	seq_des = simulate_zoib_design(1L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	expect_equal(inf$get_estimand(), "conditional")
	expect_setequal(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff"))
	expect_true(inf$supports("marginal_estimand"))
})

test_that("conditional estimate/CI/pval are unchanged from a fresh object regardless of set_estimand call history", {
	seq_des = simulate_zoib_design(2L)
	inf_a = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	est_a = inf_a$compute_estimate()
	ci_a = inf_a$compute_asymp_confidence_interval()
	pv_a = inf_a$compute_asymp_two_sided_pval()

	# Direct call with no prior compute_estimate() -- exercises compute_asymp_*
	# methods' own private$shared()-bypass fix, not just compute_estimate().
	inf_b = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	ci_b = inf_b$compute_asymp_confidence_interval()
	expect_equal(ci_b, ci_a, tolerance = 1e-8)

	# Round-trip through marginal and back to conditional.
	inf_c = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_c$compute_estimate()
	inf_c$set_estimand("marginal_mean_diff")
	inf_c$compute_estimate()
	inf_c$set_estimand("conditional")
	est_c = inf_c$compute_estimate()
	pv_c = inf_c$compute_asymp_two_sided_pval()
	expect_equal(est_c, est_a, tolerance = 1e-8)
	expect_equal(pv_c, pv_a, tolerance = 1e-8)
})

test_that("marginal_mean_diff point estimate is bounded and call-order independent", {
	seq_des = simulate_zoib_design(3L)

	inf_direct = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_direct$set_estimand("marginal_mean_diff")
	ci_direct = inf_direct$compute_asymp_confidence_interval()
	est_direct = inf_direct$compute_estimate()

	inf_estfirst = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_estfirst$set_estimand("marginal_mean_diff")
	est_first = inf_estfirst$compute_estimate()
	ci_estfirst = inf_estfirst$compute_asymp_confidence_interval()

	expect_equal(est_direct, est_first, tolerance = 1e-8)
	expect_equal(ci_direct, ci_estfirst, tolerance = 1e-8)
	expect_gte(est_direct, -1)
	expect_lte(est_direct, 1)
	expect_true(all(is.finite(ci_direct)))
})

test_that("marginal_mean_diff delta-method SE matches a hand-recomputed numerical-gradient check", {
	seq_des = simulate_zoib_design(4L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	inf$compute_estimate()
	se_cached = inf$.__enclos_env__$private$cached_values$s_beta_hat_T
	mod = inf$.__enclos_env__$private$cached_mod
	expect_false(is.null(mod$vcov))

	p = ncol(mod$X)
	q = ncol(mod$X_zero_one)
	f = function(theta) inf$.__enclos_env__$private$zoib_marginal_mean_diff_functional(theta, mod$X, mod$X_zero_one, p, q)
	grad = EDI:::numerical_gradient_central(f, mod$params, eps = 1e-6)
	se_manual = sqrt(as.numeric(t(grad) %*% mod$vcov %*% grad))

	expect_true(is.finite(se_cached))
	expect_gt(se_cached, 0)
	expect_equal(se_cached, se_manual, tolerance = 1e-8)
})

test_that("marginal estimand shrinks supported testing types to wald only, and setter order is symmetric", {
	seq_des = simulate_zoib_design(5L)

	inf1 = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	expect_true("lik_ratio" %in% inf1$get_supported_testing_types())
	inf1$set_estimand("marginal_mean_diff")
	expect_equal(inf1$get_supported_testing_types(), "wald")

	inf2 = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf2$set_testing_type("lik_ratio")
	expect_error(inf2$set_estimand("marginal_mean_diff"), "not supported under this estimand")
	expect_equal(inf2$get_estimand(), "conditional")
})

test_that("marginal estimand rejects a non-wald testing type", {
	seq_des = simulate_zoib_design(6L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	expect_error(inf$set_testing_type("lik_ratio"), "does not support")
})

test_that("compute_estimate_with_bootstrap_weights under marginal estimand returns a bounded, finite point estimate", {
	seq_des = simulate_zoib_design(7L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	inf$set_seed(1L)
	boot_distr = inf$approximate_bootstrap_distribution_beta_hat_T(B = 12L, show_progress = FALSE)
	expect_length(boot_distr, 12L)
	expect_true(all(is.finite(boot_distr)))
	expect_true(all(boot_distr >= -1 & boot_distr <= 1))
})

test_that("marginal estimand randomization inference produces finite draws", {
	seq_des = simulate_zoib_design(8L, n = 120L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	inf$set_seed(1L)
	pv = inf$compute_rand_two_sided_pval(r = 25L, show_progress = FALSE)
	expect_true(is.finite(pv))
	expect_gte(pv, 0)
	expect_lte(pv, 1)
})
