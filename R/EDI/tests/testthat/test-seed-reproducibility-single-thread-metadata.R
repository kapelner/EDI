# Regression tests for fix_design_hierarchy.md TODO-29: seed-reproducibility metadata
# for OpenMP scheduling nondeterminism.
#
# Investigation (see design_class_registry.R's
# EDI_DESIGN_SEED_REPRODUCIBLE_SINGLE_THREAD_ONLY_CLASS_NAMES comment for the full
# writeup): DesignFixedRerandomization's C++ fast path (rerandomization_search_cpp) is
# a genuine work-stealing rejection sampler -- threads race via std::atomic::fetch_add
# for both which draws to try and which output column an accepted draw claims, so
# which per-thread-seeded RNG stream fills a given replicate depends on real-time OS
# scheduling under more than one core. DesignFixedGreedy/DesignFixedBinaryMatch/
# DesignFixedMatchingGreedyPairSwitching's kernels use `schedule(static)` (deterministic
# thread-to-index assignment) and DesignFixedGreedyDOptimal's kernel has no OpenMP at
# all, so none of the other three are affected.
#
# Since the package defaults to a single core (get_num_cores() == 1 unless the caller
# opts into set_num_cores()), DesignFixedRerandomization's draws remain exactly
# seed-reproducible for the common case; the new
# seed_reproducible_draw_requires_single_thread metadata field records the narrower
# caveat rather than a blanket seed_reproducible_draw = FALSE, which would have been
# misleading for that common case.

test_that("seed_reproducible_draw_requires_single_thread is TRUE only for DesignFixedRerandomization", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	flagged = names(Filter(function(m) isTRUE(m$seed_reproducible_draw_requires_single_thread), registry))
	expect_identical(flagged, "DesignFixedRerandomization")

	# The other OpenMP-parallel-kernel designs investigated for this item are
	# confirmed unaffected (static scheduling or no OpenMP at all).
	expect_false(isTRUE(registry$DesignFixedGreedy$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedBinaryMatch$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedMatchingGreedyPairSwitching$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedGreedyDOptimal$seed_reproducible_draw_requires_single_thread))

	# The field is only meaningful (and only ever TRUE) alongside a TRUE
	# seed_reproducible_draw -- validated structurally by validate_design_class_metadata()
	# for every registered class, not just this one.
	expect_true(isTRUE(registry$DesignFixedRerandomization$seed_reproducible_draw))
})

test_that("DesignFixedRerandomization's draws are exactly seed-reproducible under the package default (single core)", {
	skip_if_not(identical(EDI:::get_num_cores(), 1L), "package-level core count was not at its default of 1")
	n = 20L
	set.seed(20260817)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))

	draw_once = function() {
		des = DesignFixedRerandomization$new(n = n, response_type = "continuous", seed = 42L)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$get_w()
	}

	expect_identical(draw_once(), draw_once())
})

test_that("DesignFixedRerandomization still produces valid draws under multi-core OpenMP (no reproducibility claim asserted)", {
	# Deliberately does not assert whether repeated draws match or differ under
	# multiple threads -- that outcome is itself governed by real-time OS scheduling
	# (the whole point of this item), so asserting either direction would make this
	# test flaky. Only confirms the multi-threaded path still runs and returns valid
	# output, and restores the single-core default afterward regardless of outcome.
	skip_on_cran()
	if (parallel::detectCores(logical = TRUE) < 2L) {
		skip("fewer than 2 logical cores available")
	}
	on.exit(EDI:::set_package_threads(1L), add = TRUE)
	EDI:::set_package_threads(2L)

	n = 20L
	set.seed(20260817)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedRerandomization$new(n = n, response_type = "continuous", seed = 42L)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_length(w, n)
	expect_true(all(w %in% c(0, 1)))
	expect_equal(sum(w), n / 2)
})
