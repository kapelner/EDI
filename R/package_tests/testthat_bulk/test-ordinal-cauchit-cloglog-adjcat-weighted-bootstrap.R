library(testthat)
library(EDI)

# InferenceOrdinalCauchitRegr, InferenceOrdinalCloglogRegr, and
# InferenceOrdinalAdjCatLogitRegr each override
# compute_estimate_with_bootstrap_weights() (inference_ordinal_cauchit.R,
# inference_ordinal_cloglog.R, inference_ordinal_adj_cat_logit.R), but no test
# anywhere in the suite ever called any of the three wrappers directly
# (verified via grep). The shared weighted_ordinal_bootstrap_surrogate_fit()
# helper they delegate to already has independent coverage across all four
# methods ("logistic"/"probit"/"cauchit"/"cloglog") in
# test-weighted-ordinal-surrogate-cold-start-reference.R, so this file checks
# the wrapper-level plumbing (weight expansion, best_X*_colnames column
# selection, cached-value population) against a direct call to that
# already-verified shared helper, matching the pattern used for the
# stereotype-logit wrapper in test-ordinal-stereotype-contratio-weighted-bootstrap.R.

make_ordinal_fixture <- function(n = 80L, seed = 42) {
	set.seed(seed)
	x1 <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	eta <- 0.5 * w + 0.3 * x1
	cut1 <- plogis(-1 - eta); cut2 <- plogis(0.3 - eta); cut3 <- plogis(1.2 - eta)
	u <- runif(n)
	y <- ifelse(u <= cut1, 1L, ifelse(u <= cut2, 2L, ifelse(u <= cut3, 3L, 4L)))
	des$add_all_subject_responses(y)
	list(des = des, w = w, x1 = x1, y = y)
}

make_bootstrap_context_inf <- function(class_generator, fixture) {
	inf <- class_generator$new(fixture$des, model_formula = ~x1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	context <- priv$build_bayesian_bootstrap_context()
	priv$current_bayesian_bootstrap_context <- context
	list(inf = inf, priv = priv, context = context)
}

test_that("cauchit weighted bootstrap wrapper matches the shared surrogate helper directly", {
	fixture <- make_ordinal_fixture(n = 70L, seed = 11)
	fx <- make_bootstrap_context_inf(InferenceOrdinalCauchitRegr, fixture)
	set.seed(3)
	weights <- sample(c(1, 2, 3), length(fixture$y), replace = TRUE)

	beta <- fx$inf$compute_estimate_with_bootstrap_weights(weights)

	X_fit <- fx$priv$build_design_matrix()
	direct <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X_fit, fx$priv$y, weights, method = "cauchit")
	expect_equal(beta, as.numeric(direct$beta_hat))
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))

	fx_zero <- make_bootstrap_context_inf(InferenceOrdinalCauchitRegr, fixture)
	result_zero <- fx_zero$inf$compute_estimate_with_bootstrap_weights(weights * 0)
	expect_true(is.na(result_zero))
})

test_that("cloglog weighted bootstrap wrapper matches the shared surrogate helper directly", {
	fixture <- make_ordinal_fixture(n = 70L, seed = 12)
	fx <- make_bootstrap_context_inf(InferenceOrdinalCloglogRegr, fixture)
	set.seed(4)
	weights <- sample(c(1, 2, 3), length(fixture$y), replace = TRUE)

	beta <- fx$inf$compute_estimate_with_bootstrap_weights(weights)

	X_fit <- fx$priv$build_design_matrix()
	direct <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X_fit, fx$priv$y, weights, method = "cloglog")
	expect_equal(beta, as.numeric(direct$beta_hat))
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))

	# estimate_only is accepted but does not change behavior (interface parity only).
	fx_eo <- make_bootstrap_context_inf(InferenceOrdinalCloglogRegr, fixture)
	beta_eo <- fx_eo$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_equal(beta_eo, beta)
})

test_that("adjacent-category logit weighted bootstrap wrapper matches the shared surrogate helper directly", {
	fixture <- make_ordinal_fixture(n = 70L, seed = 13)
	fx <- make_bootstrap_context_inf(InferenceOrdinalAdjCatLogitRegr, fixture)
	set.seed(5)
	weights <- sample(c(1, 2, 3), length(fixture$y), replace = TRUE)

	beta <- fx$inf$compute_estimate_with_bootstrap_weights(weights)

	X_fit <- fx$priv$build_design_matrix()
	direct <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X_fit, fx$priv$y, weights, method = "logistic")
	expect_equal(beta, as.numeric(direct$beta_hat))
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))

	fx_zero <- make_bootstrap_context_inf(InferenceOrdinalAdjCatLogitRegr, fixture)
	result_zero <- fx_zero$inf$compute_estimate_with_bootstrap_weights(weights * 0)
	expect_true(is.na(result_zero))
})
