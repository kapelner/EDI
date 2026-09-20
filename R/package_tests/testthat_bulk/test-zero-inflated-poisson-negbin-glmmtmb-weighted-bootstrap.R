library(testthat)
library(EDI)

# InferenceCountZeroInflatedPoisson / InferenceCountZeroInflatedNegBin do not override
# compute_estimate_with_bootstrap_weights(), so both dispatch to the shared abstract
# implementation in inference_count_zero_augmented_poisson_abstract.R
# (ZeroAugmentedCountLikelihoodSource, lines ~126-172) -- the same generic path already
# tested for InferenceCountHurdlePoisson/HurdleNegBin (test-hurdle-*-glmmtmb-weighted-bootstrap.R),
# but exercised here through genuinely different za_family()s: plain stats::poisson()/
# glmmTMB::nbinom2() with a REAL, separate zero-inflation submodel (not the truncated-count
# families the hurdle classes use). Grepped testthat/testthat_bulk for these two classes plus
# compute_estimate_with_bootstrap_weights together: no hits -- genuinely untested.

zip_weighted_fixture <- function(seed = 20260921L, n = 70L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		mu_i <- exp(0.4 + 0.4 * w_i + 0.2 * X$x1[i])
		p0 <- stats::plogis(-1.0 - 0.3 * w_i)
		y_i <- if (stats::runif(1) > p0) stats::rpois(1, mu_i) else 0L
		des$add_one_subject_response(i, y_i)
	}
	inf <- InferenceCountZeroInflatedPoisson$new(des, model_formula = ~x1, model_formula_zero = ~1, use_rcpp = TRUE)
	inf$compute_estimate()
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, des = des)
}

zinb_weighted_fixture <- function(seed = 20260921L, n = 70L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		mu_i <- exp(0.4 + 0.4 * w_i + 0.2 * X$x1[i])
		p0 <- stats::plogis(-1.0 - 0.3 * w_i)
		y_i <- if (stats::runif(1) > p0) stats::rnbinom(1, mu = mu_i, size = 4) else 0L
		des$add_one_subject_response(i, y_i)
	}
	inf <- InferenceCountZeroInflatedNegBin$new(des, model_formula = ~x1, model_formula_zero = ~1, use_rcpp = TRUE)
	inf$compute_estimate()
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, des = des)
}

reference_frame <- function(des) {
	X_raw <- des$get_X_raw()
	data.frame(y = des$get_y(), w = des$get_w(), x1 = X_raw[, "x1"])
}

test_that("weighted zero-inflated Poisson refit matches an independent glmmTMB fit, including force-included zi treatment", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- zip_weighted_fixture()
	set.seed(9)
	weights <- runif(nrow(reference_frame(fixture$des)), 0.5, 1.5)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)

	dat <- reference_frame(fixture$des)
	# model_formula_zero = ~1 above; EDI's build_component_matrix() force-includes the
	# treatment column in the zero-inflation design regardless of the formula requesting
	# it -- confirmed empirically (ziformula = ~1 alone does NOT reproduce EDI's fit; only
	# ziformula = ~w does). This is the class-specific behaviour worth pinning here.
	ref_mod <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(y ~ w + x1, ziformula = ~w, family = stats::poisson(link = "log"), data = dat, weights = weights)
	))
	expected <- unname(glmmTMB::fixef(ref_mod)$cond["w"])
	expected_se <- unname(summary(ref_mod)$coefficients$cond["w", "Std. Error"])

	expect_equal(actual, expected, tolerance = 1e-6)
	expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T, expected_se, tolerance = 1e-6)
	expect_false(isTRUE(fixture$private$last_weighted_refit$nonestimable))

	# ziformula = ~1 alone (ignoring the force-included treatment) gives a different fit --
	# confirms the force-inclusion is real, not a no-op.
	ref_mod_no_w_zi <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(y ~ w + x1, ziformula = ~1, family = stats::poisson(link = "log"), data = dat, weights = weights)
	))
	expect_false(isTRUE(all.equal(actual, unname(glmmTMB::fixef(ref_mod_no_w_zi)$cond["w"]))))
})

test_that("weighted zero-inflated NegBin refit matches an independent glmmTMB nbinom2 fit", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- zinb_weighted_fixture()
	set.seed(9)
	weights <- runif(nrow(reference_frame(fixture$des)), 0.5, 1.5)

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)

	dat <- reference_frame(fixture$des)
	ref_mod <- suppressWarnings(suppressMessages(
		glmmTMB::glmmTMB(y ~ w + x1, ziformula = ~w, family = glmmTMB::nbinom2(link = "log"), data = dat, weights = weights)
	))
	expected <- unname(glmmTMB::fixef(ref_mod)$cond["w"])
	expected_se <- unname(summary(ref_mod)$coefficients$cond["w", "Std. Error"])

	expect_equal(actual, expected, tolerance = 1e-6)
	expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T, expected_se, tolerance = 1e-6)
})

test_that("weighted zero-inflated Poisson refit is scale-invariant to a common weight multiplier", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- zip_weighted_fixture()
	set.seed(4)
	weights <- runif(nrow(reference_frame(fixture$des)), 0.5, 2)

	est1 <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
	est5 <- fixture$inf$compute_estimate_with_bootstrap_weights(5 * weights)
	expect_equal(est1, est5, tolerance = 1e-4)
})

test_that("unit-weighted zero-inflated Poisson refit (glmmTMB) agrees with the unweighted internal-solver estimate", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- zip_weighted_fixture()
	est_internal_solver <- fixture$inf$compute_estimate()
	est_glmmtmb_unit_weights <- fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, nrow(reference_frame(fixture$des))))
	expect_equal(est_internal_solver, est_glmmtmb_unit_weights, tolerance = 1e-3)
})

test_that("weighted zero-inflated refit errors clearly when glmmTMB is unavailable", {
	fixture <- zip_weighted_fixture()
	testthat::local_mocked_bindings(
		check_package_installed = function(...) FALSE,
		.package = "EDI"
	)
	expect_error(
		fixture$inf$compute_estimate_with_bootstrap_weights(rep(1, nrow(reference_frame(fixture$des)))),
		"weighted bootstrap estimation requires package 'glmmTMB'"
	)
})

test_that("a treatment coefficient dropped from the weighted zero-inflated refit is cached as nonestimable", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- zip_weighted_fixture()
	weights <- rep(1, nrow(reference_frame(fixture$des)))

	testthat::local_mocked_bindings(
		fixef = function(object, ...) list(cond = c(`(Intercept)` = 0)),
		.package = "glmmTMB"
	)

	result <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)

	expect_true(is.na(result))
	expect_true(isTRUE(fixture$private$last_weighted_refit$nonestimable))
	expect_identical(fixture$private$last_weighted_refit$nonestimable_reason, "zero_augmented_poisson_weighted_treatment_missing")
})
