library(testthat)
library(EDI)

# InferenceAll's shared private compute_jackknife_summary() (inference_all_abstract_jackknife.R) is
# used by every jackknife-capable class, but two of its five distinct nonestimable-reason branches --
# "jackknife_nonfinite_replicate_estimates" and "jackknife_extreme_finite_estimates" -- had zero test
# reference anywhere (confirmed via grep; "jackknife_original_estimate_unavailable" and
# "jackknife_extreme_summary" are each covered once elsewhere). Exercised here via a lightweight
# InferenceContinOLS instance with private$approximate_jackknife_distribution_beta_hat_T_private()
# mocked to return a controlled replicate distribution, since the branches under test depend only on
# properties of that distribution, not on any particular fitter.
#   1. Any non-finite jackknife replicate is nonestimable ("jackknife_nonfinite_replicate_estimates"),
#      with the raw (non-finite-containing) distribution still recorded.
#   2. A jackknife replicate whose magnitude exceeds bootstrap_extreme_estimate_threshold is
#      nonestimable ("jackknife_extreme_finite_estimates").
#   3. Fewer than 2 replicate estimates silently returns all-NA with no nonestimable reason recorded
#      (distinct from the two guard branches above, which both DO record a reason).
#   4. On a well-behaved distribution, estimate/bias/std_error match the jackknife formula
#      (bias-corrected estimate, delete-1 jackknife variance) computed independently by hand.
#   5. Caching: a second call for the same unit returns the cached summary without re-invoking
#      approximate_jackknife_distribution_beta_hat_T_private() at all.

jackknife_fixture <- function(seed, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	theta_hat <- as.numeric(inf$compute_estimate(estimate_only = TRUE))
	list(inf = inf, priv = priv, theta_hat = theta_hat)
}

mock_jackknife_distribution <- function(priv, distribution_fn) {
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", priv)
	priv$approximate_jackknife_distribution_beta_hat_T_private <- distribution_fn
	invisible(priv)
}

test_that("any non-finite jackknife replicate is nonestimable, with the raw distribution still recorded", {
	f <- jackknife_fixture(1L)
	jack <- c(f$theta_hat, NA_real_, f$theta_hat + 0.1)
	mock_jackknife_distribution(f$priv, function(unit) jack)

	res <- f$priv$compute_jackknife_summary(unit = "auto")
	expect_true(is.na(res$estimate)); expect_true(is.na(res$bias)); expect_true(is.na(res$std_error))
	expect_equal(res$distribution, jack)
	expect_equal(f$inf$get_nonestimable_reason(), "jackknife_nonfinite_replicate_estimates")
})

test_that("a jackknife replicate exceeding bootstrap_extreme_estimate_threshold is nonestimable", {
	f <- jackknife_fixture(2L)
	jack <- c(f$theta_hat, f$theta_hat, f$theta_hat + 1e10)
	mock_jackknife_distribution(f$priv, function(unit) jack)

	res <- f$priv$compute_jackknife_summary(unit = "auto")
	expect_true(is.na(res$estimate))
	expect_equal(f$inf$get_nonestimable_reason(), "jackknife_extreme_finite_estimates")
})

test_that("fewer than 2 replicate estimates silently returns all-NA with no nonestimable reason recorded", {
	f <- jackknife_fixture(3L)
	mock_jackknife_distribution(f$priv, function(unit) numeric(0))

	res <- f$priv$compute_jackknife_summary(unit = "auto")
	expect_true(is.na(res$estimate))
	expect_length(res$distribution, 0L)
	expect_false(isTRUE(f$inf$is_nonestimable("se")))
})

test_that("on a well-behaved distribution, estimate/bias/std_error match the jackknife formula computed independently by hand", {
	f <- jackknife_fixture(4L)
	set.seed(9L); jack <- f$theta_hat + rnorm(20L, sd = 0.05)
	mock_jackknife_distribution(f$priv, function(unit) jack)

	res <- f$priv$compute_jackknife_summary(unit = "auto")
	n_units <- length(jack)
	jack_bar <- mean(jack)
	bias_j <- (n_units - 1) * (jack_bar - f$theta_hat)
	theta_j <- f$theta_hat - bias_j
	var_j <- ((n_units - 1) / n_units) * sum((jack - jack_bar)^2)
	se_j <- sqrt(var_j)
	expect_equal(res$estimate, theta_j, tolerance = 1e-10)
	expect_equal(res$bias, bias_j, tolerance = 1e-10)
	expect_equal(res$std_error, se_j, tolerance = 1e-10)
})

test_that("caching: a second call for the same unit does not re-invoke approximate_jackknife_distribution_beta_hat_T_private() at all", {
	f <- jackknife_fixture(5L)
	set.seed(10L); jack <- f$theta_hat + rnorm(20L, sd = 0.05)
	call_count <- 0L
	mock_jackknife_distribution(f$priv, function(unit) { call_count <<- call_count + 1L; jack })
	f$priv$compute_jackknife_summary(unit = "auto")
	expect_equal(call_count, 1L)

	f$priv$compute_jackknife_summary(unit = "auto")
	expect_equal(call_count, 1L)
})
