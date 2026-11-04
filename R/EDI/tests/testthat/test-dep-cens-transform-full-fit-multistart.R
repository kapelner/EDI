# TODO-188 (v1.0.5, 2026-11-04): the full-data fit of
# InferenceSurvivalDepCensTransformRegr is bimodal in rho. A single start (the
# C++ default, atanh(rho) = 0) could stop in a rho > 0 local optimum while the
# MLE has rho ~ -0.9. Calibration null replicates (n = 200, Bernoulli design,
# same generator as R/package_tests/calibration/calibration_fast_tier_common.R
# and test-null-refit-history-independence-hurdle-negbin-dep-cens.R): `~.` rep 9
# sat at nll 301.69 (beta_T 0.050, rho 0.62) vs the MLE 292.23 (beta_T -0.262,
# rho -0.94); `~.` rep 15 at 254.26 (beta_T -0.085) vs 241.98 (beta_T -0.058).
# Null refits then landed below the "full" nll, so the LR statistic clamped.
# generate_mod() now tries a fixed set of deterministic starts and keeps the
# lowest converged nll.

make_todo188_design = function(rep){
	set.seed(1e6 * 6L + 7L * 200L + rep)
	n = 200L
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	eta = 0.5 * X$x1 + 0.5 * X$x2
	t = stats::rweibull(n, shape = 1.5, scale = exp(eta / 1.5))
	cens = stats::rexp(n, 0.3)
	ev = t <= cens
	obs = pmin(t, cens)
	des$add_all_subject_responses(ifelse(ev, obs, NA), y_Ls = ifelse(ev, NA, obs), y_Rs = ifelse(ev, NA, Inf))
	des
}

todo188_cases = list(
	list(rep = 9L, old_nll = 301.6875, mle_nll = 292.2295, mle_beta = -0.26197),
	list(rep = 15L, old_nll = 254.2558, mle_nll = 241.9759, mle_beta = -0.05765)
)

for (case in todo188_cases) {
	test_that(paste0("DepCensTransform full fit reaches the MLE on calibration rep ", case$rep, " `~.` (TODO-188)"), {
		des = make_todo188_design(case$rep)
		inf = InferenceSurvivalDepCensTransformRegr$new(des, model_formula = ~ ., verbose = FALSE)
		est = suppressWarnings(inf$compute_estimate())
		priv = inf$.__enclos_env__$private
		mod = priv$cached_mod
		expect_false(is.null(mod))
		n_params = length(mod$b)

		# The fit is the rho < 0 mode, well below the old local optimum.
		expect_equal(mod$neg_loglik, case$mle_nll, tolerance = 1e-4)
		expect_lt(mod$neg_loglik, case$old_nll - 5)
		expect_equal(est, case$mle_beta, tolerance = 1e-3)
		expect_lt(tanh(mod$b[n_params]), 0)
		expect_true(is.finite(suppressWarnings(inf$compute_asymp_two_sided_pval())))

		# The old default start alone still lands in the rho > 0 mode: the
		# data really are bimodal, so the test pins the multistart.
		X = priv$cached_values$likelihood_test_context$X
		y = as.numeric(priv$y)
		dead = as.numeric(priv$dead)
		cold = fast_dep_cens_transform_optim_cpp(X = X, y = y, dead = dead, estimate_only = TRUE)
		expect_gt(cold$neg_loglik, mod$neg_loglik + 5)

		# No delta-constrained null refit lands below the full fit.
		spec = priv$get_likelihood_test_spec()
		null_nll = vapply(est + c(-0.5, -0.1, 0, 0.1, 0.5), function(d) as.numeric(spec$fit_null(d)$neg_loglik), numeric(1))
		expect_true(all(null_nll >= mod$neg_loglik - 1e-6))

		# Same estimate whether or not an estimate-only fit ran first.
		inf2 = InferenceSurvivalDepCensTransformRegr$new(des, model_formula = ~ ., verbose = FALSE)
		suppressWarnings(inf2$compute_estimate(estimate_only = TRUE))
		expect_equal(suppressWarnings(inf2$compute_estimate()), est, tolerance = 1e-5)
	})
}
