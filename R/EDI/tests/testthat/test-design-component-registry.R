test_that("design component registry registers the planned components", {
	EDI:::populate_design_component_registry()
	registry = EDI:::design_component_registry_as_list()

	expect_setequal(names(registry), c(
		"BlockingStructure", "MatchingStructure", "ClusterStructure",
		"SequentialStrataBootstrap", "AllocationMatrixValidation", "BatchWPregeneration"
	))
	for (component in registry) {
		expect_identical(EDI:::design_component_public_names(component), component$provides_public_methods)
		expect_identical(EDI:::design_component_private_names(component), component$provides_private_methods)
	}
})

test_that("active components have real method references and pass body-reference validation", {
	EDI:::populate_design_component_registry()

	blocking = EDI:::get_design_component("BlockingStructure")
	expect_identical(blocking$status, "active")
	expect_setequal(blocking$provides_public_methods, c(
		"is_blocking_design", "assert_blocking_design", "is_complete_blocking_design",
		"assert_equal_block_sizes", "add_all_subject_matched_pair_ids", "set_m",
		"get_block_ids", "summarize_blocks", "inject_cmh_se_w_mat", "get_cmh_se_w_mat"
	))
	expect_setequal(blocking$provides_private_methods, c("assert_min_block_size", "get_strata_keys", "draw_bootstrap_indices"))
	expect_identical(blocking$dependencies, character())
	expect_identical(blocking$provides_capabilities, "blocking")
	# real references to the still-live DesignBlocking generator, not copies
	expect_identical(blocking$public$is_blocking_design, DesignBlocking$public_methods$is_blocking_design)
	expect_identical(blocking$private$get_strata_keys, DesignBlocking$private_methods$get_strata_keys)
	expect_silent(EDI:::validate_design_component_body_references(blocking))

	matching = EDI:::get_design_component("MatchingStructure")
	expect_identical(matching$status, "active")
	expect_identical(matching$dependencies, "BlockingStructure")
	expect_identical(matching$provides_capabilities, "matching")
	expect_true("m" %in% matching$requires_state)
	expect_identical(
		matching$private$draw_bootstrap_indices,
		DesignMatching$private_methods$draw_bootstrap_indices
	)
	expect_silent(EDI:::validate_design_component_body_references(matching))

	batch = EDI:::get_design_component("BatchWPregeneration")
	expect_identical(batch$status, "active")
	expect_identical(batch$provides_capabilities, "batch_w_pregeneration")
	expect_true(isTRUE(batch$public$supports_batch_w_pregeneration()))
	expect_silent(EDI:::validate_design_component_body_references(batch))

	sequential = EDI:::get_design_component("SequentialStrataBootstrap")
	expect_identical(sequential$status, "active")
	expect_setequal(sequential$provides_private_methods, c("get_strata_key", "draw_bootstrap_indices"))
	expect_identical(sequential$owns_state, "sequential_bootstrap_whole_group")
	expect_silent(EDI:::validate_design_component_body_references(sequential))
})

test_that("ClusterStructure is a real, active component with a generalized draw_bootstrap_indices", {
	# Promoted from scaffold to active once a generalized implementation was authored
	# and golden-tested against both DesignFixedCluster and DesignFixedBlockedCluster's
	# real output (test-design-cluster-structure-golden.R) -- see fix_design_hierarchy.md,
	# "Follow-Ups From Implementation" -- "Author the generalized ClusterStructure".
	EDI:::populate_design_component_registry()

	cluster = EDI:::get_design_component("ClusterStructure")
	expect_identical(cluster$status, "active")
	expect_identical(cluster$owns_state, "cluster_col")
	expect_identical(cluster$public, list())
	expect_true(is.function(cluster$private$draw_bootstrap_indices))
	expect_identical(cluster$provides_capabilities, "cluster")
	expect_silent(EDI:::validate_design_component_body_references(cluster))
})

test_that("AllocationMatrixValidation is still registered as a scaffold, not fabricated", {
	EDI:::populate_design_component_registry()

	validation = EDI:::get_design_component("AllocationMatrixValidation")
	expect_identical(validation$status, "scaffold")
	expect_identical(validation$public, list())
	expect_identical(validation$private, list())
})

test_that("scaffold components cannot be resolved as dependencies", {
	EDI:::populate_design_component_registry()

	expect_error(
		EDI:::resolve_design_component_dependencies("AllocationMatrixValidation"),
		"Scaffold design component"
	)
})

test_that("ClusterStructure, no longer a scaffold, resolves as a dependency", {
	EDI:::populate_design_component_registry()
	expect_identical(EDI:::resolve_design_component_dependencies("ClusterStructure"), "ClusterStructure")
})

test_that("dependency resolution expands MatchingStructure to include BlockingStructure", {
	EDI:::populate_design_component_registry()

	expect_identical(
		EDI:::resolve_design_component_dependencies("MatchingStructure"),
		c("BlockingStructure", "MatchingStructure")
	)
	expect_identical(
		EDI:::resolve_design_component_dependencies("BlockingStructure"),
		"BlockingStructure"
	)
	# already-satisfied (e.g. inherited from a parent class) components are not re-listed
	expect_identical(
		EDI:::resolve_design_component_dependencies("MatchingStructure", satisfied_components = "BlockingStructure"),
		"MatchingStructure"
	)
})

test_that("dependency resolution rejects duplicates, unknown components, and cycles", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)

	expect_error(
		EDI:::resolve_design_component_dependencies(c("BlockingStructure", "BlockingStructure")),
		"Duplicate direct design component"
	)
	expect_error(
		EDI:::resolve_design_component_dependencies("NotARealComponent"),
		"Unknown design component"
	)
	expect_error(
		EDI:::resolve_design_component_dependencies(c("BlockingStructure", "MatchingStructure")),
		"duplicates transitive dependency"
	)

	EDI:::register_design_component(EDI:::DesignComponent(
		name = "DesignTemporaryCycleA", status = "active", dependencies = "DesignTemporaryCycleB"
	))
	EDI:::register_design_component(EDI:::DesignComponent(
		name = "DesignTemporaryCycleB", status = "active", dependencies = "DesignTemporaryCycleA"
	))
	expect_error(
		EDI:::resolve_design_component_dependencies("DesignTemporaryCycleA"),
		"dependency cycle"
	)
})

test_that("validate_design_component_body_references catches undeclared private/self references", {
	bad_private = EDI:::DesignComponent(
		name = "DesignTemporaryBadPrivateRef",
		status = "active",
		public = list(broken = function() private$undeclared_field)
	)
	expect_error(
		EDI:::validate_design_component_body_references(bad_private),
		"undeclared private reference"
	)

	bad_self = EDI:::DesignComponent(
		name = "DesignTemporaryBadSelfRef",
		status = "active",
		public = list(broken = function() self$undeclared_method())
	)
	expect_error(
		EDI:::validate_design_component_body_references(bad_self),
		"undeclared self reference"
	)

	ok = EDI:::DesignComponent(
		name = "DesignTemporaryOkRef",
		status = "active",
		public = list(fine = function() private$owned_field),
		owns_state = "owned_field"
	)
	expect_silent(EDI:::validate_design_component_body_references(ok))
})

test_that("every registered active design component passes body-reference validation", {
	EDI:::populate_design_component_registry()
	registry = EDI:::design_component_registry_as_list()
	active = Filter(function(c) identical(c$status, "active"), registry)

	expect_gt(length(active), 0L)
	for (component in active) {
		expect_silent(EDI:::validate_design_component_body_references(component))
	}
})

test_that("DesignComponent validator rejects missing fields, invalid status, and stale method metadata", {
	valid = EDI:::get_design_component("BatchWPregeneration")
	expect_silent(EDI:::validate_design_component(valid))

	missing_field = valid
	missing_field$dependencies = NULL
	expect_error(
		EDI:::validate_design_component(missing_field),
		"missing required field"
	)

	bad_status = valid
	bad_status$status = "not_a_real_status"
	expect_error(
		EDI:::validate_design_component(bad_status),
		"invalid status"
	)

	stale_public = valid
	stale_public$provides_public_methods = c(stale_public$provides_public_methods, "phantom_method")
	expect_error(
		EDI:::validate_design_component(stale_public),
		"stale public method metadata"
	)
})

test_that("register_design_component rejects duplicate registration", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	expect_error(
		EDI:::register_design_component(EDI:::get_design_component("BlockingStructure")),
		"already registered"
	)
})

test_that("registering design components does not change any existing Design class's behavior", {
	# Components are metadata + references only at this stage (Component Registry);
	# no concrete class consumes them yet (that's Component Extraction), so ordinary
	# design usage must be completely unaffected.
	EDI:::populate_design_component_registry()

	des = DesignFixedBlocking$new(n = 8, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	des$assign_w_to_all_subjects()
	expect_length(des$get_w(), 8)
	expect_true(des$is_blocking_design())

	des2 = DesignFixedBinaryMatch$new(n = 6, response_type = "continuous")
	des2$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des2$assign_w_to_all_subjects()
	expect_length(des2$get_w(), 6)
	expect_true(des2$is_matching_design())
})
