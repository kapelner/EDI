# "Component Extraction" golden tests (fix_design_hierarchy.md).
#
# No concrete Design class has been rewired off DesignBlocking/DesignMatching
# ancestry yet -- that needs a define_design_class() factory that does not exist
# yet. What *has* happened is that BlockingStructure/MatchingStructure's public and
# private method lists are real references to DesignBlocking's/DesignMatching's own
# methods (registered in design_component_registry.R): reference-identity between
# the component's stored function and DesignBlocking's/DesignMatching's own method
# is already tested directly in test-design-component-registry.R
# (`identical(component$public$foo, DesignBlocking$public_methods$foo)`), which by
# itself proves behavioral equivalence for every class that inherits it unmodified
# -- calling the exact same function object obviously produces the exact same
# output. Concrete classes (DesignFixedBlocking, DesignFixedBinaryMatch, etc.) do
# NOT list these methods on their own `public_methods`/`private_methods` at all --
# those R6 generator fields only contain what that specific class defines directly,
# not what it inherits -- so comparing e.g. `DesignFixedBlocking$public_methods$
# is_blocking_design` (NULL, since it's inherited from DesignBlocking, never
# redefined) against the component reference is not a meaningful check; it was
# tried and correctly fails for exactly this reason, not because anything is wrong.
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
# test, so a future edit to DesignBlocking/DesignMatching that changes behavior for
# any of these classes is caught here regardless of whether the component wiring
# is touched.

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

	# Genuine finding from this pass, not a test bug: this class computes and
	# constrains its search to matched pairs internally (bms/
	# ensure_pair_structure_computed), but never sets private$matching_capable
	# (grep confirms design_fixed_matching_greedy_pair_switching.R never
	# references matching_capable/blocking_capable at all) -- so is_matching_design()
	# is FALSE here, unlike its sibling DesignFixedBinaryMatch, which does set it.
	# Whether that's intentional (this class's "matching" is a pure search
	# constraint, never exposed via get_matching_cluster_ids()/pair-aware
	# jackknife-bootstrap treatment) or a latent gap deserves its own
	# investigation -- flagged in fix_design_hierarchy.md rather than silently
	# changed here.
	expect_false(des$is_matching_design())
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

test_that("BatchWPregeneration component method is reference-identical to each pre-generating class's own method", {
	# unlike is_blocking_design/is_matching_design/etc. (defined on the ancestor
	# DesignBlocking/DesignMatching, so absent from these concrete generators' own
	# public_methods), supports_batch_w_pregeneration IS defined directly on each
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
			batch_component$public$supports_batch_w_pregeneration,
			gen$public_methods$supports_batch_w_pregeneration
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
