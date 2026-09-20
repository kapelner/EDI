library(testthat)
library(EDI)

# weighted_weibull_bootstrap_surrogate_fit() (R/EDI/R/globals.R) is a shared
# helper used by 4 classes' compute_estimate_with_bootstrap_weights()
# (inference_survival_weibull.R, inference_survival_KK_weibull_marginal.R,
# inference_survival_GLMM_weibull_frailty_loggamma.R and _normal.R), but no
# test in the suite ever called it, directly or via any of those classes'
# bootstrap-weight paths (verified via repo-wide grep). Exercise it here via
# the simplest caller, InferenceSurvivalWeibullRegr, whose contract (survreg
# weibull surrogate fit, right-censoring only, constant-weight shortcut) is
# representative of all four callers since they share this one function.

make_weibull_bootstrap_fixture <- function() {
	set.seed(20260918)
	n <- 20L
	x1 <- rnorm(n)
	w <- rep(0:1, each = n / 2L)
	eta <- 1 + 0.5 * w + 0.3 * x1
	sigma <- 0.7
	u <- runif(n)
	t_true <- exp(eta + sigma * log(-log(1 - u)))
	cens <- rexp(n, rate = 0.05)
	y <- pmin(t_true, cens)
	dead <- as.numeric(t_true <= cens)

	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(
		ifelse(dead == 1, y, NA_real_),
		ifelse(dead == 0, y, NA_real_),
		ifelse(dead == 0, Inf, NA_real_)
	)

	inf <- InferenceSurvivalWeibullRegr$new(des, model_formula = ~x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	list(inf = inf, priv = priv, y = y, dead = dead, w = w, x1 = x1)
}

test_that("compute_estimate_with_bootstrap_weights matches an independent weighted survreg surrogate fit", {
	f <- make_weibull_bootstrap_fixture()
	rw <- runif(20L, 0.5, 2)

	est <- f$inf$compute_estimate_with_bootstrap_weights(rw)
	ref <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$w + f$x1, weights = rw, dist = "weibull")
	expect_equal(est, unname(coef(ref)["f$w"]), tolerance = 1e-8)
	# estimate_only doesn't change the point estimate; both flags return the same value
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rw, estimate_only = TRUE), est)
	# s_beta_hat_T is never populated by this fast surrogate path
	expect_true(is.na(f$priv$weighted_refit_se()))
})

test_that("effectively-constant weights shortcut to the primary MLE fit rather than the survreg surrogate", {
	f <- make_weibull_bootstrap_fixture()
	shortcut <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, 20L))
	direct <- f$inf$compute_estimate(estimate_only = TRUE)
	# Two separate primary-MLE optimizer runs (the shortcut's result is no longer cached and reused).
	expect_equal(shortcut, direct, tolerance = 1e-5)

	# a scaled-but-still-constant weight vector takes the same shortcut
	scaled <- f$inf$compute_estimate_with_bootstrap_weights(rep(3.5, 20L))
	expect_equal(scaled, direct, tolerance = 1e-5)

	# genuinely varying weights do NOT take the shortcut and differ from the primary fit
	rw <- runif(20L, 0.5, 2)
	weighted <- f$inf$compute_estimate_with_bootstrap_weights(rw)
	expect_false(isTRUE(all.equal(weighted, direct)))
})

test_that("unit weights via the surrogate fit reproduce an independent unweighted survreg fit", {
	f <- make_weibull_bootstrap_fixture()
	# unit weights are exactly constant, so this exercises the same shortcut path,
	# not the survreg fit itself -- call the shared helper directly instead to
	# confirm unit-weighted survreg output equals the unweighted survreg fit.
	X <- cbind(treatment = f$w, x1 = f$x1)
	fit_unit <- EDI:::weighted_weibull_bootstrap_surrogate_fit(f$y, f$dead, X, rep(1, 20L))
	ref_unweighted <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$w + f$x1, dist = "weibull")
	expect_equal(fit_unit$beta_hat, unname(coef(ref_unweighted)["f$w"]), tolerance = 1e-8)
})

test_that("left-/interval-censored data is rejected outright before reaching the surrogate fit", {
	set.seed(20260918)
	n <- 20L
	x1 <- rnorm(n)
	w <- rep(0:1, each = n / 2L)
	y <- rexp(n, rate = 0.2) + 1
	dead <- rep(c(1, 0), length.out = n)
	yL <- ifelse(dead == 1, NA_real_, y * 0.5)
	yR <- ifelse(dead == 1, NA_real_, y)

	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), yL, yR)

	inf <- InferenceSurvivalWeibullRegr$new(des, model_formula = ~x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(priv$has_general_censoring)
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	expect_error(
		inf$compute_estimate_with_bootstrap_weights(runif(n, 0.5, 2)),
		"not yet supported for left-/interval-censored"
	)
})

test_that("weighted_weibull_bootstrap_surrogate_fit returns NULL when every row is filtered out", {
	X <- cbind(treatment = c(1, 0, 1), x1 = c(0.1, 0.2, 0.3))
	expect_null(EDI:::weighted_weibull_bootstrap_surrogate_fit(c(1, 2, 3), c(1, 0, 1), X, c(0, 0, 0)))
	expect_null(EDI:::weighted_weibull_bootstrap_surrogate_fit(c(1, 2, 3), c(1, 0, 1), X, c(NA_real_, NA_real_, NA_real_)))
})
