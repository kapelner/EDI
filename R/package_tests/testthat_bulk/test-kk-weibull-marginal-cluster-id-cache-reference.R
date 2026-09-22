library(testthat)
library(EDI)

# InferenceSurvivalKKWeibullMarginal's own private get_cluster_ids() (inference_survival_KK_
# weibull_marginal.R) -- a three-tier cache (design-level, inference-level for bootstrap
# resamples, recompute) duplicated verbatim (per its own header comment) from
# InferenceAbstractKKMarginalIncid's get_cluster_ids() since this class is survival-only. The
# incidence sibling's cache branches already have dedicated coverage
# (test-kk-marginal-incid-cluster-id-cache-and-covariate-names-reference.R); this survival class's
# own copy of the same logic had none -- existing coverage
# (test-kk-weibull-marginal-weighted-bootstrap-cluster-surrogate.R) only ever calls
# get_cluster_ids() once against the original (unresampled) match vector, so the design-level
# cache-hit shortcut, the inference-level (bootstrap-resample) cache fill/hit, and NULL/NA match
# handling were never exercised.

ref_cluster_ids <- function(m) {
	m <- as.integer(m)
	m[is.na(m)] <- 0L
	out <- m
	zero <- which(m == 0L)
	out[zero] <- max(m, 0L) + seq_along(zero)
	out
}

make_weibull_marginal_cluster_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_lat <- exp(0.8 - 0.3 * ((w_i + 1) / 2)) * rexp(1L)
		des$add_one_subject_response(i, y = max(y_lat, 0.05))
	}
	inf <- InferenceSurvivalKKWeibullMarginal$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

test_that("original match vector: cluster ids match the reference and are cached at the design level", {
	f <- make_weibull_marginal_cluster_fixture()
	des_priv <- f$priv$des_obj_priv_int
	m <- f$priv$m
	expect_true(any(m > 0) && any(m == 0))

	cid <- f$priv$get_cluster_ids()
	expect_equal(as.integer(cid), ref_cluster_ids(m))
	expect_identical(des_priv$cluster_id, cid)
	expect_equal(as.integer(des_priv$cluster_id_m_vec), as.integer(m))
	expect_null(f$priv$cached_values$cluster_id)

	# A design-level cache hit is returned as-is (no recompute).
	des_priv$cluster_id <- rep(99L, f$n)
	expect_identical(f$priv$get_cluster_ids(), rep(99L, f$n))
})

test_that("a resampled match vector uses and fills the inference-level cache without touching the design cache", {
	f <- make_weibull_marginal_cluster_fixture()
	des_priv <- f$priv$des_obj_priv_int
	orig <- f$priv$get_cluster_ids()

	m2 <- f$priv$m
	matched_val <- m2[m2 > 0][1]
	m2[m2 == matched_val] <- 0L
	f$priv$m <- m2
	cid2 <- f$priv$get_cluster_ids()
	expect_equal(as.integer(cid2), ref_cluster_ids(m2))
	expect_false(identical(cid2, orig))
	expect_identical(des_priv$cluster_id, orig)
	expect_identical(f$priv$cached_values$cluster_id, cid2)
	expect_equal(as.integer(f$priv$cached_values$cluster_id_m_vec), as.integer(m2))

	# Same resampled vector again: served from the inference-level cache.
	f$priv$cached_values$cluster_id <- rep(77L, f$n)
	expect_identical(f$priv$get_cluster_ids(), rep(77L, f$n))

	# A different resampled vector invalidates that cache and recomputes.
	m3 <- f$priv$m
	other_val <- m3[m3 > 0][1]
	m3[m3 == other_val] <- 0L
	f$priv$m <- m3
	expect_equal(as.integer(f$priv$get_cluster_ids()), ref_cluster_ids(m3))
})

test_that("NULL and NA match entries are treated as unmatched singletons", {
	f <- make_weibull_marginal_cluster_fixture()
	f$priv$m <- NULL
	expect_equal(as.integer(f$priv$get_cluster_ids()), seq_len(f$n))

	f2 <- make_weibull_marginal_cluster_fixture(seed = 2L)
	m <- f2$priv$m
	na_idx <- which(m > 0)[1:2]
	m[na_idx] <- NA
	f2$priv$m <- m
	expect_equal(as.integer(f2$priv$get_cluster_ids()), ref_cluster_ids(m))
})
