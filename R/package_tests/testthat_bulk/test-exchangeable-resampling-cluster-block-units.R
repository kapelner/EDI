library(testthat)
library(EDI)

# InferenceExtExchangeableResamplingUnits$get_exchangeable_units() (spliced into
# InferenceNonParamBootstrap) has a dedicated branch for "cluster" and "block"
# resampling units, each backed by a private accessor (get_resampling_cluster_ids/
# get_resampling_block_ids). The existing coverage (test-resampling-extension-contracts.R,
# test-m-out-of-n-prw-subsampling.R) only ever exercises the "observation" unit --
# confirmed via repo-wide grep, zero references anywhere to get_resampling_cluster_ids,
# get_resampling_block_ids, or a "cluster"/"block" call into get_exchangeable_units.

make_cluster_probe = function(n = 20L, seed = 710L) {
	set.seed(seed)
	des = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "cl", seed = seed)
	X = data.frame(x = rnorm(n), cl = rep(seq_len(n / 4L), each = 4L))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.5 * w + rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

make_block_probe = function(n = 20L, seed = 711L) {
	set.seed(seed)
	des = DesignFixedBlocking$new(n = n, response_type = "continuous", strata_cols = "x2",
		equal_block_sizes = FALSE, seed = seed)
	X = data.frame(x1 = rnorm(n), x2 = factor(rep(seq_len(n / 5L), each = 5L)))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.5 * w + rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

test_that("get_resampling_cluster_ids/get_exchangeable_units('cluster') group rows by the design's cluster column", {
	inf = make_cluster_probe()
	p = inf$.__enclos_env__$private
	p$shared()

	ids = p$get_resampling_cluster_ids()
	expect_identical(ids, rep(as.character(1:5), each = 4L))

	units = p$get_exchangeable_units("cluster")
	expect_identical(units$unit_type, "cluster")
	expect_identical(units$n_units, 5L)
	expect_identical(units$strata_ids, NULL)
	# Independent reference: row indices grouped by cluster id, in id order.
	ref_units = split(seq_len(20L), rep(1:5, each = 4L))
	names(ref_units) = NULL
	expect_identical(lapply(units$units, as.integer), lapply(ref_units, as.integer))

	# resolve_resampling_unit("auto") on a cluster-capable, non-matching design
	# should resolve to "cluster" without an explicit unit argument.
	expect_identical(p$resolve_resampling_unit("auto"), "cluster")
})

test_that("get_resampling_block_ids/get_exchangeable_units('block') group rows by the design's block assignment", {
	inf = make_block_probe()
	p = inf$.__enclos_env__$private
	p$shared()

	bids = p$get_resampling_block_ids()
	expect_identical(bids, rep(1:4, each = 5L))

	units = p$get_exchangeable_units("block")
	expect_identical(units$unit_type, "block")
	expect_identical(units$n_units, 4L)
	ref_units = split(seq_len(20L), rep(1:4, each = 5L))
	names(ref_units) = NULL
	expect_identical(lapply(units$units, as.integer), lapply(ref_units, as.integer))
})

test_that("get_resampling_cluster_ids/get_resampling_block_ids gracefully return NULL off a non-cluster/non-blocking design", {
	set.seed(712)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = 712)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(0.5 * w + rnorm(n))
	inf = InferenceAllSimpleAverageDiff$new(des)
	p = inf$.__enclos_env__$private
	p$shared()

	expect_null(p$get_resampling_cluster_ids())
	expect_null(p$get_resampling_block_ids())
	# get_exchangeable_units errors cleanly (not a crash) when the requested
	# unit type has no backing IDs on this design.
	expect_error(p$get_exchangeable_units("cluster"), "Cluster IDs are unavailable")
	expect_error(p$get_exchangeable_units("block"), "Block IDs are unavailable")
})

test_that("sample_exchangeable_unit_ids/build_resampling_draw_from_units round-trip correctly on cluster units", {
	inf = make_cluster_probe()
	p = inf$.__enclos_env__$private
	p$shared()
	units = p$get_exchangeable_units("cluster")

	set.seed(99)
	selected = p$sample_exchangeable_unit_ids(units, size = 3L, replace = FALSE, stratified = TRUE)
	expect_length(selected, 3L)
	expect_true(all(selected %in% seq_len(5L)))

	draw = p$build_resampling_draw_from_units(units, selected, size_label = "m", preserve_order = TRUE)
	# Every selected cluster contributes its full 4-row block, in cluster order.
	expected_rows = sort(unlist(units$units[selected]))
	expect_identical(sort(draw$i_b), as.integer(expected_rows))
	expect_identical(draw$m, 3L)
})
