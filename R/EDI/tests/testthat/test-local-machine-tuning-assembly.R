# Tests for local_machine_optimization.md TODO-5: persistence (diff building,
# merge-aware apply, read/write/clear/get) and the tune_EDI_for_this_machine()
# assembly (axis dispatch, progress bar, dry_run, file + in-session apply).
# All runs use a tempdir config dir and STUBBED axis tuners -- no real
# benchmarking happens here (TODO-10(a)).

# with_tuning_sandbox() / with_stub() live in helper-local-machine-tuning.R
# (shared with test-local-machine-tuning-correctness.R).

# Stubs that return canned deviations AND fire on_cell_done once per (family, n) cell,
# exactly as the real tuners do -- so the progress-bar cell accounting is exercised.
stub_cold = function(n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
	devs = list()
	for (cl in families$class) for (n in n_grid) {
		if (!is.null(on_cell_done)) on_cell_done(0.01)
		if (cl == "InferenceCountPoisson") devs[[length(devs) + 1L]] = list(class = cl, response_type = "count", n = n, from = FALSE, to = TRUE, rel_improvement = 0.2, median_baseline = 1, median_candidate = 0.8)
	}
	devs
}
stub_warm = function(operation, n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
	devs = list()
	for (cl in families$class) for (n in n_grid) {
		if (!is.null(on_cell_done)) on_cell_done(0.01)
		if (cl == "InferenceCountNegBin" && operation == "jackknife" && n == min(n_grid)) devs[[length(devs) + 1L]] = list(class = cl, response_type = "count", n = n, from = TRUE, to = FALSE, rel_improvement = 0.3, median_baseline = 1, median_candidate = 0.7)
	}
	devs
}
stub_opt = function(converged_fn, n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
	devs = list()
	for (cl in families$class) for (n in n_grid) {
		if (!is.null(on_cell_done)) on_cell_done(0.01)
		if (cl == "InferenceCountPoisson") devs[[length(devs) + 1L]] = list(class = cl, response_type = "count", n = n, from = "irls", to = "lbfgs", rel_improvement = 0.1, median_baseline = 1, median_candidate = 0.9)
	}
	devs
}
stub_par = function(operation, num_cores, n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
	devs = list()
	for (cl in families$class) {
		# crossover at the first n; fire NA for the skipped rest, as the real tuner does
		if (!is.null(on_cell_done)) { on_cell_done(0.05); for (k in seq_len(length(n_grid) - 1L)) on_cell_done(NA_real_) }
		devs[[length(devs) + 1L]] = list(class = cl, response_type = "count", operation = operation, num_cores = num_cores, crossover_n = min(n_grid), rel_improvement = 0.4 + 0.01 * num_cores)
	}
	devs
}

test_that("edi_tuning_merge_override_vector() prepends new entries and keeps the rest, in order", {
	cur = c("^A$" = FALSE, "^B$" = FALSE, "^C$" = TRUE)
	new = c("^B$" = TRUE, "^Z$" = FALSE)
	out = edi_tuning_merge_override_vector(cur, new)
	expect_equal(names(out), c("^B$", "^Z$", "^A$", "^C$"))
	expect_true(out[["^B$"]])
	expect_equal(edi_tuning_merge_override_vector(NULL, new), new)
	expect_equal(edi_tuning_merge_override_vector(cur, NULL), cur)
})

test_that("per-class override: a flip is stored only if it won at every tested n with one consistent value", {
	n_grid = c(50L, 200L)
	all_n = list(
		list(class = "X", n = 50L, to = TRUE), list(class = "X", n = 200L, to = TRUE),
		list(class = "Y", n = 50L, to = TRUE)
	)
	out = edi_tuning_per_class_override_from_deviations(all_n, n_grid)
	expect_equal(out, c("^X$" = TRUE))
	disagree = list(list(class = "X", n = 50L, to = TRUE), list(class = "X", n = 200L, to = FALSE))
	expect_null(edi_tuning_per_class_override_from_deviations(disagree, n_grid))
	expect_null(edi_tuning_per_class_override_from_deviations(list(), n_grid))
	chr = list(list(class = "X", n = 50L, to = "lbfgs"), list(class = "X", n = 200L, to = "lbfgs"))
	expect_equal(edi_tuning_per_class_override_from_deviations(chr, n_grid), c("^X$" = "lbfgs"))
})

test_that("warm-start diff: one n-conditioned rule per deviation over [n_k, n_{k+1})", {
	n_grid = c(50L, 200L, 1000L)
	devs = list(jackknife = list(list(class = "X", n = 200L, to = FALSE), list(class = "Y", n = 1000L, to = FALSE)), rand = list())
	out = edi_tuning_warm_start_diff_from_deviations(devs, n_grid)
	expect_setequal(names(out), "jackknife")
	rules = out$jackknife$n_conditioned_overrides
	expect_length(rules, 2L)
	expect_equal(rules[[1]], list(pattern = "^X$", value = FALSE, n_min = 200L, n_max = 1000L))
	expect_equal(rules[[2]], list(pattern = "^Y$", value = FALSE, n_min = 1000L, n_max = Inf))
	expect_null(edi_tuning_warm_start_diff_from_deviations(list(), n_grid))
})

test_that("parallel diff: records crossovers and picks the best core count (ties -> smaller)", {
	devs = list(
		list(class = "X", response_type = "count", operation = "bootstrap", num_cores = 2L, crossover_n = 200L, rel_improvement = 0.3),
		list(class = "X", response_type = "count", operation = "bootstrap", num_cores = 8L, crossover_n = 200L, rel_improvement = 0.5),
		list(class = "Y", response_type = "count", operation = "bootstrap", num_cores = 8L, crossover_n = 1000L, rel_improvement = 0.1)
	)
	out = edi_tuning_parallel_diff_from_deviations(devs)
	expect_length(out$crossover, 3L)
	expect_equal(out$preferred_num_cores, 2L)  # mean(0.3) = 0.3 for 2 cores; mean(0.5, 0.1) = 0.3 for 8 -> tie -> smaller
	expect_null(edi_tuning_parallel_diff_from_deviations(list()))
})

test_that("apply: cold-start and optimizer diffs MERGE into the shipped tables (other overrides survive) and dispatchers reflect them", {
	with_tuning_sandbox({
		n_before_cs = length(get_cold_start_dispatch_policy()$inference_class_overrides)
		n_before_op = length(get_optimization_dispatch_policy()$inference_class_overrides)
		diffs = list(
			cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)),
			optimizer = list(inference_class_overrides = c("^InferenceCountPoisson$" = "lbfgs")),
			warm_start = NULL, parallel = NULL
		)
		applied = edi_tuning_apply_policy_diffs(diffs)
		expect_setequal(applied, c("cold_start", "optimizer"))
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		expect_false(edi_cold_start_dispatch_policy("InferenceIncidLogRegr"))  # another shipped override intact
		expect_equal(edi_optimization_dispatch_policy("InferenceCountPoisson"), "lbfgs")
		expect_equal(edi_optimization_dispatch_policy("InferenceCountNegBin"), "lbfgs")  # shipped entry intact
		cur_cs = set_cold_start_dispatch_policy()$inference_class_overrides
		cur_op = set_optimization_dispatch_policy()$inference_class_overrides
		expect_equal(length(cur_cs), n_before_cs)  # shipped cold-start pattern is "^InferenceCountPoisson$" -> replaced in place
		# The shipped optimizer pattern is spelled "InferenceCountPoisson$" (no leading "^"), so the
		# diff's "^InferenceCountPoisson$" is a new name: it is PREPENDED (and wins by first-match)
		# rather than replacing in place. Nothing is lost either way -- assert that explicitly.
		expect_equal(length(cur_op), n_before_op + 1L)
		expect_true("InferenceCountPoisson$" %in% names(cur_op))
		expect_equal(names(cur_op)[[1]], "^InferenceCountPoisson$")
	})
})

test_that("apply: warm-start rules are prepended, and an unconditional conflict is re-expressed as a trailing catch-all", {
	with_tuning_sandbox({
		# InferenceCountNegBin is unconditionally FALSE for jackknife in the shipped table.
		expect_false(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 300L))
		diffs = list(cold_start = NULL, optimizer = NULL, parallel = NULL, warm_start = list(
			jackknife = list(n_conditioned_overrides = list(list(pattern = "^InferenceCountNegBin$", value = TRUE, n_min = 200L, n_max = 500L)))
		))
		edi_tuning_apply_policy_diffs(diffs)
		expect_true(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 300L))   # new rule wins in range
		expect_false(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 100L))  # shipped n<1000 rule preserved below the range
		# The shipped NegBin/jackknife rule only covers n < 1000; above it the shipped policy was
		# already the TRUE default -- the apply must leave that untouched too.
		expect_true(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 5000L))
		expect_false(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 999L))  # still preserved up to the shipped bound
		expect_false(edi_warm_start_dispatch_policy("InferenceSurvivalCoxPHRegr", "jackknife", 300L))  # other shipped entries intact
		expect_false("^InferenceCountNegBin$" %in% names(set_warm_start_dispatch_policy()$jackknife$inference_class_overrides))
	})
})

test_that("config read/write/validate/clear round-trip in a sandboxed config dir", {
	with_tuning_sandbox({
		expect_null(edi_tuning_read_config())
		obj = list(schema_version = EDI_TUNING_SCHEMA_VERSION, policy_diffs = list(cold_start = NULL), effort = "quick")
		path = edi_tuning_write_config(obj)
		expect_true(file.exists(path))
		back = edi_tuning_read_config()
		expect_equal(back$effort, "quick")
		expect_true(edi_tuning_validate_config(back))
		expect_false(edi_tuning_validate_config(list(schema_version = 999L, policy_diffs = list())))
		expect_false(edi_tuning_validate_config(list(schema_version = EDI_TUNING_SCHEMA_VERSION)))
		expect_true(clear_local_EDI_optimization())
		expect_false(file.exists(path))
		expect_false(clear_local_EDI_optimization())
	})
})

test_that("get_local_EDI_optimization() messages and returns NULL when nothing is saved", {
	with_tuning_sandbox({
		expect_message(res <- get_local_EDI_optimization(), "No saved local EDI tuning")
		expect_null(res)
	})
})

test_that("tune_EDI_for_this_machine() validates axes/converged_fn/parallel availability", {
	with_tuning_sandbox({
		expect_error(tune_EDI_for_this_machine(axes = "optimizer", quiet = TRUE), "converged_fn")
		expect_error(tune_EDI_for_this_machine(axes = "not_an_axis", quiet = TRUE))
		with_stub("edi_tuning_parallel_axis_available", function() FALSE,
			expect_error(tune_EDI_for_this_machine(axes = "parallel", quiet = TRUE), "Unix"))
	})
})

always_agree = function(dev, tol) list(agree = TRUE, value_from = 0, value_to = 0)

test_that("tune_EDI_for_this_machine(dry_run = TRUE) benchmarks, writes nothing, applies nothing, returns the would-be diffs", {
	# This test is about diff-building/dry-run plumbing, not TODO-8's correctness gate
	# (that has its own dedicated tests) -- stub the gate's verify functions so the
	# fabricated stub_cold/stub_warm deviations (arbitrary n, not a real timing race)
	# aren't discarded by a real re-fit finding e.g. an NA jackknife estimate at n=50.
	with_tuning_sandbox(with_stub("edi_tuning_verify_cold_start_deviation", always_agree,
		with_stub("edi_tuning_verify_warm_start_deviation", function(dev, operation, tol) list(agree = TRUE, value_from = 0, value_to = 0),
		with_stub("edi_tuning_tune_cold_start", stub_cold, with_stub("edi_tuning_tune_warm_start", stub_warm, {
		res = tune_EDI_for_this_machine(effort = "quick", axes = c("cold_start", "warm_start"),
			families = c("InferenceCountPoisson", "InferenceCountNegBin"), n_grid = c(50L, 500L), reps = 2L,
			quiet = TRUE, dry_run = TRUE)
		expect_s3_class(res, "EDILocalMachineTuning")
		expect_true(res$dry_run)
		expect_false(file.exists(edi_tuning_config_path()))
		expect_equal(res$policy_diffs$cold_start$inference_class_overrides, c("^InferenceCountPoisson$" = TRUE))
		expect_length(res$policy_diffs$warm_start$jackknife$n_conditioned_overrides, 1L)
		# nothing applied in-session
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		expect_true(edi_warm_start_dispatch_policy("InferenceCountNegBin", "jackknife", 50L) == FALSE)  # shipped: unconditional FALSE anyway
		# cold: 2 families x 2 n. warm: per operation, only the families that actually implement that
		# operation's method (edi_tuning_warm_start_families()), then effort="quick"'s narrowing -- so
		# compute the expectation from the same scoping rules rather than assuming 5 ops x 2 families.
		warm_cells = sum(vapply(names(EDI_TUNING_WARM_START_OPERATION_CALLS), function(op) {
			f = edi_tuning_warm_start_families(op)
			f = f[f$class %in% c("InferenceCountPoisson", "InferenceCountNegBin"), , drop = FALSE]
			nrow(edi_tuning_quick_warm_start_families(f))
		}, integer(1))) * 2L
		# cold: only the requested classes that the cold-start table actually governs
		# (InferenceCountNegBin is NOT in get_cold_start_dispatch_policy(), so just Poisson -> 1 x 2 n).
		cold_f = edi_tuning_cold_start_families()
		cold_cells = nrow(cold_f[cold_f$class %in% c("InferenceCountPoisson", "InferenceCountNegBin"), , drop = FALSE]) * 2L
		expect_equal(cold_cells, 2L)
		expect_equal(res$n_cells, cold_cells + warm_cells)
		expect_lt(res$n_cells, 2L * 2L + 5L * 2L * 2L)  # i.e. the naive "every class x every op" count over-counts
	})))))
})

test_that("tune_EDI_for_this_machine() writes the file, applies diffs in-session, and get/clear round-trip it", {
	with_tuning_sandbox(with_stub("edi_tuning_tune_cold_start", stub_cold, with_stub("edi_tuning_tune_optimizer_algorithm", stub_opt, {
		res = tune_EDI_for_this_machine(effort = "quick", axes = c("cold_start", "optimizer"),
			families = "InferenceCountPoisson", n_grid = c(50L, 500L), reps = 2L,
			converged_fn = function(inf) TRUE, quiet = TRUE)
		expect_true(file.exists(edi_tuning_config_path()))
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		expect_equal(edi_optimization_dispatch_policy("InferenceCountPoisson"), "lbfgs")
		expect_false(edi_cold_start_dispatch_policy("InferenceIncidLogRegr"))  # merge, not replace
		saved = NULL
		expect_output(saved <- get_local_EDI_optimization(), "Deviations from shipped defaults")
		expect_s3_class(saved, "EDILocalMachineTuning")
		expect_equal(saved$policy_diffs$cold_start, res$policy_diffs$cold_start)
		expect_equal(saved$schema_version, EDI_TUNING_SCHEMA_VERSION)
		expect_true(clear_local_EDI_optimization())
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))  # reset to shipped
	})))
})

test_that("tune_EDI_for_this_machine() shows the InferenceSuite-style progress bar with 'Cells' and a completion line", {
	with_tuning_sandbox(with_stub("edi_tuning_tune_cold_start", stub_cold, {
		out = capture.output(tune_EDI_for_this_machine(effort = "quick", axes = "cold_start",
			families = "InferenceCountPoisson", n_grid = 50L, reps = 1L, dry_run = TRUE))
		txt = paste(out, collapse = "\n")
		expect_true(grepl("Cells 0/1", txt, fixed = TRUE))
		expect_true(grepl("Cells 1/1", txt, fixed = TRUE))
		expect_true(grepl("Status: Completed in", txt, fixed = TRUE))
		expect_true(grepl("benchmark cells", txt, fixed = TRUE))
	}))
})

test_that("parallel axis: cell accounting reconciles with NA-skipped cells and preferred core count is recorded, never applied", {
	with_tuning_sandbox(with_stub("edi_tuning_parallel_axis_available", function() TRUE, with_stub("edi_tuning_tune_parallel_crossover", stub_par, {
		cores_before = get_num_cores()
		res = tune_EDI_for_this_machine(effort = "quick", axes = "parallel", families = "InferenceCountNegBin",
			n_grid = c(200L, 1000L, 5000L), reps = 1L, num_cores_grid = c(2L, 4L), quiet = TRUE, dry_run = TRUE)
		# quick -> bootstrap only; 1 family x 3 n x 2 core counts = 6 worst-case cells
		expect_equal(res$n_cells, 6L)
		expect_equal(res$policy_diffs$parallel$preferred_num_cores, 4L)  # 0.44 > 0.42
		expect_equal(get_num_cores(), cores_before)
	})))
})

# ---- TODO-6: untunable surfaces ----

test_that("edi_tuning_assert_diffs_respect_untunable() passes clean diffs and names both untunable surfaces", {
	expect_setequal(EDI_TUNING_UNTUNABLE_SURFACES, c("bootstrap_ci_type", "parallel_safety_blocklist"))
	clean = list(
		cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)),
		warm_start = list(jackknife = list(n_conditioned_overrides = list(list(pattern = "^X$", value = FALSE, n_min = 1L, n_max = Inf)))),
		optimizer = NULL,
		parallel = list(crossover = list(list(class = "InferenceCountNegBin", response_type = "count", operation = "bootstrap", num_cores = 2L, crossover_n = 200L, rel_improvement = 0.3)), preferred_num_cores = 2L)
	)
	expect_true(edi_tuning_assert_diffs_respect_untunable(clean))
	expect_true(edi_tuning_assert_diffs_respect_untunable(list(cold_start = NULL, warm_start = NULL, optimizer = NULL, parallel = NULL)))
})

test_that("edi_tuning_assert_diffs_respect_untunable() refuses any bootstrap-CI-type (or unknown) surface", {
	expect_error(edi_tuning_assert_diffs_respect_untunable(list(bootstrap = list(default_type = "percentile"))), "untunable/unknown")
	expect_error(edi_tuning_assert_diffs_respect_untunable(list(cold_start = NULL, bootstrap_ci_type = list())), "untunable/unknown")
})

test_that("edi_tuning_assert_diffs_respect_untunable() refuses un-serializing a parallel-safety-blocklisted combination", {
	# Incidence response type is forced serial for both operations in the shipped policy.
	bad_rt = list(cold_start = NULL, warm_start = NULL, optimizer = NULL, parallel = list(
		crossover = list(list(class = "InferenceIncidLogRegr", response_type = "incidence", operation = "bootstrap", num_cores = 2L, crossover_n = 200L, rel_improvement = 0.3)),
		preferred_num_cores = 2L))
	expect_error(edi_tuning_assert_diffs_respect_untunable(bad_rt), "parallel-SAFETY")
	# Non-KK survival is blocklisted for bootstrap specifically via a class pattern.
	bad_cls = list(cold_start = NULL, warm_start = NULL, optimizer = NULL, parallel = list(
		crossover = list(list(class = "InferenceSurvivalCoxPHRegr", response_type = "survival", operation = "bootstrap", num_cores = 2L, crossover_n = 200L, rel_improvement = 0.3)),
		preferred_num_cores = 2L))
	expect_error(edi_tuning_assert_diffs_respect_untunable(bad_cls), "parallel-SAFETY")
	# ...but that same class is NOT blocklisted for rand_ci, so it passes there.
	ok_cls = bad_cls; ok_cls$parallel$crossover[[1]]$operation = "rand_ci"
	expect_true(edi_tuning_assert_diffs_respect_untunable(ok_cls))
	expect_error(edi_tuning_assert_diffs_respect_untunable(list(parallel = list(crossover = list(list(class = "X", response_type = "count", operation = "nope"))))), "unknown operation")
})

test_that("tune_EDI_for_this_machine() refuses to write or apply if a (stubbed) tuner proposes un-serializing a blocklisted class", {
	rogue_par = function(operation, num_cores, n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
		for (cl in families$class) for (n in n_grid) if (!is.null(on_cell_done)) on_cell_done(0.01)
		list(list(class = "InferenceIncidLogRegr", response_type = "incidence", operation = operation, num_cores = num_cores, crossover_n = min(n_grid), rel_improvement = 0.9))
	}
	with_tuning_sandbox(with_stub("edi_tuning_parallel_axis_available", function() TRUE, with_stub("edi_tuning_tune_parallel_crossover", rogue_par, {
		expect_error(
			tune_EDI_for_this_machine(effort = "quick", axes = "parallel", families = "InferenceCountNegBin",
				n_grid = 200L, reps = 1L, num_cores_grid = 2L, quiet = TRUE),
			"parallel-SAFETY")
		expect_false(file.exists(edi_tuning_config_path()))  # nothing written
	})))
})

# ---- TODO-9: .onLoad() import path ----

valid_saved_config = function(diffs, fingerprint = edi_tuning_hardware_fingerprint()) {
	list(schema_version = EDI_TUNING_SCHEMA_VERSION, edi_version = "test", timestamp = Sys.time(),
	     effort = "quick", hardware_fingerprint = fingerprint, policy_diffs = diffs)
}

test_that("import: no file -> 'none', silent, shipped defaults untouched", {
	with_tuning_sandbox({
		expect_silent(status <- edi_tuning_import_saved_policies(quiet = FALSE))
		expect_equal(status, "none")
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: EDI_SKIP_LOCAL_TUNING disables the import even when a valid file exists", {
	with_tuning_sandbox({
		edi_tuning_write_config(valid_saved_config(list(cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)))))
		withr::with_envvar(c(EDI_SKIP_LOCAL_TUNING = "1"), {
			expect_equal(edi_tuning_import_saved_policies(quiet = FALSE), "skipped")
		})
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		withr::with_envvar(c(EDI_SKIP_LOCAL_TUNING = "0"), {
			expect_equal(edi_tuning_import_saved_policies(quiet = TRUE), "applied")
		})
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: a valid file on matching hardware is applied silently and merge-aware", {
	with_tuning_sandbox({
		edi_tuning_write_config(valid_saved_config(list(
			cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)),
			optimizer = list(inference_class_overrides = c("^InferenceCountPoisson$" = "lbfgs"))
		)))
		expect_silent(status <- edi_tuning_import_saved_policies(quiet = FALSE))
		expect_equal(status, "applied")
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		expect_equal(edi_optimization_dispatch_policy("InferenceCountPoisson"), "lbfgs")
		expect_false(edi_cold_start_dispatch_policy("InferenceIncidLogRegr"))  # other shipped overrides survive
	})
})

test_that("import: hardware mismatch still applies but emits the 'appears to differ' startup message", {
	with_tuning_sandbox({
		fp = edi_tuning_hardware_fingerprint()
		fp$logical_cores = (fp$logical_cores %||% 1L) + 97L
		fp$cpu_model = "Totally Different CPU 9000"
		edi_tuning_write_config(valid_saved_config(list(cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE))), fingerprint = fp))
		expect_message(status <- edi_tuning_import_saved_policies(quiet = FALSE), "appears to differ")
		expect_equal(status, "applied_hardware_changed")
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: incompatible schema -> 'invalid', one message, shipped defaults stand", {
	with_tuning_sandbox({
		bad = valid_saved_config(list(cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE))))
		bad$schema_version = 999L
		edi_tuning_write_config(bad)
		expect_message(status <- edi_tuning_import_saved_policies(quiet = FALSE), "incompatible schema")
		expect_equal(status, "invalid")
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: an unreadable file -> 'invalid', one message, shipped defaults stand", {
	with_tuning_sandbox({
		dir.create(edi_tuning_config_dir(), recursive = TRUE, showWarnings = FALSE)
		writeLines("this is not an rds file", edi_tuning_config_path())
		expect_message(status <- edi_tuning_import_saved_policies(quiet = FALSE), "could not be read")
		expect_equal(status, "invalid")
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: a diff that fails to apply -> 'error', one message, and NO partial state (everything reset)", {
	with_tuning_sandbox({
		# cold_start is valid and would apply first; warm_start is malformed (not a list per op)
		# so the apply errors part-way -- the import must roll everything back to shipped defaults.
		edi_tuning_write_config(valid_saved_config(list(
			cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)),
			warm_start = list(jackknife = "not a list")
		)))
		expect_message(status <- edi_tuning_import_saved_policies(quiet = FALSE), "could not be applied")
		expect_equal(status, "error")
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))  # rolled back, not left half-applied
		expect_identical(set_warm_start_dispatch_policy(), get_warm_start_dispatch_policy())
	})
})

test_that("import: a file proposing an untunable (blocklisted) parallel change is refused and rolled back", {
	with_tuning_sandbox({
		edi_tuning_write_config(valid_saved_config(list(
			cold_start = list(inference_class_overrides = c("^InferenceCountPoisson$" = TRUE)),
			parallel = list(crossover = list(list(class = "InferenceIncidLogRegr", response_type = "incidence", operation = "bootstrap", num_cores = 2L, crossover_n = 200L, rel_improvement = 0.5)), preferred_num_cores = 2L)
		)))
		expect_message(status <- edi_tuning_import_saved_policies(quiet = FALSE), "parallel-SAFETY")
		expect_equal(status, "error")
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})

test_that("import: the parallel diff never changes the active core count (recorded-only)", {
	with_tuning_sandbox({
		cores_before = get_num_cores()
		edi_tuning_write_config(valid_saved_config(list(
			parallel = list(crossover = list(list(class = "InferenceCountNegBin", response_type = "count", operation = "bootstrap", num_cores = 8L, crossover_n = 200L, rel_improvement = 0.5)), preferred_num_cores = 8L)
		)))
		expect_equal(edi_tuning_import_saved_policies(quiet = TRUE), "applied")
		expect_equal(get_num_cores(), cores_before)
	})
})

# ---- TODO-7: contention guard ----

test_that("edi_tuning_machine_load() is numeric-or-NA and edi_tuning_machine_looks_busy() has the documented shape", {
	l = edi_tuning_machine_load()
	expect_true(is.numeric(l) && length(l) == 1L)
	b = edi_tuning_machine_looks_busy(calib_reps = 3L)
	expect_setequal(names(b), c("busy", "load_1min", "cores", "load_ratio", "calib_cv", "reasons"))
	expect_true(is.logical(b$busy) && length(b$busy) == 1L)
	expect_true(is.character(b$reasons))
	expect_equal(b$busy, length(b$reasons) > 0L)
	# Thresholds of Inf can never trip; thresholds of -1 always trip (when the signal is finite).
	expect_false(edi_tuning_machine_looks_busy(load_ratio_threshold = Inf, calib_cv_threshold = Inf, calib_reps = 3L)$busy)
	trip = edi_tuning_machine_looks_busy(load_ratio_threshold = -1, calib_cv_threshold = -1, calib_reps = 3L)
	expect_true(trip$busy || (!is.finite(trip$load_ratio) && !is.finite(trip$calib_cv)))
})

test_that("tune_EDI_for_this_machine() refuses a busy machine non-interactively unless force = TRUE (and the gate applies to dry_run)", {
	busy_now = function(...) list(busy = TRUE, load_1min = 99, cores = 2L, load_ratio = 49.5, calib_cv = 0.1, reasons = "1-minute load average 99.00 on 2 cores (ratio 49.50 > 0.50)")
	idle_now = function(...) list(busy = FALSE, load_1min = 0.1, cores = 2L, load_ratio = 0.05, calib_cv = 0.1, reasons = character(0))
	with_tuning_sandbox(with_stub("edi_tuning_tune_cold_start", stub_cold, {
		with_stub("edi_tuning_machine_looks_busy", busy_now, {
			expect_error(tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
				n_grid = 50L, reps = 1L, quiet = TRUE, dry_run = TRUE), "looks busy")
			expect_false(file.exists(edi_tuning_config_path()))
			# force = TRUE overrides and the run completes normally
			res = tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
				n_grid = 50L, reps = 1L, quiet = TRUE, dry_run = TRUE, force = TRUE)
			expect_s3_class(res, "EDILocalMachineTuning")
		})
		with_stub("edi_tuning_machine_looks_busy", idle_now, {
			res = tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
				n_grid = 50L, reps = 1L, quiet = TRUE, dry_run = TRUE)
			expect_s3_class(res, "EDILocalMachineTuning")
		})
	}))
	expect_error(tune_EDI_for_this_machine(force = "yes"))
})

# ---- Progress bar `label` argument: default output is byte-identical to the pre-argument bar ----

test_that("run_all_inference_progress_bar_line() default label reproduces the original 'Classes i/N' bar exactly, and 'Cells' swaps only the noun", {
	withr::with_options(list(width = 100L), {
		default_line = run_all_inference_progress_bar_line(3L, 10L, c(1, 2, 3))
		explicit_line = run_all_inference_progress_bar_line(3L, 10L, c(1, 2, 3), label = "Classes")
		expect_identical(default_line, explicit_line)
		expect_true(startsWith(default_line, "Classes 3/10"))
		# Pin the ORIGINAL geometry: at n_total = 10 the label column is exactly 14 wide
		# (max(14, nchar("Classes 10/10")) = 14), so "[" sits at position 15. A version that
		# measured the width from the already-rendered "Classes 3/10 10/10" string put "[" at 19.
		expect_identical(substr(default_line, 15L, 15L), "[")
		expect_identical(substr(run_all_inference_progress_bar_line(3L, 10L, c(1, 2, 3), label = "Cells"), 15L, 15L), "[")
		expect_true(grepl("Estimated Time Left: ", default_line, fixed = TRUE))
		cells_line = run_all_inference_progress_bar_line(3L, 10L, c(1, 2, 3), label = "Cells")
		expect_true(startsWith(cells_line, "Cells 3/10"))
		# Same bar/ETA tail for both nouns (everything from the "[" on is label-independent here,
		# since both labels pad to the same 14-char label width at n_total = 10).
		expect_identical(sub("^[^\\[]*", "", cells_line), sub("^[^\\[]*", "", default_line))
		# zero-done and all-done frames keep their original status strings
		expect_true(grepl("Status: Estimating...", run_all_inference_progress_bar_line(0L, 10L, numeric(10)), fixed = TRUE))
		expect_true(grepl("Estimated Time Left: 0s", run_all_inference_progress_bar_line(10L, 10L, rep(1, 10)), fixed = TRUE))
	})
})

test_that("edi_tuning_count_cells() arithmetic matches the plan shape", {
	fam2 = data.frame(class = c("A", "B"), response_type = "count", stringsAsFactors = FALSE)
	plan = list(
		cold_start = list(families = fam2, n_grid = c(1L, 2L, 3L)),
		optimizer = list(families = fam2[1, , drop = FALSE], n_grid = c(1L, 2L)),
		warm_start = list(families_by_operation = list(jackknife = fam2, rand = fam2[1, , drop = FALSE]), n_grid = c(1L, 2L)),
		parallel = list(families_by_operation = list(bootstrap = fam2), n_grid = c(1L, 2L), num_cores_grid = c(2L, 8L))
	)
	expect_equal(edi_tuning_count_cells(plan), 6L + 2L + (4L + 2L) + 8L)
	expect_equal(edi_tuning_count_cells(list()), 0L)
})

# ---- TODO-10: remaining test items not already covered above ----
# (a) round-trip, (b) corrupt/stale-schema, (c) fingerprint-mismatch, (e) TODO-6
# assertion, and (f) dry_run are already exercised by the TODO-5/6/7/9 tests above;
# this section closes the two still-open items: (d) unknown class patterns are
# inert, and one explicit tune -> write -> simulate-fresh-load -> applied flow
# tying the mocked benchmark and the .onLoad() import together end to end.

test_that("(a) round-trip: tune (mocked benchmark) -> write -> simulate a fresh session -> import -> applied", {
	with_tuning_sandbox(with_stub("edi_tuning_verify_cold_start_deviation", always_agree,
		with_stub("edi_tuning_tune_cold_start", stub_cold, {
			# Step 1: a real user's call, with the benchmark itself mocked (per TODO-10(a): "so CI
			# takes seconds, not minutes") -- everything else (diff-building, the untunable gate,
			# the correctness gate, persistence) is the real code path.
			res = tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
				n_grid = 50L, reps = 1L, quiet = TRUE)
			expect_true(file.exists(edi_tuning_config_path()))
			expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))  # applied in THIS session

			# Step 2: simulate a fresh R session finding the file on disk -- reset every policy to
			# shipped defaults first, exactly as a brand-new session would start.
			set_cold_start_dispatch_policy(reset = TRUE)
			set_warm_start_dispatch_policy(reset = TRUE)
			set_optimization_dispatch_policy(reset = TRUE)
			expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))  # confirms the reset took

			# Step 3: the .onLoad() import path picks the saved file back up.
			status = edi_tuning_import_saved_policies(quiet = TRUE)
			expect_equal(status, "applied")
			expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
			expect_false(edi_cold_start_dispatch_policy("InferenceIncidLogRegr"))  # other shipped overrides untouched
		})
	))
})

test_that("(d) a saved diff naming a class pattern that no longer matches anything is inert -- applies cleanly, changes nothing it doesn't name, and every live class is unaffected", {
	with_tuning_sandbox({
		obj = valid_saved_config(list(
			cold_start = list(inference_class_overrides = c(
				"^InferenceCountPoisson$" = TRUE,
				"^InferenceTotallyMadeUpClassThatWasRenamedOrRemovedXYZ$" = TRUE
			))
		))
		edi_tuning_write_config(obj)
		status = edi_tuning_import_saved_policies(quiet = TRUE)
		expect_equal(status, "applied")
		# the real, still-live entry took effect...
		expect_true(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		# ...the phantom pattern matches no live class, so it's simply never consulted (inert, not an error)...
		families = edi_tuning_live_families()
		expect_false(any(grepl("^InferenceTotallyMadeUpClassThatWasRenamedOrRemovedXYZ$", families$class, perl = TRUE)))
		# ...and every OTHER shipped cold-start override is untouched.
		expect_false(edi_cold_start_dispatch_policy("InferenceIncidLogRegr"))
		expect_false(edi_cold_start_dispatch_policy("InferencePropFractionalLogit"))
	})
})

test_that("real (non-mocked) tune_EDI_for_this_machine() end-to-end run -- skip-on-CRAN, real benchmarking", {
	skip_on_cran()
	with_tuning_sandbox({
		res = tune_EDI_for_this_machine(effort = "quick", axes = "cold_start",
			families = "InferenceCountPoisson", n_grid = 15L, reps = 2L, quiet = TRUE)
		expect_s3_class(res, "EDILocalMachineTuning")
		expect_false(res$dry_run)
		expect_true(file.exists(edi_tuning_config_path()))
		# whatever it decided, the saved file round-trips through get_local_EDI_optimization()
		# and clear_local_EDI_optimization() actually resets the live policy.
		expect_output(saved <- get_local_EDI_optimization(), "EDI local machine tuning")
		expect_equal(saved$schema_version, EDI_TUNING_SCHEMA_VERSION)
		expect_true(clear_local_EDI_optimization())
		expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
	})
})
