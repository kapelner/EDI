# Numerical-robustness review audit, 2026-11-17: simulate_under_lik_null() reads the null fit's
# parameter vector as c(beta, log_sigma_b, log_sigma_e), but fast_gaussian_lmm_cpp returns c(beta,
# log_sigma_e, log_sigma_b) (fast_gaussian_lmm.cpp:539-545). The parametric-bootstrap LR null
# replicates are therefore drawn with the residual and random-intercept SDs swapped. With sigma_e = 1
# and sigma_b = 3, the simulated within-pair noise has SD 3 instead of 1.
# Where: R/EDI/R/inference_continuous_KK_glmm.R:503 (kind: other_numerical).
# On commit 4fc58cd063bc this test failed with: Expected `sigma_e_hat` < 1.6. Actual comparison: 3.3
# >= 1.6 Difference: 1.7 >= 0
# Tracked by v1.0.6-TODO-20; fixed by v1.0.6-TODO-178 (2026-11-21), which also adds the end-to-end
# parametric-bootstrap check below (docs-scenarios sequential-designs F4: replicate SD ~0.005 vs SE ~0.23).

test_that("LMM null simulation uses log_sigma_e for the residual SD and log_sigma_b for the random intercept", {
		set.seed(2)
		np = 40L
		ns = 10L
		n = 2L * np + ns
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
		Xd = data.frame(x1 = rnorm(n))
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(Xd[i, , drop = FALSE])
		des$.__enclos_env__$private$m = c(rep(seq_len(np), each = 2L), rep(0L, ns))
		w = des$get_w()
		g = c(rep(seq_len(np), each = 2L), np + seq_len(ns))
		des$add_all_subject_responses(1 + 0.5 * w + rnorm(max(g), 0, 1)[g] + rnorm(n, 0, 1))
		inf = InferenceContinKKGLMM$new(des, verbose = FALSE)
		p = inf$.__enclos_env__$private
		X = cbind(b0 = 1, w = w, x1 = Xd$x1)
		spec = list(X = X, group_id = as.integer(g), j = 2L)
		# kernel order: c(beta, log_sigma_e, log_sigma_b); sigma_e = 1, sigma_b = 3
		null_fit = list(b = c(1, 0, 0, log(1), log(3)))
		set.seed(11)
		sim = p$simulate_under_lik_null(spec, 0, null_fit)
		expect_false(is.null(sim))
		if (!is.null(sim)) {
			y_sim = environment(sim$fit_null)$y_sim
			# within a pair the mean and random intercept cancel, so var(diff) = 2 * sigma_e^2
			d = y_sim[seq(1L, 2L * np, by = 2L)] - y_sim[seq(2L, 2L * np, by = 2L)]
			sigma_e_hat = sqrt(mean(d^2) / 2)
			expect_lt(sigma_e_hat, 1.6)
			expect_gt(sigma_e_hat, 0.6)
		}
})

test_that("KK GLMM parametric-bootstrap replicates spread like the estimator (v1.0.6-TODO-178)", {
	set.seed(20261118)
	n = 60
	X = data.frame(age = round(rnorm(n, 55, 10)), severity = round(rnorm(n), 2))
	y0 = 0.05 * (X$age - 55) + 1.2 * X$severity + rnorm(n)
	d = DesignSeqOneByOneKK14$new(response_type = "continuous", n = n, seed = 7041, verbose = FALSE)
	for (i in 1:n) {
		w = d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y0[i] + 0.6 * w)
	}
	g = InferenceContinKKGLMM$new(d, verbose = FALSE)
	g$set_seed(1)
	est = g$compute_estimate()
	ci = g$compute_param_bootstrap_confidence_interval(alpha = 0.05, B = 99)
	reps = g$get_last_param_bootstrap_estimate_diagnostics()$replicate_estimates
	# the fitted pair SD is ~0 here, so the OLS SE is the right scale (lmer REML = FALSE gives 0.233)
	ols_se = summary(lm(y ~ w + age + severity, data.frame(y = d$get_y(), w = d$get_w(), X)))$coef["w", 2]
	# before the fix: sd(reps) ~ 0.005 and the CI ~ [0.81, 0.83]
	expect_gt(sd(reps), 0.75 * ols_se)
	expect_lt(sd(reps), 1.33 * ols_se)
	expect_lt(ci[1], est)
	expect_gt(ci[2], est)
	expect_gt(ci[2] - ci[1], 2 * ols_se)
})
