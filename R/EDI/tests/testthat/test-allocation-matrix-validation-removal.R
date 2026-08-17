# Regression tests for fix_design_hierarchy.md's "AllocationMatrixValidation" item:
# the four duplicated validate_allocation_matrix() implementations
# (DesignFixedRerandomization, DesignFixedBinaryMatch, DesignFixedGreedy,
# DesignFixedMatchingGreedyPairSwitching) were deleted outright rather than merged
# into a shared component, after confirming each was dead defensive code -- the
# underlying C++ search kernels each guarantee valid, correctly-shaped, balanced
# {0,1} output by construction (confirmed via source inspection, not just testing).
# The one real behavior these classes had was DesignFixedRerandomization's "found
# fewer than r acceptable draws within max_draws" case, which now errors instead of
# silently recycling already-found columns to pad out to r.

test_that("DesignFixedRerandomization errors (not recycles) when too few acceptable draws are found", {
	set.seed(20260817)
	n = 20L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	# An essentially unattainable cutoff forces rerandomization_search_cpp to find zero
	# acceptable draws within a small max_draws budget, so the "found < r" branch fires.
	des = DesignFixedRerandomization$new(
		n = n, response_type = "continuous", obj_val_cutoff = 1e-12
	)
	des$add_all_subjects_to_experiment(X)
	expect_error(
		des$assign_w_to_all_subjects(),
		"could not find .* acceptable allocation"
	)
})

test_that("DesignFixedRerandomization still produces valid, correctly-shaped draws under an achievable cutoff", {
	set.seed(20260817)
	n = 20L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedRerandomization$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_length(w, n)
	expect_true(all(w %in% c(0, 1)))
	expect_equal(sum(w), n / 2)
})

test_that("DesignFixedBinaryMatch still produces valid, correctly-shaped draws without the old validation layer", {
	set.seed(20260817)
	n = 20L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBinaryMatch$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_length(w, n)
	expect_true(all(w %in% c(0, 1)))
	expect_equal(sum(w), n / 2)
})

test_that("DesignFixedGreedy still produces valid, correctly-shaped draws without the old validation layer", {
	set.seed(20260817)
	n = 20L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedGreedy$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_length(w, n)
	expect_true(all(w %in% c(0, 1)))
	expect_equal(sum(w), n / 2)
})

test_that("DesignFixedMatchingGreedyPairSwitching still produces valid, correctly-shaped draws without the old validation layer", {
	set.seed(20260817)
	n = 20L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedMatchingGreedyPairSwitching$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_length(w, n)
	expect_true(all(w %in% c(0, 1)))
	expect_equal(sum(w), n / 2)
})

test_that("no AllocationMatrixValidation component is registered", {
	EDI:::populate_design_component_registry()
	expect_false("AllocationMatrixValidation" %in% names(EDI:::design_component_registry_as_list()))
})
