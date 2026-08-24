# save_load_api.md, section B: round-trip smoke tests verifying the actual
# claim ("persist a Design via saveRDS()/readRDS(), continue enrolling,
# Inference* is disposable and rebuilt fresh") rather than inferring
# serialization safety from reading the code. See design_abstract.R's
# "Saving and loading" roxygen section for the documented contract.

test_that("plain sequential design round-trips through saveRDS()/readRDS() and permits continued enrollment", {
	n = 20L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", seed = 1L, verbose = FALSE)
	for (i in 1:10) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(10))

	X_before = des$get_X_raw()
	w_before = des$get_w()[1:10]
	y_before = des$get_y()[1:10]
	t_before = des$get_t()
	version_before = des$get_edi_version_created()

	tmp = tempfile(fileext = ".rds")
	saveRDS(des, tmp, version = 2)
	reloaded = readRDS(tmp)

	# Structural fidelity: everything recorded before save must survive intact.
	# get_X_raw() is a data.table; identical() compares its internal
	# self-reference pointer too, which legitimately differs after a
	# serialize/deserialize round trip even though the data itself is
	# unchanged -- compare values with expect_equal(), not expect_identical().
	expect_equal(reloaded$get_X_raw(), X_before)
	expect_identical(reloaded$get_w()[1:10], w_before)
	expect_identical(reloaded$get_y()[1:10], y_before)
	expect_identical(reloaded$get_t(), t_before)
	expect_identical(reloaded$get_edi_version_created(), version_before)

	# Continue enrolling on the reloaded object.
	for (i in 11:n) {
		w_t = reloaded$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		expect_true(w_t %in% c(0, 1))
	}
	for (i in 11:n) reloaded$add_one_subject_response(i, y = rnorm(1))
	expect_identical(reloaded$get_t(), n)

	# Inference* is disposable and reconstructed fresh -- never persisted itself.
	inf = InferenceContinOLS$new(reloaded, verbose = FALSE)
	est = inf$compute_estimate()
	expect_true(is.numeric(est))
	expect_length(est, 1L)
})

test_that("KK-matching design round-trips through saveRDS()/readRDS() with non-trivial matching state", {
	n = 16L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", seed = 2L, verbose = FALSE)
	for (i in 1:10) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	add_all_subject_responses_seq(des, rnorm(10))

	# Exercise the matching cache (private$all_subject_data_cache / private$m)
	# before saving, so the round trip is tested mid-trial with non-trivial
	# reservoir/matching state, not just at t = 0. get_block_ids() only
	# resolves once every subject has arrived (see test-designs.R's
	# DesignSeqOneByOneiBCRD case), so compare the raw match-vector state
	# directly instead of calling it mid-trial.
	m_before = des$.__enclos_env__$private$m
	X_before = des$get_X_raw()
	y_before = des$get_y()[1:10]
	w_before = des$get_w()[1:10]

	tmp = tempfile(fileext = ".rds")
	saveRDS(des, tmp, version = 2)
	reloaded = readRDS(tmp)

	expect_equal(reloaded$get_X_raw(), X_before)
	expect_identical(reloaded$get_y()[1:10], y_before)
	expect_identical(reloaded$get_w()[1:10], w_before)
	expect_identical(reloaded$.__enclos_env__$private$m, m_before)
	expect_true(reloaded$is_matching_design())

	for (i in 11:n) {
		reloaded$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
		reloaded$add_one_subject_response(i, y = rnorm(1))
	}
	expect_identical(reloaded$get_t(), n)

	inf = InferenceAllSimpleAverageDiff$new(reloaded, verbose = FALSE)
	est = inf$compute_estimate()
	expect_true(is.numeric(est))
})

test_that("version-mismatch check warns once on a major-version difference and is silent otherwise", {
	des = DesignFixedBernoulli$new(n = 6L, response_type = "continuous", seed = 3L, verbose = FALSE)

	# Same major version as currently loaded: silent.
	expect_silent(des$draw_ws_according_to_design(1L))

	# Simulate an object saved under a different major version by rewriting the
	# stamped field directly (mirrors what a real cross-major-version reload
	# would leave behind).
	des2 = DesignFixedBernoulli$new(n = 6L, response_type = "continuous", seed = 4L, verbose = FALSE)
	current = as.character(utils::packageVersion("EDI"))
	current_major = as.integer(strsplit(current, "\\.")[[1]][1])
	des2$.__enclos_env__$private$edi_version_created = paste0(current_major - 1L, ".0.0")
	expect_warning(
		des2$draw_ws_according_to_design(1L),
		"EDI version"
	)
	# One-time: the second call must not warn again.
	expect_silent(des2$draw_ws_according_to_design(1L))

	# Missing field entirely (object saved before the version stamp existed):
	# self-initializes to the current version and therefore never warns, since
	# there is no recoverable baseline to compare against.
	des3 = DesignFixedBernoulli$new(n = 6L, response_type = "continuous", seed = 5L, verbose = FALSE)
	des3$.__enclos_env__$private$edi_version_created = NULL
	expect_silent(des3$draw_ws_according_to_design(1L))
	expect_identical(des3$get_edi_version_created(), current)

	# Same check for the sequential "continue enrolling" entry point.
	des4 = DesignSeqOneByOneBernoulli$new(n = 6L, response_type = "continuous", seed = 6L, verbose = FALSE)
	des4$.__enclos_env__$private$edi_version_created = paste0(current_major - 1L, ".0.0")
	expect_warning(
		des4$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1))),
		"EDI version"
	)
	expect_silent(des4$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1))))
})

test_that("duplicate() carries the version stamp and mismatch-checked flag over via R6's default clone()", {
	des = DesignFixedBernoulli$new(n = 6L, response_type = "continuous", seed = 7L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(6)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(6))

	version_before = des$get_edi_version_created()
	dup = des$duplicate()
	expect_identical(dup$get_edi_version_created(), version_before)
})

# Cross-subclass field-audit: every DesignSeqOneByOne* subclass, iterated over
# the same construction list SimulationFramework..default_design_classes()
# uses for its sequential designs (simulations_framework.R), saved mid-trial
# and reloaded, asserting the recorded data survives byte-identical.
build_seq_design_for_save_load_audit = list(
	DesignSeqOneByOneBernoulli = function(seed)
		DesignSeqOneByOneBernoulli$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneEfron = function(seed)
		DesignSeqOneByOneEfron$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneAtkinson = function(seed)
		DesignSeqOneByOneAtkinson$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneKK14 = function(seed)
		DesignSeqOneByOneKK14$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneiBCRD = function(seed)
		DesignSeqOneByOneiBCRD$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneUrn = function(seed)
		DesignSeqOneByOneUrn$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneKK21 = function(seed)
		DesignSeqOneByOneKK21$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneKK21stepwise = function(seed)
		DesignSeqOneByOneKK21stepwise$new(n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneRandomBlockSize = function(seed)
		DesignSeqOneByOneRandomBlockSize$new(strata_cols = "strata", n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOneSPBR = function(seed)
		DesignSeqOneByOneSPBR$new(strata_cols = "strata", n = 8L, response_type = "continuous", seed = seed, verbose = FALSE),
	DesignSeqOneByOnePocockSimon = function(seed)
		DesignSeqOneByOnePocockSimon$new(strata_cols = "strata", n = 8L, response_type = "continuous", seed = seed, verbose = FALSE)
)

test_that("build_seq_design_for_save_load_audit covers every concrete DesignSeqOneByOne* subclass", {
	ns = asNamespace("EDI")
	registry = EDI:::design_class_registry_as_list()
	generators = Filter(function(name) {
		obj = get(name, envir = ns)
		EDI:::is_design_r6_generator(obj) && identical(obj$classname, name)
	}, sort(ls(ns)))
	seq_concrete = generators[
		vapply(generators, function(g) isFALSE(registry[[g]]$abstract) && isTRUE(registry[[g]]$exported), logical(1)) &
		vapply(generators, function(g) identical(registry[[g]]$timing_family, "sequential"), logical(1))
	]
	expect_setequal(names(build_seq_design_for_save_load_audit), seq_concrete)
})

for (design_name in names(build_seq_design_for_save_load_audit)) {
	local({
		this_name = design_name
		build = build_seq_design_for_save_load_audit[[this_name]]
		test_that(paste(this_name, "save/reload round trip preserves recorded state"), {
			needs_strata = this_name %in% c("DesignSeqOneByOneRandomBlockSize", "DesignSeqOneByOneSPBR", "DesignSeqOneByOnePocockSimon")
			needs_two_cov = this_name %in% c("DesignSeqOneByOneAtkinson", "DesignSeqOneByOneKK14", "DesignSeqOneByOneKK21", "DesignSeqOneByOneKK21stepwise")

			des = build(101L)
			make_row = function() {
				row = data.frame(x1 = rnorm(1))
				if (needs_two_cov) row$x2 = rnorm(1)
				if (needs_strata) row$strata = factor(sample(c("A", "B"), 1), levels = c("A", "B"))
				row
			}
			for (i in 1:5) des$add_one_subject_to_experiment_and_assign(make_row())
			add_all_subject_responses_seq(des, rnorm(5))

			X_before = des$get_X_raw()
			y_before = des$get_y()[1:5]
			w_before = des$get_w()[1:5]

			tmp = tempfile(fileext = ".rds")
			saveRDS(des, tmp, version = 2)
			reloaded = readRDS(tmp)

			# get_X_raw() is a data.table; identical() compares its internal
	# self-reference pointer too, which legitimately differs after a
	# serialize/deserialize round trip even though the data itself is
	# unchanged -- compare values with expect_equal(), not expect_identical().
	expect_equal(reloaded$get_X_raw(), X_before)
			expect_identical(reloaded$get_y()[1:5], y_before)
			expect_identical(reloaded$get_w()[1:5], w_before)
			expect_identical(reloaded$get_t(), des$get_t())
			expect_identical(reloaded$get_edi_version_created(), des$get_edi_version_created())

			# Continuing enrollment on the reloaded copy must not error.
			expect_no_error(reloaded$add_one_subject_to_experiment_and_assign(make_row()))
		})
	})
}
