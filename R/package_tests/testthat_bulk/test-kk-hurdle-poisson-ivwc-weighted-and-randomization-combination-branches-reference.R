library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC (inference_count_KK_cond_poisson.R) implements the same m_ok/r_ok
# inverse-variance-combination logic in THREE separate places: shared() (already closed this stretch
# in test-kk-hurdle-poisson-ivwc-shared-matched-reservoir-combination-branches-reference.R),
# compute_estimate_with_bootstrap_weights(), and compute_treatment_estimate_during_randomization_
# inference() -- the latter two have their own independent copies of the m_ok/r_ok dispatch (not
# delegating to shared()), and neither had a test exercising anything but the ordinary "both pieces
# succeed" happy path:
#   - test-hurdle-poisson-ivwc-weighted-bootstrap-reference.R only ever calls
#     compute_estimate_with_bootstrap_weights() on real, well-conditioned data where both the
#     matched-pairs and reservoir pieces are usable.
#   - compute_treatment_estimate_during_randomization_inference() (the per-permutation randomization-
#     inference hot path) has no test reference anywhere calling it directly (confirmed via grep).
# This file closes the matched-only/reservoir-only/neither-usable branches for both methods, using
# the identical unlockBinding-replacement mocking technique already established for this class's
# shared() test (stubbing fit_hurdle_for_matched_pairs()/fit_poisson_for_reservoir() with exact
# beta/variance values), independent of the real hurdle-GLMM/Poisson-fitting machinery (already
# tested elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rpois(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)
	list(inf = inf, priv = priv, n = n)
}

set_mocks <- function(priv, beta_m, se_m, beta_r, ssq_r) {
	unlockBinding("fit_hurdle_for_matched_pairs", priv)
	priv$fit_hurdle_for_matched_pairs <- function(...) list(beta_hat = beta_m, se = se_m)
	unlockBinding("fit_poisson_for_reservoir", priv)
	priv$fit_poisson_for_reservoir <- function(...) list(beta_hat = beta_r, ssq_hat = ssq_r)
}

test_that("compute_estimate_with_bootstrap_weights(): matched-only piece succeeds gives beta_m", {
	f <- mk_fixture(1L)
	set_mocks(f$priv, 1.2, sqrt(0.2), NA_real_, NA_real_)
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = FALSE), 1.2)
})

test_that("compute_estimate_with_bootstrap_weights(): reservoir-only piece succeeds gives beta_r", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, NA_real_, NA_real_, 0.9, 0.5)
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = FALSE), 0.9)
})

test_that("compute_estimate_with_bootstrap_weights(): neither piece succeeds gives NA", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = FALSE)))
})

test_that("compute_estimate_with_bootstrap_weights(): both pieces succeed matches the closed-form IVWC formula", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, 1.2, sqrt(0.2), 0.9, 0.5)
	est <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = FALSE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.9, tolerance = 1e-10)
})

test_that("estimate-only weighted bootstrap still requests both real component variances", {
	f <- mk_fixture(41L)
	calls <- new.env(parent = emptyenv())
	unlockBinding("fit_hurdle_for_matched_pairs", f$priv)
	f$priv$fit_hurdle_for_matched_pairs <- function(...) {
		calls$matched <- list(...)
		list(beta_hat = 1.2, se = sqrt(0.2))
	}
	unlockBinding("fit_poisson_for_reservoir", f$priv)
	f$priv$fit_poisson_for_reservoir <- function(...) {
		calls$reservoir <- list(...)
		list(beta_hat = 0.9, ssq_hat = 0.5)
	}
	est <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = TRUE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.9, tolerance = 1e-10)
	expect_false("se" %in% names(calls$matched))
	expect_false("estimate_only" %in% names(calls$reservoir))
})

test_that("compute_treatment_estimate_during_randomization_inference(): matched-only piece succeeds gives beta_m", {
	f <- mk_fixture(5L)
	set_mocks(f$priv, 1.2, sqrt(0.2), NA_real_, NA_real_)
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE), 1.2)
})

test_that("compute_treatment_estimate_during_randomization_inference(): reservoir-only piece succeeds gives beta_r", {
	f <- mk_fixture(6L)
	set_mocks(f$priv, NA_real_, NA_real_, 0.9, 0.5)
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE), 0.9)
})

test_that("compute_treatment_estimate_during_randomization_inference(): neither piece succeeds gives NA", {
	f <- mk_fixture(7L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)))
})

test_that("compute_treatment_estimate_during_randomization_inference(): both pieces succeed matches the closed-form IVWC formula", {
	f <- mk_fixture(8L)
	set_mocks(f$priv, 1.2, sqrt(0.2), 0.9, 0.5)
	est <- f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.9, tolerance = 1e-10)
})

test_that("estimate-only ordinary and randomization paths preserve real IVWC weights", {
	for (mode in c("ordinary", "randomization")) {
		f <- mk_fixture(if (mode == "ordinary") 42L else 43L)
		calls <- new.env(parent = emptyenv())
		unlockBinding("fit_hurdle_for_matched_pairs", f$priv)
		f$priv$fit_hurdle_for_matched_pairs <- function(...) {
			args <- list(...); calls$matched <- args
			list(beta_hat = 1.2, se = if (isFALSE(args$se)) 1 else sqrt(0.2))
		}
		unlockBinding("fit_poisson_for_reservoir", f$priv)
		f$priv$fit_poisson_for_reservoir <- function(...) {
			args <- list(...); calls$reservoir <- args
			list(beta_hat = 0.9, ssq_hat = if (isTRUE(args$estimate_only)) 1 else 0.5)
		}
		est <- if (mode == "ordinary") {
			f$inf$compute_estimate(estimate_only = TRUE)
		} else {
			f$priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
		}
		w_star <- 0.5 / (0.5 + 0.2)
		expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.9, tolerance = 1e-10)
		expect_false("se" %in% names(calls$matched))
		expect_false("estimate_only" %in% names(calls$reservoir))
	}
})
