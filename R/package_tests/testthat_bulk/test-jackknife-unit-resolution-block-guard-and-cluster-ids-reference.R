library(testthat)
library(EDI)

# InferenceNonParamBootstrap jackknife plumbing: resolve_jackknife_unit() per design kind,
# jackknife_block_size_gt_one_unsupported() (blocks of size > 1 cannot be deleted one
# observation at a time), mark_jackknife_nonestimable_if_block_unsupported(), and
# get_cluster_jackknife_ids() (cluster labels or NULL).

fx_plain <- function(n = 20L) {
	set.seed(1)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); list(inf = inf, p = inf$.__enclos_env__$private, des = des)
}

fx_block <- function(n = 24L) {
	set.seed(2)
	des <- DesignFixedBlocking$new(strata_cols = "g", response_type = "continuous", n = n, seed = 2, verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(data.frame(g = factor(rep(c("a", "b", "c"), each = n / 3)), x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); list(inf = inf, p = inf$.__enclos_env__$private, des = des)
}

fx_cluster <- function(n = 24L) {
	set.seed(3)
	des <- DesignFixedCluster$new(cluster_col = "cl", response_type = "continuous", n = n, seed = 3, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(cl = rep(paste0("c", 1:6), each = n / 6), x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); list(inf = inf, p = inf$.__enclos_env__$private, des = des)
}

test_that("unit resolution: observation by default, block for blocking designs, cluster for cluster designs; explicit units pass through", {
	expect_equal(fx_plain()$p$resolve_jackknife_unit("auto"), "observation")
	expect_equal(fx_block()$p$resolve_jackknife_unit("auto"), "block")
	expect_equal(fx_cluster()$p$resolve_jackknife_unit("auto"), "cluster")
	for (u in c("observation", "block", "cluster", "pair", "matched_set")) expect_equal(fx_plain()$p$resolve_jackknife_unit(u), u)
	expect_error(fx_plain()$p$resolve_jackknife_unit("nonsense"))
})

test_that("block-size guard: only observation-level deletion inside multi-member blocks is unsupported", {
	b <- fx_block()
	expect_false(b$p$jackknife_block_size_gt_one_unsupported("auto"))           # deletes whole blocks
	expect_false(b$p$jackknife_block_size_gt_one_unsupported("block"))
	expect_false(b$p$jackknife_block_size_gt_one_unsupported("pair"))
	expect_true(b$p$jackknife_block_size_gt_one_unsupported("observation"))     # blocks of 8 cannot be broken up
	expect_false(fx_plain()$p$jackknife_block_size_gt_one_unsupported("observation"))   # not a blocking design
	expect_false(fx_cluster()$p$jackknife_block_size_gt_one_unsupported("auto"))
	# Singleton blocks are fine at the observation level.
	s <- fx_block(); unlockBinding("get_block_ids", s$des)
	s$des$get_block_ids <- function() seq_len(24L)
	expect_false(s$p$jackknife_block_size_gt_one_unsupported("observation"))
	# An unavailable block-id vector or one with no usable ids is treated as supported.
	n1 <- fx_block(); unlockBinding("get_block_ids", n1$des); n1$des$get_block_ids <- function() NULL
	expect_false(n1$p$jackknife_block_size_gt_one_unsupported("observation"))
	n2 <- fx_block(); unlockBinding("get_block_ids", n2$des); n2$des$get_block_ids <- function() rep(NA_integer_, 24L)
	expect_false(n2$p$jackknife_block_size_gt_one_unsupported("observation"))
})

test_that("marking: an unsupported block size caches a nonestimable SE with the documented reason", {
	b <- fx_block()
	expect_false(b$p$mark_jackknife_nonestimable_if_block_unsupported("auto"))
	expect_false(b$inf$is_nonestimable("any"))
	expect_true(b$p$mark_jackknife_nonestimable_if_block_unsupported("observation"))
	expect_true(b$inf$is_nonestimable("se"))
	expect_identical(b$inf$get_nonestimable_reason(), "jackknife_block_size_gt_one_not_supported")
})

test_that("cluster jackknife ids are the design's cluster labels for cluster designs and NULL otherwise", {
	c1 <- fx_cluster()
	expect_equal(c1$p$get_cluster_jackknife_ids(c1$des), rep(paste0("c", 1:6), each = 4))
	expect_type(c1$p$get_cluster_jackknife_ids(c1$des), "character")
	p1 <- fx_plain(); b1 <- fx_block()
	expect_null(p1$p$get_cluster_jackknife_ids(p1$des))
	expect_null(b1$p$get_cluster_jackknife_ids(b1$des))
})
