library(testthat)
library(EDI)

# InferenceMixinKKPassThroughCompound$reduce_design_matrix_once(X, j_treat, cache_key)
# (inference_mixin_kk_passthrough_compound.R) is a QR-rank-based column-dropping helper shared by
# every KK compound OLS/robust-regr/one-lik/IVWC estimator. Its only existing test reference
# (test-inference-core-cache-and-matrix-contracts.R) checks that the method exists on the component,
# not what it does. Reached here via InferenceContinKKOLSOneLik, a non-IVWC concrete host of the
# same shared mixin (the IVWC compound estimators are out of scope for this suite).
#
# The function has 4 distinct behaviors:
#   1) full column rank: X passes through unchanged, j_treat unchanged.
#   2) rank-deficient with the treatment column already among the kept pivot columns: drops the
#      redundant column(s), j_treat is remapped to its new position.
#   3) rank-deficient with the treatment column NOT among the naturally-kept pivot columns (it is
#      itself the linearly dependent one): the `if (!(j_treat %in% keep)) keep[rank] = j_treat`
#      rescue fires to force it back in, so a fit against the reduced matrix can still estimate a
#      treatment effect.
#   4) a second call with an X of the SAME ncol as a cached call reuses the cached `keep` selection
#      (and does NOT recompute a fresh QR against the new values) -- verified by using new data whose
#      own rank-revealing QR would select a different column set than the cached one.

kk_ols_onelik_priv <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
	list(priv = inf$.__enclos_env__$private, w = w, n = n)
}

test_that("a full-rank design matrix passes through unchanged", {
	f <- kk_ols_onelik_priv()
	X <- cbind(1, f$w, rnorm(f$n))
	out <- f$priv$reduce_design_matrix_once(X, j_treat = 2L, cache_key = "cache_fullrank")
	expect_identical(out$X, X)
	expect_identical(out$j_treat, 2L)
})

test_that("a rank-deficient matrix drops the redundant column when the treatment column survives pivoting naturally", {
	f <- kk_ols_onelik_priv()
	X <- cbind(1, f$w, f$w)  # column 3 duplicates the treatment column
	qr_X <- qr(X)
	stopifnot(qr_X$rank < ncol(X))
	keep_ref <- sort(qr_X$pivot[seq_len(qr_X$rank)])
	stopifnot(2L %in% keep_ref)  # confirms this fixture exercises the "already kept" sub-case

	out <- f$priv$reduce_design_matrix_once(X, j_treat = 2L, cache_key = "cache_natural")
	expect_identical(out$X, X[, keep_ref, drop = FALSE])
	expect_identical(out$j_treat, which(keep_ref == 2L))
})

test_that("a rank-deficient matrix where the treatment column itself is dropped by pivoting is forced back in", {
	f <- kk_ols_onelik_priv()
	set.seed(7)
	x1 <- rnorm(f$n); x2 <- rnorm(f$n)
	w_redundant <- x1 - x2  # exactly linearly dependent on the two preceding columns
	X <- cbind(1, x1, x2, w_redundant)
	qr_X <- qr(X)
	stopifnot(qr_X$rank < ncol(X))
	pivot_keep <- qr_X$pivot[seq_len(qr_X$rank)]
	stopifnot(!(4L %in% pivot_keep))  # confirms this fixture exercises the "forced back in" sub-case
	# the source overwrites the LAST pivot-order slot with j_treat (not a union/append) before sorting
	pivot_keep[qr_X$rank] <- 4L
	expected_keep <- sort(unique(pivot_keep))

	out <- f$priv$reduce_design_matrix_once(X, j_treat = 4L, cache_key = "cache_forced")
	expect_identical(out$X, X[, expected_keep, drop = FALSE])
	expect_identical(out$j_treat, which(expected_keep == 4L))
})

test_that("a second call with the same ncol reuses the cached column selection instead of a fresh QR", {
	f <- kk_ols_onelik_priv()
	X1 <- cbind(1, f$w, f$w)  # rank-deficient: cached keep drops column 3
	out1 <- f$priv$reduce_design_matrix_once(X1, j_treat = 2L, cache_key = "cache_reuse")
	cached_keep <- c(1L, 2L)
	expect_identical(out1$X, X1[, cached_keep, drop = FALSE])

	# same ncol (3), but full-rank data whose OWN QR would keep all 3 columns -- if the cache were
	# not being reused, this call would return all 3 columns instead of the stale 2
	set.seed(8)
	X2 <- cbind(1, f$w, rnorm(f$n))
	stopifnot(qr(X2)$rank == 3L)
	out2 <- f$priv$reduce_design_matrix_once(X2, j_treat = 2L, cache_key = "cache_reuse")
	expect_identical(out2$X, X2[, cached_keep, drop = FALSE])
	expect_identical(out2$j_treat, 2L)
})
