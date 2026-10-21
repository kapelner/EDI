# fix_design_hierarchy.md TODO-59: construct every concrete, randomization-capable
# design twice with the same `seed`, run it through its normal draw path, and
# assert identical output when the registry claims `seed_reproducible_draw = TRUE`
# (skip the assertion, rather than silently passing, for any class the registry
# marks FALSE) -- so a future change that accidentally breaks reproducibility for
# a class that currently has it is caught instead of going unnoticed.
#
# ObservationalDesign/ObservationalDesignBlocks/ObservationalDesignMatching are
# deliberately excluded: they have no draw mechanism at all (assignment is always
# user-supplied via `assign_w_to_all_subjects(w_precomputed = ...)`, never drawn
# from a random mechanism -- see design_observational*.R), so "reproducing a draw"
# is not a meaningful claim for them.

run_seq_design_for_seed_test = function(des, X) {
	for (i in seq_len(nrow(X))) {
		des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	}
	des$get_w()
}

run_fixed_design_for_seed_test = function(des, X) {
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$get_w()
}

n   = 10L
n12 = 12L
X   = data.frame(x1 = rnorm(n),   x2 = rnorm(n))
X12 = data.frame(x1 = rnorm(n12), x2 = rnorm(n12))
Xf = data.frame(
	x1      = rnorm(n),
	strata  = rep(c("A", "B"), each = n / 2),
	cluster = rep(1:5, each = 2)
)
Xf12 = data.frame(
	x1      = rnorm(n12),
	strata  = rep(c("A", "B"), each = n12 / 2),
	cluster = c(rep(1:3, each = 2), rep(4:6, each = 2))
)

# name -> function(seed) that constructs a fresh instance, drives it through its
# normal draw path with the given `seed`, and returns the resulting w encoding.
design_seed_reproducibility_cases = list(
	DesignFixedBernoulli = function(seed)
		run_fixed_design_for_seed_test(DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed), X),
	DesignFixedRerandomization = function(seed)
		run_fixed_design_for_seed_test(DesignFixedRerandomization$new(n = n, response_type = "continuous", seed = seed), X),
	DesignFixedBlocking = function(seed)
		run_fixed_design_for_seed_test(
			DesignFixedBlocking$new(n = n, response_type = "continuous", strata_cols = "strata",
				equal_block_sizes = FALSE, seed = seed),
			Xf
		),
	DesignFixedBinaryMatch = function(seed) {
		skip_if_not_installed("nbpMatching")
		run_fixed_design_for_seed_test(DesignFixedBinaryMatch$new(n = n, response_type = "continuous", seed = seed), X)
	},
	DesignFixedGreedy = function(seed)
		run_fixed_design_for_seed_test(DesignFixedGreedy$new(n = n, response_type = "continuous", seed = seed), X),
	DesignFixedOptimalBlocks = function(seed)
		run_fixed_design_for_seed_test(
			DesignFixedOptimalBlocks$new(n = n12, response_type = "continuous", B = 2, seed = seed),
			X12
		),
	DesignFixedMatchingGreedyPairSwitching = function(seed) {
		skip_if_not_installed("nbpMatching")
		run_fixed_design_for_seed_test(
			DesignFixedMatchingGreedyPairSwitching$new(n = n12, response_type = "continuous", seed = seed),
			X12
		)
	},
	DesignFixediBCRD = function(seed)
		run_fixed_design_for_seed_test(DesignFixediBCRD$new(n = n, response_type = "continuous", seed = seed), X),
	DesignFixedCluster = function(seed)
		run_fixed_design_for_seed_test(
			DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "cluster", seed = seed),
			Xf
		),
	DesignFixedBlockedCluster = function(seed)
		run_fixed_design_for_seed_test(
			DesignFixedBlockedCluster$new(n = n12, response_type = "continuous",
				strata_cols = "strata", cluster_col = "cluster", seed = seed),
			Xf12
		),
	DesignFixedFactorial = function(seed)
		run_fixed_design_for_seed_test(
			DesignFixedFactorial$new(response_type = "continuous", factors = list(A = 2), n = n, seed = seed),
			X
		),
	DesignFixedGreedyDOptimal = function(seed)
		run_fixed_design_for_seed_test(DesignFixedGreedyDOptimal$new(response_type = "continuous", n = n, seed = seed), X),
	DesignFixedOptimal = function(seed) {
		skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
		run_fixed_design_for_seed_test(DesignFixedOptimal$new(response_type = "continuous", n = n, seed = seed), X)
	},

	DesignSeqOneByOneBernoulli = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOneEfron = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneEfron$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOneAtkinson = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneAtkinson$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOneKK14 = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOneSPBR = function(seed)
		run_seq_design_for_seed_test(
			DesignSeqOneByOneSPBR$new(strata_cols = "strata", n = n, response_type = "continuous", seed = seed),
			Xf
		),
	DesignSeqOneByOneiBCRD = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneiBCRD$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOnePocockSimon = function(seed)
		run_seq_design_for_seed_test(
			DesignSeqOneByOnePocockSimon$new(strata_cols = "strata", n = n, response_type = "continuous", seed = seed),
			Xf
		),
	DesignSeqOneByOneUrn = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneUrn$new(n = n, response_type = "continuous", seed = seed), X),
	DesignSeqOneByOneKK21 = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneKK21$new(response_type = "continuous", n = n, seed = seed), X),
	DesignSeqOneByOneKK21stepwise = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneKK21stepwise$new(response_type = "continuous", n = n, seed = seed), X),
	DesignSeqOneByOneRandomBlockSize = function(seed)
		run_seq_design_for_seed_test(DesignSeqOneByOneRandomBlockSize$new(response_type = "continuous", n = n, seed = seed), X)
)

test_that("every entry in design_seed_reproducibility_cases matches a real, non-abstract, exported design generator", {
	ns = asNamespace("EDI")
	all_names = sort(ls(ns))
	generators = Filter(function(name) {
		obj = get(name, envir = ns)
		EDI:::is_design_r6_generator(obj) && identical(obj$classname, name)
	}, all_names)
	registry = EDI:::design_class_registry_as_list()
	concrete_exported = generators[vapply(generators, function(g) isFALSE(registry[[g]]$abstract) && isTRUE(registry[[g]]$exported), logical(1))]

	# observational designs never draw randomly -- see file banner comment.
	expected = setdiff(concrete_exported, c("ObservationalDesign", "ObservationalDesignBlocks", "ObservationalDesignMatching"))
	expect_setequal(names(design_seed_reproducibility_cases), expected)
})

for (design_name in names(design_seed_reproducibility_cases)) {
	local({
		this_name = design_name
		build = design_seed_reproducibility_cases[[this_name]]
		test_that(paste(this_name, "draw reproducibility matches its seed_reproducible_draw metadata"), {
			if (identical(this_name, "DesignFixedOptimalBlocks")) skip_if_not_installed("anticlust")
			metadata = EDI:::get_design_class_metadata(this_name)
			if (isTRUE(metadata$seed_reproducible_draw_requires_single_thread)) {
				skip_if_not(identical(EDI:::get_num_cores(), 1L), "package-level core count was not at its default of 1")
			}

			w1 = build(12345L)
			w2 = build(12345L)

			if (isTRUE(metadata$seed_reproducible_draw)) {
				expect_identical(w1, w2)
			} else {
				skip(paste(this_name, "is registered as seed_reproducible_draw = FALSE; no reproducibility claim to test"))
			}
		})
	})
}

test_that("every registry design that promises seeded draws is invariant across core counts", {
	skip_on_cran()
	available_cores = parallel::detectCores(logical = TRUE)
	if (is.na(available_cores) || available_cores < 2L) {
		skip("fewer than 2 logical cores available")
	}
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_package_threads(old_cores), add = TRUE)

	registry = EDI:::design_class_registry_as_list()
	# Observational designs accept a user-supplied w and have no draw path; the
	# registry's TRUE value describes seed behavior if a draw existed, not a
	# promise that these classes generate assignments.
	no_draw_designs = c("ObservationalDesign", "ObservationalDesignBlocks", "ObservationalDesignMatching")
	reproducible = setdiff(
		names(Filter(function(metadata) isTRUE(metadata$seed_reproducible_draw), registry)),
		no_draw_designs
	)
	expect_true(all(reproducible %in% names(design_seed_reproducibility_cases)))
	draw_at = function(build, cores) {
		EDI:::set_package_threads(cores)
		set.seed(20261013L)
		build(20261013L)
	}

	for (name in reproducible) {
		metadata = registry[[name]]
		packages = metadata$required_packages
		if (is.null(packages)) packages = character()
		if (length(packages) && !all(vapply(packages, requireNamespace, logical(1), quietly = TRUE))) next

		build = design_seed_reproducibility_cases[[name]]
		w1 = draw_at(build, 1L)
		for (cores in c(2L, if (available_cores >= 4L) 4L)) {
			w = draw_at(build, cores)
			expect_identical(w1, w, info = paste(name, cores, "cores"))
			if (cores == 4L) {
				expect_identical(w, draw_at(build, 4L), info = paste(name, "4-core repeat"))
			}
		}
	}
})

test_that("seeded randomization p-values for thread-sensitive designs are core-invariant", {
	skip_on_cran()
	if (!requireNamespace("nbpMatching", quietly = TRUE)) skip("requires nbpMatching")
	# R CMD check --as-cran sets _R_CHECK_LIMIT_CORES_, under which parallel
	# refuses more than 2 simultaneous processes (makeForkCluster then fails
	# with "4 simultaneous processes spawned"), so compare 1 vs 2 cores there.
	cores_limited = nzchar(Sys.getenv("_R_CHECK_LIMIT_CORES_")) &&
		!tolower(Sys.getenv("_R_CHECK_LIMIT_CORES_")) %in% c("false", "0")
	many_cores = if (cores_limited) 2L else 4L
	available_cores = parallel::detectCores(logical = TRUE)
	if (is.na(available_cores) || available_cores < many_cores) skip(paste0("fewer than ", many_cores, " logical cores available"))
	old_cores = EDI:::get_num_cores()
	on.exit(EDI:::set_num_cores(old_cores), add = TRUE)
	n_test = 12L
	set.seed(20261014L)
	X_test = data.frame(x1 = rnorm(n_test), x2 = rnorm(n_test))
	epsilon = rnorm(n_test)
	seed = 20261015L
	design_names = c(
		"DesignFixedGreedy", "DesignFixedGreedyDOptimal",
		"DesignFixedMatchingGreedyPairSwitching", "DesignFixedRerandomization"
	)
	build = function(name, cores) {
		EDI:::set_num_cores(cores)
		set.seed(seed)
		des = switch(name,
			DesignFixedGreedy = DesignFixedGreedy$new(n = n_test, response_type = "continuous", seed = seed, verbose = FALSE),
			DesignFixedGreedyDOptimal = DesignFixedGreedyDOptimal$new(n = n_test, response_type = "continuous", seed = seed, verbose = FALSE),
			DesignFixedMatchingGreedyPairSwitching = DesignFixedMatchingGreedyPairSwitching$new(n = n_test, response_type = "continuous", seed = seed, verbose = FALSE),
			DesignFixedRerandomization = DesignFixedRerandomization$new(n = n_test, response_type = "continuous", obj_val_cutoff = 0.35, seed = seed, verbose = FALSE)
		)
		des$add_all_subjects_to_experiment(X_test)
		des$assign_w_to_all_subjects()
		w = as.numeric(des$get_w())
		des$add_all_subject_responses(0.5 * w + 0.2 * X_test$x1 - 0.1 * X_test$x2 + epsilon)
		inf = InferenceContinOLS$new(des, verbose = FALSE)
		inf$num_cores = cores
		inf$set_seed(seed + 1L)
		as.numeric(inf$compute_rand_two_sided_pval(r = 51L, show_progress = FALSE))
	}

	for (name in design_names) {
		p1 = build(name, 1L)
		p_many = build(name, many_cores)
		expect_true(is.finite(p1), info = paste(name, "one-core p-value is finite"))
		expect_identical(p1, p_many, info = paste(name, "randomization p-value at 1/", many_cores, " cores"))
	}
})
