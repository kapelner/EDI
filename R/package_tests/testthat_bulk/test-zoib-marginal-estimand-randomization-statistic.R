# v1.0.6-TODO-184: InferencePropZeroOneInflatedBetaRegr's randomization statistic
# (compute_treatment_estimate_during_randomization_inference) always returned the
# conditional interior-beta coefficient, even under estimand = "marginal_mean_diff".
# The plain randomization test and the BRT slow path therefore ran on the
# conditional scale while the BRT worker (and compute_estimate()) used the marginal
# mean difference: the BRT p-value compared a conditional observed statistic with
# marginal null draws. Also covered: switching estimands on one object reused the
# cached resampling distributions / workers of the old estimand, and the
# randomization / randomization-bootstrap CIs, which invert a logit shift, are
# refused under a marginal estimand.

make_zoib_marginal_rand_fixture = function(effect, seed = 1L, n = 80L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	ds = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	ds$add_all_subjects_to_experiment(X)
	ds$assign_w_to_all_subjects()
	w = ds$get_w()
	y = plogis(-0.2 + 0.5 * X$x1 + effect * w + rnorm(n, 0, 0.6))
	u = runif(n)
	y[u < 0.1] = 0
	y[u > 0.9] = 1
	ds$add_all_subject_responses(y)
	inf = InferencePropZeroOneInflatedBetaRegr$new(ds, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(seed)
	inf
}

test_that("ZOIB randomization statistic follows the estimand", {
	for (estimand in c("conditional", "marginal_mean_diff")) {
		inf = make_zoib_marginal_rand_fixture(effect = 0.8)
		inf$set_estimand(estimand)
		est = inf$compute_estimate()
		stat = inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference()
		expect_equal(stat, est, tolerance = 1e-3, info = estimand)
	}
	inf = make_zoib_marginal_rand_fixture(effect = 0.8)
	cond = inf$compute_estimate()
	inf$set_estimand("marginal_mean_diff")
	marg = inf$compute_estimate()
	expect_gt(abs(cond - marg), 0.3)
})

test_that("ZOIB BRT slow path and reused worker agree under the marginal estimand", {
	inf = make_zoib_marginal_rand_fixture(effect = 0.8)
	inf$set_estimand("marginal_mean_diff")
	inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	set.seed(5)
	draws = priv$generate_rand_bootstrap_draws(8, materialize_w = TRUE)
	fast = inf$approximate_rand_bootstrap_distribution_beta_hat_T(
		B = 8, delta = 0, transform_responses = "logit",
		rand_bootstrap_draws = draws, show_progress = FALSE)
	slow = vapply(draws, function(d) priv$run_rand_bootstrap_iteration(d, 0, "logit", priv$y), numeric(1))
	expect_true(all(is.finite(fast)) && all(is.finite(slow)))
	# Was 0.22 apart (slow path on the conditional scale); now only optimizer
	# warm-start differences remain (~5e-4).
	expect_lt(max(abs(fast - slow)), 5e-3)
})

test_that("ZOIB randomization p-values after an estimand switch equal a fresh object's", {
	switched = make_zoib_marginal_rand_fixture(effect = 0.8)
	set.seed(2)
	switched$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
	set.seed(2)
	switched$compute_rand_bootstrap_two_sided_pval(B = 49, show_progress = FALSE)
	switched$set_estimand("marginal_mean_diff")
	set.seed(2)
	p_rand_switched = switched$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
	set.seed(2)
	p_brt_switched = switched$compute_rand_bootstrap_two_sided_pval(B = 49, show_progress = FALSE)

	fresh = make_zoib_marginal_rand_fixture(effect = 0.8)
	fresh$set_estimand("marginal_mean_diff")
	set.seed(2)
	p_rand_fresh = fresh$compute_rand_two_sided_pval(r = 49, show_progress = FALSE)
	set.seed(2)
	p_brt_fresh = fresh$compute_rand_bootstrap_two_sided_pval(B = 49, show_progress = FALSE)

	expect_equal(p_rand_switched, p_rand_fresh)
	expect_equal(p_brt_switched, p_brt_fresh)
})

test_that("ZOIB randomization and randomization-bootstrap CIs are refused under the marginal estimand", {
	inf = make_zoib_marginal_rand_fixture(effect = 0.8)
	inf$set_estimand("marginal_mean_diff")
	expect_error(
		inf$compute_rand_confidence_interval(r = 49, show_progress = FALSE),
		class = "edi_rand_ci_estimand_scale_mismatch_refused"
	)
	expect_error(
		inf$compute_rand_bootstrap_confidence_interval(B = 49, show_progress = FALSE),
		class = "edi_rand_ci_estimand_scale_mismatch_refused"
	)
	# Conditional estimand: not refused by this guard (the rand CI may still be
	# refused for exact 0/1 responses, a different reason).
	inf$set_estimand("conditional")
	err = tryCatch({ inf$compute_rand_confidence_interval(r = 49, show_progress = FALSE); NULL }, error = function(e) e)
	expect_false(inherits(err, "edi_rand_ci_estimand_scale_mismatch_refused"))
})
