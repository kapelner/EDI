# v1.0.6-TODO-161: on unscaled covariates (survival::colon: age in years, node
# counts, times in days) the Weibull AFT lbfgs fit stopped at its iteration cap
# short of the optimum, so InferenceSurvivalWeibullRegr judged the full fit
# unusable and dropped real covariates (edi_covariate_dropped_warning). A failed
# fit now retries on standardized columns and polishes on the original scale.

colon_weibull_design = function() {
	d = subset(survival::colon, etype == 2 & rx %in% c("Obs", "Lev+5FU"))
	d$w = as.integer(d$rx == "Lev+5FU")
	covs = c("age", "sex", "obstruct", "perfor", "adhere", "nodes", "differ", "extent", "surg")
	d = d[stats::complete.cases(d[, covs]), ]
	des = DesignFixediBCRD$new(n = nrow(d), response_type = "survival", prob_T = mean(d$w), verbose = FALSE)
	des$add_all_subjects_to_experiment(d[, covs])
	des$assign_w_to_all_subjects(w_precomputed = d$w)
	died = d$status == 1
	des$add_all_subject_responses(ys = ifelse(died, d$time, NA), y_Ls = ifelse(died, NA, d$time),
	                              y_Rs = ifelse(died, NA, Inf))
	list(des = des, d = d, covs = covs)
}

test_that("Weibull fit on unscaled colon covariates keeps every covariate and matches survreg", {
	skip_if_not_installed("survival")
	z = colon_weibull_design()
	wb = InferenceSurvivalWeibullRegr$new(z$des, verbose = FALSE)
	wb$num_cores = 1L
	expect_no_warning(est <- wb$compute_estimate(), class = "edi_covariate_dropped_warning")
	ci = wb$compute_asymp_confidence_interval(alpha = 0.05)
	expect_setequal(wb$.__enclos_env__$private$best_X_colnames, z$covs)

	f = stats::as.formula(paste("survival::Surv(time, status) ~ w +", paste(z$covs, collapse = " + ")))
	sr = survival::survreg(f, data = z$d, dist = "weibull")
	expect_equal(est, unname(stats::coef(sr)["w"]), tolerance = 1e-4)
	se = (ci[2] - ci[1]) / (2 * stats::qnorm(0.975))
	expect_equal(unname(se), unname(sqrt(stats::vcov(sr)["w", "w"])), tolerance = 1e-3)

	expect_no_warning(p_lr <- wb$compute_lik_ratio_two_sided_pval(), class = "edi_covariate_dropped_warning")
	sr0 = survival::survreg(stats::update(f, . ~ . - w), data = z$d, dist = "weibull")
	expect_equal(p_lr, stats::pchisq(2 * (sr$loglik[2] - sr0$loglik[2]), df = 1, lower.tail = FALSE),
	             tolerance = 1e-3)
})

test_that("standardized retry maps the solution back to the original columns", {
	skip_if_not_installed("survival")
	z = colon_weibull_design()
	wb = InferenceSurvivalWeibullRegr$new(z$des, verbose = FALSE)
	p = wb$.__enclos_env__$private
	X = p$build_design_matrix()
	X[, 1L] = 2  # a non-unit constant column still absorbs the centering
	fit_X = function(X_try, ws) fast_weibull_regression_cpp(X = X_try, y = p$y, dead = p$dead, warm_start_params = ws)
	# Whether this unscaled fit hits its iteration cap depends on the compiler/BLAS:
	# it does locally but converges on GitHub's R CMD check runners (2026-11-19). The
	# retry below does not depend on it: it refits on standardized columns and maps back.
	failed = fit_X(X, NULL)
	res = weibull_fit_standardized_retry(fit_X, X, failed_res = failed)
	expect_true(isTRUE(res$converged))
	sr = survival::survreg(survival::Surv(p$y, p$dead) ~ X - 1, dist = "weibull")
	expect_equal(unname(res$params[seq_len(ncol(X))]), unname(stats::coef(sr)), tolerance = 1e-4)
	# a fit that cannot be rescued is returned unchanged
	expect_identical(weibull_fit_standardized_retry(function(X_try, ws) NULL, X, failed_res = failed), failed)
})

# v1.0.6-TODO-163 (docs-scenarios survival-censoring F1): on installed 1.0.4 the default L-BFGS fit
# stopped short of the MLE (0.4776586 vs survreg 0.4771847); fixed by the internal column scaling.
test_that("default Weibull AFT fit matches survreg on the survival-censoring F1 repro", {
	skip_if_not_installed("survival")
	set.seed(20261118); n = 80
	X = data.frame(age = round(rnorm(n, 62, 9)), ecog = sample(0:1, n, replace = TRUE))
	des = DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects(); w = des$get_w()
	t_ev = rweibull(n, shape = 1.3, scale = 10 * exp(0.5 * w - 0.02 * (X$age - 62) - 0.3 * X$ecog))
	fu = round(18 - runif(n, 0, 10), 2); obs = t_ev <= fu; tm = ifelse(obs, round(t_ev, 2), fu)
	des$add_all_subject_responses(ys = ifelse(obs, tm, NA), y_Ls = ifelse(obs, NA, tm), y_Rs = ifelse(obs, NA, Inf))
	inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	g = survival::survreg(survival::Surv(tm, as.integer(obs)) ~ w + age + ecog, data = X, dist = "weibull")
	expect_equal(inf$compute_estimate(), unname(coef(g)["w"]), tolerance = 1e-6)
	inf$set_optimization_alg("newton_raphson")
	expect_equal(inf$compute_estimate(), unname(coef(g)["w"]), tolerance = 1e-6)
})
