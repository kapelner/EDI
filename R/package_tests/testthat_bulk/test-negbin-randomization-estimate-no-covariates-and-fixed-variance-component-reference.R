library(testthat)
library(EDI)

# InferenceCountNegBin's compute_treatment_estimate_during_randomization_inference()
# (inference_count_negbin.R) has two branches not covered by
# test-negbin-randomization-estimate-descriptors-and-null-simulation-reference.R (which exercises
# the covariate-adjusted refit, the shared()-first no-prior-selection path, and backend-failure/
# non-finite-coefficient -> NA):
#   1. length(best_X_colnames) == 0L: no covariates selected (model_formula = ~1), so X = cbind(1, w)
#      rather than cbind(1, treatment = w, X_cov).
#   2. private$cached_vc_params finite (a fixed dispersion carried over from a prior fit -- note
#      compute_estimate() itself already populates this as a side effect of the joint fit's theta,
#      so the "unset" contrast case below has to clear it explicitly): the fast_neg_bin_cpp() call is
#      made with fixed_idx/fixed_values set to pin log(theta) at that value, rather than refitting
#      it -- verified by mocking the fitter to capture its own call arguments directly.

nb_no_cov_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.5 + 0.4 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceCountNegBin$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

nb_fixture <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.5 + 0.4 * w + 0.3 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, X = X, y = y, w = w)
}

test_that("with no covariates selected, the randomization-time refit uses X = cbind(1, w) and matches glm.nb(y ~ w)", {
	f <- nb_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(MASS::glm.nb(f$y ~ f$w))[2])
	expect_equal(est, ref, tolerance = 0.01)
})

test_that("a finite cached_vc_params pins the dispersion via fixed_idx/fixed_values instead of refitting it", {
	f <- nb_fixture()
	f$inf$compute_estimate()

	captured <- list()
	local_mocked_bindings(
		fast_neg_bin_cpp = function(X, y, ..., fixed_idx = NULL, fixed_values = NULL) {
			captured[["fixed_idx"]] <<- fixed_idx
			captured[["fixed_values"]] <<- fixed_values
			list(b = c(0.5, 0.4, 0.3), theta_hat = 3, fisher_information = diag(3))
		},
		.package = "EDI"
	)

	# baseline: cached_vc_params explicitly cleared -> no fixed_idx/fixed_values
	f$priv$cached_vc_params <- NA_real_
	f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_null(captured$fixed_idx)
	expect_null(captured$fixed_values)

	# a finite cached vc param pins log(theta)
	f$priv$cached_vc_params <- 1.2
	f$priv$compute_treatment_estimate_during_randomization_inference()
	X_cols_used <- 1L + length(f$priv$best_X_colnames) + 1L  # intercept + covariates + treatment
	expect_equal(captured$fixed_idx, X_cols_used + 1L)
	expect_equal(captured$fixed_values, 1.2)
})
