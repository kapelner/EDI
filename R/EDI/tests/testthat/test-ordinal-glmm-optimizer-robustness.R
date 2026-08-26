library(testthat)
library(EDI)

make_ordinal_glmm_optimizer_fixture = function(seed = 17L, sigma = 0.7) {
	set.seed(seed)
	n_groups = 50L
	# Deliberately non-contiguous: the two members of group g are g and g + G.
	group_id = as.integer(rep(seq_len(n_groups), 2L))
	w = c(rep(0, n_groups), rep(1, n_groups))
	x = rnorm(2L * n_groups)
	u_group = rnorm(n_groups, sd = sigma)
	eta = 2.3 * w + 0.25 * x + u_group[group_id]
	u = runif(length(eta))
	p1 = plogis(-0.5 - eta)
	p2 = plogis(0.8 - eta)
	y = as.integer(ifelse(u < p1, 1L, ifelse(u < p2, 2L, 3L)))
	list(X = cbind(w = w, x = x), y = y, group_id = group_id)
}

test_that("fast_ordinal_glmm_cpp is invariant to non-contiguous group row order", {
	d = make_ordinal_glmm_optimizer_fixture()
	fit_input = fast_ordinal_glmm_cpp(
		d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		warm_start_params = c(0, 0, 0, 0, -3), eps_g = 1e-6
	)
	o = order(d$group_id, method = "radix")
	fit_sorted = fast_ordinal_glmm_cpp(
		d$X[o, , drop = FALSE], d$y[o], d$group_id[o], K = 3L, j_T = 0L,
		warm_start_params = c(0, 0, 0, 0, -3), eps_g = 1e-6
	)

	expect_true(fit_input$converged)
	expect_true(fit_sorted$converged)
	expect_equal(fit_input$neg_loglik, fit_sorted$neg_loglik, tolerance = 1e-7)
	expect_equal(fit_input$b, fit_sorted$b, tolerance = 1e-7)
	expect_equal(fit_input$log_sigma, fit_sorted$log_sigma, tolerance = 1e-7)
})

test_that("ordinal GLMM multistart escapes the near-zero variance start", {
	d = make_ordinal_glmm_optimizer_fixture()
	fit_near_zero = fast_ordinal_glmm_cpp(
		d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		warm_start_params = c(0, 0, 0, 0, -3), eps_g = 1e-6
	)
	fit_moderate = fast_ordinal_glmm_cpp(
		d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		warm_start_params = c(0, 0, 0, 0, 0), eps_g = 1e-6
	)

	expect_true(fit_near_zero$converged)
	expect_lte(fit_near_zero$gradient_norm, 1e-5)
	expect_true(fit_near_zero$newton_polish_attempted)
	expect_true(fit_near_zero$newton_polish_accepted)
	expect_gt(fit_near_zero$newton_polish_iterations, 0L)
	expect_gt(fit_near_zero$log_sigma, -2)
	expect_equal(fit_near_zero$neg_loglik, fit_moderate$neg_loglik, tolerance = 1e-7)
	expect_equal(fit_near_zero$b, fit_moderate$b, tolerance = 1e-7)
})

test_that("ordinal GLMM returns usable score, information, and treatment variance", {
	d = make_ordinal_glmm_optimizer_fixture()
	fit = fast_ordinal_glmm_cpp(d$X, d$y, d$group_id, K = 3L, j_T = 0L)
	n_params = 2L + ncol(d$X) + 1L

	expect_true(fit$converged)
	expect_length(fit$score, n_params)
	expect_true(all(is.finite(fit$score)))
	expect_equal(dim(fit$fisher_information), c(n_params, n_params))
	expect_true(all(is.finite(fit$fisher_information)))
	expect_true(is.finite(fit$ssq_b_T) && fit$ssq_b_T > 0)
})

test_that("ordinal GLMM analytic score agrees with finite differences", {
	d = make_ordinal_glmm_optimizer_fixture()
	fit = fast_ordinal_glmm_cpp(d$X, d$y, d$group_id, K = 3L, j_T = 0L)
	params = as.numeric(fit$params)
	h = 1e-5
	numeric_nll_gradient = vapply(seq_along(params), function(j) {
		plus = minus = params
		plus[j] = plus[j] + h
		minus[j] = minus[j] - h
		(EDI:::get_ordinal_glmm_neg_loglik_cpp(d$X, d$y, d$group_id, plus, K = 3L) -
			EDI:::get_ordinal_glmm_neg_loglik_cpp(d$X, d$y, d$group_id, minus, K = 3L)) / (2 * h)
	}, numeric(1L))

	expect_equal(
		EDI:::get_ordinal_glmm_score_cpp(d$X, d$y, d$group_id, params, K = 3L),
		as.numeric(fit$score), tolerance = 1e-8
	)
	expect_equal(-as.numeric(fit$score), numeric_nll_gradient, tolerance = 2e-4)
	expect_equal(
		EDI:::get_ordinal_glmm_hessian_cpp(d$X, d$y, d$group_id, params, K = 3L),
		fit$fisher_information, tolerance = 1e-8
	)
})

test_that("ordinal GLMM numerical log-sigma boundary is respected from unsafe starts", {
	d = make_ordinal_glmm_optimizer_fixture()
	fit_low = fast_ordinal_glmm_cpp(
		d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		max_abs_log_sigma = 8, warm_start_params = c(0, 0, 0, 0, -20)
	)
	fit_high = fast_ordinal_glmm_cpp(
		d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		max_abs_log_sigma = 8, warm_start_params = c(0, 0, 0, 0, 20)
	)

	expect_true(fit_low$converged)
	expect_true(fit_high$converged)
	expect_lte(abs(fit_low$log_sigma), 8 + 1e-3)
	expect_lte(abs(fit_high$log_sigma), 8 + 1e-3)
	expect_equal(fit_low$neg_loglik, fit_high$neg_loglik, tolerance = 1e-7)
})
