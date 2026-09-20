library(testthat)
library(EDI)

# DesignFixedOptimalBlocks: assert_feasible_block_sizes() (floor(n / B) >= 2), draw_ws_raw()
# (exact within-block balance from randomizr::block_ra), and block formation when n is not a
# multiple of B for each solver. The greedy (blockTools) path leaves a trailing incomplete
# block that its own nearest-neighbour fallback never sees (pinned below as a source bug).

X9 <- data.frame(
	x1 = c(-3, -2.9, -2.8, -2.7, -2.6, 2.7, 2.8, 2.9, 3),
	x2 = c(0, 0.1, -0.1, 0.05, 0.2, 5, 5.1, 4.9, 5.05))

mk <- function(method, B = 2L, X = X9, dist = "euclidean") {
	des <- DesignFixedOptimalBlocks$new(response_type = "continuous", method = method, B = B, dist = dist,
		n = nrow(X), seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	list(des = des, p = des$.__enclos_env__$private)
}

test_that("feasibility: blocks need at least two subjects each, checked at construction and before solving", {
	expect_error(mk("K-way", B = 4L, X = X9[1:6, ]), "floor\\(n / B\\) = 1 < 2")
	expect_error(mk("K-way", B = 5L, X = X9), "Minimum block size is 2")
	ok <- mk("K-way", B = 4L, X = rbind(X9, X9[1:3, ]))                      # n = 12, B = 4 -> blocks of 3
	expect_silent(ok$p$assert_feasible_block_sizes(12L))
	expect_error(ok$p$assert_feasible_block_sizes(7L), "floor\\(n / B\\) = 1")
	expect_null(ok$p$assert_feasible_block_sizes(8L))
	withr::local_options(edi.run_asserts = FALSE)
	expect_silent(ok$p$assert_feasible_block_sizes(3L))                         # assertions off: no check
})

test_that("draw_ws_raw draws balanced assignments within every block, one column per draw", {
	set.seed(3); X16 <- data.frame(x1 = rnorm(16), x2 = rnorm(16))
	f <- mk("K-way", X = X16)                                                       # n = 16, B = 2 -> blocks of 8
	W <- f$p$draw_ws_raw(r = 30L)
	expect_equal(dim(W), c(16L, 30L))
	expect_true(all(W %in% c(0, 1)))
	blocks <- as.integer(f$p$get_or_compute_block_ids())
	for (b in unique(blocks)) {
		nb <- sum(blocks == b)
		counts <- colSums(W[blocks == b, , drop = FALSE])
		expect_true(all(counts %in% c(floor(nb / 2), ceiling(nb / 2))), info = paste("block", b))   # prob_T = 0.5
	}
	expect_gt(length(unique(apply(W, 2, paste, collapse = ""))), 1L)                   # draws differ
})

test_that("ompr blocks handle n not divisible by B: every subject is assigned and sizes differ by at most one", {
	skip_if(!all(vapply(c("ompr", "ompr.roi", "ROI.plugin.glpk"), requireNamespace, logical(1), quietly = TRUE)))
	ids <- mk("ompr")$p$get_or_compute_block_ids()
	expect_false(anyNA(ids))
	expect_equal(levels(ids), c("1", "2"))
	sizes <- as.integer(table(ids))
	expect_lte(max(sizes) - min(sizes), 1L)
	expect_equal(sum(sizes), 9L)
})

test_that("K-way blocks handle n not divisible by B: outlying subjects are held out and join the nearest cluster", {
	ids <- mk("K-way")$p$get_or_compute_block_ids()
	expect_length(ids, 9L)
	expect_false(anyNA(ids))
	expect_equal(levels(ids), c("1", "2"))
	# The fixture has two obvious groups (five with x1 < 0, four with x1 > 0); the held-out subject
	# does not distort them, whichever labels the clustering picks.
	expect_equal(length(unique(ids[X9$x1 < 0])), 1L)
	expect_equal(length(unique(ids[X9$x1 > 0])), 1L)
	expect_false(ids[1] == ids[9])
	expect_equal(sort(as.integer(table(ids))), c(4L, 5L))
	expect_gte(min(table(ids)), 2L)
	# Divisible n still uses the plain balanced clustering (equal groups).
	ids8 <- mk("K-way", X = X9[1:8, ])$p$get_or_compute_block_ids()
	expect_equal(as.integer(table(ids8)), c(4L, 4L))
})

test_that("greedy blocks are complete when n is a multiple of the block size", {
	f <- mk("greedy", X = X9[1:8, ])
	ids <- f$p$get_or_compute_block_ids()
	expect_false(anyNA(ids))
	expect_equal(as.integer(table(ids)), c(4L, 4L))
})

test_that("greedy blocks assign the leftover subject to its nearest assigned neighbour's block when n is not a multiple of the block size", {
	ids <- mk("greedy")$p$get_or_compute_block_ids()
	expect_length(ids, 9L)
	expect_false(anyNA(ids))
	expect_equal(levels(ids), c("1", "2"))
	# blockTools leaves subject 3 unassigned (blocks {1,2,4,5} and {6,7,8,9}); its nearest assigned
	# neighbour (brute force over the eight) decides its block.
	X <- as.matrix(X9)
	assigned <- setdiff(1:9, 3L)
	nearest <- assigned[which.min(rowSums(sweep(X[assigned, ], 2, X[3, ])^2))]
	expect_equal(ids[3], ids[nearest])
	expect_equal(as.integer(ids[-3]), c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L))
	expect_equal(as.integer(ids[3]), 1L)
})
