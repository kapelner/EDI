library(testthat)
library(EDI)

# InferenceCountHurdlePoisson does not override compute_estimate_with_bootstrap_weights(),
# so it dispatches to the shared abstract implementation in
# inference_count_zero_augmented_poisson_abstract.R (ZeroAugmentedCountLikelihoodSource,
# lines ~126-172) via glmmTMB::truncated_poisson(). No existing test calls this method with
# actual varying weights on this class (grepped testthat/testthat_bulk for
# InferenceCountHurdlePoisson and compute_estimate_with_bootstrap_weights together: no hits).
# This mirrors test-hurdle-negbin-glmmtmb-weighted-bootstrap.R's pattern for the sibling
# InferenceCountHurdleNegBin class, which has its own separate override using truncated_nbinom2().

hurdle_poisson_weighted_fixture <- function(seed = 20260918L, n = 60L) {
	set.seed(seed)
	w <- rep(c(0, 1), each = n / 2L)
	mu <- exp(0.3 + 0.4 * w)
	y <- ifelse(rbinom(n, 1, plogis(0.2 + 0.3 * w)) == 1, pmax(1L, rpois(n, mu)), 0L)
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceCountHurdlePoisson$new(des, model_formula = ~ 1, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, w = w)
}

test_that("weighted hurdle poisson refit matches an independent glmmTMB truncated_poisson fit", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_poisson_weighted_fixture()
	set.seed(20260918L)
	weights <- runif(length(fixture$y), 0.5, 2)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)

	dat <- data.frame(y = fixture$y, w = fixture$w)
	ref_mod <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(
			y ~ w, ziformula = ~ w,
			family = glmmTMB::truncated_poisson(link = "log"),
			data = dat, weights = weights
		)
	))
	expected <- unname(glmmTMB::fixef(ref_mod)$cond["w"])
	expect_equal(actual, expected, tolerance = 1e-6)

	# Documented contract: point-estimate-only fit clears nonestimable state and leaves SE/df unset
	# (the fix noted in the abstract's 2026-09-07 comment only applies when estimate_only = FALSE).
	# The weighted call's outcome lives in last_weighted_refit; the ordinary cache stays untouched.
	lw <- fixture$private$last_weighted_refit
	expect_true(is.na(lw$s_beta_hat_T))
	expect_true(is.na(lw$df))
	expect_false(isTRUE(lw$nonestimable))
	expect_null(fixture$private$cached_mod)
	expect_null(fixture$private$cached_values$full_coefficients)
	expect_null(fixture$private$cached_values$likelihood_test_context)
	expect_false(isTRUE(fixture$private$cached_values$nonestimable))
})

test_that("estimate_only = FALSE populates a finite weighted SE from glmmTMB's sdreport", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_poisson_weighted_fixture()
	set.seed(3)
	weights <- runif(length(fixture$y), 0.5, 2)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)

	dat <- data.frame(y = fixture$y, w = fixture$w)
	ref_mod <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(
			y ~ w, ziformula = ~ w,
			family = glmmTMB::truncated_poisson(link = "log"),
			data = dat, weights = weights
		)
	))
	expected <- unname(glmmTMB::fixef(ref_mod)$cond["w"])
	expected_se <- unname(summary(ref_mod)$coefficients$cond["w", "Std. Error"])

	expect_equal(actual, expected, tolerance = 1e-6)
	expect_true(is.finite(fixture$private$last_weighted_refit$s_beta_hat_T))
	expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T, expected_se, tolerance = 1e-6)
})

test_that("weighted hurdle poisson refit is scale-invariant to a common weight multiplier", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_poisson_weighted_fixture()
	set.seed(2)
	weights <- runif(length(fixture$y), 0.5, 2)

	est1 <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
	est5 <- fixture$inf$compute_estimate_with_bootstrap_weights(5 * weights)
	expect_equal(est1, est5, tolerance = 1e-4)
})

test_that("unit weighted hurdle poisson refit (glmmTMB) agrees with the unweighted internal-solver estimate", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_poisson_weighted_fixture()
	est_internal_solver <- fixture$inf$compute_estimate()
	est_glmmtmb_unit_weights <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y)))
	# Two different MLE solvers (internal C++ Newton solver vs. glmmTMB's TMB/Laplace fit)
	# converging to the same log-likelihood surface; agreement confirms both are fitting the
	# same hurdle Poisson model, not just "doesn't error".
	expect_equal(est_internal_solver, est_glmmtmb_unit_weights, tolerance = 1e-3)
})

test_that("weighted hurdle poisson refit errors clearly when glmmTMB is unavailable", {
	fixture <- hurdle_poisson_weighted_fixture()
	testthat::local_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI"
	)
	expect_error(
		fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, length(fixture$y))),
		"weighted bootstrap estimation requires package 'glmmTMB'"
	)
})

test_that("a treatment coefficient dropped from the weighted refit is cached as nonestimable", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_poisson_weighted_fixture()
	weights <- rep(1, length(fixture$y))

	# Monkeypatch fixef() so the refit "succeeds" but comes back with no treatment
	# coefficient, exercising the missing-treatment nonestimable branch (lines ~147-151)
	# without needing a genuinely-failing glmmTMB fit.
	testthat::local_mocked_bindings(
		fixef = function(object, ...) list(cond = c(`(Intercept)` = 0)),
		.package = "glmmTMB"
	)

	result <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)

	expect_true(is.na(result))
	expect_true(fixture$private$weighted_refit_is_nonestimable("estimate"))
	expect_identical(fixture$private$last_weighted_refit$nonestimable_reason, "zero_augmented_poisson_weighted_treatment_missing")
	expect_false(fixture$inf$is_nonestimable("any"))                    # the ordinary state is not flagged
})
