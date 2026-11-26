# v1.0.6-TODO-36: DesignFixedBlockedCluster rejected blocks with different numbers of
# subjects and told the user to set equal_block_sizes = FALSE, an argument it does not
# take. Its randomization unit is the cluster, so unequal strata are allowed; the shared
# unequal-blocks error now names only arguments the class's constructor has.

test_that("DesignFixedBlockedCluster randomizes clusters within unequal-sized blocks", {
	set.seed(1)
	cl = factor(rep(1:8, times = c(3, 4, 5, 6, 3, 4, 5, 7)))
	blk = factor(rep(c("a", "b"), times = c(18, 19)))
	X = data.frame(cl = cl, blk = blk, x = rnorm(37))
	d = DesignFixedBlockedCluster$new(n = 37, response_type = "continuous",
		strata_cols = "blk", cluster_col = "cl", seed = 1)
	d$add_all_subjects_to_experiment(X)
	expect_no_error(d$assign_w_to_all_subjects())
	w = d$get_w()
	expect_true(all(w %in% c(0, 1)))
	# each cluster gets one assignment
	expect_true(all(tapply(w, cl, function(v) length(unique(v))) == 1L))

	# batched path: within each block, exactly half of the 4 clusters are treated
	w_mat = d$draw_ws_according_to_design(50)
	clust_first = match(levels(cl), cl)
	clust_blk = blk[clust_first]
	for (j in seq_len(ncol(w_mat))) {
		expect_true(all(tapply(w_mat[clust_first, j], clust_blk, sum) == 2))
		expect_true(all(tapply(w_mat[, j], cl, function(v) length(unique(v))) == 1L))
	}
})

test_that("DesignFixedBlockedCluster balances clusters per block with odd cluster counts", {
	set.seed(2)
	cl = factor(rep(1:7, times = c(2, 5, 3, 4, 6, 2, 3)))
	blk = factor(c(rep("a", 2 + 5 + 3), rep("b", 4 + 6 + 2 + 3)))
	X = data.frame(cl = cl, blk = blk, x = rnorm(length(cl)))
	d = DesignFixedBlockedCluster$new(n = length(cl), response_type = "continuous",
		strata_cols = "blk", cluster_col = "cl", seed = 3)
	d$add_all_subjects_to_experiment(X)
	w_mat = d$draw_ws_according_to_design(200)
	clust_first = match(levels(cl), cl)
	clust_blk = blk[clust_first]
	n_T = apply(w_mat[clust_first, , drop = FALSE], 2, function(wc) tapply(wc, clust_blk, sum))
	expect_true(all(n_T["a", ] %in% c(1, 2)))   # 3 clusters, prob_T = 0.5
	expect_true(all(n_T["b", ] == 2))           # 4 clusters
	expect_true(any(n_T["a", ] == 1) && any(n_T["a", ] == 2))
})

test_that("equal-size DesignFixedBlockedCluster allocations are unchanged", {
	set.seed(1)
	X2 = data.frame(x1 = rnorm(20), x2 = factor(rep(1:2, each = 10)), cl = factor(rep(1:10, each = 2)))
	d2 = DesignFixedBlockedCluster$new(n = 20, response_type = "continuous",
		strata_cols = "x2", cluster_col = "cl", seed = 7)
	d2$add_all_subjects_to_experiment(X2)
	d2$assign_w_to_all_subjects()
	expect_equal(d2$get_w(), c(0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 1, 1, 0, 0))
})

test_that("DesignFixedBlocking still enforces equal_block_sizes and names its own arguments", {
	set.seed(1)
	X = data.frame(g = factor(rep(c("a", "b"), times = c(9, 11))), x = rnorm(20))
	d = DesignFixedBlocking$new(n = 20, response_type = "continuous", strata_cols = "g")
	d$add_all_subjects_to_experiment(X)
	expect_error(d$assign_w_to_all_subjects(), "Set equal_block_sizes = FALSE")
	d_ok = DesignFixedBlocking$new(n = 20, response_type = "continuous", strata_cols = "g",
		equal_block_sizes = FALSE)
	d_ok$add_all_subjects_to_experiment(X)
	expect_no_error(d_ok$assign_w_to_all_subjects())
})

test_that("the unequal-blocks error does not suggest arguments a class lacks", {
	set.seed(1)
	X = data.frame(cl = factor(rep(1:6, times = c(3, 3, 3, 4, 4, 4))),
		blk = factor(rep(c("a", "b"), times = c(9, 12))))
	d = DesignFixedBlockedCluster$new(n = 21, response_type = "continuous",
		strata_cols = "blk", cluster_col = "cl")
	d$add_all_subjects_to_experiment(X)
	# force the requirement on a class whose constructor has no equal_block_sizes
	d$.__enclos_env__$private$equal_block_sizes = TRUE
	err = tryCatch(d$assign_w_to_all_subjects(), error = function(e) conditionMessage(e))
	expect_match(err, "requires equal block sizes")
	expect_false(grepl("equal_block_sizes", err, fixed = TRUE))
	expect_false(grepl("B_target", err, fixed = TRUE))
})

# v1.0.6-TODO-36 (remaining part, docs-scenarios factorial F6): with B_target given and categorical
# strata of unequal size, the error said "strata_cols was named without B_target" and advised passing
# B_target, which cannot equalise categories.
test_that("the unequal-block error advice matches whether B_target was given and whether the strata are categorical", {
	set.seed(5)
	n = 198
	X = data.frame(age = rnorm(n), B = factor(rep(0:1, c(100, 98))))
	msg = function(...) {
		d = DesignFixedBlocking$new(n = n, response_type = "incidence", verbose = FALSE, ...)
		d$add_all_subjects_to_experiment(X)
		tryCatch({ d$assign_w_to_all_subjects(); NA_character_ }, error = function(e) conditionMessage(e))
	}
	m_target = msg(strata_cols = "B", B_target = 2)
	expect_match(m_target, "B_target = 2 was given, but the strata are categorical", fixed = TRUE)
	expect_false(grepl("without B_target", m_target, fixed = TRUE))
	expect_false(grepl("pass an explicit B_target", m_target, fixed = TRUE))
	m_none = msg(strata_cols = "B")
	expect_match(m_none, "named without B_target", fixed = TRUE)
	expect_false(grepl("pass an explicit B_target", m_none, fixed = TRUE))
	expect_match(m_none, "equal_block_sizes = FALSE", fixed = TRUE)
})
