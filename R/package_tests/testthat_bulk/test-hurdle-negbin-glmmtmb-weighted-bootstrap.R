library(testthat)
library(EDI)

# InferenceCountHurdleNegBin$compute_estimate_with_bootstrap_weights() (inference_count_hurdle.R,
# lines ~406-448) is the only weighted-refit path in this class that dispatches to glmmTMB's
# truncated_nbinom2() instead of the package's internal C++ solver. No existing test calls it
# with actual varying weights (grepped testthat/testthat_bulk for InferenceCountHurdleNegBin and
# compute_estimate_with_bootstrap_weights together; the only direct call found,
# test-design-inference.R, only exercises the unweighted compute_estimate()).

hurdle_negbin_weighted_fixture <- function(seed = 20260918L, n = 60L) {
	set.seed(seed)
	w <- rep(c(0, 1), each = n / 2L)
	mu <- exp(0.3 + 0.4 * w)
	y <- ifelse(rbinom(n, 1, plogis(0.2 + 0.3 * w)) == 1, pmax(1L, rpois(n, mu)), 0L)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceCountHurdleNegBin$new(des, model_formula = ~ 1, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, w = w)
}

test_that("weighted hurdle negbin refit matches an independent glmmTMB truncated_nbinom2 fit", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_negbin_weighted_fixture()
	set.seed(20260918L)
	weights <- runif(length(fixture$y), 0.5, 2)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)

	dat <- data.frame(y = fixture$y, w = fixture$w)
	ref_mod <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(
			y ~ w, ziformula = ~ w,
			family = glmmTMB::truncated_nbinom2(link = "log"),
			data = dat, weights = weights
		)
	))
	expected <- unname(glmmTMB::fixef(ref_mod)$cond["w"])
	expect_equal(actual, expected, tolerance = 1e-6)

	# Documented contract: no SE/df computed, cached_mod/full_coefficients populated, state cleared.
	expect_true(is.na(fixture$private$cached_values$s_beta_hat_T))
	expect_true(is.na(fixture$private$cached_values$df))
	expect_s3_class(fixture$private$cached_mod, "glmmTMB")
	expect_true("w" %in% names(fixture$private$cached_values$full_coefficients))
	expect_null(fixture$private$cached_values$count_likelihood_context)
	expect_false(isTRUE(fixture$private$cached_values$nonestimable))
})

test_that("weighted hurdle negbin refit is scale-invariant to a common weight multiplier", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_negbin_weighted_fixture()
	set.seed(2)
	weights <- runif(length(fixture$y), 0.5, 2)

	est1 <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
	est5 <- fixture$inf$compute_estimate_with_bootstrap_weights(5 * weights)
	expect_equal(est1, est5, tolerance = 1e-4)
})

test_that("unit weighted hurdle negbin refit (glmmTMB) agrees with the unweighted internal-solver estimate", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_negbin_weighted_fixture()
	est_internal_solver <- fixture$inf$compute_estimate()
	est_glmmtmb_unit_weights <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y)))
	# Two different MLE solvers (internal C++ Newton solver vs. glmmTMB's TMB/Laplace fit)
	# converging to the same log-likelihood surface; agreement confirms both are fitting the
	# same hurdle negative-binomial model, not just "doesn't error".
	expect_equal(est_internal_solver, est_glmmtmb_unit_weights, tolerance = 1e-3)
})

test_that("weighted hurdle negbin refit errors clearly when glmmTMB is unavailable", {
	fixture <- hurdle_negbin_weighted_fixture()
	testthat::local_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI"
	)
	expect_error(
		fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y))),
		"weighted bootstrap estimation requires package 'glmmTMB'"
	)
})
