test_that("continuation-ratio null refit chooses the better constrained start", {
	set.seed(4201)
	n = 90L
	x = rnorm(n)
	w = rep(0:1, each = n / 2L)
	latent = 0.35 * w + 0.25 * x + rlogis(n)
	y = as.integer(cut(latent, breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE))
	des = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf = InferenceOrdinalContRatioRegr$new(des, model_formula = ~ x, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
	priv = inf$.__enclos_env__$private
	spec = priv$get_likelihood_test_spec()
	delta = 0.125

	starts = list()
	local_mocked_bindings(
		fast_continuation_ratio_regression_cpp = function(
			X, y, warm_start_beta = NULL, fixed_idx = NULL, fixed_values = NULL, ...
		){
			starts[[length(starts) + 1L]] <<- list(value = warm_start_beta)
			is_full_start = !is.null(warm_start_beta) &&
				isTRUE(all.equal(warm_start_beta[fixed_idx], fixed_values)) &&
				all(abs(warm_start_beta[-fixed_idx] - (spec$full_fit$params[-fixed_idx] + 1e-3)) < 1e-12)
			if (is.null(warm_start_beta)) warm_start_beta = spec$full_fit$params
			list(
				params = warm_start_beta,
				neg_loglik = if (is_full_start) 2 else 7,
				converged = TRUE,
				fisher_information = diag(length(warm_start_beta))
			)
		},
		.package = "EDI"
	)
	fit = spec$fit_null(delta)

	expect_length(starts, 2L)
	expect_equal(fit$neg_loglik, 2)
	expect_equal(fit$params[spec$j], delta)
})
