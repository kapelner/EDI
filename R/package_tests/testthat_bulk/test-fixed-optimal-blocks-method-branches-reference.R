library(testthat)
library(EDI)

# DesignFixedOptimalBlocks' block-formation branches. Existing coverage
# (R/EDI/tests/testthat/test-fixed-design-optimal-blocks.R) exercises only the
# ompr solve's shape (length / balance), never blocks' membership against an
# independent reference, and never the greedy (blockTools) or K-way
# (anticlust) methods, the no-covariate round-robin fallback, the distance
# matrix conventions, or the block-id / distance-matrix caches.

blocks_fixture_X <- function() {
	data.frame(
		x1 = c(-3, -2.9, -2.8, -2.7, 2.7, 2.8, 2.9, 3),
		x2 = c(0, 0.1, -0.1, 0.05, 5, 5.1, 4.9, 5.05)
	)
}

make_blocks_design <- function(method = "K-way", dist = "euclidean", B = 2L, X = blocks_fixture_X()) {
	des <- DesignFixedOptimalBlocks$new(
		response_type = "continuous", method = method, B = B, dist = dist,
		n = nrow(X), verbose = FALSE
	)
	des$add_all_subjects_to_experiment(X)
	des
}

same_partition <- function(ids, truth) {
	ids <- as.integer(ids)
	length(unique(paste(ids, truth))) == length(unique(ids)) && length(unique(ids)) == length(unique(truth))
}

two_cluster_truth <- c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L)

test_that("greedy (blockTools) and K-way (anticlust) recover two well-separated clusters and randomize within blocks", {
	skip_if_not_installed("blockTools")
	skip_if_not_installed("anticlust")
	for (method in c("greedy", "K-way")) {
		des <- make_blocks_design(method)
		ids <- des$.__enclos_env__$private$get_or_compute_block_ids()
		expect_s3_class(ids, "factor")
		expect_equal(levels(ids), c("1", "2"))
		expect_true(same_partition(ids, two_cluster_truth), info = method)

		set.seed(5)
		W <- des$draw_ws_according_to_design(r = 6)
		expect_equal(dim(W), c(8L, 6L))
		# Block-randomized at prob_T = 0.5: exactly half of each block is treated.
		for (b in levels(ids)) {
			expect_true(all(colSums(W[ids == b, , drop = FALSE]) == 2), info = paste(method, b))
		}
	}
})

test_that("block ids are cached after the first computation", {
	skip_if_not_installed("anticlust")
	des <- make_blocks_design("K-way")
	priv <- des$.__enclos_env__$private
	first <- priv$get_or_compute_block_ids()
	priv$X <- matrix(0, nrow = 8, ncol = 3)
	expect_identical(priv$get_or_compute_block_ids(), first)
})

test_that("with no usable covariates the blocks fall back to round-robin labels", {
	skip_if_not_installed("anticlust")
	des <- make_blocks_design("K-way", B = 3L, X = data.frame(x = 1:9))
	priv <- des$.__enclos_env__$private
	priv$X <- matrix(0, nrow = 9, ncol = 0)
	ids <- priv$get_or_compute_block_ids()
	expect_equal(as.integer(as.character(ids)), rep(1:3, length.out = 9))
	expect_equal(levels(ids), c("1", "2", "3"))
})

test_that("distance-matrix conventions match independent references and the matrix is cached", {
	X <- blocks_fixture_X()
	get_D <- function(dist) {
		priv <- make_blocks_design("ompr", dist = dist)$.__enclos_env__$private
		Xp <- priv$X[1:8, , drop = FALSE]
		list(priv = priv, X = Xp, D = priv$get_or_compute_distance_matrix(Xp))
	}
	e <- get_D("euclidean")
	expect_equal(unname(e$D), unname(as.matrix(dist(e$X))^2), tolerance = 1e-10)
	s <- get_D("sum_abs_diff")
	expect_equal(unname(s$D), unname(as.matrix(dist(s$X, method = "manhattan"))), tolerance = 1e-10)
	m <- get_D("mahal")
	ref_m <- outer(1:8, 1:8, Vectorize(function(i, j) mahalanobis(m$X[i, ], m$X[j, ], cov(m$X))))
	expect_equal(unname(m$D), ref_m, tolerance = 1e-4)

	f <- get_D(function(a, b) sum(abs(a - b)))
	expect_equal(unname(f$D), unname(s$D), tolerance = 1e-10)

	# Cached: a later call with a different X returns the stored matrix.
	expect_identical(e$priv$get_or_compute_distance_matrix(e$X * 100), e$D)
})

test_that("ompr blocks attain the constrained optimum of an independent brute-force search (and expose the x[k,k] seed constraint)", {
	skip_if_not_installed("ompr")
	skip_if_not_installed("ompr.roi")
	skip_if_not_installed("ROI.plugin.glpk")
	skip_on_os("windows")
	des <- make_blocks_design("ompr", dist = "sum_abs_diff")
	priv <- des$.__enclos_env__$private
	D <- priv$get_or_compute_distance_matrix(priv$X[1:8, , drop = FALSE])
	ids <- as.integer(priv$get_or_compute_block_ids())

	within_cost <- function(assign) {
		sum(vapply(1:2, function(b) {
			idx <- which(assign == b)
			if (length(idx) < 2L) 0 else sum(D[idx, idx][upper.tri(D[idx, idx])])
		}, numeric(1)))
	}
	expect_equal(as.integer(table(ids)), c(4L, 4L))

	subsets <- utils::combn(8, 4)
	costs <- apply(subsets, 2, function(s) { a <- rep(2L, 8); a[s] <- 1L; within_cost(a) })
	seed_sep <- apply(subsets, 2, function(s) xor(1L %in% s, 2L %in% s))

	# SOURCE QUIRK (noted, not fixed): solve_optimal_blocks() adds
	# `x[k, k] == 1`, pinning subject k to block k for k = 1..B. That is not a
	# valid symmetry-breaking rule -- it forces subjects 1..B into DIFFERENT
	# blocks -- so the solve attains only the optimum among partitions that
	# separate subjects 1 and 2, not the true optimum (the two clusters here,
	# whose first two subjects are neighbors).
	expect_equal(within_cost(ids), min(costs[seed_sep]), tolerance = 1e-8)
	expect_lt(min(costs), within_cost(ids))
	expect_false(same_partition(ids, two_cluster_truth))
})
