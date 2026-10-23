# fix: release_v1_0_5.md TODO-118. Blocked null draws are generated in one batched,
# vectorized pass (block_ra_batch) instead of replicate(r, randomizr::block_ra()).
# Same per-block law as block_ra; NOT bit-identical to the old replicate() path under a
# fixed seed (different RNG consumption), a documented seed-pinned-draw change.

make_blocking_design_t118 = function(sizes, prob_T = 0.5, seed = 11L) {
	n = sum(sizes)
	X = data.frame(b = factor(rep(seq_along(sizes), times = sizes)), x = seq_len(n) / n)
	d = DesignFixedBlocking$new(response_type = "continuous", n = n, strata_cols = "b",
		B_target = length(sizes), equal_block_sizes = FALSE, prob_T = prob_T, seed = seed)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	list(d = d, blocks = X$b)
}

test_that("block_ra_batch: every draw has exactly the allowed treated count per block", {
	set.seed(1)
	blocks = rep(1:4, times = c(10, 8, 5, 1))
	w = block_ra_batch(blocks, 0.5, 500L)
	expect_equal(dim(w), c(length(blocks), 500L))
	expect_true(all(w %in% c(0, 1)))
	for (b in 1:4) {
		N = sum(blocks == b)
		tr = colSums(w[blocks == b, , drop = FALSE])
		expect_true(all(tr %in% unique(c(floor(N * 0.5), if (N == 1L || ceiling(N * 0.5) < N) ceiling(N * 0.5)))))
	}
	# singleton block (randomizr: Bernoulli(prob)), not stuck at control
	expect_equal(mean(w[blocks == 4, ]), 0.5, tolerance = 0.1)
	expect_equal(mean(block_ra_batch(c(1, 1, 2), 0.3, 4000L)[3, ]), 0.3, tolerance = 0.04)
	# even block: exactly half every draw
	expect_true(all(colSums(w[blocks == 1, ]) == 5))
	# odd block of 5: 2 or 3, both occur, about half each
	tr5 = colSums(w[blocks == 3, ])
	expect_setequal(unique(tr5), c(2, 3))
	expect_equal(mean(tr5 == 3), 0.5, tolerance = 0.1)
})

test_that("block_ra_batch: marginal treatment probability matches prob and block_ra", {
	skip_if_not_installed("randomizr")
	blocks = rep(1:3, times = c(7, 6, 10))
	for (p in c(0.5, 0.3)) {
		set.seed(2)
		wb = block_ra_batch(blocks, p, 4000L)
		set.seed(3)
		wr = replicate(1500L, as.numeric(as.character(randomizr::block_ra(blocks = blocks, prob = p))))
		expect_equal(rowMeans(wb), rep(p, length(blocks)), tolerance = 0.03)
		expect_equal(mean(rowMeans(wb) - rowMeans(wr)), 0, tolerance = 0.03)
		expect_equal(rowMeans(wb), rowMeans(wr), tolerance = 0.05)
		# same distribution of treated count per block
		for (b in 1:3) {
			tb = table(factor(colSums(wb[blocks == b, , drop = FALSE]), levels = 0:10)) / ncol(wb)
			tr = table(factor(colSums(wr[blocks == b, , drop = FALSE]), levels = 0:10)) / ncol(wr)
			expect_lt(max(abs(tb - tr)), 0.06)
		}
	}
})

test_that("DesignFixedBlocking draws: valid, reproducible by seed, independent of core count", {
	x = make_blocking_design_t118(c(10, 10, 9, 7))
	d = x$d
	w1 = d$draw_ws_according_to_design(200L)
	expect_equal(dim(w1), c(36L, 200L))
	for (b in levels(x$blocks)) {
		N = sum(x$blocks == b)
		tr = colSums(w1[x$blocks == b, , drop = FALSE])
		expect_true(all(tr %in% c(floor(N / 2), ceiling(N / 2))))
	}
	# reproducible: same seed -> same draws, repeated and from a fresh design
	expect_identical(w1, d$draw_ws_according_to_design(200L))
	expect_identical(w1, make_blocking_design_t118(c(10, 10, 9, 7))$d$draw_ws_according_to_design(200L))
	# different seed differs
	expect_false(identical(w1, make_blocking_design_t118(c(10, 10, 9, 7), seed = 12L)$d$draw_ws_according_to_design(200L)))
})

test_that("DesignFixedBlocking draws do not depend on the core count", {
	# set_num_cores(2L) spawns real mirai daemons, and set_num_cores() is one of
	# the documented hang sites (see start_mirai_daemons_bounded() in globals.R),
	# so this has to carry the shared worker-test guard.
	skip_if_prepush_no_parallel()
	x = make_blocking_design_t118(c(10, 10, 9, 7))
	d = x$d
	w1 = d$draw_ws_according_to_design(200L)
	on.exit(unset_num_cores(), add = TRUE)
	set_num_cores(1L); wa = d$draw_ws_according_to_design(200L)
	set_num_cores(2L); wb = d$draw_ws_according_to_design(200L)
	expect_identical(wa, wb)
	expect_identical(wa, w1)
})

test_that("DesignFixedBlocking draws do not require randomizr and honor prob_T", {
	x = make_blocking_design_t118(c(10, 10, 10), prob_T = 0.3)
	w = x$d$draw_ws_according_to_design(100L)
	for (b in levels(x$blocks)) {
		expect_true(all(colSums(w[x$blocks == b, , drop = FALSE]) == 3))
	}
})
