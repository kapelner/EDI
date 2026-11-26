library(testthat)
library(EDI)

# v1.0.6-TODO-112: fast_weibull_regression_cpp did not converge on covariates
# left on their raw scale (age in years, lymph-node counts) next to an
# intercept -- both L-BFGS and Newton-Raphson hit maxit with a gradient norm in
# the tens, and InferenceSurvivalWeibullRegr then dropped covariates
# (edi_covariate_dropped_warning). The kernel now standardizes badly scaled
# columns internally and maps every output back to the original scale.
# Reference: survival::survreg on the same design matrix. Data: the colon
# cancer trial (survival::colon, death endpoint, observation vs levamisole +
# 5-FU), as in the case-study article.

colon_weibull_data = function() {
	d = subset(survival::colon, etype == 2 & rx %in% c("Obs", "Lev+5FU"))
	covs = c("age", "sex", "obstruct", "perfor", "adhere", "nodes", "differ", "extent", "surg")
	Z = d[, covs]
	Z$nodes_is_missing = as.integer(is.na(Z$nodes))
	Z$differ_is_missing = as.integer(is.na(Z$differ))
	Z$nodes[is.na(Z$nodes)] = stats::median(Z$nodes, na.rm = TRUE)
	Z$differ[is.na(Z$differ)] = stats::median(Z$differ, na.rm = TRUE)
	list(
		Z = Z,
		w = as.integer(d$rx == "Lev+5FU"),
		y = as.numeric(d$time),
		dead = as.numeric(d$status == 1)
	)
}

survreg_reference = function(X, y, dead) {
	fit = survival::survreg(survival::Surv(y, dead) ~ X - 1, dist = "weibull",
		control = survival::survreg.control(rel.tolerance = 1e-12, maxiter = 100))
	list(coef = unname(stats::coef(fit)), vcov = unname(stats::vcov(fit)),
		log_sigma = log(fit$scale), loglik = fit$loglik[2])
}

rel_err = function(a, b) max(abs(a - b) / pmax(abs(b), 1e-8))

test_that("Weibull AFT kernel converges on raw-scale colon covariates and matches survreg", {
	skip_if_not_installed("survival")
	dat = colon_weibull_data()
	X = cbind("(Intercept)" = 1, treatment = dat$w, as.matrix(dat$Z))
	ref = survreg_reference(X, dat$y, dat$dead)
	p = ncol(X)

	for (alg in c("lbfgs", "newton_raphson")) {
		fit = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead, optimization_alg = alg)
		expect_true(isTRUE(fit$converged), info = alg)
		expect_false(isTRUE(fit$hit_iteration_cap), info = alg)
		expect_lt(fit$gradient_norm, 1e-4)
		expect_equal(fit$loglik, ref$loglik, tolerance = 1e-8)
		expect_lt(rel_err(fit$params[seq_len(p)], ref$coef), 1e-4)
		expect_lt(abs(fit$params[p + 1L] - ref$log_sigma), 1e-6)
		# treatment estimate and its standard error
		expect_lt(rel_err(fit$params[2], ref$coef[2]), 1e-4)
		expect_lt(rel_err(sqrt(fit$vcov[2, 2]), sqrt(ref$vcov[2, 2])), 1e-4)
		# whole covariance matrix ([beta, log_sigma]; survreg's last row is log(scale))
		expect_lt(max(abs(fit$vcov - ref$vcov) / sqrt(outer(diag(ref$vcov), diag(ref$vcov)))), 1e-4)
		# information on the original scale is the inverse of the reported vcov
		expect_equal(unname(fit$information %*% fit$vcov), diag(p + 1L), tolerance = 1e-6)
	}

	est = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead, estimate_only = TRUE)
	expect_true(isTRUE(est$converged))
	expect_lt(rel_err(est$b, ref$coef), 1e-4)

	# the general (left/interval-censoring) kernel on the same right-censored data
	gen = EDI:::fast_weibull_regression_general_cpp(
		X, ifelse(dat$dead == 1, dat$y, NA), ifelse(dat$dead == 1, NA, dat$y), ifelse(dat$dead == 1, NA, Inf))
	expect_true(isTRUE(gen$converged))
	expect_lt(rel_err(gen$params[seq_len(p)], ref$coef), 1e-4)
	expect_lt(rel_err(sqrt(gen$vcov[2, 2]), sqrt(ref$vcov[2, 2])), 1e-4)
})

test_that("Weibull AFT kernel is invariant to rescaling a covariate column", {
	skip_if_not_installed("survival")
	dat = colon_weibull_data()
	X = cbind("(Intercept)" = 1, treatment = dat$w, as.matrix(dat$Z))
	X_big = X
	X_big[, "age"] = X_big[, "age"] * 1000
	fit = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead)
	fit_big = EDI:::fast_weibull_regression_cpp(X_big, dat$y, dat$dead)
	expect_true(isTRUE(fit_big$converged))
	expect_lt(rel_err(fit_big$params[2], fit$params[2]), 1e-6)
	expect_lt(rel_err(sqrt(fit_big$vcov[2, 2]), sqrt(fit$vcov[2, 2])), 1e-6)
	expect_lt(rel_err(fit_big$params[3] * 1000, fit$params[3]), 1e-6)
	expect_equal(fit_big$loglik, fit$loglik, tolerance = 1e-10)
})

test_that("Weibull AFT kernel keeps fixed parameters fixed on the original scale", {
	skip_if_not_installed("survival")
	dat = colon_weibull_data()
	X = cbind("(Intercept)" = 1, treatment = dat$w, as.matrix(dat$Z))
	# treatment fixed at 0: the restricted fit is survreg without that column
	fit0 = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead, fixed_idx = 2L, fixed_values = 0)
	ref0 = survreg_reference(X[, -2], dat$y, dat$dead)
	expect_true(isTRUE(fit0$converged))
	expect_identical(fit0$params[2], 0)
	expect_equal(fit0$loglik, ref0$loglik, tolerance = 1e-8)
	expect_lt(rel_err(fit0$params[-c(2, ncol(X) + 1L)], ref0$coef), 1e-4)
	# a raw-scale covariate (age) fixed at a nonzero value
	ref = survreg_reference(X, dat$y, dat$dead)
	fit_age = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead, fixed_idx = 3L, fixed_values = ref$coef[3])
	expect_identical(fit_age$params[3], ref$coef[3])
	expect_lt(rel_err(fit_age$params[2], ref$coef[2]), 1e-4)
	# the intercept fixed at its MLE: the other columns are scaled but not centered
	fit_int = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead, fixed_idx = 1L, fixed_values = ref$coef[1])
	expect_true(isTRUE(fit_int$converged))
	expect_identical(fit_int$params[1], ref$coef[1])
	expect_lt(rel_err(fit_int$params[2], ref$coef[2]), 1e-4)
	# warm start from the original-scale optimum stays there
	fit_ws = EDI:::fast_weibull_regression_cpp(X, dat$y, dat$dead,
		warm_start_params = c(ref$coef, ref$log_sigma), warm_start_fisher_info = solve(ref$vcov))
	expect_true(isTRUE(fit_ws$converged))
	expect_lt(rel_err(fit_ws$params[seq_len(ncol(X))], ref$coef), 1e-6)
})

test_that("InferenceSurvivalWeibullRegr keeps every colon covariate and matches survreg", {
	skip_if_not_installed("survival")
	dat = colon_weibull_data()
	n = length(dat$y)
	des = DesignFixediBCRD$new(n = n, response_type = "survival", prob_T = mean(dat$w), verbose = FALSE)
	des$add_all_subjects_to_experiment(dat$Z)
	des$assign_w_to_all_subjects(w_precomputed = dat$w)
	died = dat$dead == 1
	des$add_all_subject_responses(ys = ifelse(died, dat$y, NA), y_Ls = ifelse(died, NA, dat$y),
		y_Rs = ifelse(died, NA, Inf))

	inf = expect_no_warning(InferenceSurvivalWeibullRegr$new(des), class = "edi_covariate_dropped_warning")
	est = expect_no_warning(inf$compute_estimate(), class = "edi_covariate_dropped_warning")
	ci = inf$compute_asymp_confidence_interval(0.05)

	X = inf$.__enclos_env__$private$build_design_matrix()
	expect_equal(ncol(X), 2L + ncol(dat$Z))
	ref = survreg_reference(X, dat$y, dat$dead)
	expect_lt(rel_err(as.numeric(est), ref$coef[2]), 1e-4)
	se = (ci[2] - ci[1]) / (2 * stats::qnorm(0.975))
	expect_lt(rel_err(unname(se), sqrt(ref$vcov[2, 2])), 1e-4)
})
