library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM$compute_estimate_with_bootstrap_weights()
# (inference_incidence_KK_cond_logit_glmm_abstract.R) short-circuits when the supplied
# subject/block weights are effectively constant (weights_are_effectively_constant()):
# instead of fitting the weighted glmmTMB model, it reuses the plain (unweighted)
# self$compute_estimate(estimate_only = TRUE) point estimate directly and sets
# s_beta_hat_T to NA -- entirely bypassing the glmmTMB weighted-refit machinery this
# method otherwise performs. The existing weighted-refit reference tests
# (test-prop-kk-glmm-weighted-refit-reference.R,
# test-kk-cond-logit-glmm-weighted-refit-extreme-coefficient-guard-reference.R) only ever
# pass genuinely varying block weights, so this short-circuit branch had zero test
# references anywhere. Exercised on a real InferencePropKKGLMM instance with a constant
# weight vector, independent of glmmTMB (never invoked on this path). As with all weighted
# refits (InferenceAllAbstract$install_weighted_refit_isolation()), the outer wrapper rolls
# private$cached_values back afterward and records the call's own outcome in
# private$last_weighted_refit instead.

test_that("a constant weight vector short-circuits to the unweighted point estimate with s_beta_hat_T left NA", {
	set.seed(1)
	n <- 30L
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "proportion", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, rbeta(1, 2, 2))
	}
	inf <- EDI:::InferencePropKKGLMM$new(des, model_formula = ~ x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()

	point_estimate <- as.numeric(inf$compute_estimate(estimate_only = TRUE))[1L]
	expect_true(is.finite(point_estimate))

	n_blocks <- length(unique(priv$m[priv$m != 0])) + sum(priv$m == 0)
	res <- inf$compute_estimate_with_bootstrap_weights(rep(2, n_blocks), estimate_only = TRUE)

	expect_equal(res, point_estimate)
	expect_equal(priv$last_weighted_refit$beta_hat_T, point_estimate)
	expect_true(is.na(priv$last_weighted_refit$s_beta_hat_T))
})
