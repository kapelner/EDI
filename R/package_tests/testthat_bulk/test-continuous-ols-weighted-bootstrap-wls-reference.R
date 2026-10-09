library(testthat)
library(EDI)

test_that("continuous OLS weighted refit and SE match lm.wfit reference", {
	set.seed(20261009L)
	n <- 80L
	x1 <- rnorm(n)
	x2 <- 0.7 * x1 + rnorm(n, sd = 0.4)
	w <- rep(c(0, 1), length.out = n)
	y <- 0.4 * w + 0.6 * x1 - 0.3 * x2 + rnorm(n, sd = 0.8)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1, x2 = x2))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceContinOLS$new(des, model_formula = ~ ., verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	weights <- rexp(n)

	got <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	X <- priv$create_design_matrix()
	ref <- lm.wfit(X, y, weights)
	df <- n - length(coef(ref))
	ref_se <- sqrt(
		sum(weights * ref$residuals^2) / df *
			solve(crossprod(X * sqrt(weights)))[2L, 2L]
	)

	expect_equal(got, unname(coef(ref)[2L]), tolerance = 1e-10)
	expect_equal(priv$last_weighted_refit$s_beta_hat_T, ref_se, tolerance = 1e-10)
	expect_equal(priv$last_weighted_refit$df, df)
})
