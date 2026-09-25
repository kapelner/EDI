library(testthat)
library(EDI)

# InferenceMixinKKPassThroughCompound (inference_mixin_kk_passthrough_compound.R, registry
# weighted_opportunity 28) provides reduce_design_matrix_once()/only_matches()/only_reservoir()/
# compute_estimate_from_matched_and_reservoir() shared by every KK compound OLS/robust-regr/one-lik/
# IVWC estimator. The happy path (both matched and reservoir data usable, well-conditioned design) is
# well exercised via the concrete classes' own golden/reference tests, but a codebase-wide grep found
# zero test references anywhere to only_matches()/only_reservoir()/
# compute_estimate_from_matched_and_reservoir(), and reduce_design_matrix_once()'s rank-deficient QR
# branch and identical-ncol cache-hit-reuse branch were likewise untested. Exercised here directly via
# InferenceContinKKOLSIVWC (the simplest, purely-linear-algebra concrete consumer of this mixin --
# deliberately not one of the IVWC compound estimators with a numerically fragile optimizer) by
# injecting a private KKstats cache and calling these private methods directly, independent of the
# real matching/statistics machinery (already tested elsewhere via the concrete classes' own tests).

mk_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("only_matches()/only_reservoir() are both FALSE before any KKstats are cached", {
	f <- mk_fixture(1L)
	expect_false(f$priv$only_matches())
	expect_false(f$priv$only_reservoir())
})

test_that("only_matches() is TRUE when nRT <= 1 or nRC <= 1 (reservoir unusable)", {
	f <- mk_fixture(2L)
	f$priv$cached_values$KKstats <- list(nRT = 5, nRC = 1, m = 6)
	expect_true(f$priv$only_matches())
	expect_false(f$priv$only_reservoir())

	f2 <- mk_fixture(3L)
	f2$priv$cached_values$KKstats <- list(nRT = 1, nRC = 5, m = 6)
	expect_true(f2$priv$only_matches())
})

test_that("only_reservoir() is TRUE when m <= 1 (no usable matched pairs)", {
	f <- mk_fixture(4L)
	f$priv$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 1)
	expect_false(f$priv$only_matches())
	expect_true(f$priv$only_reservoir())
})

test_that("both are FALSE when nRT/nRC/m are all comfortably above their thresholds", {
	f <- mk_fixture(5L)
	f$priv$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = 6)
	expect_false(f$priv$only_matches())
	expect_false(f$priv$only_reservoir())
})

test_that("non-finite nRT/nRC/m are treated as inconclusive (both FALSE), not as satisfying the <= 1 condition", {
	f <- mk_fixture(6L)
	f$priv$cached_values$KKstats <- list(nRT = NA_real_, nRC = 5, m = 6)
	expect_false(f$priv$only_matches())
	f2 <- mk_fixture(7L)
	f2$priv$cached_values$KKstats <- list(nRT = 5, nRC = 5, m = NA_real_)
	expect_false(f2$priv$only_reservoir())
})

test_that("compute_estimate_from_matched_and_reservoir() caches 'kk_design_required' and calls neither closure when has_match_structure is FALSE", {
	f <- mk_fixture(8L)
	unlockBinding("has_match_structure", f$priv)
	f$priv$has_match_structure <- FALSE
	matched_called <- FALSE; reservoir_called <- FALSE
	f$priv$compute_estimate_from_matched_and_reservoir(
		run_matched = function() matched_called <<- TRUE,
		run_reservoir = function() reservoir_called <<- TRUE
	)
	expect_false(matched_called)
	expect_false(reservoir_called)
	expect_identical(f$priv$cached_values$nonestimable_reason, "kk_design_required")
})

test_that("compute_estimate_from_matched_and_reservoir() dispatches to only run_matched() when only_matches() is TRUE", {
	f <- mk_fixture(9L)
	f$priv$compute_basic_match_data()
	f$priv$cached_values$KKstats$nRT <- 5
	f$priv$cached_values$KKstats$nRC <- 1
	matched_called <- FALSE; reservoir_called <- FALSE
	f$priv$compute_estimate_from_matched_and_reservoir(
		run_matched = function() matched_called <<- TRUE,
		run_reservoir = function() reservoir_called <<- TRUE
	)
	expect_true(matched_called)
	expect_false(reservoir_called)
})

test_that("compute_estimate_from_matched_and_reservoir() dispatches to only run_reservoir() when only_reservoir() is TRUE", {
	f <- mk_fixture(10L)
	f$priv$compute_basic_match_data()
	f$priv$cached_values$KKstats$m <- 1
	matched_called <- FALSE; reservoir_called <- FALSE
	f$priv$compute_estimate_from_matched_and_reservoir(
		run_matched = function() matched_called <<- TRUE,
		run_reservoir = function() reservoir_called <<- TRUE
	)
	expect_false(matched_called)
	expect_true(reservoir_called)
})

test_that("reduce_design_matrix_once() drops a rank-deficient column via QR pivoting but preserves the treatment column", {
	f <- mk_fixture(11L)
	n <- 20L
	X1 <- cbind(1, treatment = rep(0:1, n / 2), x1 = rnorm(n))
	X_rankdef <- cbind(X1, x1dup = X1[, "x1"])  # exact duplicate -> rank deficient
	res <- f$priv$reduce_design_matrix_once(X_rankdef, j_treat = 2L, cache_key = "test_key")
	expect_equal(ncol(res$X), 3L)  # one column dropped
	expect_equal(res$X[, res$j_treat], X_rankdef[, 2L])  # treatment column survives and j_treat re-indexes correctly
})

test_that("reduce_design_matrix_once() reuses the cached column-keep decision for a later call with the same ncol(X), even with different content", {
	f <- mk_fixture(12L)
	n <- 20L
	X1 <- cbind(1, treatment = rep(0:1, n / 2), x1 = rnorm(n))
	X_rankdef <- cbind(X1, x1dup = X1[, "x1"])
	res1 <- f$priv$reduce_design_matrix_once(X_rankdef, j_treat = 2L, cache_key = "test_key_2")

	# same ncol(X) = 4, but a genuinely full-rank matrix this time -- the cache-hit path must still
	# apply the FIRST call's keep decision rather than re-running QR on this call's own (full-rank) X
	X2 <- cbind(1, treatment = rep(1:0, n / 2), x1 = rnorm(n), x2 = rnorm(n))
	res2 <- f$priv$reduce_design_matrix_once(X2, j_treat = 2L, cache_key = "test_key_2")
	expect_equal(ncol(res2$X), ncol(res1$X))
	expect_equal(res2$j_treat, res1$j_treat)
	# confirms this is the cached (dropped-4th-column) shape, not a fresh QR on X2's own (full-rank) structure
	expect_equal(res2$X, X2[, -4, drop = FALSE])
})
