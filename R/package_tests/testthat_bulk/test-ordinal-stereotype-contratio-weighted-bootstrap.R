library(testthat)
library(EDI)

# InferenceOrdinalStereotypeLogitRegr and InferenceOrdinalContRatioRegr both
# override compute_estimate_with_bootstrap_weights() (inference_ordinal_stereotype_logit.R,
# lines ~34 and ~533) but neither wrapper had a test calling it anywhere in
# the suite (verified via grep) -- only the shared surrogate helper
# (weighted_ordinal_bootstrap_surrogate_fit, used by the stereotype class)
# already had independent coverage elsewhere. The continuation-ratio class
# refits a real weighted likelihood via fast_continuation_ratio_regression_weighted_cpp,
# a genuinely different, previously untested code path.

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

test_that("continuation-ratio weighted bootstrap refit matches an independent weighted VGAM cratio fit", {
	skip_if_not_installed("VGAM")
	fixture <- make_ordinal_fixture()
	fx <- make_bootstrap_context_inf(InferenceOrdinalContRatioRegr, fixture)
	set.seed(1)
	weights <- sample(c(1, 2, 3), length(fixture$y), replace = TRUE)

	dat <- data.frame(y = ordered(fixture$y), w = fixture$w, x1 = fixture$x1, weight = weights)
	reference <- VGAM::vglm(y ~ w + x1, family = VGAM::cratio(parallel = TRUE, reverse = FALSE),
		data = dat, weights = weight)
	beta_ref <- unname(VGAM::coef(reference)["w"])

	beta <- fx$inf$compute_estimate_with_bootstrap_weights(weights)
	expect_equal(beta, beta_ref, tolerance = 1e-4)
	# No standard error is computed on this weighted path, by design.
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))

	# Unit weights reproduce the plain unweighted MLE.
	fx_unit <- make_bootstrap_context_inf(InferenceOrdinalContRatioRegr, fixture)
	beta_unit <- fx_unit$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y)))
	inf_plain <- InferenceOrdinalContRatioRegr$new(fixture$des, model_formula = ~x1, verbose = FALSE)
	beta_plain <- inf_plain$compute_estimate(estimate_only = TRUE)
	expect_equal(beta_unit, beta_plain, tolerance = 1e-6)

	# estimate_only leaves the same beta but is still SE-free (already NA regardless).
	fx_eo <- make_bootstrap_context_inf(InferenceOrdinalContRatioRegr, fixture)
	beta_eo <- fx_eo$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_equal(beta_eo, beta_ref, tolerance = 1e-4)
})

test_that("continuation-ratio weighted bootstrap refit returns NA when every weight is zero", {
	fixture <- make_ordinal_fixture(seed = 7)
	fx <- make_bootstrap_context_inf(InferenceOrdinalContRatioRegr, fixture)
	result <- fx$inf$compute_estimate_with_bootstrap_weights(rep(0, length(fixture$y)))
	expect_true(is.na(result))
})

test_that("stereotype-logit weighted bootstrap wrapper matches the already-tested shared surrogate helper directly", {
	fixture <- make_ordinal_fixture(n = 60L, seed = 42)
	fx <- make_bootstrap_context_inf(InferenceOrdinalStereotypeLogitRegr, fixture)
	set.seed(2)
	weights <- sample(c(1, 2, 3), length(fixture$y), replace = TRUE)

	beta <- fx$inf$compute_estimate_with_bootstrap_weights(weights)

	X_fit <- fx$priv$build_design_matrix()
	direct <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(X_fit, fx$priv$y, weights, method = "logistic")
	expect_equal(beta, as.numeric(direct$beta_hat))
	# The surrogate never estimates a standard error for this wrapper.
	expect_true(is.na(fx$priv$cached_values$s_beta_hat_T))

	# Zero weights make the surrogate fail, which the wrapper reports as NA
	# and marks nonestimable, matching the documented contract.
	fx_zero <- make_bootstrap_context_inf(InferenceOrdinalStereotypeLogitRegr, fixture)
	result_zero <- fx_zero$inf$compute_estimate_with_bootstrap_weights(weights * 0)
	expect_true(is.na(result_zero))
	expect_true(fx_zero$inf$is_nonestimable())
})
