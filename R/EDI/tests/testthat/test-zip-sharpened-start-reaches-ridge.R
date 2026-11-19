# v1.0.6-TODO-232 (2026-11-19): with covariates in the zero formula, a small ZIP
# fit can stop unflagged at an interior local maximum (gradient ~1e-10,
# information positive definite) while the likelihood's supremum is on a ridge
# where the zero part separates some zeros from every positive count.
# pscl::zeroinfl() stops at another interior maximum, so it could not reveal
# this. Each ZIP fit now also runs L-BFGS from pscl's start with the zero part
# scaled by 10, which reaches the ridge here; the separated zero part is then
# flagged (v1.0.6-TODO-152).

zip_sharpened_repro = function() {
	# The v1.0.6-TODO-218 sweep generator at dataset 1057 (seed 101057).
	set.seed(101057)
	n = sample(c(24, 40, 60, 100, 200, 400), 1)
	infl = sample(c(-Inf, -2.5, -1, 0, 1), 1, prob = c(0.3, 0.2, 0.2, 0.15, 0.15))
	zx = sample(c(0, 1, 3), 1); px = sample(1:2, 1); b0 = sample(c(0, 0.7), 1)
	x1 = rnorm(n); x2 = rbinom(n, 1, 0.4); w = sample(rep(0:1, length.out = n))
	pz = if (is.infinite(infl)) rep(0, n) else plogis(infl + zx * x1 - 0.4 * w)
	y = ifelse(runif(n) < pz, 0, rpois(n, exp(b0 + 0.3 * w + 0.2 * x1 - 0.1 * x2)))
	X = if (px == 1) data.frame(x1 = x1) else data.frame(x1 = x1, x2 = x2)
	des = DesignFixediBCRD$new(n = n, response_type = "count")
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("the sharpened pscl-start candidate escapes an interior maximum below the ridge", {
	des = zip_sharpened_repro()
	expect_equal(des$get_n(), 24L)
	inf = InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	expect_warning(est <- inf$compute_estimate(), class = "edi_zero_part_separation_warning")
	pv = inf$.__enclos_env__$private
	ctx = pv$cached_values$likelihood_test_context
	y = as.numeric(pv$y)
	nll = zip_neg_loglik_r(pv$cached_mod$params, ctx$X, ctx$Xzi, y)
	# Before: default start and pscl start both stopped at nll 21.073 (estimate
	# -0.344); pscl::zeroinfl() at 20.903 (-0.261); the ridge limit is ~20.159.
	expect_lt(nll, 20.2)
	expect_equal(est, -0.164, tolerance = 5e-3)
	expect_identical(pv$cached_values$zero_part_nonestimable_reason, "zero_part_separated")

	# The interior point the default start reaches is a genuine local maximum,
	# so only a different start can escape it.
	f0 = fast_zero_augmented_poisson_cpp(ctx$X, y, ctx$Xzi, FALSE, smart_cold_start = TRUE,
		estimate_only = TRUE, optimization_alg = "newton_raphson")
	expect_true(isTRUE(f0$converged))
	expect_equal(zip_neg_loglik_r(f0$params, ctx$X, ctx$Xzi, y), 21.073, tolerance = 1e-3)
	start = zero_augmented_pscl_start(ctx$X, y, ctx$Xzi)
	f1 = fast_zero_augmented_poisson_cpp(ctx$X, y, ctx$Xzi, FALSE, warm_start_params = start,
		smart_cold_start = FALSE, estimate_only = TRUE, optimization_alg = "lbfgs")
	expect_equal(zip_neg_loglik_r(f1$params, ctx$X, ctx$Xzi, y), 21.073, tolerance = 1e-3)
	g = fast_zero_augmented_poisson_cpp_guarded(ctx$X, y, ctx$Xzi, estimate_only = TRUE,
		optimization_alg = "newton_raphson")
	expect_identical(g$start_candidate, "pscl_start_sharpened_lbfgs")
	expect_lt(zip_neg_loglik_r(g$params, ctx$X, ctx$Xzi, y), 20.2)
})
