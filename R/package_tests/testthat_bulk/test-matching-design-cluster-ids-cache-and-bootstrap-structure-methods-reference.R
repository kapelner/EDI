library(testthat)
library(EDI)

# DesignMatching private methods on a KK14 design: compute_matching_cluster_ids(m_vec) (matched pairs share their pair id,
# reservoir subjects get fresh singleton ids, design-level cache only for the design's own m), init_matching_bootstrap_structure()
# (pair-row matrix + reservoir indices), draw_matching_bootstrap_indices() / draw_bootstrap_indices() (pairs resampled as units,
# reservoir resampled iid), reset_matching_caches(). References: hand-derived from the match vector.

set.seed(3); n <- 30L
d <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
for (i in seq_len(n)) { d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1))); d$add_one_subject_response(i, rnorm(1)) }
p <- d$.__enclos_env__$private
m <- as.integer(p$m); m[is.na(m)] <- 0L
m_max <- max(m); n_res <- sum(m == 0L)

test_that("fixture has both matched pairs and reservoir subjects", {
	expect_gt(m_max, 3L); expect_gt(n_res, 3L)
	expect_true(all(as.integer(table(m[m > 0])) == 2L))
})

test_that("cluster ids: pair members share the pair id; reservoir subjects get distinct ids above the pair ids in order", {
	cid <- p$compute_matching_cluster_ids()
	expect_length(cid, n)
	expect_identical(cid[m > 0], m[m > 0])
	expect_identical(cid[m == 0], m_max + seq_len(n_res))
	expect_false(anyDuplicated(cid[m == 0]) > 0)
})

test_that("the design's own match vector is cached; a different vector is computed fresh and does not overwrite the cache", {
	p$reset_matching_caches()
	expect_null(p$cluster_id)
	cid <- p$compute_matching_cluster_ids()
	expect_identical(p$cluster_id, cid); expect_identical(p$cluster_id_m_vec, m)
	p$cluster_id <- rev(cid)                                                           # poison the cache to prove it is used
	expect_identical(p$compute_matching_cluster_ids(), rev(cid))
	alt <- c(1L, 1L, rep(0L, n - 2L))
	got <- p$compute_matching_cluster_ids(alt)
	expect_identical(got, c(1L, 1L, 2:(n - 1L)))                                     # fresh computation; pair id 1 then singletons
	expect_identical(p$cluster_id, rev(cid))                                          # cache untouched
	p$reset_matching_caches()
})

test_that("bootstrap structure: one row per pair holding its two subject indices, reservoir index vector, and idempotence", {
	p$reset_matching_caches()
	expect_null(p$init_matching_bootstrap_structure())
	pr <- p$boot_pair_rows
	expect_identical(dim(pr), c(m_max, 2L))
	for (pid in seq_len(m_max)) expect_identical(as.integer(pr[pid, ]), which(m == pid))
	expect_identical(p$boot_i_reservoir, which(m == 0L)); expect_identical(p$boot_n_reservoir, n_res)
	before <- p$boot_pair_rows; p$init_matching_bootstrap_structure(); expect_identical(p$boot_pair_rows, before)
})

test_that("bootstrap draw: reservoir first (iid from the reservoir, id 0), then whole pairs (consecutive rows, ids 1..k twice)", {
	p$reset_matching_caches()
	set.seed(5); b <- p$draw_matching_bootstrap_indices()
	expect_length(b$i_b, n); expect_length(b$m_vec_b, n)
	expect_identical(b$m_vec_b[seq_len(n_res)], rep(0L, n_res))
	expect_true(all(b$i_b[seq_len(n_res)] %in% which(m == 0L)))
	pair_part <- b$i_b[n_res + seq_len(2L * m_max)]
	firsts <- pair_part[seq(1, 2 * m_max, 2)]; seconds <- pair_part[seq(2, 2 * m_max, 2)]
	expect_identical(m[firsts], m[seconds])                                          # both members of every drawn pair come from the same original pair
	expect_true(all(m[firsts] > 0L)); expect_true(all(firsts != seconds))
	expect_identical(b$m_vec_b[n_res + seq_len(2L * m_max)], rep(seq_len(m_max), each = 2L))
	set.seed(5); expect_identical(p$draw_matching_bootstrap_indices(), b)              # reproducible under the R seed
	set.seed(5); expect_identical(p$draw_bootstrap_indices(), b)                        # the generic entry point delegates to it
})

test_that("resampling actually varies: different seeds give different draws, pair units repeat", {
	set.seed(1); a <- p$draw_matching_bootstrap_indices(); set.seed(2); b <- p$draw_matching_bootstrap_indices()
	expect_false(identical(a$i_b, b$i_b))
	set.seed(3); pairs_drawn <- vapply(1:200, function(i) length(unique(m[p$draw_matching_bootstrap_indices()$i_b[-seq_len(n_res)]])), 0L)
	expect_lt(mean(pairs_drawn), m_max)                                                  # with-replacement over pairs loses some pairs on average
})

test_that("reset clears every cached matching structure", {
	p$compute_matching_cluster_ids(); p$init_matching_bootstrap_structure()
	p$reset_matching_caches()
	for (nm in c("xm_structural", "xm_m_vec", "lin_xm_structural", "lin_xm_m_vec", "cluster_id", "cluster_id_m_vec", "boot_pair_rows", "boot_i_reservoir", "boot_n_reservoir"))
		expect_null(p[[nm]], info = nm)
})
