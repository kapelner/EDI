library(testthat)
library(EDI)

# inference_incidence_KK_gcomp_abstract.R's own get_cluster_ids() -- a third verbatim copy of the
# same three-tier cache (design-level, inference-level for bootstrap resamples, recompute) already
# covered separately for InferenceAbstractKKMarginalIncid (incidence, test-kk-marginal-incid-
# cluster-id-cache-and-covariate-names-reference.R) and InferenceSurvivalKKWeibullMarginal
# (survival, test-kk-weibull-marginal-cluster-id-cache-reference.R). This gcomp copy is
# specifically documented as "copied verbatim" from InferenceAbstractKKMarginalIncid in this
# class's own migration-golden test header comment (test-incid-kk-gcomp-migration-golden.R),
# which itself only ever mentions get_cluster_ids() in a comment, never calls it directly or
# resamples the match vector -- existing coverage on InferenceIncidKKGCompRiskDiff/RiskRatio
# exercises jackknife/bootstrap machinery (which calls get_cluster_ids() internally) but never at
# more than one match vector, so the design-level cache-hit shortcut, the inference-level
# (bootstrap-resample) cache fill/hit, and NULL/NA match handling were never directly exercised.
# Only the pure m_vec-caching logic is touched here -- no bootstrap-worker-reuse machinery.

ref_cluster_ids <- function(m) {
	m <- as.integer(m)
	m[is.na(m)] <- 0L
	out <- m
	zero <- which(m == 0L)
	out[zero] <- max(m, 0L) + seq_along(zero)
	out
}

make_kk_gcomp_cluster_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w <- rep(c(0, 1), n / 2L)
	des$overwrite_all_subject_assignments(w)
	y <- rbinom(n, 1, plogis(-0.5 + w + 0.4 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKGCompRiskDiff$new(des, model_formula = ~ x, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

test_that("original match vector: cluster ids match the reference and are cached at the design level", {
	f <- make_kk_gcomp_cluster_fixture()
	des_priv <- f$priv$des_obj_priv_int
	m <- f$priv$m
	expect_true(all(m > 0))

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
	f <- make_kk_gcomp_cluster_fixture()
	des_priv <- f$priv$des_obj_priv_int
	orig <- f$priv$get_cluster_ids()

	m2 <- f$priv$m
	m2[m2 == 1] <- 0L
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
	m3[m3 == 2] <- 0L
	f$priv$m <- m3
	expect_equal(as.integer(f$priv$get_cluster_ids()), ref_cluster_ids(m3))
})

test_that("NULL and NA match entries are treated as unmatched singletons", {
	f <- make_kk_gcomp_cluster_fixture()
	f$priv$m <- NULL
	expect_equal(as.integer(f$priv$get_cluster_ids()), seq_len(f$n))

	f2 <- make_kk_gcomp_cluster_fixture(seed = 2L)
	m <- f2$priv$m
	na_idx <- which(m > 0)[1:2]
	m[na_idx] <- NA
	f2$priv$m <- m
	expect_equal(as.integer(f2$priv$get_cluster_ids()), ref_cluster_ids(m))
})
