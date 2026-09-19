library(testthat)
library(EDI)

# InferencePropGCompMeanDiff's private bootstrap_sample_is_usable() (called
# from load_bootstrap_sample_into_worker() during approximate_bootstrap_distribution_beta_hat_T())
# gates every resample against boundary mass / group-size / separation
# thresholds before it's allowed to feed a bootstrap point estimate. Confirmed
# via repo-wide grep this predicate has zero test references anywhere,
# despite being the resample-screening gate for the entire bootstrap-CI path.

prop_gcomp_screening_fixture <- function() {
	set.seed(1)
	n <- 40L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- plogis(-0.2 + 0.6 * w + 0.4 * x + rnorm(n, sd = 0.3))
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE)
}

test_that("bootstrap_sample_is_usable rejects mismatched lengths, empty input, and non-finite responses", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private

	expect_false(priv$bootstrap_sample_is_usable(w_b = c(0, 1), y_b = c(0.3, 0.4, 0.5)))
	expect_false(priv$bootstrap_sample_is_usable(w_b = numeric(0), y_b = numeric(0)))
	expect_false(priv$bootstrap_sample_is_usable(w_b = c(0, 1, 1), y_b = c(0.2, NA_real_, 0.4)))
	expect_false(priv$bootstrap_sample_is_usable(w_b = c(0, 1, 1), y_b = c(0.2, Inf, 0.4)))
})

test_that("bootstrap_sample_is_usable requires both arms present", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private

	# All-treatment or all-control resamples have no contrast to estimate.
	expect_false(priv$bootstrap_sample_is_usable(w_b = rep(1, 10), y_b = runif(10, 0.2, 0.8)))
	expect_false(priv$bootstrap_sample_is_usable(w_b = rep(0, 10), y_b = runif(10, 0.2, 0.8)))
})

test_that("bootstrap_sample_is_usable rejects excessive boundary mass at the default threshold", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private
	w_b <- rep(0:1, 10)
	# 19/20 values sit at or past the 0.02 boundary_tol -- default max_boundary_mass
	# is 0.95, so this must fail; loosening the tolerance to allow it must pass.
	y_boundary <- c(rep(0.005, 19), 0.5)
	expect_false(priv$bootstrap_sample_is_usable(w_b, y_boundary))
	expect_true(priv$bootstrap_sample_is_usable(w_b, y_boundary, max_boundary_mass = 0.99))
})

test_that("bootstrap_sample_is_usable rejects groups below min_group_n", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private
	# Only 3 control units, default min_group_n = 5.
	w_b <- c(rep(0, 3), rep(1, 10))
	y_b <- runif(13, 0.3, 0.7)
	expect_false(priv$bootstrap_sample_is_usable(w_b, y_b))
	expect_true(priv$bootstrap_sample_is_usable(w_b, y_b, min_group_n = 3L))
})

test_that("bootstrap_sample_is_usable rejects perfectly separated arms and honors sep_tol", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private
	w_b <- rep(0:1, 10)
	# Control arm entirely below 0.3, treatment arm entirely above 0.5 -- a
	# clean separation gap exceeding the default sep_tol = 0.02.
	y_sep <- rep(NA_real_, 20)
	y_sep[w_b == 0] <- runif(10, 0.1, 0.25)
	y_sep[w_b == 1] <- runif(10, 0.55, 0.75)
	expect_false(priv$bootstrap_sample_is_usable(w_b, y_sep))
	# A tighter sep_tol than the actual observed gap should still reject it;
	# a tolerance larger than the gap must let the sample through.
	gap <- min(y_sep[w_b == 1]) - max(y_sep[w_b == 0])
	expect_false(priv$bootstrap_sample_is_usable(w_b, y_sep, sep_tol = gap * 0.5))
	expect_true(priv$bootstrap_sample_is_usable(w_b, y_sep, sep_tol = gap * 1.5))
})

test_that("bootstrap_sample_is_usable accepts a well-mixed, adequately-sized, non-separated resample", {
	inf <- prop_gcomp_screening_fixture()
	priv <- inf$.__enclos_env__$private
	set.seed(11)
	w_b <- rep(0:1, 15)
	y_b <- plogis(rnorm(30, sd = 0.5))
	expect_true(priv$bootstrap_sample_is_usable(w_b, y_b))
})
