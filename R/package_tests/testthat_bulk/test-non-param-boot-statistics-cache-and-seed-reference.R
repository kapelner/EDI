library(testthat)
library(EDI)

# Release v1.0.5 TODO-57 -> bayesian_bootstrap_performance.md TODO-11: the ordinary bootstrap's
# approximate_bootstrap_statistics_beta_hat_T() caches the unfiltered B x 2 (theta, se) matrix keyed
# by B and smooth, and honors the object seed with a save/restore of .Random.seed.

make_stats_cache_fixture <- function(seed = NULL, n = 30L) {
	set.seed(11L)
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	d$add_all_subject_responses(rnorm(n) + d$get_w())
	inf <- InferenceContinLin$new(d, harden = FALSE, verbose = FALSE)
	if (!is.null(seed)) inf$set_seed(seed)
	inf
}

cache_names <- function(inf) names(inf$.__enclos_env__$private$cached_values$boot_stats_cache)

test_that("a second statistics request with the same B/smooth reuses the cached resamples", {
	inf <- make_stats_cache_fixture()
	priv <- inf$.__enclos_env__$private
	a <- priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, require_se = TRUE)
	b <- priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, require_se = TRUE)
	# unseeded: identical values can only come from the cache, not fresh resamples
	expect_identical(a, b)
	expect_length(cache_names(inf), 1L)
	# na.rm = FALSE shares the same entry and returns all B rows
	c0 <- priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, require_se = TRUE, na.rm = FALSE)
	expect_length(c0$theta, 20L)
	expect_equal(c0$theta[is.finite(c0$se) & c0$se > 0], a$theta)
	expect_length(cache_names(inf), 1L)
	# a require_se = TRUE smooth entry serves a later require_se = FALSE smooth request; se is blanked
	e <- priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, smooth = TRUE, require_se = TRUE)
	expect_length(cache_names(inf), 2L)
	d <- priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, smooth = TRUE, require_se = FALSE, na.rm = FALSE)
	expect_length(cache_names(inf), 2L)
	expect_equal(d$theta, priv$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, smooth = TRUE, require_se = TRUE, na.rm = FALSE)$theta)
	expect_true(all(is.na(d$se)))
})

test_that("a different B or smooth setting misses the cache", {
	inf <- make_stats_cache_fixture()
	priv <- inf$.__enclos_env__$private
	priv$approximate_bootstrap_statistics_beta_hat_T(B = 15L, show_progress = FALSE, require_se = TRUE)
	priv$approximate_bootstrap_statistics_beta_hat_T(B = 16L, show_progress = FALSE, require_se = TRUE)
	expect_length(cache_names(inf), 2L)
	priv$approximate_bootstrap_statistics_beta_hat_T(B = 15L, show_progress = FALSE, smooth = TRUE, require_se = TRUE)
	expect_length(cache_names(inf), 3L)
})

test_that("with a seed set, two fresh objects give identical statistics and the caller's RNG is restored", {
	a <- make_stats_cache_fixture(seed = 7L)
	b <- make_stats_cache_fixture(seed = 7L)
	set.seed(99L); before <- .Random.seed
	sa <- a$.__enclos_env__$private$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, require_se = TRUE)
	expect_identical(.Random.seed, before)
	sb <- b$.__enclos_env__$private$approximate_bootstrap_statistics_beta_hat_T(B = 20L, show_progress = FALSE, require_se = TRUE)
	expect_identical(sa, sb)
})

test_that("duplicate() does not carry the statistics cache", {
	inf <- make_stats_cache_fixture()
	priv <- inf$.__enclos_env__$private
	priv$approximate_bootstrap_statistics_beta_hat_T(B = 10L, show_progress = FALSE, require_se = TRUE)
	expect_false(is.null(priv$cached_values$boot_stats_cache))
	dup <- inf$duplicate()
	expect_null(dup$.__enclos_env__$private$cached_values$boot_stats_cache)
})
