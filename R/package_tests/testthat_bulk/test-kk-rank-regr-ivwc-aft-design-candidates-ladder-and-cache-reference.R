library(testthat)
library(EDI)

# InferenceSurvivalKKRankRegrIVWC's private aft_design_candidates(w, X, cache_key) (inference_survival_
# KK_rank_regr_ivwc_abstract.R) builds the ladder of candidate design matrices the aftsrr fits try in
# turn (a hardened-QR-column-dropped "standard" candidate first, then increasingly aggressive
# correlated-column-dropping thresholds, de-duplicated by column set), cached per cache_key so the
# matched-pairs and reservoir components don't recompute or clobber each other's ladder. A codebase-
# wide grep confirmed zero test references anywhere -- the class's 3 existing test files all exercise
# compute_estimate_with_bootstrap_weights()/migration parity/shared()'s nonestimable guards, none of
# which happen to reach this specific helper directly (aftsrr_for_matched_pairs/_reservoir call it
# internally, but those in turn need the real, comparatively slow aftsrr fitting machinery to reach it
# through the public API). This helper itself is pure/deterministic (fit_fun is the identity and fit_ok
# is always TRUE, so it never actually fits a model) and fast, so it is exercised directly via the
# private method, independent of any aftsrr fit.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rexp(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, X = as.matrix(X))
}

test_that("a full-rank, uncorrelated design's first (standard) candidate keeps every column, always including the required treatment column w", {
	f <- fx(1L)
	cands <- f$priv$aft_design_candidates(f$w, f$X, cache_key = "matched")
	expect_gte(length(cands), 1L)
	expect_identical(colnames(cands[[1L]]), c("w", "x1", "x2"))
	for (cc in lapply(cands, colnames)) expect_true("w" %in% cc)
})

test_that("a highly-correlated covariate pair produces additional, distinct candidates that drop the redundant column, always keeping w", {
	set.seed(2L)
	n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	x1 <- rnorm(n)
	X <- data.frame(x1 = x1, x2 = x1 + rnorm(n, sd = 0.001), x3 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rexp(n, exp(0.3 * w)))
	inf <- InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	cands <- priv$aft_design_candidates(w, as.matrix(X), cache_key = "matched")
	expect_gt(length(cands), 1L)
	col_sets <- lapply(cands, colnames)
	expect_length(unique(vapply(col_sets, paste, character(1L), collapse = "|")), length(cands))  # all distinct
	for (cc in col_sets) expect_true("w" %in% cc)
	# at least one later candidate drops one of the two near-collinear columns
	expect_true(any(vapply(col_sets, function(cc) !all(c("x1", "x2") %in% cc), logical(1L))))
})

test_that("results are cached per cache_key: a repeated call with the same key returns the identical cached object, and different keys are independent", {
	f <- fx(3L)
	cands1 <- f$priv$aft_design_candidates(f$w, f$X, cache_key = "matched")
	cands2 <- f$priv$aft_design_candidates(f$w, f$X, cache_key = "matched")
	expect_identical(cands1, cands2)

	# directly overwrite the "matched" cache entry: a repeat call for the SAME key returns the
	# overwritten value (proving it's a genuine cache hit, not recomputation)...
	f$priv$cached_values$rank_regr_design_candidates_matched <- list(matrix(99))
	cands3 <- f$priv$aft_design_candidates(f$w, f$X, cache_key = "matched")
	expect_identical(cands3, list(matrix(99)))

	# ...while the "reservoir" key is untouched and still computes normally
	cands_reservoir <- f$priv$aft_design_candidates(f$w, f$X, cache_key = "reservoir")
	expect_identical(colnames(cands_reservoir[[1L]]), c("w", "x1", "x2"))
})
