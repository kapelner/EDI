library(testthat)
library(EDI)

# The MatchingStructure design component (design_matching_abstract.R):
# assert_matching_design(), init_matching_bootstrap_structure(),
# reset_matching_caches(), draw_matching_bootstrap_indices() /
# draw_bootstrap_indices(), and compute_matching_cluster_ids() /
# get_matching_cluster_ids() with their design-level cache. None had a direct
# test reference. References are rebuilt from the design's match vector.

kk_design <- function(n = 30L, seed = 9L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	list(des = des, priv = des$.__enclos_env__$private, n = n)
}

test_that("assert_matching_design passes for matching designs and errors otherwise", {
	f <- kk_design()
	expect_true(f$des$is_matching_design())
	expect_silent(f$des$assert_matching_design())
	# The component's capability flag drives the answer (non-matching designs do not
	# carry the component's methods at all).
	f$priv$matching_capable <- FALSE
	expect_false(f$des$is_matching_design())
	expect_error(f$des$assert_matching_design(), "requires a matching design")
	old <- options(edi.run_asserts = FALSE); on.exit(options(old), add = TRUE)
	expect_silent(f$des$assert_matching_design())
})

test_that("init_matching_bootstrap_structure records pair rows and reservoir rows exactly as the match vector implies", {
	f <- kk_design()
	m <- f$priv$m
	m[is.na(m)] <- 0L
	f$priv$init_matching_bootstrap_structure()
	pair_ids <- seq_len(max(m))
	ref_pairs <- t(vapply(pair_ids, function(p) which(m == p), integer(2)))
	expect_equal(f$priv$boot_pair_rows, ref_pairs)
	expect_equal(f$priv$boot_i_reservoir, which(m == 0L))
	expect_equal(f$priv$boot_n_reservoir, sum(m == 0L))

	# Idempotent: once set, a second call leaves the structure alone.
	f$priv$boot_n_reservoir <- 999L
	f$priv$init_matching_bootstrap_structure()
	expect_equal(f$priv$boot_n_reservoir, 999L)
})

test_that("without a match vector every subject is a reservoir subject", {
	f <- kk_design()
	f$priv$m <- NULL
	f$priv$boot_pair_rows <- NULL
	f$priv$init_matching_bootstrap_structure()
	expect_equal(f$priv$boot_i_reservoir, seq_len(f$n))
	expect_equal(f$priv$boot_n_reservoir, f$n)
	expect_equal(dim(f$priv$boot_pair_rows), c(0L, 2L))
})

test_that("reset_matching_caches clears every cached matching field", {
	f <- kk_design()
	f$priv$init_matching_bootstrap_structure()
	f$des$get_matching_cluster_ids()
	f$priv$xm_structural <- "x"; f$priv$xm_m_vec <- 1L
	f$priv$lin_xm_structural <- "y"; f$priv$lin_xm_m_vec <- 2L
	expect_false(is.null(f$priv$cluster_id))
	expect_invisible(f$priv$reset_matching_caches())
	for (fld in c("xm_structural", "xm_m_vec", "lin_xm_structural", "lin_xm_m_vec", "cluster_id",
		"cluster_id_m_vec", "boot_pair_rows", "boot_i_reservoir", "boot_n_reservoir")) {
		expect_null(f$priv[[fld]], info = fld)
	}
})

test_that("matching bootstrap draws resample reservoir subjects singly and matched pairs whole, with compact match ids", {
	f <- kk_design()
	m <- f$priv$m
	m[is.na(m)] <- 0L
	reservoir <- which(m == 0L)
	pair_rows <- t(vapply(seq_len(max(m)), function(p) which(m == p), integer(2)))
	n_res <- length(reservoir)
	n_pairs <- nrow(pair_rows)

	set.seed(4)
	d <- f$priv$draw_matching_bootstrap_indices()
	expect_length(d$i_b, f$n)
	expect_length(d$m_vec_b, f$n)
	expect_true(all(d$i_b[seq_len(n_res)] %in% reservoir))
	expect_equal(as.integer(d$m_vec_b[seq_len(n_res)]), rep(0L, n_res))
	pair_part <- d$i_b[-seq_len(n_res)]
	expect_length(pair_part, 2L * n_pairs)
	blocks <- matrix(pair_part, ncol = 2, byrow = TRUE)
	valid <- apply(blocks, 1, function(b) any(apply(pair_rows, 1, function(r) all(sort(b) == sort(r)))))
	expect_true(all(valid))
	expect_equal(as.integer(d$m_vec_b[-seq_len(n_res)]), rep(seq_len(n_pairs), each = 2))

	# Seed-reproducible.
	set.seed(4)
	expect_identical(f$priv$draw_matching_bootstrap_indices(), d)
})

test_that("draw_bootstrap_indices dispatches to the matching draw or falls back to a plain resample", {
	f <- kk_design()
	set.seed(6)
	via_generic <- f$priv$draw_bootstrap_indices()
	set.seed(6)
	expect_identical(via_generic, f$priv$draw_matching_bootstrap_indices())

	f$priv$m <- NULL
	set.seed(7)
	plain <- f$priv$draw_bootstrap_indices()
	expect_null(plain$m_vec_b)
	expect_length(plain$i_b, f$n)
	expect_true(all(plain$i_b %in% seq_len(f$n)))

	f2 <- kk_design()
	f2$priv$matching_capable <- FALSE
	set.seed(8)
	expect_null(f2$priv$draw_bootstrap_indices()$m_vec_b)
})

test_that("matching cluster ids keep pair ids, number reservoir subjects after them, and cache only the design's own vector", {
	f <- kk_design()
	m <- f$priv$m
	m[is.na(m)] <- 0L
	ref <- as.integer(m)
	zero <- which(ref == 0L)
	ref[zero] <- max(ref) + seq_along(zero)

	expect_null(f$priv$cluster_id)
	cid <- f$des$get_matching_cluster_ids()
	expect_equal(as.integer(cid), ref)
	expect_identical(f$priv$cluster_id, cid)
	expect_equal(f$priv$cluster_id_m_vec, as.integer(m))

	# Cache hit for the design's own vector, even if the stored value is tampered with.
	f$priv$cluster_id <- rep(42L, f$n)
	expect_identical(f$des$get_matching_cluster_ids(), rep(42L, f$n))

	# A different vector is computed fresh and does not replace the design cache.
	m2 <- m; m2[m2 == 1L] <- 0L
	other <- f$des$get_matching_cluster_ids(m2)
	ref2 <- as.integer(m2); z2 <- which(ref2 == 0L); ref2[z2] <- max(ref2) + seq_along(z2)
	expect_equal(as.integer(other), ref2)
	expect_identical(f$priv$cluster_id, rep(42L, f$n))

	# NULL / NA match entries behave as unmatched singletons.
	f$priv$m <- NULL
	f$priv$cluster_id <- NULL
	expect_equal(as.integer(f$des$get_matching_cluster_ids(NULL)), seq_len(f$n))
})
