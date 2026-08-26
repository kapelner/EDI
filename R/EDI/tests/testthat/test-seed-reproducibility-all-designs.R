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
	DesignFixedOptimal = function(seed)
		run_fixed_design_for_seed_test(DesignFixedOptimal$new(response_type = "continuous", n = n, seed = seed), X),

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
