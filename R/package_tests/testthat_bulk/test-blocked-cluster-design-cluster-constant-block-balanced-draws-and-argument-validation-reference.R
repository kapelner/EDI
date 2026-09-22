library(testthat)
library(EDI)

# DesignFixedBlockedCluster$draw_ws_raw() (randomizr::block_and_cluster_ra): every cluster receives one common assignment, exactly half of the clusters in
# each stratum are treated for prob_T = 0.5 (so half of the subjects when clusters have equal size), columns differ, assign_w_to_all_subjects() obeys
# the same structure, treated-cluster counts follow round(k * prob_T)-type rules for other prob_T, and the argument validation for strata / cluster columns.

mk <- function(ncl = 24L, sz = 3L, pT = 0.5, seed = 1L, unequal = FALSE) {
	set.seed(seed)
	cl <- rep(seq_len(ncl), each = sz)
	s <- rep(rep(c("a", "b"), each = ncl / 2), each = sz)
	X <- data.frame(s = factor(s), cl = factor(cl), x = rnorm(ncl * sz))
	d <- DesignFixedBlockedCluster$new(strata_cols = "s", cluster_col = "cl", response_type = "continuous", prob_T = pT, n = nrow(X), seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	list(d = d, cl = cl, s = s, X = X)
}
cluster_const <- function(w, cl) all(tapply(w, cl, function(v) length(unique(v))) == 1L)

test_that("assign_w_to_all_subjects: one assignment per cluster and half of each stratum's clusters treated", {
	f <- mk(); f$d$assign_w_to_all_subjects(); w <- f$d$get_w()
	expect_true(cluster_const(w, f$cl))
	for (st in c("a", "b")) expect_equal(sum(w[f$s == st]) / 3, 6)             # 12 clusters per stratum -> 6 treated
	expect_equal(sum(w), 36)
})

test_that("draw_ws_raw: every column is cluster-constant and stratum-balanced; columns differ; dimensions n x r", {
	f <- mk(); p <- f$d$.__enclos_env__$private
	W <- p$draw_ws_raw(r = 40L)
	expect_equal(dim(W), c(72L, 40L)); expect_true(all(W %in% 0:1))
	for (b in seq_len(ncol(W))) {
		expect_true(cluster_const(W[, b], f$cl), info = as.character(b))
		expect_equal(sum(W[f$s == "a", b]), 18); expect_equal(sum(W[f$s == "b", b]), 18)
	}
	expect_gt(length(unique(apply(W, 2, paste, collapse = ""))), 35L)
	expect_equal(rowMeans(W)[1:3], rep(mean(W[1, ]), 3))                        # subjects of one cluster always agree
})

test_that("every cluster is treated about half the time across draws (uniform over clusters within its stratum)", {
	f <- mk(); W <- f$d$.__enclos_env__$private$draw_ws_raw(r = 800L)
	share <- tapply(rowMeans(W), f$cl, mean)
	expect_lt(max(abs(share - 0.5)), 0.08)
})

test_that("prob_T = 1/3 treats a third of the clusters in each stratum (24 clusters, 12 per stratum -> 4 treated)", {
	f <- mk(pT = 1 / 3); W <- f$d$.__enclos_env__$private$draw_ws_raw(r = 20L)
	for (b in seq_len(ncol(W))) for (st in c("a", "b")) expect_equal(sum(W[f$s == st, b]) / 3, 4, info = paste(b, st))
})

test_that("strata_cols / cluster_col validation", {
	f <- mk()
	expect_error(DesignFixedBlockedCluster$new(strata_cols = "cl", cluster_col = "cl", response_type = "continuous", n = 72L, verbose = FALSE), "must not also appear in strata_cols")
	expect_error(DesignFixedBlockedCluster$new(strata_cols = character(0), cluster_col = "cl", response_type = "continuous", n = 72L, verbose = FALSE))
	expect_error(DesignFixedBlockedCluster$new(strata_cols = "s", cluster_col = c("a", "b"), response_type = "continuous", n = 72L, verbose = FALSE))
})
