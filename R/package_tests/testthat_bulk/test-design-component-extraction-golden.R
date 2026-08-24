# "Component Extraction" golden tests (fix_design_hierarchy.md).
#
# BlockingStructure/MatchingStructure are now self-contained literal method + state
# bundles. The legacy DesignBlocking/DesignMatching generators no longer exist;
# concrete classes receive these exact closures through define_design_class().
# test-design-component-registry.R pins reference identity between the registered
# component and its canonical literal source, while this file locks in behavior on
# every concrete structural host.
#
# This file also does NOT re-invoke component methods through a manually
# reassigned environment (`environment(fn) <- des$.__enclos_env__`): that pattern
# was tried and found unsafe -- R does not reliably copy-on-write a closure pulled
# out of a list via `[[`, so mutating its `environment()` can corrupt later lookups
# of *other*, unrelated entries in the same registry (reproduced directly: calling
# a component method that way once, then looking up a different method name from
# the same component on a later call, failed with "recursive indexing failed at
# level 2" -- a symptom of the underlying list/closure structure being mutated in
# place). Given reference identity already proves equivalence, re-deriving it via
# a risky manual dispatch trick added risk for zero additional coverage.
#
# What this file does: lock in each concrete class named in the plan's Component
# Extraction TODO (DesignFixedBlocking, DesignFixedOptimalBlocks,
# ObservationalDesignBlocks, DesignFixedBinaryMatch,
# DesignFixedMatchingGreedyPairSwitching, DesignSeqOneByOneKK14,
# ObservationalDesignMatching)'s own behavioral output as an ordinary regression
# test, so a future edit to either structural component is caught here regardless
# of whether the consuming class is touched.

test_that("DesignFixedBlocking blocking behavior is correct", {
	set.seed(1)
	des = DesignFixedBlocking$new(n = 8, response_type = "continuous", seed = 1)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8), x2 = sample(c("a", "b"), 8, TRUE)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(8))

	expect_true(des$is_blocking_design())
	expect_length(des$get_block_ids(), 8)
	expect_true(des$is_complete_blocking_design())
	expect_type(des$summarize_blocks(), "list")
})

test_that("DesignFixedOptimalBlocks blocking behavior is correct", {
	skip_if_not_installed("anticlust")
	set.seed(2)
	des = DesignFixedOptimalBlocks$new(n = 12, response_type = "continuous", seed = 2)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(12)))
	des$assign_w_to_all_subjects()

	expect_true(des$is_blocking_design())
	expect_length(des$get_block_ids(), 12)
})

test_that("ObservationalDesignBlocks blocking behavior is correct", {
	des = ObservationalDesignBlocks$new(response_type = "continuous", m = c(1, 1, 2, 2, 3, 3))
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des$assign_w_to_all_subjects(w_precomputed = c(1, 0, 1, 0, 1, 0))

	expect_true(des$is_blocking_design())
	expect_identical(des$get_block_ids(), c(1L, 1L, 2L, 2L, 3L, 3L))
	expect_error(des$set_m(c(1L, 1L, 2L, 2L, 3L, 3L)), "not yet been set")
})

test_that("DesignFixedBinaryMatch matching behavior is correct", {
	skip_if_not_installed("nbpMatching")
	set.seed(3)
	des = DesignFixedBinaryMatch$new(n = 8, response_type = "continuous", seed = 3)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(8))

	expect_true(des$is_matching_design())
	expect_length(des$get_matching_cluster_ids(), 8)
	boot = des$.__enclos_env__$private$draw_bootstrap_indices(NULL)
	expect_length(boot$i_b, 8)
})

test_that("DesignFixedMatchingGreedyPairSwitching matching behavior is correct", {
	skip_if_not_installed("nbpMatching")
	set.seed(5)
	des = DesignFixedMatchingGreedyPairSwitching$new(n = 8, response_type = "continuous", seed = 5, n_iter = 5)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	des$assign_w_to_all_subjects()

	# TODO-26/TODO-35 resolved the old latent flag gap: the search's binary pairs
	# are now installed as the design's matching structure, so every resampling
	# path sees the same pair units as this class's own nonparametric bootstrap.
	expect_true(des$is_matching_design())
	expect_true(des$is_blocking_design())
	cluster_ids = des$get_matching_cluster_ids()
	expect_length(cluster_ids, 8)
	expect_true(all(table(cluster_ids) == 2L))
})

test_that("DesignSeqOneByOneKK14 matching behavior is correct", {
	set.seed(6)
	des = DesignSeqOneByOneKK14$new(n = 8, response_type = "continuous", seed = 6)
	for (i in 1:8) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}

	expect_true(des$is_matching_design())
	expect_length(des$get_matching_cluster_ids(), 8)
})

test_that("ObservationalDesignMatching matching behavior is correct", {
	des = ObservationalDesignMatching$new(response_type = "continuous", n = 6)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des$assign_w_to_all_subjects(w_precomputed = c(1, 0, 0, 1, 1, 0))
	des$add_all_subject_responses(rnorm(6))

	expect_true(des$is_matching_design())
	expect_identical(des$get_matching_cluster_ids(), c(1L, 1L, 2L, 2L, 3L, 3L))
	boot = des$.__enclos_env__$private$draw_bootstrap_indices(NULL)
	expect_length(boot$i_b, 6)
})

test_that("BatchWPregeneration component method is body-identical to each pre-generating class's own method", {
	# supports_batch_w_pregeneration is defined directly on each
	# of these four classes -- so a direct generator-level reference check is
	# meaningful here.
	EDI:::populate_design_component_registry()
	batch_component = EDI:::get_design_component("BatchWPregeneration")

	for (class_name in c(
		"DesignFixedBinaryMatch", "DesignFixedGreedy",
		"DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimalBlocks"
	)) {
		gen = get(class_name, envir = asNamespace("EDI"))
		expect_identical(
			body(batch_component$public$supports_batch_w_pregeneration),
			body(gen$public_methods$supports_batch_w_pregeneration)
		)
	}
})

test_that("Design$capabilities()/supports() bridge legacy predicates to real answers today", {
	blocking_des = DesignFixedBlocking$new(n = 8, response_type = "continuous")
	expect_true(blocking_des$supports("blocking"))
	expect_false(blocking_des$supports("matching"))

	matching_des = DesignFixedBinaryMatch$new(n = 6, response_type = "continuous")
	expect_true(matching_des$supports("blocking"))
	expect_true(matching_des$supports("matching"))
	expect_true(matching_des$supports("batch_w_pregeneration"))

	bernoulli_des = DesignFixedBernoulli$new(n = 6, response_type = "continuous")
	expect_false(bernoulli_des$supports("matching"))
	expect_false(bernoulli_des$supports("batch_w_pregeneration"))

	obs_des = ObservationalDesign$new(n = 6, response_type = "continuous")
	expect_false(obs_des$supports("blocking"))
	expect_false(obs_des$supports("matching"))
})

test_that("simulations_framework batch-pregeneration dispatch uses registry metadata, not generator-shape sniffing", {
	expect_true(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedGreedy))
	expect_true(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedBinaryMatch))
	expect_true(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedMatchingGreedyPairSwitching))
	expect_true(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedOptimalBlocks))
	expect_false(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedBernoulli))
	expect_false(EDI:::design_class_generator_supports_batch_w_pregeneration(DesignFixedGreedyDOptimal))

	# unregistered/custom generator falls back to the old shape-sniffing check rather
	# than erroring or silently returning FALSE
	CustomTestDesign = R6::R6Class("CustomTestDesign", inherit = DesignFixed, public = list(
		supports_batch_w_pregeneration = function() TRUE
	))
	expect_true(EDI:::design_class_generator_supports_batch_w_pregeneration(CustomTestDesign))
})
