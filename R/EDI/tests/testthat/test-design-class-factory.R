# define_design_class() and its assembly/validation helpers
# (fix_design_hierarchy.md, "Class Factory Implementation").
#
# All classes built here are temporary/throwaway (DesignTemporary* naming, mirroring
# the InferenceTemporary* convention in test-inference-class-registry.R) -- none of
# them are real production designs. Building a class with this factory does NOT
# register it in EDI_DESIGN_CLASS_REGISTRY (define_design_class() never calls
# register_design_class(), exactly like define_inference_class() never calls
# register_inference_class() -- registration for every Design generator, however
# built, comes uniformly from populate_design_class_registry()'s namespace scan).

test_that("design class assembly preserves NULL private state", {
	assembled = EDI:::assemble_design_private(
		"DesignTemporaryNullState",
		component_names = character(),
		private = list(optional_cache = NULL)
	)

	expect_named(assembled, "optional_cache")
	expect_null(assembled$optional_cache)
})

test_that("component-owned state is materialized and permits declared host defaults", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	EDI:::register_design_component(EDI:::DesignComponent(
		name = "DesignTemporaryStateComponent",
		private = list(component_cache = NULL),
		owns_state = "component_cache",
		allowed_host_overrides = list(public = character(), private = "component_cache")
	))

	DesignTemporaryStateHost = EDI:::define_design_class(
		classname = "DesignTemporaryStateHost",
		inherit = Design,
		components = "DesignTemporaryStateComponent",
		private = list(component_cache = "host-default")
	)

	expect_identical(DesignTemporaryStateHost$private_fields$component_cache, "host-default")
})

test_that("define_design_class() assembles a working BlockingStructure host", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	DesignTemporaryBlockingHost = EDI:::define_design_class(
		classname = "DesignTemporaryBlockingHost",
		inherit = DesignFixed,
		components = "BlockingStructure",
		public = list(
			initialize = function(response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$blocking_capable = TRUE
			}
		),
		private = list(
			draw_ws_raw = function(r = 1L) {
				matrix(rep(c(1, 0), length.out = self$get_n() * r), ncol = r)
			}
		)
	)

	des = DesignTemporaryBlockingHost$new(response_type = "continuous", n = 6)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des$assign_w_to_all_subjects()
	# blocking_capable is set unconditionally in this class's own constructor (a
	# class-level responsibility, same as every real blocking-capable design today),
	# so is_blocking_design() is TRUE from construction, independent of set_m().
	expect_true(des$is_blocking_design())
	des$set_m(c(1L, 1L, 2L, 2L, 3L, 3L))
	expect_true(des$is_blocking_design())
	expect_identical(des$get_block_ids(), c(1L, 1L, 2L, 2L, 3L, 3L))
})

test_that("define_design_class() correctly finds root Design methods through a multi-level inherit chain", {
	# The regression this guards: a one-level-only inherited-name lookup (the shape
	# contracts_mixins.R's r6_inherited_public_names() uses) missed get_X_raw for a
	# class declared `inherit = DesignFixed` while DesignFixed still (pre "Timing-
	# Family Split") sits three hops below Design. design_r6_inherited_public_names()/
	# design_r6_inherited_private_names() must walk the full chain.
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	expect_silent(EDI:::define_design_class(
		classname = "DesignTemporaryDeepChainHost",
		inherit = DesignFixed,
		components = "BlockingStructure"
	))
	expect_silent(EDI:::define_design_class(
		classname = "DesignTemporaryRootHost",
		inherit = Design,
		components = "BlockingStructure"
	))
})

test_that("define_design_class() rejects a class missing a component's required root method", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	expect_error(
		EDI:::define_design_class(
			classname = "DesignTemporaryNoRootHost",
			inherit = NULL,
			components = "BlockingStructure"
		),
		"missing public method\\(s\\) required by BlockingStructure: get_X_raw"
	)
})

test_that("define_design_class() rejects an undeclared public collision with a component method", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	expect_error(
		EDI:::define_design_class(
			classname = "DesignTemporaryCollisionHost",
			inherit = DesignFixed,
			components = "BlockingStructure",
			public = list(is_blocking_design = function() stop("shadow"))
		),
		"overrides component public member\\(s\\) without declaration: is_blocking_design"
	)
})

test_that("define_design_class() accepts a declared override of a component method", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	DesignTemporaryOverrideHost = EDI:::define_design_class(
		classname = "DesignTemporaryOverrideHost",
		inherit = DesignFixed,
		components = "BlockingStructure",
		public = list(is_blocking_design = function() "overridden"),
		overrides = list(public = "is_blocking_design")
	)
	des = DesignTemporaryOverrideHost$new(response_type = "continuous", n = 4)
	expect_identical(des$is_blocking_design(), "overridden")
})

test_that("define_design_class() rejects composing a scaffold component", {
	# No permanent scaffold remains in the registry (see
	# test-design-component-registry.R's identical note), so this test registers a
	# temporary one itself.
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	EDI:::register_design_component(EDI:::DesignComponent(
		name = "DesignTemporaryScaffold",
		status = "scaffold"
	))
	expect_error(
		EDI:::define_design_class(
			classname = "DesignTemporaryScaffoldHost",
			inherit = DesignFixed,
			components = "DesignTemporaryScaffold"
		),
		"Scaffold design component\\(s\\) cannot be resolved: DesignTemporaryScaffold"
	)
})

test_that("define_design_class() expands MatchingStructure's BlockingStructure dependency automatically", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	DesignTemporaryMatchingHost = EDI:::define_design_class(
		classname = "DesignTemporaryMatchingHost",
		inherit = DesignFixed,
		components = "MatchingStructure",
		public = list(
			initialize = function(response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$blocking_capable = TRUE
				private$matching_capable = TRUE
			}
		),
		private = list(draw_ws_raw = function(r = 1L) matrix(1, nrow = self$get_n(), ncol = r)),
		# MatchingStructure's pair-preserving draw_bootstrap_indices must win over
		# BlockingStructure's plain block-based one (auto-expanded dependency); both
		# now provide the method since BlockingStructure's generalization landed.
		overrides = list(private = "draw_bootstrap_indices")
	)
	des = DesignTemporaryMatchingHost$new(response_type = "continuous", n = 4)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(4)))
	des$assign_w_to_all_subjects()
	des$set_m(c(1L, 1L, 2L, 2L))
	expect_true(des$is_matching_design())
	expect_true(des$is_blocking_design())
})

test_that("define_design_class() rejects lock_objects other than FALSE", {
	expect_error(
		EDI:::define_design_class(classname = "DesignTemporaryLockedHost", lock_objects = TRUE),
		"must keep `lock_objects = FALSE`"
	)
})

test_that("a declared override name suppresses both the plain collision and a method/state kind mismatch", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	# is_blocking_design is a method on BlockingStructure and a plain value (state)
	# on the host here -- a kind mismatch, not just a name collision. Declaring the
	# name in overrides is sufficient to silence both checks uniformly (there is no
	# separate declaration for "I know the kind changed too"); this matches
	# contracts_mixins.R's identical combine_component_slot() behavior for Inference.
	assembled = EDI:::assemble_design_public(
		"DesignTemporaryKindCollisionHost",
		"BlockingStructure",
		public = list(is_blocking_design = "not_a_function"),
		overrides = list(public = "is_blocking_design")
	)
	expect_identical(assembled$is_blocking_design, "not_a_function")
})

test_that("designed classes built via the factory are not auto-registered in the class registry", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	EDI:::define_design_class(
		classname = "DesignTemporaryUnregisteredHost",
		inherit = DesignFixed,
		components = "BlockingStructure"
	)
	expect_error(
		EDI:::get_design_class_metadata("DesignTemporaryUnregisteredHost"),
		"No design class metadata registered"
	)
})

# fix_design_hierarchy.md Source Invariant #15 / "Follow-Ups" item: component-owned
# state must survive Design$duplicate() the way root Design state does, and must not
# be silently reset or shared between the original and the clone. The Inference
# migration hit a real, silent-wrong-answer bug of exactly this shape once
# (InferenceContinQuantileRegr's tau/fit_warm_keep fields reset to NULL by a
# duplicate()-style clone helper -- see that class's correction note in
# fix_inference_hierarchy.md). This is now testable for Design because
# define_design_class() exists; no real production Design class composed a component
# with real mutable state before this.
test_that("BlockingStructure component-owned state survives Design$duplicate()", {
	on.exit(EDI:::populate_design_component_registry(), add = TRUE)
	DesignTemporaryDuplicateHost = EDI:::define_design_class(
		classname = "DesignTemporaryDuplicateHost",
		inherit = DesignFixed,
		components = "BlockingStructure",
		public = list(
			initialize = function(response_type, n, ...) {
				super$initialize(response_type = response_type, n = n, ...)
				private$blocking_capable = TRUE
			}
		),
		private = list(
			draw_ws_raw = function(r = 1L) {
				matrix(rep(c(1, 0), length.out = self$get_n() * r), ncol = r)
			}
		)
	)

	des = DesignTemporaryDuplicateHost$new(response_type = "continuous", n = 6)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des$assign_w_to_all_subjects()
	des$set_m(c(1L, 1L, 2L, 2L, 3L, 3L))
	des$add_all_subject_responses(rnorm(6))

	clone = des$duplicate()

	# survives with the correct value, not reset to NULL/default
	expect_identical(clone$get_block_ids(), c(1L, 1L, 2L, 2L, 3L, 3L))
	expect_true(clone$is_blocking_design())

	# is a real independent copy, not a shared reference: mutating the clone's
	# component-owned state must not bleed back into the original
	clone$.__enclos_env__$private$m = c(9L, 9L, 9L, 9L, 9L, 9L)
	expect_identical(des$get_block_ids(), c(1L, 1L, 2L, 2L, 3L, 3L))
	expect_identical(clone$get_block_ids(), c(9L, 9L, 9L, 9L, 9L, 9L))
})

test_that("TODO-35 production generators use define_design_class", {
	# dir.exists() alone isn't a reliable signal: under covr's test-coverage
	# CI job, tests run against an INSTALLED package's copied-out tests
	# directory (R_LIBS.../EDI-tests/testthat/, per test-coverage-R.yaml's own
	# comment on why testthat.Rout never lands under R/EDI), where a
	# coincidentally-existing "../../R" can resolve to something that isn't
	# actually this package's R/ source tree at all -- readLines() then fails
	# with a raw "cannot open the connection" instead of the graceful skip
	# below. Require an actual known source file to be present, not just a
	# directory named "R", before trusting a candidate.
	source_dirs = c(file.path("R", "EDI", "R"), file.path("..", "..", "R"))
	source_dirs = source_dirs[
		dir.exists(source_dirs) &
			file.exists(file.path(source_dirs, "design_fixed_bernoulli.R"))
	]
	skip_if(length(source_dirs) == 0L, "package source files are unavailable")
	source_dir = source_dirs[[1L]]

	class_files = c(
		DesignFixedCustom = "design_custom_extensions.R",
		DesignCustomSequential = "design_custom_extensions.R",
		DesignFixedBernoulli = "design_fixed_bernoulli.R",
		DesignFixedFactorial = "design_fixed_factorial.R",
		DesignFixedGreedy = "design_fixed_greedy.R",
		DesignFixediBCRD = "design_fixed_ibcrd.R",
		DesignFixedMatchingGreedyPairSwitching = "design_fixed_matching_greedy_pair_switching.R",
		DesignFixedRerandomization = "design_fixed_rerandomization.R",
		ObservationalDesign = "design_observational.R",
		DesignSeqOneByOneAtkinson = "design_seq_one_by_one_atkinson.R",
		DesignSeqOneByOneBernoulli = "design_seq_one_by_one_bernoulli.R",
		DesignSeqOneByOneEfron = "design_seq_one_by_one_efron.R",
		DesignSeqOneByOneiBCRD = "design_seq_one_by_one_ibcrd.R",
		DesignSeqOneByOnePocockSimon = "design_seq_one_by_one_pocock_simon.R",
		DesignSeqOneByOneRandomBlockSize = "design_seq_one_by_one_random_block_size.R",
		DesignSeqOneByOneSPBR = "design_seq_one_by_one_spbr.R",
		DesignSeqOneByOneUrn = "design_seq_one_by_one_urn.R"
	)

	for (class_name in names(class_files)) {
		text = paste(readLines(file.path(source_dir, class_files[[class_name]]), warn = FALSE), collapse = "\n")
		expect_match(
			text,
			paste0("(?m)^", class_name, "\\s*=\\s*define_design_class\\("),
			perl = TRUE,
			info = class_name
		)
	}
})
