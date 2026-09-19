library(testthat)
library(EDI)

# InferenceAbstractKKMarginalIncid's private get_cluster_ids() (three-tier
# cache: design-level, inference-level for bootstrap resamples, recompute) and
# get_covariate_names() (colnames fallback). The sibling asymptotic reference
# test calls get_cluster_ids() once on the original matching only, so the
# bootstrap-resample cache branches and the NA/NULL match-vector handling were
# never exercised. Reference cluster ids are built from scratch: matched
# subjects (m > 0) share their pair id, unmatched subjects (m == 0 or NA) become
# singletons numbered consecutively after the largest pair id.

ref_cluster_ids <- function(m) {
	m <- as.integer(m)
	m[is.na(m)] <- 0L
	out <- m
	zero <- which(m == 0L)
	out[zero] <- max(m, 0L) + seq_along(zero)
	out
}

make_kk_cluster_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
		des$add_one_subject_response(i, rbinom(1, 1, 0.4))
	}
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

test_that("original match vector: cluster ids match the reference and are cached at the design level", {
	f <- make_kk_cluster_fixture()
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
	f <- make_kk_cluster_fixture()
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
	f <- make_kk_cluster_fixture()
	f$priv$m <- NULL
	expect_equal(as.integer(f$priv$get_cluster_ids()), seq_len(f$n))

	f2 <- make_kk_cluster_fixture()
	m <- f2$priv$m
	m[c(2, 4)] <- NA
	f2$priv$m <- m
	expect_equal(as.integer(f2$priv$get_cluster_ids()), ref_cluster_ids(m))
})

test_that("get_covariate_names returns design colnames and falls back to x1..xp when unnamed", {
	f <- make_kk_cluster_fixture()
	expect_equal(f$priv$get_covariate_names(), c("x1", "x2"))

	unlockBinding("get_X", f$priv)
	f$priv$get_X <- function() matrix(0, nrow = 5, ncol = 3)
	expect_equal(f$priv$get_covariate_names(), c("x1", "x2", "x3"))
	f$priv$get_X <- function() matrix(0, nrow = 5, ncol = 2, dimnames = list(NULL, c("a", "b")))
	expect_equal(f$priv$get_covariate_names(), c("a", "b"))
})
