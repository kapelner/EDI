library(testthat)
library(EDI)

# InferenceSurvivalStratCoxPHRegr$compute_estimate_with_bootstrap_weights() and
# compute_rand_confidence_interval() (inference_survival_strat_cox.R) previously appeared
# only in a public-method-inventory name list (test-partial-likelihood-migration-baseline.R),
# never actually invoked with real weights or called at all (grepped testthat/testthat_bulk for
# both method names together with this class; no direct call found).

strat_cox_fixture <- function(seed = 20260918L, n = 60L, stratified = FALSE) {
	set.seed(seed)
	x1 <- rnorm(n)
	covars <- data.frame(x1 = x1)
	formula <- ~x1
	if (stratified) {
		strat <- sample(1:3, n, replace = TRUE)
		covars$strat <- factor(strat)
		formula <- ~ x1 + strat
	} else {
		strat <- NULL
	}
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(covars)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- -0.2 + 0.15 * w + 0.2 * x1 + if (stratified) 0.3 * strat else 0
	y <- rexp(n, rate = exp(lin))
	des$add_all_subject_responses(y)
	inf <- InferenceSurvivalStratCoxPHRegr$new(des, model_formula = formula, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, w = w, x1 = x1)
}

test_that("unstratified weighted refit matches an independent weighted survival::coxph fit", {
	fixture <- strat_cox_fixture()
	set.seed(1)
	weights <- runif(length(fixture$y), 0.5, 2)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)

	dat <- data.frame(time = fixture$y, dead = fixture$private$dead, treatment = fixture$w, x1 = fixture$x1)
	ref <- survival::coxph(survival::Surv(time, dead) ~ treatment + x1, data = dat, weights = weights)
	expect_equal(actual, unname(coef(ref)["treatment"]), tolerance = 1e-6)
})

test_that("stratified weighted refit dispatches strata() and matches an independent weighted coxph fit", {
	fixture <- strat_cox_fixture(stratified = TRUE)
	X_cov <- fixture$private$get_X()
	X_cov_reduced <- fixture$private$reduce_covariates_preserving_treatment(X_cov)
	info <- fixture$private$compute_strata_info(X_cov)
	expect_gt(info$num_strata, 1L)

	set.seed(2)
	weights <- runif(length(fixture$y), 0.5, 2)
	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)

	X_fit <- cbind(treatment = fixture$w, X_cov_reduced)
	dat <- as.data.frame(X_fit)
	dat$time <- fixture$y
	dat$dead <- fixture$private$dead
	dat$strata_id <- factor(info$strata_id)
	ref <- survival::coxph(
		stats::as.formula(paste0("Surv(time, dead) ~ ", paste(colnames(X_fit), collapse = " + "), " + strata(strata_id)")),
		data = dat, weights = weights
	)
	expect_equal(actual, unname(coef(ref)["treatment"]), tolerance = 1e-6)
})

test_that("effectively-constant weights take the unweighted compute_estimate shortcut", {
	fixture <- strat_cox_fixture()
	unweighted <- as.numeric(fixture$inf$compute_estimate(estimate_only = TRUE))
	unit_weighted <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y)))
	expect_equal(unit_weighted, unweighted, tolerance = 1e-8)

	nearly_constant <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(2, length(fixture$y)) + 1e-14)
	expect_equal(nearly_constant, unweighted, tolerance = 1e-8)
})

test_that("degenerate all-zero weights make the surrogate fit fail and return NA", {
	fixture <- strat_cox_fixture()
	result <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(0, length(fixture$y)))
	expect_true(is.na(result))
})

test_that("compute_rand_confidence_interval is explicitly unsupported for stratified Cox PH", {
	fixture <- strat_cox_fixture()
	expect_error(
		fixture$inf$compute_rand_confidence_interval(),
		"Randomization confidence intervals are not supported for stratified Cox PH models"
	)
})
