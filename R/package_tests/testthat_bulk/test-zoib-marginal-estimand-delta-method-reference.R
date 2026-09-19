library(testthat)
library(EDI)

# inference_proportion_zero_one_inflated_beta.R's "marginal_mean_diff" estimand
# has two distinct code paths that were only smoke-tested for boundedness/
# finiteness before this file (test-zoib-marginal-estimand.R):
#  (a) compute_marginal_mean_diff_estimate() (lines ~419-445): joint-MLE fit
#      (fast_zero_one_inflated_beta_cpp), delta-method SE via the shared
#      marginal_estimand_delta_se() helper (central-difference gradient).
#  (b) compute_estimate_with_bootstrap_weights()'s marginal overwrite (lines
#      ~325-337): a DIFFERENT estimator -- three separate weighted fits
#      (two weighted logistic regressions for the zero/one submodels via
#      fast_logistic_regression_weighted_cpp, one weighted betareg/lm.wfit
#      for the mid-interval beta submodel) -- combined via the same
#      zoib_marginal_mean_diff_from_coefs() g-computation formula, but on
#      genuinely different fitted coefficients than (a). This file verifies
#      each against its own independent reference.

simulate_zoib_design = function(seed = 1L, n = 250L, beta_T = 0.6){
	set.seed(seed)
	seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	x1 = rnorm(n)
	for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
	w = seq_des$get_w()
	lin = 0.3 + beta_T * w + 0.4 * x1
	mu = plogis(lin)
	p0 = plogis(-2 - 0.2 * w)
	p1 = plogis(-2 + 0.1 * w)
	u = runif(n)
	y = numeric(n)
	for (i in seq_len(n)) {
		if (u[i] < p0[i]) {
			y[i] = 0
		} else if (u[i] < p0[i] + p1[i]) {
			y[i] = 1
		} else {
			y[i] = rbeta(1L, mu[i] * 8, (1 - mu[i]) * 8)
		}
	}
	seq_des$add_all_subject_responses(y)
	seq_des
}

# Independent re-derivation (from the model definition, not the package's
# private methods) of the ZOIB mixture mean given already-fit submodel
# coefficients, and the g-computation mean-difference functional built on it.
independent_zoib_mean_from_coefs = function(b_beta, b_zero, b_one, X, X_zero_one) {
	mu  = 1 / (1 + exp(-as.numeric(X %*% b_beta)))
	pi0 = 1 / (1 + exp(-as.numeric(X_zero_one %*% b_zero)))
	pi1 = 1 / (1 + exp(-as.numeric(X_zero_one %*% b_one)))
	pi_mid = pmax(1 - pi0 - pi1, 0)
	denom = pi0 + pi1 + pi_mid
	denom[!is.finite(denom) | denom <= 0] = 1
	(pi1 + pi_mid * mu) / denom
}
independent_zoib_marginal_diff_from_coefs = function(b_beta, b_zero, b_one, X, X_zero_one) {
	X1 = X; X1[, 2L] = 1
	X0 = X; X0[, 2L] = 0
	XZ1 = X_zero_one; XZ1[, 2L] = 1
	XZ0 = X_zero_one; XZ0[, 2L] = 0
	mean(
		independent_zoib_mean_from_coefs(b_beta, b_zero, b_one, X1, XZ1) -
		independent_zoib_mean_from_coefs(b_beta, b_zero, b_one, X0, XZ0)
	)
}
independent_zoib_marginal_diff_functional = function(theta, X, X_zero_one, p, q) {
	b_beta = theta[seq_len(p)]
	b_zero = theta[(p + 2L):(p + 1L + q)]
	b_one  = theta[(p + 2L + q):(p + 1L + 2L * q)]
	independent_zoib_marginal_diff_from_coefs(b_beta, b_zero, b_one, X, X_zero_one)
}

test_that("marginal_mean_diff joint-MLE point estimate and delta-method SE agree with an independent gradient", {
	skip_if_not_installed("numDeriv")
	seq_des = simulate_zoib_design(11L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	est = inf$compute_estimate()

	priv = inf$.__enclos_env__$private
	mod = priv$cached_mod
	p = ncol(mod$X); q = ncol(mod$X_zero_one)
	expect_equal(length(mod$params), p + 1L + 2L * q)

	ind_est = independent_zoib_marginal_diff_functional(mod$params, mod$X, mod$X_zero_one, p, q)
	expect_equal(est, ind_est, tolerance = 1e-8)

	grad_ind = numDeriv::grad(
		function(theta) independent_zoib_marginal_diff_functional(theta, mod$X, mod$X_zero_one, p, q),
		mod$params
	)
	se_ind = sqrt(as.numeric(t(grad_ind) %*% mod$vcov %*% grad_ind))
	expect_true(is.finite(se_ind) && se_ind > 0)
	se_pkg = priv$cached_values$s_beta_hat_T
	expect_equal(se_pkg, se_ind, tolerance = 1e-3)

	# Wald CI/p-value consistency with the (now independently verified) point/SE.
	alpha = 0.05
	ci = inf$compute_asymp_confidence_interval(alpha = alpha)
	z = qnorm(1 - alpha / 2)
	expect_equal(unname(ci), est + c(-1, 1) * z * se_pkg, tolerance = 1e-6)
	pv = inf$compute_asymp_two_sided_pval()
	expect_equal(pv, 2 * pnorm(-abs(est / se_pkg)), tolerance = 1e-6)
})

test_that("marginal_mean_diff estimate is invariant to conditional/marginal estimand switching (cached fit reused)", {
	seq_des = simulate_zoib_design(12L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$compute_estimate()  # conditional first
	inf$set_estimand("marginal_mean_diff")
	est_after_switch = inf$compute_estimate()

	inf_direct = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_direct$set_estimand("marginal_mean_diff")
	est_direct = inf_direct$compute_estimate()

	expect_equal(est_after_switch, est_direct, tolerance = 1e-10)
})

test_that("compute_estimate_with_bootstrap_weights under marginal_mean_diff uses a genuinely different (three-separate-fits) estimator, verified independently", {
	seq_des = simulate_zoib_design(13L, n = 150L)
	inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf$set_estimand("marginal_mean_diff")
	priv0 = inf$.__enclos_env__$private
	priv0$current_bayesian_bootstrap_context = priv0$build_bayesian_bootstrap_context()
	w = rep(1, 150L)
	boot_est = inf$compute_estimate_with_bootstrap_weights(w, estimate_only = TRUE)
	expect_true(is.finite(boot_est))

	priv = inf$.__enclos_env__$private
	X = priv$build_component_matrix(priv$model_formula, priv$best_X_colnames)
	X_zero_one = priv$build_component_matrix(priv$model_formula_zero_one, priv$best_X_zero_one_colnames)
	y = as.numeric(priv$y)
	is_zero = as.numeric(y == 0); is_one = as.numeric(y == 1); is_mid = y > 0 & y < 1

	zero_fit_ind = glm(is_zero ~ X_zero_one[, -1, drop = FALSE], family = binomial(), weights = w)
	one_fit_ind  = glm(is_one  ~ X_zero_one[, -1, drop = FALSE], family = binomial(), weights = w)
	# Mirrors the source's own betareg-then-lm.wfit-on-logit cascade (source
	# lines ~271-297): with this data and the package's start=list(phi=10),
	# betareg's optimizer hits a non-finite initial value and errors, so the
	# ACTUAL behavior being exercised here is the lm.wfit fallback, not
	# betareg itself -- confirmed independently below, not assumed.
	beta_fit_ind = tryCatch(
		betareg::betareg(y ~ ., data = data.frame(X[is_mid, -1, drop = FALSE], y = y[is_mid]),
		                  weights = w[is_mid], control = betareg::betareg.control(start = list(phi = 10))),
		error = function(e) NULL
	)
	b_beta_ind = if (!is.null(beta_fit_ind)) {
		coef(beta_fit_ind)[colnames(X)]
	} else {
		coef(lm.wfit(x = X[is_mid, , drop = FALSE], y = qlogis(y[is_mid]), w = w[is_mid]))
	}
	expect_true(is.null(beta_fit_ind))  # documents the fallback actually triggers on this fixture

	ind_est = independent_zoib_marginal_diff_from_coefs(
		b_beta_ind, coef(zero_fit_ind), coef(one_fit_ind), X, X_zero_one
	)
	expect_equal(boot_est, ind_est, tolerance = 1e-6)

	# This is a distinct estimator from the joint-MLE conditional-path fit --
	# confirm it does NOT trivially collapse to the same joint-MLE marginal
	# estimate on the same data (proves the separate-fits path is real, not
	# accidentally routed through compute_estimate()'s cached_mod).
	inf_joint = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
	inf_joint$set_estimand("marginal_mean_diff")
	joint_est = inf_joint$compute_estimate(estimate_only = TRUE)
	expect_false(isTRUE(all.equal(boot_est, joint_est, tolerance = 1e-6)))
})
