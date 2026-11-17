# Numerical-robustness review audit, 2026-11-17: simulate_under_lik_null() reads the null fit's
# parameter vector as c(beta, log_sigma_b, log_sigma_e), but fast_gaussian_lmm_cpp returns c(beta,
# log_sigma_e, log_sigma_b) (fast_gaussian_lmm.cpp:539-545). The parametric-bootstrap LR null
# replicates are therefore drawn with the residual and random-intercept SDs swapped. With sigma_e = 1
# and sigma_b = 3, the simulated within-pair noise has SD 3 instead of 1.
# Where: R/EDI/R/inference_continuous_KK_glmm.R:503 (kind: other_numerical).
# On commit 4fc58cd063bc this test failed with: Expected `sigma_e_hat` < 1.6. Actual comparison: 3.3
# >= 1.6 Difference: 1.7 >= 0
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("LMM null simulation uses log_sigma_e for the residual SD and log_sigma_b for the random intercept", {
	skip("open a release TODO for this")
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
