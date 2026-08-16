canonical_design_generators = function() {
	ns = asNamespace("EDI")
	all_names = sort(ls(ns))
	Filter(function(name) {
		obj = get(name, envir = ns)
		EDI:::is_design_r6_generator(obj) && identical(obj$classname, name)
	}, all_names)
}

test_that("design class registry has one canonical metadata entry per generator", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()
	generators = canonical_design_generators()

	expect_setequal(names(registry), generators)
	expect_equal(length(registry), length(generators))
	expect_silent(EDI:::validate_design_class_registry(registry))

	for (name in generators) {
		metadata = EDI:::get_design_class_metadata(name)
		gen = get(name, envir = asNamespace("EDI"))
		parent_gen = gen$get_inherit()
		parent_name = if (is.null(parent_gen)) NULL else parent_gen$classname

		expect_identical(metadata$name, name)
		expect_identical(metadata$parent, parent_name)
		expect_true(is.logical(metadata$abstract))
		expect_true(is.logical(metadata$exported))
		expect_true(is.character(metadata$timing_family) && length(metadata$timing_family) == 1L)
		expect_true(is.character(metadata$randomization_family) && length(metadata$randomization_family) == 1L)
		expect_true(is.logical(metadata$seed_reproducible_draw) && length(metadata$seed_reproducible_draw) == 1L)
		expect_identical(EDI:::get_direct_design_components(name), metadata$direct_components)
		expect_type(EDI:::get_effective_design_components(name), "character")
		expect_type(EDI:::get_effective_design_capabilities(name), "character")
	}
})

test_that("timing_family values are drawn from the closed enum, or NA only for the unsplit bases", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	for (name in names(registry)) {
		timing_family = registry[[name]]$timing_family
		if (is.na(timing_family)) {
			expect_true(
				name %in% EDI:::EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES,
				info = sprintf("%s has NA timing_family but is not an unsplit base", name)
			)
		} else {
			expect_true(
				timing_family %in% EDI:::EDI_DESIGN_ALLOWED_TIMING_FAMILIES,
				info = sprintf("%s has invalid timing_family %s", name, timing_family)
			)
		}
	}

	# every concrete/extension-base design resolves to a real timing family
	concrete_and_extension_bases = setdiff(names(registry), EDI:::EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES)
	for (name in concrete_and_extension_bases) {
		expect_false(is.na(registry[[name]]$timing_family), info = name)
	}

	expect_identical(registry$DesignFixed$timing_family, "fixed")
	expect_identical(registry$DesignSeqOneByOne$timing_family, "sequential")
	expect_identical(registry$DesignFixedCustom$timing_family, "fixed")
	expect_identical(registry$DesignCustomSequential$timing_family, "sequential")
	expect_identical(registry$DesignFixedBernoulli$timing_family, "fixed")
	expect_identical(registry$DesignSeqOneByOneBernoulli$timing_family, "sequential")
	expect_identical(registry$ObservationalDesign$timing_family, "fixed")
	expect_identical(registry$ObservationalDesignBlocks$timing_family, "fixed")
	expect_identical(registry$ObservationalDesignMatching$timing_family, "fixed")
})

test_that("randomization_family values are drawn from the closed enum, or NA only for the family-less bases", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()
	family_less = c(EDI:::EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES, "DesignFixed", "DesignSeqOneByOne")

	for (name in names(registry)) {
		randomization_family = registry[[name]]$randomization_family
		if (is.na(randomization_family)) {
			expect_true(
				name %in% family_less,
				info = sprintf("%s has NA randomization_family but is not a family-less base", name)
			)
		} else {
			expect_true(
				randomization_family %in% EDI:::EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES,
				info = sprintf("%s has invalid randomization_family %s", name, randomization_family)
			)
		}
	}

	# every concrete/extension-base design (i.e. not one of the 5 family-less bases)
	# resolves to a real, single randomization_family
	non_family_less = setdiff(names(registry), family_less)
	for (name in non_family_less) {
		expect_false(is.na(registry[[name]]$randomization_family), info = name)
	}

	# spot-check a representative sample against the documented mapping
	expect_identical(registry$DesignFixedBernoulli$randomization_family, "bernoulli")
	expect_identical(registry$DesignFixedBinaryMatch$randomization_family, "binary_match")
	expect_identical(registry$DesignFixedBlocking$randomization_family, "blocked")
	expect_identical(registry$DesignFixedCluster$randomization_family, "clustered")
	expect_identical(registry$DesignFixedBlockedCluster$randomization_family, "blocked_cluster")
	expect_identical(registry$DesignFixedGreedyDOptimal$randomization_family, "greedy_d_optimal")
	expect_identical(registry$DesignFixedGreedy$randomization_family, "greedy")
	expect_identical(registry$DesignFixedRerandomization$randomization_family, "rerandomization")
	expect_identical(registry$DesignFixedOptimalBlocks$randomization_family, "optimal_blocks")
	expect_identical(registry$DesignFixedFactorial$randomization_family, "factorial")
	expect_identical(registry$DesignFixediBCRD$randomization_family, "complete_randomization")
	expect_identical(registry$DesignSeqOneByOneiBCRD$randomization_family, "complete_randomization")
	expect_identical(registry$DesignFixedMatchingGreedyPairSwitching$randomization_family, "matching_greedy_pair_switching")
	expect_identical(registry$DesignFixedCustom$randomization_family, "custom_fixed")
	expect_identical(registry$DesignCustomSequential$randomization_family, "custom_sequential")
	expect_identical(registry$DesignSeqOneByOneKK14$randomization_family, "kk14")
	expect_identical(registry$DesignSeqOneByOneKK21$randomization_family, "kk21")
	expect_identical(registry$DesignSeqOneByOneKK21stepwise$randomization_family, "kk21_stepwise")
	expect_identical(registry$DesignSeqOneByOneAtkinson$randomization_family, "atkinson")
	expect_identical(registry$DesignSeqOneByOneEfron$randomization_family, "efron")
	expect_identical(registry$DesignSeqOneByOnePocockSimon$randomization_family, "pocock_simon")
	expect_identical(registry$DesignSeqOneByOneRandomBlockSize$randomization_family, "random_block_size")
	expect_identical(registry$DesignSeqOneByOneSPBR$randomization_family, "spbr")
	expect_identical(registry$DesignSeqOneByOneUrn$randomization_family, "urn")

	# the observational family has no randomization mechanism at all -- "none" is a
	# real enum member, distinct from the NA used by the abstract bases
	expect_identical(registry$ObservationalDesign$randomization_family, "none")
	expect_identical(registry$ObservationalDesignBlocks$randomization_family, "none")
	expect_identical(registry$ObservationalDesignMatching$randomization_family, "none")
})

test_that("seed_reproducible_draw flags the known non-reproducible optimal-design classes", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	# the former A-/D-optimal seed-reproducibility exceptions were merged into
	# DesignFixedGreedyDOptimal after the RNG migration made the kernel R-seeded
	expect_true(registry$DesignFixedGreedyDOptimal$seed_reproducible_draw)
	expect_true(registry$DesignFixedGreedy$seed_reproducible_draw)
	expect_true(registry$DesignFixedBernoulli$seed_reproducible_draw)
	expect_true(is.na(registry$Design$seed_reproducible_draw))
	expect_true(is.na(registry$DesignFixed$seed_reproducible_draw))
})

test_that("supports_batch_w_pregeneration matches the known pre-generating classes", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()
	pregen = Filter(function(name) isTRUE(registry[[name]]$supports_batch_w_pregeneration), names(registry))

	expect_setequal(pregen, c(
		"DesignFixedBinaryMatch", "DesignFixedGreedy",
		"DesignFixedMatchingGreedyPairSwitching", "DesignFixedOptimalBlocks"
	))
})

test_that("required_packages matches the known Suggests-only dependencies", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	expect_setequal(registry$DesignFixedBinaryMatch$required_packages, "nbpMatching")
	expect_setequal(registry$DesignFixedMatchingGreedyPairSwitching$required_packages, "nbpMatching")
	expect_setequal(registry$DesignFixedCluster$required_packages, "randomizr")
	expect_setequal(registry$DesignFixedBlockedCluster$required_packages, "randomizr")
	expect_setequal(registry$DesignFixedBlocking$required_packages, "randomizr")
	expect_setequal(
		registry$DesignFixedOptimalBlocks$required_packages,
		c("anticlust", "blockTools", "ompr", "ompr.roi", "ROI.plugin.glpk", "randomizr")
	)
	expect_identical(registry$DesignFixedBernoulli$required_packages, character())
})

test_that("design class metadata rejects missing fields and invalid enum values", {
	valid = EDI:::get_design_class_metadata("DesignFixedBernoulli")
	expect_silent(EDI:::validate_design_class_metadata(valid))

	missing_family = valid
	missing_family$randomization_family = NULL
	expect_error(
		EDI:::validate_design_class_metadata(missing_family),
		"missing required field"
	)

	bad_randomization_family = valid
	bad_randomization_family$randomization_family = "not_a_real_family"
	expect_error(
		EDI:::validate_design_class_metadata(bad_randomization_family),
		"invalid `randomization_family`"
	)

	bad_timing_family = valid
	bad_timing_family$timing_family = "somewhere_in_between"
	expect_error(
		EDI:::validate_design_class_metadata(bad_timing_family),
		"invalid `timing_family`"
	)

	na_timing_on_concrete = valid
	na_timing_on_concrete$timing_family = NA_character_
	expect_error(
		EDI:::validate_design_class_metadata(na_timing_on_concrete),
		"only Design, DesignBlocking, DesignMatching"
	)

	na_family_on_concrete = valid
	na_family_on_concrete$randomization_family = NA_character_
	expect_error(
		EDI:::validate_design_class_metadata(na_family_on_concrete),
		"only the unsplit/timing-root bases"
	)

	unsplit_base = EDI:::get_design_class_metadata("Design")
	expect_silent(EDI:::validate_design_class_metadata(unsplit_base))
	expect_true(is.na(unsplit_base$timing_family))
	expect_true(is.na(unsplit_base$randomization_family))

	timing_root = EDI:::get_design_class_metadata("DesignFixed")
	expect_silent(EDI:::validate_design_class_metadata(timing_root))
	expect_identical(timing_root$timing_family, "fixed")
	expect_true(is.na(timing_root$randomization_family))
})

test_that("register_design_class rejects duplicate registration", {
	on.exit(EDI:::populate_design_class_registry(), add = TRUE)
	expect_error(
		EDI:::register_design_class("Design"),
		"already registered"
	)
})

test_that("design class registry timing_family agrees with the real R6 inheritance chain", {
	EDI:::populate_design_class_registry()
	registry = EDI:::design_class_registry_as_list()

	for (name in names(registry)) {
		if (name %in% EDI:::EDI_DESIGN_UNSPLIT_ABSTRACT_CLASS_NAMES) next
		obj = get(name, envir = asNamespace("EDI"))
		expected = EDI:::infer_design_timing_family(obj)
		expect_identical(registry[[name]]$timing_family, expected, info = name)
	}
})

test_that("deterministic_optimal family is registered for the upcoming DesignFixedOptimal (design_fixed_optimal.md TODO-8)", {
	# The closed enum admits the new family...
	expect_true("deterministic_optimal" %in% EDI:::EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES)
	# ...the by-name mapping is staged (inert until the class exists, since
	# populate_design_class_registry() scans the namespace)...
	expect_identical(unname(EDI:::EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME["DesignFixedOptimal"]), "deterministic_optimal")
	# ...no other class claims the family (one-class-one-family rule)...
	expect_identical(
		names(EDI:::EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME)[EDI:::EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME == "deterministic_optimal"],
		"DesignFixedOptimal"
	)
	# ...and the ompr-path packages are declared (lazily checked at solve time;
	# commercial ROI plugins deliberately absent per the never-Suggests rule).
	expect_identical(
		EDI:::EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME[["DesignFixedOptimal"]],
		c("ompr", "ompr.roi", "ROI.plugin.glpk")
	)
	expect_false(any(grepl("gurobi|cplex", EDI:::EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME[["DesignFixedOptimal"]])))
	# Not a batch-w-pregeneration class (one deterministic w*, nothing to batch).
	expect_false("DesignFixedOptimal" %in% EDI:::EDI_DESIGN_BATCH_W_PREGENERATION_CLASS_NAMES)
	# The registry itself must remain valid with the staged, class-less mapping.
	expect_silent(EDI:::validate_design_class_registry())
})
