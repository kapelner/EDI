# TODO-128 (v1.0.5, 2026-10-22): the covariate-adjusted
# InferenceIncidLogBinomial jackknife used to depend on call history. The
# plain bootstrap and the jackknife both ran through the serial reusable-worker
# cache under the same key ("non_param_boot"), but duplicate() fixes a worker's
# warm-start switch from the active operation's dispatch policy, which for this
# class is cold for "non_param_boot" (n < 500) and warm for "jackknife". A
# jackknife after compute_bootstrap_confidence_interval(type = "bca") therefore
# refit every leave-one-out sample cold, a fresh one warm, and because the
# Fisher-scoring fit stops at a relative step of 1e-6 the two answers differed
# by up to ~1e-5 (per-fold ~1e-7, amplified (n - 1)-fold by the jackknife). The
# reverse order leaked the jackknife's warm worker into the bootstrap. Both
# directions must now be identical regardless of what ran before.

make_todo128_design = function(seed = 20261022L, n = 120L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rnorm(n))
	X = as.data.frame(scale(X) / ncol(X))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = qlogis(0.35) + 2 * X$x1 - 1.5 * X$x2 + X$x3 + 0.3 * w + rnorm(n, 0, 0.5)
	des$add_all_subject_responses(stats::rbinom(n, 1, plogis(eta)))
	des
}

new_todo128_inf = function(des, fml){
	inf = InferenceIncidLogBinomial$new(des, model_formula = fml, verbose = FALSE)
	inf$num_cores = 1L
	inf$compute_estimate()
	inf
}

todo128_jackknife_summary = function(inf){
	c(
		est = inf$compute_jackknife_estimate(),
		se = inf$compute_jackknife_std_error(),
		inf$compute_jackknife_wald_confidence_interval(alpha = 0.05)
	)
}

for (fml_txt in c("~1", "~.")) {
	test_that(paste0("log-binomial jackknife does not depend on a prior BCa bootstrap call (", fml_txt, ")"), {
		des = make_todo128_design()
		fml = stats::as.formula(fml_txt)

		fresh = new_todo128_inf(des, fml)
		fresh_summary = todo128_jackknife_summary(fresh)
		expect_true(all(is.finite(fresh_summary)))

		after_bca = new_todo128_inf(des, fml)
		set.seed(1)
		suppressWarnings(after_bca$compute_bootstrap_confidence_interval(type = "bca", B = 31, show_progress = FALSE))
		# BCa computes and caches the jackknife for its acceleration constant;
		# the public jackknife methods below read that cached distribution.
		expect_equal(after_bca_summary <- todo128_jackknife_summary(after_bca), fresh_summary, tolerance = 1e-8)
		expect_lte(max(abs(after_bca_summary - fresh_summary)), 1e-8)
	})

	test_that(paste0("log-binomial bootstrap does not depend on a prior jackknife call (", fml_txt, ")"), {
		des = make_todo128_design()
		fml = stats::as.formula(fml_txt)

		fresh = new_todo128_inf(des, fml)
		set.seed(2)
		fresh_ci = fresh$compute_bootstrap_confidence_interval(type = "percentile", B = 31, show_progress = FALSE)

		after_jack = new_todo128_inf(des, fml)
		after_jack$compute_jackknife_estimate()
		set.seed(2)
		after_jack_ci = after_jack$compute_bootstrap_confidence_interval(type = "percentile", B = 31, show_progress = FALSE)
		expect_lte(max(abs(after_jack_ci - fresh_ci)), 1e-8)
	})
}

test_that("log-binomial refits do not stall at a boundary full-data fit (TODO-128)", {
	# With ~. this design's full-data fit has a subject on the exp(X b) < 1
	# boundary. Warm-started refits from that fit used to report convergence
	# without moving (step halving shrank every outward step to ~1e-8), so
	# nearly every leave-one-out estimate equalled the full-data estimate (the
	# jackknife SE was ~9x too small) and Dirichlet-weighted draws were
	# squeezed toward it. logbin_feasible_warm_start_args() now cold-starts such refits.
	des = make_todo128_design()
	inf = new_todo128_inf(des, ~.)
	priv = inf$.__enclos_env__$private
	X = priv$build_design_matrix()
	expect_gt(max(X %*% priv$cached_mod$b), -1e-6)
	theta_hat = inf$compute_estimate()

	jack = inf$approximate_jackknife_distribution_beta_hat_T()
	expect_true(all(is.finite(jack)))
	expect_lt(sum(abs(jack - theta_hat) < 1e-7), 5L)
	expect_gt(inf$compute_jackknife_std_error(), 0.1)

	set.seed(3)
	bayes = inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 41, show_progress = FALSE)
	# Warm-started draws barely moved from theta_hat: sd 0.106 before the
	# fix, 0.181 after (cold-started refits).
	expect_gt(stats::sd(bayes, na.rm = TRUE), 0.15)

	# An interior warm start is passed through untouched.
	interior = list(warm_start_beta = c(-2, 0, 0, 0, 0, 0), warm_start_fisher_info = diag(6))
	expect_identical(priv$logbin_feasible_warm_start_args(X, interior), interior)
	dropped = priv$logbin_feasible_warm_start_args(X, list(warm_start_beta = priv$cached_mod$b, warm_start_fisher_info = diag(6)))
	expect_null(dropped$warm_start_beta)
	expect_null(dropped$warm_start_fisher_info)
})
