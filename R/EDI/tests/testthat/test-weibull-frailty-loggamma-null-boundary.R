library(testthat)
library(EDI)

# TODO-121 third batch: InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik with
# testing_type = "lik_ratio" returned NA on an all-matched KK design because the
# NULL refit (beta_T fixed at delta) drives the Clayton dependence log(theta) to
# -16 and below -- the no-frailty (theta -> 0) boundary -- where the native
# kernel's logA = log(e^{theta h1} + e^{theta h2} - 1) cancels to 0 and the
# log-likelihood is NaN.  .clayton_weibull_null_fit_robust() falls back to
# multi-start with log(theta) fixed at a documented floor (-12) when the plain
# warm-started fit is non-finite / unconverged / below the floor.

make_t121c = function(formula = ~ x1, kk14 = FALSE, n = 40L, seed = 2L, gsd = 0.3) {
	set.seed(seed)
	x1 = rnorm(n)
	if (!kk14) {
		des = DesignFixedBinaryMatch$new(
			response_type = "survival", n = n, m = rep(seq_len(n / 2L), each = 2L),
			design_formula = formula, verbose = FALSE
		)
		des$add_all_subjects_to_experiment(data.frame(x1 = x1))
		w = as.vector(replicate(n / 2L, sample(0:1)))
		des$assign_w_to_all_subjects(w)
	} else {
		des = DesignSeqOneByOneKK14$new(response_type = "survival", n = n, design_formula = formula, verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
		w = des$get_w()
	}
	g = rep(rnorm(n / 2L, 0, gsd), each = 2L)
	y = rexp(n, exp(-(0.4 * w + g)))
	if (!kk14) des$add_all_subject_responses(y) else for (i in seq_len(n)) des$add_one_subject_response(i, y[i])
	des
}

pv4 = function(inf) vapply(c("wald", "score", "lik_ratio", "gradient"), function(tt) {
	inf$set_testing_type(tt)
	suppressWarnings(inf$compute_asymp_two_sided_pval(0))
}, numeric(1))

lr_stat = function(inf) {
	sp = inf$.__enclos_env__$private$get_likelihood_test_spec()
	f0 = sp$fit_null(0)
	list(stat = 2 * (sp$neg_loglik(f0) - sp$neg_loglik(sp$full_fit)),
		null_lt = sp$extract_start(f0)[length(sp$extract_start(f0))], f0 = f0)
}

test_that("all-matched null refit at the no-frailty boundary gives a finite LR p-value (was NA)", {
	inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(make_t121c(~ x1), verbose = FALSE)
	inf$compute_estimate()
	p = pv4(inf)
	expect_true(all(is.finite(p)))
	expect_gt(p[["lik_ratio"]], 0)
	expect_lt(p[["lik_ratio"]], 0.05)
	# same ballpark as Wald / score (all strongly significant, p < 0.01 on the log scale of 2.5 decades)
	expect_lt(abs(log10(p[["lik_ratio"]]) - log10(p[["wald"]])), 2.5)
	expect_lt(abs(log10(p[["lik_ratio"]]) - log10(p[["score"]])), 2.5)
	r = lr_stat(inf)
	expect_true(isTRUE(r$f0$converged))
	expect_true(is.finite(r$stat))
	expect_gte(r$stat, 0)
	expect_gte(r$null_lt, -12 - 1e-8)  # documented log-theta floor for null refits
})

test_that("pairs + reservoir KK14 fixture is unchanged by the robust null refit", {
	inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(make_t121c(~ x1, kk14 = TRUE), verbose = FALSE)
	inf$compute_estimate()
	p = pv4(inf)
	# 2026-10-23 post-build verification (G1, cpp patch 03 / TODO-121 3rd batch): Wald was
	# 0.50572. This fit sits at log(theta) = -8.92, inside patch 03's stable-logA gate; the old
	# logA cancellation noise swamped the tiny log-theta information (I_tt ~ 1.7e-7), so the
	# finite-difference Hessian effectively dropped the beta_T/log-theta coupling (SE 0.3165,
	# = survreg's conditional-on-theta SE 0.31683). The patched kernel gives the full-information
	# SE 0.32638, matching an R central-difference Hessian of the score (0.32655, stable for
	# h = 1e-2..1e-5). Score / LR / gradient are unchanged.
	expect_equal(unname(p), c(0.51851, 0.50294, 0.50955, 0.51205), tolerance = 2e-4)
	# well-behaved fit returns the plain kernel result: no fallback marker
	expect_null(lr_stat(inf)$f0$log_theta_null_floor_fallback)
})

test_that("true frailty variance 0 (boundary): LR finite, >= 0 and close to Wald", {
	for (seed in c(2L, 3L)) {
		inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(make_t121c(~ x1, seed = seed, gsd = 0), verbose = FALSE)
		inf$compute_estimate()
		p = pv4(inf)
		expect_true(all(is.finite(p)), info = seed)
		expect_lt(abs(p[["lik_ratio"]] - p[["wald"]]), 0.1)
		expect_gte(lr_stat(inf)$stat, -1e-6)
	}
})

test_that(".clayton_weibull_null_fit_robust is a pass-through when the warm-started fit is valid", {
	inf = InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(make_t121c(~ x1, kk14 = TRUE), verbose = FALSE)
	inf$compute_estimate()
	sp = inf$.__enclos_env__$private$get_likelihood_test_spec()
	st = sp$extract_start(sp$full_fit)
	direct = EDI:::fast_clayton_weibull_aft_optim_cpp(X = sp$X, y = sp$y, dead = sp$dead,
		pair_idx = sp$pair_idx, singleton_rows = sp$singleton_rows, warm_start_params = st,
		estimate_only = FALSE, fixed_idx = sp$j, fixed_values = 0)
	rob = EDI:::.clayton_weibull_null_fit_robust(sp$X, sp$y, sp$dead, sp$pair_idx, sp$singleton_rows,
		sp$j, 0, st)
	expect_equal(rob$neg_loglik, direct$neg_loglik, tolerance = 1e-12)
	expect_equal(as.numeric(rob$params), as.numeric(direct$params), tolerance = 1e-10)
})
