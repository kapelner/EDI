library(testthat)
library(EDI)

# inference_ext_exchangeable_resampling_units.R's get_exchangeable_units() has three sibling
# "structure unavailable" guards for unit = "pair"/"matched_set" (matching), "cluster", and "block".
# The matching-branch guard ("Matching structure is unavailable for resampling.") is already covered
# by test-exchangeable-resampling-units-matching-branch-error-guards-reference.R, but the sibling
# cluster/block guards -- "Cluster IDs are unavailable for resampling." (get_resampling_cluster_ids()
# returns NULL whenever the design has no cluster_col) and "Block IDs are unavailable for
# resampling." (get_resampling_block_ids() returns NULL whenever the design has no get_block_ids()
# method) -- had zero test references anywhere, despite the sibling being fully tested. Reachable
# directly on any plain (non-cluster, non-blocking) design composing InferenceNonParamBootstrap, via
# the private unit-resolution entry point.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("get_exchangeable_units('cluster') errors on a non-cluster design with the documented message", {
	priv <- fx(seed = 1L)
	expect_null(priv$get_resampling_cluster_ids())
	expect_error(priv$get_exchangeable_units("cluster"), "Cluster IDs are unavailable for resampling\\.")
})

test_that("get_exchangeable_units('block') errors on a non-blocking design with the documented message", {
	priv <- fx(seed = 2L)
	expect_null(priv$get_resampling_block_ids())
	expect_error(priv$get_exchangeable_units("block"), "Block IDs are unavailable for resampling\\.")
})

test_that("a cluster-capable design supplies real cluster units, no error", {
	set.seed(3L)
	n <- 24L
	clus <- rep(1:8, each = 3L)
	d <- DesignFixedCluster$new(cluster_col = "cl", response_type = "continuous", n = n, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), cl = clus)); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	res <- priv$get_exchangeable_units("cluster")
	expect_identical(res$unit_type, "cluster")
	expect_equal(res$n_units, 8L)
})
