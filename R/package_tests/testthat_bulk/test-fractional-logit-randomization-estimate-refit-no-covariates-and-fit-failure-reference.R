library(testthat)
library(EDI)

# InferencePropFractionalLogit's compute_treatment_estimate_during_randomization_inference()
# (inference_proportion_fractional_logit.R) had no test reference anywhere -- the same gap pattern
# already closed this session on InferenceIncidLogRegr/InferenceIncidProbitRegr/
# InferenceIncidModifiedPoisson/InferenceIncidLogBinomial/InferenceCountNegBin:
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      glm(family = quasibinomial()) fit (the class's own Papke-Wooldridge fractional-logit point
#      estimate is the quasibinomial/binomial MLE; only the dispersion-scaled SE differs, which this
#      fast estimate_only path skips entirely).
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = cbind(`(Intercept)` = 1, treatment = w)
#      rather than including covariate columns.
#   4. A fitter failure (res NULL or non-finite res$b[2]) returns NA.

frac_fixture <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- pmin(pmax(plogis(0.3 * w + 0.5 * x + rnorm(n, sd = 0.5)), 0.02), 0.98)
	des$add_all_subject_responses(y)
	inf <- InferencePropFractionalLogit$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

frac_no_cov_fixture <- function(seed = 2L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- pmin(pmax(plogis(0.3 * w + rnorm(n, sd = 0.5)), 0.02), 0.98)
	des$add_all_subject_responses(y)
	inf <- InferencePropFractionalLogit$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching glm(quasibinomial)", {
	f <- frac_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x")

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ f$w + f$x, family = quasibinomial()))[2])
	expect_equal(est, ref, tolerance = 0.01)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(glm(f$y ~ w2 + f$x, family = quasibinomial()))[2])
	expect_equal(est2, ref2, tolerance = 0.01)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- frac_fixture(seed = 3L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses cbind(1, treatment = w) and matches glm(y ~ w, quasibinomial)", {
	f <- frac_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ f$w, family = quasibinomial()))[2])
	expect_equal(est, ref, tolerance = 0.01)
})

test_that("a fitter failure (res NULL or non-finite res$b[2]) returns NA", {
	f <- frac_fixture(seed = 4L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_logistic_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_logistic_regression_cpp = function(X, ...) list(b = c(0, NA_real_, rep(0, ncol(X) - 2L))),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
