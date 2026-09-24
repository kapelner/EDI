library(testthat)
library(EDI)

# DesignFixedCluster's own private draw_ws_raw() (design_fixed_cluster.R) stop()s with "Cluster IDs
# cannot be missing." when the designated cluster_col contains any NA -- confirmed reachable via a
# zero-hit grep for the exact message across the whole test suite. add_all_subjects_to_experiment()'s
# own validation (assertStrataClusterArgs()) only checks that cluster_col is a length-1 character naming
# a column present in the supplied data.frame; it never inspects the column's own values for missingness,
# so an NA in the cluster column survives all the way to the first assign_w_to_all_subjects() call, where
# this class's own draw_ws_raw() override catches it before delegating to randomizr::cluster_ra() (which
# would otherwise silently mis-cluster the NA-labeled subjects). DesignFixedCluster is otherwise covered
# extensively elsewhere (capability flags, resampling units, jackknife cluster ids, matching/blocking
# geometry, observational contracts) but always with a fully-populated cluster column.
#   1. A cluster column containing one NA errors with the documented message on assign_w_to_all_subjects().
#   2. The identical fixture with the NA replaced by a valid cluster label does NOT error.

test_that("an NA in the cluster column errors with the documented message on assign_w_to_all_subjects()", {
	set.seed(1L)
	n <- 20L
	des <- DesignFixedCluster$new(response_type = "continuous", n = n, cluster_col = "cl", verbose = FALSE)
	X <- data.frame(cl = c(NA, rep(letters[1:4], length.out = n - 1L)))
	des$add_all_subjects_to_experiment(X)
	expect_error(des$assign_w_to_all_subjects(), "Cluster IDs cannot be missing\\.")
})

test_that("the identical fixture with no NA in the cluster column does not error", {
	set.seed(1L)
	n <- 20L
	des <- DesignFixedCluster$new(response_type = "continuous", n = n, cluster_col = "cl", verbose = FALSE)
	X <- data.frame(cl = rep(letters[1:4], length.out = n))
	des$add_all_subjects_to_experiment(X)
	expect_no_error(des$assign_w_to_all_subjects())
})
