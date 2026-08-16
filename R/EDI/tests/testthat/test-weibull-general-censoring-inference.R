library(testthat)
library(EDI)

# interval_censored_survival_response.md TODO-5: unit tests for
# InferenceSurvivalWeibullRegr's *class-level* end-to-end behavior under
# general censoring (complementing TODO-3's kernel-level tests in
# test-weibull-general-censoring.R, which never touch the R6 class). Also
# pins down that exact/right-censored data produces numerically identical
# results whether or not the general-censoring dispatch machinery exists at
# all -- i.e. the "benchmark confirming the exact/right-censored paths are
# unchanged" TODO-5 asks for, done here as a correctness regression rather
# than a timing check (timing is covered separately by the
# weibull_general_est entry in R/profile/edi_kernel_profiler.R).

make_interval_censored_design = function(seed, n = 400L, beta_true = 0.5, sigma_true = 1.1, g = 0.5){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = beta_true * w + 0.2 * X$x1
	u = runif(n)
	true_time = exp(eta + sigma_true * log(-log(1 - u)))
	y_L = floor(true_time / g) * g
	y_R = y_L + g
	des$add_all_subject_responses(y_Ls = y_L, y_Rs = y_R)
	list(des = des, beta_true = beta_true)
}

make_left_censored_design = function(seed, n = 400L, beta_true = 0.5, sigma_true = 1.1, cens_quantile = 0.3){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = beta_true * w + 0.2 * X$x1
	u = runif(n)
	true_time = exp(eta + sigma_true * log(-log(1 - u)))
	thresh = as.numeric(quantile(true_time, cens_quantile))
	y_exact = ifelse(true_time > thresh, true_time, NA_real_)
	y_L = ifelse(true_time > thresh, NA_real_, 0)
	y_R = ifelse(true_time > thresh, NA_real_, thresh)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	list(des = des, beta_true = beta_true)
}

test_that("InferenceSurvivalWeibullRegr recovers the true treatment effect under interval censoring", {
	setup = make_interval_censored_design(seed = 2001L)
	inf = InferenceSurvivalWeibullRegr$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	expect_true(isTRUE(priv$has_general_censoring))
	est = as.numeric(inf$compute_estimate())[1L]
	expect_true(is.finite(est))
	expect_equal(est, setup$beta_true, tolerance = 0.3)

	ci = inf$compute_asymp_confidence_interval()
	pv = inf$compute_asymp_two_sided_pval()
	expect_true(all(is.finite(ci)))
	expect_true(ci[1] < est && est < ci[2])
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("InferenceSurvivalWeibullRegr recovers the true treatment effect under left censoring", {
	setup = make_left_censored_design(seed = 2002L)
	inf = InferenceSurvivalWeibullRegr$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	expect_true(isTRUE(priv$has_general_censoring))
	est = as.numeric(inf$compute_estimate())[1L]
	expect_true(is.finite(est))
	expect_equal(est, setup$beta_true, tolerance = 0.3)
})

test_that("InferenceSurvivalWeibullRegr recovers the true treatment effect under mixed exact/right/interval censoring", {
	set.seed(2003L)
	n = 400L
	beta_true = 0.5
	sigma_true = 1.1
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	eta = beta_true * w + 0.2 * X$x1
	u = runif(n)
	true_time = exp(eta + sigma_true * log(-log(1 - u)))

	group = sample(1:3, n, replace = TRUE)
	g = 0.5
	y_exact = ifelse(group == 1, true_time, NA_real_)
	y_L = ifelse(group == 1, NA_real_, ifelse(group == 2, floor(true_time / 5) * 5, floor(true_time / g) * g))
	y_R = ifelse(group == 1, NA_real_, ifelse(group == 2, Inf, floor(true_time / g) * g + g))
	des$add_all_subject_responses(y_exact, y_L, y_R)

	inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(isTRUE(priv$has_general_censoring))
	expect_equal(sum(is.na(priv$y)), sum(group != 1))

	est = as.numeric(inf$compute_estimate())[1L]
	expect_true(is.finite(est))
	expect_equal(est, beta_true, tolerance = 0.3)
})

test_that("InferenceSurvivalWeibullRegr's estimate/CI/pval match the general kernel on exact/right-censored data", {
	set.seed(2004L)
	n = 200L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y_raw = rexp(n, rate = 0.15 * exp(0.4 * w + 0.1 * X$x1))
	dead = rbinom(n, 1, 0.75)
	y_L = ifelse(dead == 1, NA_real_, y_raw)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	y_exact = ifelse(dead == 1, y_raw, NA_real_)
	des$add_all_subject_responses(y_exact, y_L, y_R)

	inf = InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_false(isTRUE(priv$has_general_censoring))

	est = as.numeric(inf$compute_estimate())[1L]
	ci = inf$compute_asymp_confidence_interval()
	pv = inf$compute_asymp_two_sided_pval()

	X_full = priv$build_design_matrix()
	fit_direct = fast_weibull_regression_general_cpp(X_full, priv$y, priv$y_L, priv$y_R)
	expect_true(isTRUE(fit_direct$converged))
	expect_equal(est, as.numeric(fit_direct$params[2L]), tolerance = 1e-8)
	expect_true(all(is.finite(ci)))
	expect_true(is.finite(pv))
})

test_that("guards fire with a clear message under general censoring and are absent for exact/right-censored data", {
	setup_gen = make_interval_censored_design(seed = 2005L, n = 150L)
	inf_gen = InferenceSurvivalWeibullRegr$new(setup_gen$des, verbose = FALSE)
	expect_error(inf_gen$compute_bayesian_bootstrap_two_sided_pval(B = 11, show_progress = FALSE), "not yet supported")
	expect_error(inf_gen$compute_lik_ratio_bartlett_approx_two_sided_pval(), "not yet supported|Bartlett")
	expect_error(inf_gen$compute_rand_two_sided_pval(r = 11, delta = 0.1, show_progress = FALSE), "nonzero null shift")
	# delta = 0 must NOT be blocked by the general-censoring guard
	expect_no_error(inf_gen$compute_rand_two_sided_pval(r = 11, delta = 0, show_progress = FALSE))
})
