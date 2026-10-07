test_that("modified Poisson inference uses the Bernoulli robust sandwich variance", {
	set.seed(20261007L)
	n <- 80L
	w <- rep(c(0L, 1L), n / 2L)
	x <- seq(-1, 1, length.out = n)
	y <- stats::rbinom(n, 1, stats::plogis(-0.7 + 0.35 * w + 0.25 * x))

	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidModifiedPoisson$new(des, model_formula = ~ x, verbose = FALSE)

	expect_true(is.finite(inf$compute_estimate(estimate_only = FALSE)))
	priv <- inf$.__enclos_env__$private
	mod <- priv$cached_mod
	X <- cbind(`(Intercept)` = 1, treatment = w, x = x)
	bread <- solve(mod$fisher_information)
	resid <- y - as.numeric(mod$mu)
	expected <- (bread %*% crossprod(X * resid) %*% bread)[2L, 2L]

	expect_equal(mod$ssq_b_j, expected, tolerance = 1e-12)
	expect_equal(mod$ssq_b_2, expected, tolerance = 1e-12)
	expect_equal(priv$cached_values$s_beta_hat_T^2, expected, tolerance = 1e-12)
	expect_gt(abs(expected - bread[2L, 2L]), 1e-8)
})
