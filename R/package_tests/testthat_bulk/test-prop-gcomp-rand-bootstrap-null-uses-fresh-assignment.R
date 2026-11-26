# v1.0.6-TODO-101: InferencePropGCompMeanDiff's bootstrap randomization test
# (BRT) reuses the bootstrap worker estimator, which fit the treatment column and
# responses snapshotted by the row-resample loader instead of the fresh design
# assignment and sharp-null responses the BRT loader installs afterwards. Every
# "null" draw was an ordinary bootstrap replicate centered at the estimate, so
# the p-value was ~0.9 at a strong effect while the randomization test gave 0.01.

make_prop_gcomp_brt_fixture = function(effect, seed = 1L, n = 80L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	ds = DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	ds$add_all_subjects_to_experiment(X)
	ds$assign_w_to_all_subjects()
	w = ds$get_w()
	ds$add_all_subject_responses(plogis(-0.2 + 0.5 * X$x1 + effect * w + rnorm(n, 0, 0.6)))
	inf = InferencePropGCompMeanDiff$new(ds, verbose = FALSE)
	inf$num_cores = 1L
	inf$set_seed(seed)
	inf
}

test_that("PropGCompMeanDiff BRT null distribution is centered at the null, not the estimate", {
	inf = make_prop_gcomp_brt_fixture(effect = 0.6)
	est = inf$compute_estimate()
	t0 = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 49, show_progress = FALSE)
	expect_true(all(is.finite(t0)))
	expect_lt(abs(mean(t0)), 0.25 * est)
	expect_lt(inf$compute_rand_bootstrap_two_sided_pval(B = 49, show_progress = FALSE), 0.05)
})

test_that("PropGCompMeanDiff reused-worker BRT draws equal the slow path draw by draw", {
	inf = make_prop_gcomp_brt_fixture(effect = 0.6)
	priv = inf$.__enclos_env__$private
	expect_true(priv$use_reusable_bootstrap_worker())
	set.seed(5)
	draws = priv$generate_rand_bootstrap_draws(15, materialize_w = TRUE)
	for (delta in c(0, 0.3)) {
		fast = inf$approximate_rand_bootstrap_distribution_beta_hat_T(
			B = 15, delta = delta, transform_responses = "logit",
			rand_bootstrap_draws = draws, show_progress = FALSE)
		y0 = if (delta != 0) priv$shift_randomization_responses(
			y = priv$y, w = priv$w, delta = delta, transform_responses = "logit",
			response_type = "proportion", inverse = TRUE) else priv$y
		slow = vapply(draws, function(d) priv$run_rand_bootstrap_iteration(d, delta, "logit", y0), numeric(1))
		expect_equal(fast, slow, tolerance = 1e-10)
	}
})

test_that("PropGCompMeanDiff plain bootstrap worker still fits the resampled observed data", {
	inf = make_prop_gcomp_brt_fixture(effect = 0.6)
	est = inf$compute_estimate()
	boot = inf$approximate_bootstrap_distribution_beta_hat_T(B = 29, show_progress = FALSE)
	expect_true(sum(is.finite(boot)) >= 25L)
	expect_lt(abs(mean(boot, na.rm = TRUE) - est), 0.5 * est)
})
