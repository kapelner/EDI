test_that("cloglog parametric simulation preserves the public coefficient sign", {
	set.seed(20261009)
	n = 180L
	x = rnorm(n)
	w = rep(0:1, each = n / 2L)
	eta = 0.8 * w + 0.3 * x
	cuts = c(-0.8, 0.3)
	cum_probs = cbind(
		1 - exp(-exp(cuts[1L] - eta)),
		1 - exp(-exp(cuts[2L] - eta))
	)
	u = runif(n)
	y = ifelse(u <= cum_probs[, 1L], 1L, ifelse(u <= cum_probs[, 2L], 2L, 3L))

	des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceOrdinalCloglogRegr$new(des, model_formula = ~ x, verbose = FALSE)
	observed = inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	spec = priv$get_likelihood_test_spec()

	set.seed(7812)
	refits = replicate(20L, {
		draw = priv$simulate_under_lik_null(spec, observed, spec$full_fit)
		if (is.null(draw)) return(NA_real_)
		-as.numeric(draw$full_fit$params[spec$j])
	})

	expect_gt(observed, 0.5)
	expect_gte(sum(is.finite(refits)), 18L)
	expect_gt(stats::median(refits, na.rm = TRUE), 0.5)
	expect_lt(abs(stats::median(refits, na.rm = TRUE) - observed), 0.6)
})

test_that("cloglog full-data multistart keeps the lower usable likelihood", {
	X = cbind(treatment = c(0, 1, 0, 1), x = c(-1, 0, 1, 2))
	y = c(1, 2, 3, 2)
	primary = list(
		params = c(-0.5, 0.5, 2, 0.1), b = c(2, 0.1),
		neg_loglik = 10, ssq_b_j = 0.4, fisher_information = diag(4)
	)
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, warm_start_params, ...){
			is_zero = identical(as.numeric(warm_start_params[3L]), 0)
			list(
				params = warm_start_params, b = warm_start_params[3:4],
				neg_loglik = if (is_zero) 7 else 11,
				fisher_information = diag(4), converged = TRUE
			)
		},
		fast_ordinal_cloglog_regression_with_var_cpp = function(X, y, warm_start_params, ...){
			list(
				params = warm_start_params, b = warm_start_params[3:4],
				neg_loglik = 7, ssq_b_j = 0.3,
				fisher_information = diag(4), converged = TRUE
			)
		},
		.package = "EDI"
	)
	selected = EDI:::.cloglog_full_data_multistart(X, y, primary, FALSE)
	expect_equal(selected$neg_loglik, 7)
	expect_equal(selected$params[3L], 0)
	expect_equal(selected$ssq_b_j, 0.3)
})
