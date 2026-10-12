# Regression tests for TODO-95's draw-index seeding.  Every OpenMP design
# candidate must be determined by its logical draw index, never by the worker
# that happened to evaluate it.

test_that("no design is marked reproducible only with a single thread", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	flagged = names(Filter(function(m) isTRUE(m$seed_reproducible_draw_requires_single_thread), registry))
	expect_identical(flagged, character(0))

	# All affected OpenMP paths now derive a stream from the draw index.
	expect_false(isTRUE(registry$DesignFixedGreedy$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedBinaryMatch$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedMatchingGreedyPairSwitching$seed_reproducible_draw_requires_single_thread))
	expect_false(isTRUE(registry$DesignFixedGreedyDOptimal$seed_reproducible_draw_requires_single_thread))
	expect_true(isTRUE(registry$DesignFixedRerandomization$seed_reproducible_draw))
	expect_false(isTRUE(registry$DesignFixedRerandomization$seed_reproducible_draw_requires_single_thread))
})

test_that("DesignFixedRerandomization's draws are exactly seed-reproducible under the package default (single core)", {
	skip_if_not(identical(EDI:::get_num_cores(), 1L), "package-level core count was not at its default of 1")
	n = 20L
	set.seed(20260817)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))

	draw_once = function() {
		# Use the native rejection path rather than prop_acceptable's separate
		# batched sampler, so this exercises draw-index seeding directly.
		des = DesignFixedRerandomization$new(
			n = n, response_type = "continuous", seed = 42L,
			obj_val_cutoff = 0.1, verbose = FALSE
		)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$get_w()
	}

	expect_identical(draw_once(), draw_once())
})

test_that("DesignFixedRerandomization uses the same draw matrix at every available core count", {
	skip_on_cran()
	if (parallel::detectCores(logical = TRUE) < 2L) {
		skip("fewer than 2 logical cores available")
	}
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)

	n = 20L
	set.seed(20260817)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))

	draw_matrix = function(cores) {
		EDI:::set_package_threads(cores)
		# The tight cutoff exercises rejected candidates and wave completion in
		# the native C++ sampler, not the separate prop_acceptable path.
		des = DesignFixedRerandomization$new(
			n = n, response_type = "continuous", seed = 42L,
			obj_val_cutoff = 0.1, verbose = FALSE
		)
		des$add_all_subjects_to_experiment(X)
		des$draw_ws_according_to_design(16L)
	}

	w1 = draw_matrix(1L)
	w2 = draw_matrix(2L)
	expect_identical(w1, w2)
	if (parallel::detectCores(logical = TRUE) >= 4L) {
		expect_identical(w1, draw_matrix(4L))
	}
	expect_true(all(w1 %in% c(0, 1)))
	expect_true(all(colSums(w1) == n / 2))
})

test_that("greedy-family draw matrices are invariant to the OpenMP core count", {
	skip_on_cran()
	if (parallel::detectCores(logical = TRUE) < 2L) {
		skip("fewer than 2 logical cores available")
	}
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)
	n = 20L
	set.seed(20261011)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	factories = list(
		DesignFixedGreedy = function() DesignFixedGreedy$new(
			n = n, response_type = "continuous", seed = 91L, verbose = FALSE
		),
		DesignFixedGreedyDOptimal = function() DesignFixedGreedyDOptimal$new(
			n = n, response_type = "continuous", seed = 91L, verbose = FALSE
		),
		DesignFixedRerandomization = function() DesignFixedRerandomization$new(
			n = n, response_type = "continuous", seed = 91L,
			obj_val_cutoff = 0.1, verbose = FALSE
		)
	)
	draw_matrix = function(factory, cores) {
		EDI:::set_package_threads(cores)
		des = factory()
		des$add_all_subjects_to_experiment(X)
		des$draw_ws_according_to_design(12L)
	}
	for (name in names(factories)) {
		w1 = draw_matrix(factories[[name]], 1L)
		expect_identical(w1, draw_matrix(factories[[name]], 2L), info = name)
		# Repeating at two cores catches a residual scheduler race independently
		# of the cross-core assertion.
		expect_identical(w1, draw_matrix(factories[[name]], 2L), info = paste(name, "repeat"))
		if (parallel::detectCores(logical = TRUE) >= 4L) {
			expect_identical(w1, draw_matrix(factories[[name]], 4L), info = name)
		}
	}
})

test_that("matching greedy pair switching is invariant to the OpenMP core count", {
	skip_on_cran()
	skip_if_not_installed("nbpMatching")
	if (parallel::detectCores(logical = TRUE) < 2L) {
		skip("fewer than 2 logical cores available")
	}
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)
	n = 20L
	set.seed(20261012)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	draw_matrix = function(cores) {
		EDI:::set_package_threads(cores)
		des = DesignFixedMatchingGreedyPairSwitching$new(
			n = n, response_type = "continuous", seed = 92L, verbose = FALSE
		)
		des$add_all_subjects_to_experiment(X)
		des$draw_ws_according_to_design(12L)
	}
	w1 = draw_matrix(1L)
	expect_identical(w1, draw_matrix(2L))
	expect_identical(w1, draw_matrix(2L))
	if (parallel::detectCores(logical = TRUE) >= 4L) {
		expect_identical(w1, draw_matrix(4L))
	}
})

test_that("OpenMP draw kernels retain no worker-indexed seed path", {
	src_dir = testthat::test_path("..", "..", "src")
	files = c(
		"design_fixed_greedy.cpp", "optimal_design_search.cpp",
		"rerandomization_helpers.cpp", "binary_match_search.cpp",
		"greedy_pairwise_swap_engine.h"
	)
	lines = unlist(lapply(file.path(src_dir, files), readLines, warn = FALSE), use.names = FALSE)
	code = lines[!grepl("^\\s*//", lines)]
	expect_false(any(grepl("seed_per_thread_rngs_from_r", code, fixed = TRUE)))
	expect_false(any(grepl("seeds[", code, fixed = TRUE)))
	expect_false(any(grepl("omp_get_thread_num()", code, fixed = TRUE)))
	expect_true(any(grepl("seed_for_index", code, fixed = TRUE)))
})
