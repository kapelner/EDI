library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr's compute_estimate_with_bootstrap_weights()
# (inference_survival_dep_cens_transform.R) had no test reference anywhere despite the class's own
# override list explicitly declaring it -- confirmed via grep: no test file mentions both the class
# name and this method together. It dispatches to the standalone weighted_cox_bootstrap_surrogate_fit()
# helper (independently tested elsewhere, e.g. for the sibling LWA-Cox/Weibull-marginal classes), so
# this file targets the DISPATCH wiring specific to this class: the design-matrix construction
# (build_design_matrix()'s first column renamed "treatment"), the effectively-constant-weights
# shortcut to compute_estimate(), and the NA-on-fit-failure guard.
#   1. A genuinely weighted refit matches an independently re-derived direct call to
#      weighted_cox_bootstrap_surrogate_fit() built from the same design-matrix construction.
#   2. Unit (effectively-constant) weights reproduce compute_estimate()'s own unweighted value via
#      the documented shortcut.
#   3. A fit-failure (weighted_cox_bootstrap_surrogate_fit() returns NULL) returns NA_real_.

dep_cens_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * rnorm(n) + 0.2 * w)))
	inf <- InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)
	list(inf = inf, priv = priv)
}

test_that("a genuinely weighted refit matches an independently re-derived weighted_cox_bootstrap_surrogate_fit() call", {
	f <- dep_cens_fixture(1L)
	invisible(f$inf$compute_estimate())
	set.seed(2L); row_weights <- runif(f$priv$n, 0.3, 2)
	res <- f$inf$compute_estimate_with_bootstrap_weights(row_weights, estimate_only = TRUE)

	X_fit <- f$priv$build_design_matrix()[, -1, drop = FALSE]
	colnames(X_fit)[1L] <- "treatment"
	fit_ref <- EDI:::weighted_cox_bootstrap_surrogate_fit(
		f$priv$y, f$priv$dead, X_fit, row_weights,
		warm_start_beta = f$priv$get_fit_warm_start_for_length("params", ncol(X_fit)) %||% f$priv$get_fit_warm_start_for_length("beta", ncol(X_fit))
	)
	expect_equal(res, as.numeric(fit_ref$beta_hat), tolerance = 1e-10)
})

test_that("unit (effectively-constant) weights reproduce compute_estimate()'s own unweighted value", {
	f <- dep_cens_fixture(3L)
	unweighted <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))
	res <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$priv$n), estimate_only = TRUE)
	expect_equal(res, unweighted, tolerance = 1e-8)
})

test_that("a fit failure (weighted_cox_bootstrap_surrogate_fit() returns NULL) returns NA_real_", {
	f <- dep_cens_fixture(4L)
	invisible(f$inf$compute_estimate())
	local_mocked_bindings(weighted_cox_bootstrap_surrogate_fit = function(...) NULL, .package = "EDI")
	set.seed(5L); row_weights <- runif(f$priv$n, 0.3, 2)
	res <- f$inf$compute_estimate_with_bootstrap_weights(row_weights, estimate_only = TRUE)
	expect_true(is.na(res))
})
