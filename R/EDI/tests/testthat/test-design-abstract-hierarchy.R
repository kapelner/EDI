test_that("Design hierarchy supports both fixed and sequential designs", {
	seq_des = DesignSeqOneByOneBernoulli$new(n = 4, response_type = "continuous", verbose = FALSE)
	fixed_des = DesignFixedBernoulli$new(n = 4, response_type = "continuous", verbose = FALSE)

	expect_true(is(seq_des, "Design"))
	expect_true(is(fixed_des, "Design"))
	expect_false(is(seq_des, "DesignBlocking"))
	expect_false(is(fixed_des, "DesignBlocking"))
	expect_false(is(seq_des, "DesignMatching"))
	expect_false(is(fixed_des, "DesignMatching"))
	expect_false(is(seq_des, "DesignFixed"))
	expect_true(is(fixed_des, "DesignFixed"))
	expect_false(seq_des$is_blocking_design())
	expect_false(fixed_des$is_blocking_design())
	expect_false(seq_des$is_matching_design())
	expect_false(fixed_des$is_matching_design())
})

test_that("legacy structural generators are absent", {
	ns = asNamespace("EDI")
	expect_false(exists("DesignBlocking", envir = ns, inherits = FALSE))
	expect_false(exists("DesignMatching", envir = ns, inherits = FALSE))
	expect_identical(DesignFixed$get_inherit(), Design)
	expect_identical(DesignSeqOneByOne$get_inherit(), Design)
})

test_that("sequential structural capabilities come from components, not timing ancestry", {
	expect_identical(DesignSeqOneByOne$get_inherit(), Design)

	blocking_des = DesignSeqOneByOneSPBR$new(
		strata_cols = "stratum", n = 4, response_type = "continuous", verbose = FALSE
	)
	matching_des = DesignSeqOneByOneKK14$new(
		n = 4, response_type = "continuous", verbose = FALSE
	)

	for (des in list(blocking_des, matching_des)) {
		expect_false(is(des, "DesignBlocking"))
		expect_false(is(des, "DesignMatching"))
		expect_true(des$is_blocking_design())
	}
	expect_false(blocking_des$is_matching_design())
	expect_true(matching_des$is_matching_design())
})

test_that("iBCRD single-block state is supplied by BlockingStructure", {
	fixed_des = DesignFixediBCRD$new(n = 4, response_type = "continuous", verbose = FALSE)
	expect_true(fixed_des$is_blocking_design())
	fixed_des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(4L)))
	fixed_des$assign_w_to_all_subjects()
	fixed_des$add_all_subject_responses(seq_len(4L))
	expect_identical(fixed_des$get_block_ids(), rep(1L, 4L))

	seq_des = DesignSeqOneByOneiBCRD$new(n = 4, response_type = "continuous", verbose = FALSE)
	expect_true("BlockingStructure" %in% EDI:::get_effective_design_components("DesignSeqOneByOneiBCRD"))
	expect_true(seq_des$is_blocking_design())
	for (i in seq_len(4L)) {
		seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i))
	}
	seq_des$add_all_subject_responses(seq_len(4L))
	expect_identical(seq_des$get_block_ids(), rep(1L, 4L))
})

test_that("DesignFixedTestFixture supports analysis but not redraw-based resampling", {
	des = DesignFixedTestFixture$new(n = 4, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = 1:4))
	des$overwrite_all_subject_assignments(c(0, 1, 0, 1))
	des$add_all_subject_responses(c(1, 3, 2, 4))

	expect_false(des$supports_resampling())
	expect_false(des$supports_randomization_draw())
	expect_false(des$supports_resampling_replay())
	expect_error(des$assign_w_to_all_subjects(), "draw_ws_raw must be implemented")

	inf = InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	expect_equal(inf$compute_estimate(), 2)
	expect_length(inf$compute_asymp_confidence_interval(), 2)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_error(
		inf$compute_bootstrap_two_sided_pval(B = 11),
		"Bootstrap inference is not available for plain DesignFixed objects"
	)
	expect_error(
		inf$compute_rand_two_sided_pval(r = 11),
		"Randomization inference is not available for this design"
	)

	# Structural mutation APIs are supplied only by structural components.
	expect_false("add_all_subject_matched_pair_ids" %in% names(des))
	expect_false(des$is_blocking_design())
	expect_false(des$is_matching_design())
})

test_that("DesignFixedTestFixture batch ingest validates input shape and type", {
	des = DesignFixedTestFixture$new(n = 4, response_type = "continuous", verbose = FALSE)
	expect_error(des$add_all_subjects_to_experiment(matrix(1:4, ncol = 1)), "data.frame")
	expect_error(
		des$add_all_subjects_to_experiment(data.frame(x1 = 1:3)),
		"exactly 4 rows"
	)
})

test_that("capabilities()/supports() report instance-level truth, not class-level component composition (fix_design_hierarchy.md TODO-28)", {
	# DesignFixediBCRD composes BlockingStructure (so it *could* be
	# blocking-capable), but with an unknown n at construction time its
	# documented behavior is blocking_capable = FALSE for this specific
	# instance -- is_blocking_design() must reflect that instance state, and
	# capabilities()/supports("blocking") must agree with it exactly, not
	# report "blocking" just because the class composes the component. This
	# was a real, reproducible false positive during this TODO's
	# implementation (a premature union with the class-level component
	# registry), not a hypothetical.
	des = DesignFixediBCRD$new(response_type = "continuous")
	expect_false(des$is_blocking_design())
	expect_false(des$supports("blocking"))
	expect_false("blocking" %in% des$capabilities())

	# A class-level registry read should still say the class *composes*
	# BlockingStructure -- that's a different, correct question this
	# instance-level check must not be confused with.
	expect_true("BlockingStructure" %in% EDI:::get_effective_design_components("DesignFixediBCRD"))

	# ClusterStructure-composing classes: "cluster" was previously never
	# reachable via capabilities()/supports() at all (no legacy predicate
	# checked it) -- now sourced from is_a_cluster_capable() directly.
	cluster_des = DesignFixedCluster$new(n = 6, response_type = "continuous", cluster_col = "cluster")
	expect_true(cluster_des$supports("cluster"))
	non_cluster_des = DesignFixedBernoulli$new(n = 4, response_type = "continuous")
	expect_false(non_cluster_des$supports("cluster"))
})

test_that("abstract Design base classes cannot be instantiated directly", {
	expect_error(
		EDI:::Design$new(n = 4, response_type = "continuous", verbose = FALSE),
		"abstract Design base class and cannot be instantiated directly"
	)
	expect_error(
		EDI:::DesignFixed$new(n = 4, response_type = "continuous", verbose = FALSE),
		"abstract Design base class and cannot be instantiated directly"
	)
	expect_error(
		EDI:::DesignSeqOneByOne$new(n = 4, response_type = "continuous", verbose = FALSE),
		"abstract Design base class and cannot be instantiated directly"
	)
	expect_error(
		EDI:::DesignFixedCustom$new(n = 4, response_type = "continuous", verbose = FALSE),
		"abstract Design base class and cannot be instantiated directly"
	)
	expect_error(
		EDI:::DesignCustomSequential$new(n = 4, response_type = "continuous", verbose = FALSE),
		"abstract Design base class and cannot be instantiated directly"
	)

	# A concrete subclass of an abstract base is unaffected by the gate.
	des = DesignFixedTestFixture$new(n = 4, response_type = "continuous", verbose = FALSE)
	expect_true(is(des, "DesignFixed"))

	# A third-party/test-defined class the registry never scanned is also
	# unaffected -- the gate must not misfire on unregistered names.
	DesignTemporaryUnregistered = EDI:::define_design_class(
		classname = "DesignTemporaryUnregistered",
		inherit = DesignFixed,
		components = character(),
		public = list()
	)
	expect_true(is(DesignTemporaryUnregistered$new(n = 4, response_type = "continuous", verbose = FALSE), "DesignFixed"))
})
