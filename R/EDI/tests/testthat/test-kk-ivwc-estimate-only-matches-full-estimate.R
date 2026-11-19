# v1.0.6-TODO-132: compute_estimate(estimate_only = TRUE) must be the same estimator as
# compute_estimate(). InferenceSurvivalKKStratCoxPHIVWC (sample-size weights) and both
# Weibull frailty IVWC classes (50/50 weights, or halves with no finite variance kept)
# pooled the matched and reservoir halves differently under estimate_only, so the
# reusable bootstrap worker, the jackknife and the slow subset refit (all estimate_only)
# resampled a different estimator from the reported one, and the result depended on call
# order. InferenceIncidKKCondLogitIVWC returned before caching the SE under estimate_only,
# so a later full call had no standard error (NA CI and p-value).

kk_ivwc_eo_rare_strat_cox_design = function(n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), r = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, design_formula = ~ x + r)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, stats::rexp(1, exp(-0.5 * w_i)))
	}
	des
}

kk_ivwc_eo_design = function(response_type, seed = 1L, n = 80L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), b = rbinom(n, 1, 0.4))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE, design_formula = ~ x1 + x2 + b)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = 0.5 * w + 0.6 * X$x1[i] - 0.3 * X$x2[i] + 0.4 * X$b[i]
		if (response_type == "incidence") {
			des$add_one_subject_response(i, rbinom(1, 1, plogis(eta)))
		} else {
			t_i = rexp(1, exp(-eta))
			if (i %% 6L == 0L) des$add_one_subject_response(i, y_L = t_i, y_R = Inf) else des$add_one_subject_response(i, t_i)
		}
	}
	des
}

quiet_ivwc = function(expr) suppressWarnings(suppressMessages(expr))

expect_estimate_only_matches_full = function(generator, des){
	full_first = generator$new(des, verbose = FALSE)
	est_full = quiet_ivwc(full_first$compute_estimate())
	ci_full = quiet_ivwc(full_first$compute_asymp_confidence_interval())
	pval_full = quiet_ivwc(full_first$compute_asymp_two_sided_pval())
	expect_true(is.finite(est_full))
	expect_true(all(is.finite(ci_full)))
	expect_identical(quiet_ivwc(full_first$compute_estimate(estimate_only = TRUE)), est_full)

	eo_first = generator$new(des, verbose = FALSE)
	expect_equal(quiet_ivwc(eo_first$compute_estimate(estimate_only = TRUE)), est_full, tolerance = 1e-12)
	expect_equal(quiet_ivwc(eo_first$compute_estimate()), est_full, tolerance = 1e-12)
	expect_equal(quiet_ivwc(eo_first$compute_asymp_confidence_interval()), ci_full, tolerance = 1e-12)
	expect_equal(quiet_ivwc(eo_first$compute_asymp_two_sided_pval()), pval_full, tolerance = 1e-12)
	est_full
}

expect_worker_matches_slow_path = function(generator, des, n_draws = 4L, seed = 7L){
	inf = generator$new(des, verbose = FALSE)
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	expect_true(isTRUE(p$use_reusable_bootstrap_worker()))
	ws = p$create_reusable_bootstrap_worker()
	set.seed(seed)
	for (k in seq_len(n_draws)) {
		draw = p$bootstrap_sample_indices(des$get_n())
		p$load_bootstrap_sample_into_worker(ws, draw)
		theta_worker = quiet_ivwc(p$compute_bootstrap_worker_estimate(ws))
		theta_slow = quiet_ivwc(p$bootstrap_subset_inference(draw)$compute_estimate())
		expect_equal(theta_worker, theta_slow, tolerance = 1e-8)
	}
}

test_that("KK StratCox IVWC: estimate_only is the inverse-variance-weighted estimate in either call order", {
	skip_if_not_installed("survival")
	des = kk_ivwc_eo_rare_strat_cox_design()
	est = expect_estimate_only_matches_full(InferenceSurvivalKKStratCoxPHIVWC, des)
	# Before the fix a fresh estimate_only call gave the sample-size-weighted -4.653.
	expect_equal(est, -0.7573653, tolerance = 1e-6)
	expect_estimate_only_matches_full(InferenceSurvivalKKStratCoxPHIVWC, kk_ivwc_eo_design("survival", seed = 2L))
})

test_that("KK StratCox IVWC: reusable worker equals the slow-path full fit on bootstrap draws", {
	skip_if_not_installed("survival")
	expect_worker_matches_slow_path(InferenceSurvivalKKStratCoxPHIVWC, kk_ivwc_eo_rare_strat_cox_design(), n_draws = 8L)
})

test_that("KK StratCox IVWC: jackknife replicates centre on the reported estimate", {
	skip_if_not_installed("survival")
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_ivwc_eo_rare_strat_cox_design(), verbose = FALSE)
	inf$num_cores = 1L
	est = quiet_ivwc(inf$compute_estimate())
	jack = quiet_ivwc(inf$approximate_jackknife_distribution_beta_hat_T())
	expect_true(all(is.finite(jack)))
	# Leave-one-out replicates of the IVW estimator stay near it (the old
	# sample-size-weighted replicates averaged -4.40 against an estimate of -0.757).
	expect_lt(abs(mean(jack) - est), 0.1)
})

for (generator_name in c("InferenceSurvivalGLMMWeibullFrailtyNormalIVWC", "InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC")) {
	local({
		gen_name = generator_name
		test_that(paste0(gen_name, ": estimate_only is the inverse-variance-weighted estimate in either call order"), {
			gen = get(gen_name)
			expect_estimate_only_matches_full(gen, kk_ivwc_eo_design("survival", seed = 1L))
			expect_estimate_only_matches_full(gen, kk_ivwc_eo_design("survival", seed = 3L))
		})
		test_that(paste0(gen_name, ": reusable worker equals the slow-path full fit on bootstrap draws"), {
			expect_worker_matches_slow_path(get(gen_name), kk_ivwc_eo_design("survival", seed = 1L))
		})
	})
}

test_that("KK CondLogit IVWC: a full call after estimate_only still has its standard error", {
	expect_estimate_only_matches_full(InferenceIncidKKCondLogitIVWC, kk_ivwc_eo_design("incidence", seed = 1L))
	expect_estimate_only_matches_full(InferenceIncidKKCondLogitIVWC, kk_ivwc_eo_design("incidence", seed = 2L))
	expect_worker_matches_slow_path(InferenceIncidKKCondLogitIVWC, kk_ivwc_eo_design("incidence", seed = 1L))
})
