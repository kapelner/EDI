test_that("Weibull Frailty Inference works for KK designs", {
	n <- 40
	# Use KK14 design to ensure we have matches
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	set.seed(1)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	# Generate some survival data with many events to ensure convergence
	y <- rexp(n, rate = 0.1)
	dead <- rep(1L, n)
	add_all_subject_responses_seq(des, y, deads = dead)

	# 1. Univariate IVWC (model_formula = ~ 1)
	inf_univ_ivwc <- InferenceSurvivalGLMMWeibullFrailtyNormalIVWC$new(des, model_formula = ~ 1, verbose = FALSE)
	est_univ_ivwc <- inf_univ_ivwc$compute_estimate()
	expect_true(is.numeric(est_univ_ivwc))
	expect_true(is.finite(est_univ_ivwc))
	
	ci_univ_ivwc <- inf_univ_ivwc$compute_asymp_confidence_interval()
	expect_length(ci_univ_ivwc, 2)
	expect_true(all(is.finite(ci_univ_ivwc)))

	# 2. Multivariate IVWC (default)
	inf_multi_ivwc <- InferenceSurvivalGLMMWeibullFrailtyNormalIVWC$new(des, verbose = FALSE)
	est_multi_ivwc <- inf_multi_ivwc$compute_estimate()
	expect_true(is.numeric(est_multi_ivwc))
	expect_true(is.finite(est_multi_ivwc))

	# 3. Univariate OneLik (model_formula = ~ 1)
	inf_univ_onelik <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, model_formula = ~ 1, verbose = FALSE)
	est_univ_onelik <- inf_univ_onelik$compute_estimate()
	expect_true(is.numeric(est_univ_onelik))
	expect_true(is.finite(est_univ_onelik))
	
	pv_univ_onelik <- inf_univ_onelik$compute_asymp_two_sided_pval()
	expect_true(is.numeric(pv_univ_onelik))
	expect_true(is.na(pv_univ_onelik) || (pv_univ_onelik >= 0 && pv_univ_onelik <= 1))

	# 4. Multivariate OneLik (default)
	inf_multi_onelik <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, verbose = FALSE)
	est_multi_onelik <- inf_multi_onelik$compute_estimate()
	expect_true(is.numeric(est_multi_onelik))
	expect_true(is.finite(est_multi_onelik))

	# 5. Likelihood tests are now enabled for OneLik
	expect_true("lik_ratio" %in% inf_univ_onelik$get_supported_testing_types())
	pv_lr  <- inf_univ_onelik$compute_lik_ratio_two_sided_pval()
	pv_sc  <- inf_univ_onelik$compute_score_two_sided_pval()
	pv_gr  <- inf_univ_onelik$compute_gradient_two_sided_pval()
	expect_true(is.finite(pv_lr)  && pv_lr  >= 0 && pv_lr  <= 1)
	expect_true(is.finite(pv_sc)  && pv_sc  >= 0 && pv_sc  <= 1)
	expect_true(is.finite(pv_gr)  && pv_gr  >= 0 && pv_gr  <= 1)
})

test_that("weibull frailty analytic score matches numerical gradient of its neg-loglik", {
	set.seed(10)
	n_pairs <- 15
	n <- 2 * n_pairs
	group_id <- rep(seq_len(n_pairs), each = 2)
	w <- rep(c(1, 0), n_pairs)
	x1 <- rnorm(n)
	X <- cbind(w = w, x1 = x1)
	u_g <- rnorm(n_pairs, sd = 0.5)[group_id]
	y <- rexp(n) * exp(0.6 * w - 0.2 * x1 + u_g)
	dead <- rbinom(n, 1, 0.8)
	params <- c(0.5, -0.3, 0.1, -0.5) # [beta_w, beta_x1, log_sigma_eps, log_sigma_u]

	score <- as.numeric(EDI:::get_weibull_frailty_score_cpp(X, y, dead, group_id, params))
	num_grad_negll <- numDeriv::grad(
		function(p) EDI:::get_weibull_frailty_neg_loglik_cpp(X, y, dead, group_id, p),
		params
	)
	# score is d(+loglik)/d params, the numerical gradient is of the NEGATIVE loglik
	expect_equal(score, -num_grad_negll, tolerance = 1e-5)
})

test_that("weibull frailty loglik collapses to survreg's weibull loglik as sigma_u -> 0", {
	set.seed(11)
	n_pairs <- 20
	n <- 2 * n_pairs
	group_id <- rep(seq_len(n_pairs), each = 2)
	w <- rep(c(1, 0), n_pairs)
	x1 <- rnorm(n)
	# exponentiate by 1.7 so the Weibull scale is far from 1 -- at scale 1 a
	# spurious 1/sigma factor on the loglik terms would go undetected
	y <- (rexp(n) * exp(0.5 * w + 0.3 * x1))^1.7
	dead <- rbinom(n, 1, 0.85)

	fit_r <- survival::survreg(survival::Surv(y, dead) ~ w + x1, dist = "weibull")
	X <- cbind(`(Intercept)` = 1, w = w, x1 = x1)
	params <- c(as.numeric(stats::coef(fit_r)), log(fit_r$scale), -8) # log_sigma_u at clamp floor

	neg_ll_frailty <- EDI:::get_weibull_frailty_neg_loglik_cpp(X, y, dead, group_id, params)
	expect_equal(neg_ll_frailty, -as.numeric(stats::logLik(fit_r)), tolerance = 1e-4)
})

test_that("weibull frailty one-lik fit carries an intercept and is unbiased under H0 with a nonzero baseline", {
	# Regression for the 2026-09-03 bug: the primary fit passed X = [w] (no
	# intercept) to fast_weibull_frailty_cpp, pinning the control arm's log-time
	# location at 0. With a nonzero baseline log-time the leftover location
	# leaked into beta_hat_T (H0 rejection ~50-70%).
	n = 200L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	set.seed(20260903)
	x1 = rnorm(n); x2 = rnorm(n)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
	}
	# beta_T = 0 with a nonzero baseline log-time (0.7) and a covariate signal
	# that KK matching turns into a pair-shared component -- the same shape as
	# the comprehensive-tests survival fixtures where the bias showed up.
	y = exp(0.7 + 0.6 * x1 + 0.3 * rnorm(n))
	add_all_subject_responses_seq(des, y, deads = rep(1L, n))

	inf = InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, model_formula = ~ 1, verbose = FALSE)
	est = inf$compute_estimate()
	ctx = inf$.__enclos_env__$private$cached_values$likelihood_test_context
	expect_identical(colnames(ctx$X)[1:2], c("w", "(Intercept)"))

	# The class estimate must be the with-intercept MLE ...
	fit_int = EDI:::fast_weibull_frailty_cpp(X = ctx$X, y = ctx$y, dead = ctx$dead, group_id = as.integer(ctx$group_id), estimate_only = FALSE)
	expect_equal(est, as.numeric(fit_int$b[1L]), tolerance = 1e-6)
	# ... and not the old intercept-free MLE, which is visibly biased on this data.
	fit_noint = EDI:::fast_weibull_frailty_cpp(X = ctx$X[, "w", drop = FALSE], y = ctx$y, dead = ctx$dead, group_id = as.integer(ctx$group_id), estimate_only = FALSE)
	expect_gt(abs(as.numeric(fit_noint$b[1L])), abs(est))
	expect_lt(abs(est), 0.15)

	# Multivariate path keeps [w, (Intercept), covariates...] ordering too.
	inf_multi = InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	est_multi = inf_multi$compute_estimate()
	ctx_multi = inf_multi$.__enclos_env__$private$cached_values$likelihood_test_context
	expect_identical(colnames(ctx_multi$X)[1:2], c("w", "(Intercept)"))
	expect_true(all(c("x1", "x2") %in% colnames(ctx_multi$X)))
	expect_lt(abs(est_multi), 0.15)
})
