# v1.0.6-TODO-192: the g-computation weighted refit (Bayesian bootstrap and other weighted
# resampling) chains each replicate's coefficients into the next replicate's warm start. The KK
# class cached every fit, converged or not: one diverged IRLS fit (|b| ~ 1e9 after 100 iterations)
# then made every later replicate of the chain garbage (RR exactly 1, NA SE). The non-KK class
# kept usable but non-converged fits and dropped covariates on a fit a cold start would have
# converged. Now a fit is accepted only if it converged and its coefficients are usable;
# otherwise it is retried from the full-data warm start and then cold, and a failed fit is never
# cached. Data: rep 102 of the v1.0.6-TODO-168 coverage study, whose replicate chain diverged
# from the warm start (-0.70, 2.24, 3.18, -1.38).

make_gcomp_rep102_design = function(){
	set.seed(100102)
	n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w + 0.4 * X$x1)))
	des
}

diverging_warm_start = c(-0.70, 2.24, 3.18, -1.38)

test_that("KK g-computation weighted refit does not keep a diverged warm-start fit", {
	des = make_gcomp_rep102_design()
	n = des$get_t()
	for (cls in c("InferenceIncidKKGCompRiskRatio", "InferenceIncidKKGCompRiskDiff")) {
		inf = get(cls)$new(des, verbose = FALSE)
		priv = inf$.__enclos_env__$private
		est = as.numeric(inf$compute_estimate())
		expect_true(is.finite(est), info = cls)
		X_fit = as.matrix(priv$build_design_matrix())
		# The chained start really diverges at unit weights.
		bad = fast_logistic_regression_weighted_cpp(X = X_fit, y = as.numeric(priv$y), weights = rep(1, n),
			warm_start_beta = diverging_warm_start, warm_start_fisher_info = priv$get_fit_warm_start_fisher(4L))
		expect_false(isTRUE(bad$converged), info = cls)

		priv$gcomp_boot_beta = diverging_warm_start
		val = priv$compute_weighted_gcomp_estimate(rep(1, n), with_se = TRUE)
		# Unit weights reproduce the full-data fit, with a finite SE.
		expect_equal(as.numeric(val), est, tolerance = 1e-8, info = cls)
		expect_true(is.finite(attr(val, "se")) && attr(val, "se") > 0, info = cls)
		# The cached warm start is the converged fit, not the diverged one.
		expect_true(all(is.finite(priv$gcomp_boot_beta)), info = cls)
		expect_lt(max(abs(priv$gcomp_boot_beta)), 25)
	}
})

test_that("non-KK g-computation weighted refit retries a diverged warm start before dropping covariates", {
	des = make_gcomp_rep102_design()
	n = des$get_t()
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	est = as.numeric(inf$compute_estimate())
	expect_true(is.finite(est))
	priv$gcomp_boot_beta = diverging_warm_start
	effects = priv$weighted_gcomp_effects_from_row_weights(rep(1, n))
	expect_false(is.null(effects))
	# The full model is kept (no covariate dropped) and matches the full-data fit.
	expect_identical(ncol(effects$fit$X), 4L)
	expect_equal(effects$rr, est, tolerance = 1e-8)
	expect_lt(max(abs(priv$gcomp_boot_beta)), 25)
})

test_that("KK g-computation Bayesian bootstrap chain stays finite on the rep-102 data", {
	des = make_gcomp_rep102_design()
	inf = InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	priv = inf$.__enclos_env__$private
	inf$compute_estimate()
	# Before the fix, seed 1 hit the diverged fit at replicate 166; every replicate after it
	# returned RR = 1 with an NA SE.
	set.seed(1)
	st = priv$approximate_bayesian_bootstrap_statistics_beta_hat_T(B = 250, show_progress = FALSE,
		na.rm = FALSE, require_se = TRUE)
	expect_true(all(is.finite(st$theta)))
	expect_true(all(is.finite(st$se) & st$se > 0))
	expect_false(any(st$theta == 1))
})
