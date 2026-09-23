library(testthat)
library(EDI)

# InferencePropBetaRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_proportion_beta.R) had no test reference anywhere -- the same gap pattern already closed
# this session on several sibling classes -- and shares InferenceCountNegBin's extra
# cached_vc_params-pinning wrinkle:
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      betareg::betareg() fit.
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = cbind((Intercept)=1, treatment=w) rather
#      than including covariate columns.
#   4. A fitter failure (res NULL or non-finite res$coefficients[2]) returns NA.
#   5. A finite private$cached_vc_params (a fixed dispersion carried over from a prior fit --
#      compute_estimate() itself already populates this, same discovery as the NegBin sibling test)
#      pins phi via fixed_idx/fixed_values rather than refitting it -- verified by mocking the fitter
#      to capture its own call arguments directly.

beta_fixture <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	mu <- plogis(0.3 + 0.5 * w + 0.4 * x)
	y <- rbeta(n, mu * 8, (1 - mu) * 8)
	des$add_all_subject_responses(y)
	inf <- InferencePropBetaRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

beta_no_cov_fixture <- function(seed = 2L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	mu <- plogis(0.3 + 0.5 * w)
	y <- rbeta(n, mu * 8, (1 - mu) * 8)
	des$add_all_subject_responses(y)
	inf <- InferencePropBetaRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching betareg::betareg", {
	f <- beta_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x")
	# compute_estimate() already populates cached_vc_params (see the "fixed phi" test below), which
	# pins phi at the ORIGINAL data's estimate on every subsequent randomization-time refit -- fine
	# for self-consistency against the same data, but it means a refit on a genuinely different
	# (permuted) y/w pattern is no longer comparable to betareg::betareg()'s own unconstrained refit
	# of phi. Clear it before each comparison so both sides freely estimate phi.
	f$priv$cached_vc_params <- NA_real_

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(betareg::betareg(f$y ~ f$w + f$x))[2])
	expect_equal(est, ref, tolerance = 0.01)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	f$priv$cached_vc_params <- NA_real_
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(betareg::betareg(f$y ~ w2 + f$x))[2])
	expect_equal(est2, ref2, tolerance = 0.01)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- beta_fixture(seed = 3L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses cbind(1, treatment = w) and matches betareg::betareg(y ~ w)", {
	f <- beta_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))
	f$priv$cached_vc_params <- NA_real_  # same reason as the covariate-adjusted case above

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(betareg::betareg(f$y ~ f$w))[2])
	expect_equal(est, ref, tolerance = 0.01)
})

test_that("a fitter failure (res NULL or non-finite res$coefficients[2]) returns NA", {
	f <- beta_fixture(seed = 4L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_beta_regression_cpp = function(...) NULL, .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))

	local_mocked_bindings(
		fast_beta_regression_cpp = function(X, ...) list(coefficients = c(0, NA_real_, rep(0, ncol(X) - 2L)), phi = 5),
		.package = "EDI"
	)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})

test_that("a finite cached_vc_params pins phi via fixed_idx/fixed_values instead of refitting it", {
	f <- beta_fixture(seed = 5L)
	f$inf$compute_estimate()

	captured <- list()
	local_mocked_bindings(
		fast_beta_regression_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL) {
			captured[["fixed_idx"]] <<- fixed_idx
			captured[["fixed_values"]] <<- fixed_values
			list(coefficients = c(0.3, 0.5, 0.4), phi = 8, fisher_information = diag(3))
		},
		.package = "EDI"
	)

	# baseline: cached_vc_params explicitly cleared -> no fixed_idx/fixed_values
	f$priv$cached_vc_params <- NA_real_
	f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_null(captured$fixed_idx)
	expect_null(captured$fixed_values)

	# a finite cached vc param pins log(phi)
	f$priv$cached_vc_params <- 2.1
	f$priv$compute_treatment_estimate_during_randomization_inference()
	X_cols_used <- 1L + length(f$priv$best_X_colnames) + 1L  # intercept + covariates + treatment
	expect_equal(captured$fixed_idx, X_cols_used + 1L)
	expect_equal(captured$fixed_values, 2.1)
})
