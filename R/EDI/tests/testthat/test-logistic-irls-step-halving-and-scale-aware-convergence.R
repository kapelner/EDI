# v1.0.6-TODO-192 C++ follow-up (filed under v1.0.6-TODO-169/170): the logistic IRLS kernel
# (fast_logistic_regression_internal, behind fast_logistic_regression_cpp / _weighted_cpp /
# _with_var_cpp) had no step halving. From the warm start (-0.70, 2.24, 3.18, -1.38) on the
# rep-102 data of the v1.0.6-TODO-168 coverage study it ran the coefficients to |b| ~ 1e9 in 100
# iterations with converged = FALSE, although a cold start converges to glm's answer. A fit that
# does not converge on the plain IRLS path is now rerun with step halving (the negative
# log-likelihood may not increase). Separately (v1.0.6-TODO-170), the absolute gradient rule
# reported a correct fit as not converged when a covariate has a large offset; a scale-aware
# Newton-decrement fallback now declares it converged.
#
# These tests need a build of EDI that contains the patched kernel: they skip when the kernel
# in use predates it (its weighted result has no `num_step_halvings` field).

skip_unless_logistic_irls_has_step_halving = function(){
	probe = fast_logistic_regression_weighted_cpp(X = cbind(1, c(0, 1, 0, 1, 1, 0)), y = c(0, 1, 1, 1, 0, 0),
		weights = rep(1, 6))
	testthat::skip_if(is.null(probe$num_step_halvings),
		"installed EDI predates the logistic IRLS step-halving patch (v1.0.6-TODO-192 C++ follow-up); rebuild EDI")
}

make_logistic_rep102_fit_inputs = function(){
	set.seed(100102)
	n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w + 0.4 * X$x1)))
	inf = InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	inf$compute_estimate()
	list(X = as.matrix(priv$build_design_matrix()), y = as.numeric(priv$y),
		fisher = priv$get_fit_warm_start_fisher(4L))
}

test_that("weighted logistic IRLS converges to the cold-start/glm fit from the diverging warm start", {
	skip_unless_logistic_irls_has_step_halving()
	d = make_logistic_rep102_fit_inputs()
	n = nrow(d$X)
	bad_start = c(-0.70, 2.24, 3.18, -1.38)
	cold = fast_logistic_regression_weighted_cpp(X = d$X, y = d$y, weights = rep(1, n))
	expect_true(isTRUE(cold$converged))
	expect_identical(cold$num_step_halvings, 0L)
	g = glm.fit(d$X, d$y, family = binomial(), control = glm.control(epsilon = 1e-12))
	for (fisher in list(d$fisher, NULL)) {
		fit = fast_logistic_regression_weighted_cpp(X = d$X, y = d$y, weights = rep(1, n),
			warm_start_beta = bad_start, warm_start_fisher_info = fisher)
		expect_true(isTRUE(fit$converged))
		expect_false(isTRUE(fit$hit_iteration_cap))
		expect_gte(fit$num_step_halvings, 1L)
		expect_lt(max(abs(fit$b)), 5)
		expect_equal(as.numeric(fit$b), as.numeric(cold$b), tolerance = 1e-8)
		expect_equal(as.numeric(fit$b), unname(g$coefficients), tolerance = 1e-7)
	}
	# The unweighted entry points share the kernel and converge from the same start too.
	u = fast_logistic_regression_cpp(X = d$X, y = d$y, warm_start_beta = bad_start)
	expect_true(isTRUE(u$converged))
	expect_equal(as.numeric(u$b), as.numeric(cold$b), tolerance = 1e-8)
	v = fast_logistic_regression_with_var_cpp(X = d$X, y = d$y, j = 2L, warm_start_beta = bad_start,
		warm_start_fisher_info = d$fisher)
	expect_true(isTRUE(v$converged))
	expect_equal(as.numeric(v$b), as.numeric(cold$b), tolerance = 1e-8)
})

test_that("logistic IRLS declares a correct fit converged when a covariate has a large offset", {
	skip_unless_logistic_irls_has_step_halving()
	# Seed 2: the absolute gradient rule fails here (gradient ~ 2e-6 at the optimum) because the
	# age column is offset by 1e5; the coefficients already match glm.
	set.seed(2)
	n = 300
	x1 = rnorm(n); age = rnorm(n, 60, 10); w = rbinom(n, 1, 0.5)
	y = rbinom(n, 1, plogis(-0.3 + 0.5 * w + 0.4 * x1 + 0.03 * (age - 60)))
	X = cbind(1, w, x1, age + 1e5)
	g = glm.fit(X, y, family = binomial())
	fit = fast_logistic_regression_cpp(X, y)
	expect_true(isTRUE(fit$converged))
	expect_false(isTRUE(fit$hit_iteration_cap))
	expect_equal(fit$b[2], unname(g$coefficients[2]), tolerance = 1e-8)
	fit_w = fast_logistic_regression_weighted_cpp(X = X, y = y, weights = rep(1, n))
	expect_true(isTRUE(fit_w$converged))
	expect_equal(as.numeric(fit_w$b), as.numeric(fit$b))
})
