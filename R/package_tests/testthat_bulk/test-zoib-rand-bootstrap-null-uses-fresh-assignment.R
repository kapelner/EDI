# v1.0.6-TODO-167: InferencePropZeroOneInflatedBetaRegr's bootstrap randomization
# test (BRT) reuses the bootstrap worker estimator, whose fast path fit the
# design matrices snapshotted by the row-resample loader (treatment column =
# observed w[i_b]) against the sharp-null responses the BRT loader installs
# afterwards. Every "null" draw was centred at the estimate, so the BRT p-value
# was ~0.85 at a strong effect while the randomization test gave 0.01. Same bug
# as v1.0.6-TODO-150 (PropGComp).

make_zoib_brt_fixture = function(effect, seed = 1L, n = 80L){
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

test_that("ZOIB BRT null distribution is centred at the null, not the estimate", {
	inf = make_zoib_brt_fixture(effect = 0.8)
	est = inf$compute_estimate()
	t0 = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 39, show_progress = FALSE)
	expect_true(all(is.finite(t0)))
	expect_lt(abs(mean(t0)), 0.25 * est)
	expect_lt(inf$compute_rand_bootstrap_two_sided_pval(B = 39, show_progress = FALSE), 0.1)
})

test_that("ZOIB reused-worker fast path fits the fresh BRT assignment (equals the worker's full fit)", {
	for (estimand in c("conditional", "marginal_mean_diff")) {
		inf = make_zoib_brt_fixture(effect = 0.8)
		inf$set_estimand(estimand)
		inf$compute_estimate()
		priv = inf$.__enclos_env__$private
		expect_true(priv$use_reusable_bootstrap_worker())
		set.seed(5)
		draws = priv$generate_rand_bootstrap_draws(6, materialize_w = TRUE)
		ws = priv$create_bootstrap_worker_state()
		for (delta in c(0, 0.3)) {
			y0 = if (delta != 0) priv$shift_randomization_responses(
				y = priv$y, w = priv$w, delta = delta, transform_responses = "logit",
				response_type = "proportion", inverse = TRUE) else priv$y
			for (draw in draws) {
				priv$load_rand_bootstrap_draw_into_worker(ws, draw, delta, "logit", y0)
				expect_true(isTRUE(ws$runtime$fast_path_ready))
				fast = priv$compute_bootstrap_worker_estimate(ws)
				# Same draw, same warm state, but through generate_mod(), which builds
				# its matrices from the worker's live w.
				priv$load_rand_bootstrap_draw_into_worker(ws, draw, delta, "logit", y0)
				full = as.numeric(ws$worker$compute_estimate(estimate_only = TRUE))[1L]
				expect_equal(fast, full, tolerance = 1e-10, info = paste(estimand, delta))
			}
		}
	}
})

test_that("ZOIB reused-worker BRT draws agree with the slow path up to optimizer tolerance", {
	# The slow path (run_rand_bootstrap_iteration) refits a fresh subset copy from
	# a different start and holds the nuisance parameters at cached_vc_params, so
	# agreement is ~1e-3, not exact. The old bug put the draws ~0.6 apart.
	inf = make_zoib_brt_fixture(effect = 0.8)
	priv = inf$.__enclos_env__$private
	inf$compute_estimate()
	set.seed(5)
	draws = priv$generate_rand_bootstrap_draws(8, materialize_w = TRUE)
	fast = inf$approximate_rand_bootstrap_distribution_beta_hat_T(
		B = 8, rand_bootstrap_draws = draws, show_progress = FALSE)
	slow = vapply(draws, function(d) priv$run_rand_bootstrap_iteration(d, 0, "logit", priv$y), numeric(1))
	expect_lt(max(abs(fast - slow)), 0.02)
})
