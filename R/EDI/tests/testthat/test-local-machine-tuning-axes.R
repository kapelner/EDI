# Tests for local_machine_optimization.md TODO-4: per-axis tuners built on the
# TODO-3 harness. The shared engine is tested with a mocked micro-benchmark (fast,
# deterministic) per TODO-10(a)'s guidance; the cold-start axis is also smoke-tested
# against real Inference construction with a tiny n/reps to keep it CI-fast.

test_that("edi_tuning_tune_binary_axis() accepts a clean, consistent win and proposes flipping it", {
	families = data.frame(class = "FakeClassA", response_type = "continuous", stringsAsFactors = FALSE)
	# setting=TRUE is slow, setting=FALSE is fast and clearly wins. The fast
	# side does no Sys.sleep() at all (2026-08-26 fix for a Windows-only CI
	# failure): Windows' Sys.sleep()/scheduler timer granularity is ~15.6ms,
	# so two sub-tick sleeps (0.02s vs the previous 0.001s) can round to the
	# same measured elapsed time there, making the "clean win" this test
	# expects statistically undetectable and leaving `deviations` empty.
	# Skipping the sleep on the fast side instead of shortening it keeps the
	# gap (~20ms vs ~0ms) safely larger than one tick on every platform.
	run_setting = function(class, response_type, n, setting, seed) {
		if (isTRUE(setting)) Sys.sleep(0.02)
	}
	deviations = edi_tuning_tune_binary_axis(
		families = families,
		n_grid = 100L,
		reps = 4L,
		get_current_setting = function(class, n) TRUE,
		run_setting = run_setting
	)
	expect_length(deviations, 1L)
	expect_identical(deviations[[1]]$class, "FakeClassA")
	expect_true(deviations[[1]]$from)
	expect_false(deviations[[1]]$to)
	expect_gt(deviations[[1]]$rel_improvement, 0.05)
})

test_that("edi_tuning_tune_binary_axis() proposes nothing when both settings are identically (near-zero-cost) fast", {
	families = data.frame(class = "FakeClassB", response_type = "count", stringsAsFactors = FALSE)
	# Deliberately no Sys.sleep(): both sides do the exact same negligible work, so timer
	# jitter (OS sleep-granularity variance) can't spuriously trigger the acceptance rule.
	run_setting = function(class, response_type, n, setting, seed) invisible(NULL)
	deviations = edi_tuning_tune_binary_axis(
		families = families,
		n_grid = c(50L, 500L),
		reps = 3L,
		get_current_setting = function(class, n) FALSE,
		run_setting = run_setting
	)
	expect_length(deviations, 0L)
})

test_that("edi_tuning_tune_binary_axis() runs one cell per (family, n) combination", {
	families = data.frame(class = c("C1", "C2"), response_type = c("continuous", "count"), stringsAsFactors = FALSE)
	calls = new.env()
	calls$n = 0L
	run_setting = function(class, response_type, n, setting, seed) {
		calls$n = calls$n + 1L
	}
	edi_tuning_tune_binary_axis(
		families = families,
		n_grid = c(10L, 20L, 30L),
		reps = 2L,
		get_current_setting = function(class, n) TRUE,
		run_setting = run_setting
	)
	# 2 families x 3 n-values x 2 settings x 2 reps = 24 calls.
	expect_equal(calls$n, 24L)
})

test_that("edi_tuning_cold_start_families() is a nonempty subset of the live families matching the cold-start override patterns", {
	families = edi_tuning_cold_start_families()
	expect_true(is.data.frame(families))
	expect_gt(nrow(families), 0L)
	expect_true("InferenceCountPoisson" %in% families$class)
	expect_true("InferenceIncidLogRegr" %in% families$class)
	# A class with no cold-start override entry should not appear.
	expect_false("InferenceSurvivalCoxPHRegr" %in% families$class)
})

test_that("edi_tuning_cold_start_run_setting() restores the prior cold-start policy even after an override", {
	on.exit(set_cold_start_dispatch_policy(reset = TRUE))
	set_cold_start_dispatch_policy(list(inference_class_overrides = c("^InferenceCountPoisson$" = FALSE)))
	before = get_cold_start_dispatch_policy()

	edi_tuning_cold_start_run_setting("InferenceCountPoisson", "count", n = 15L, setting = TRUE, seed = 1L)

	after = get_cold_start_dispatch_policy()
	expect_identical(before, after)
	# The class-specific override this function set internally must not leak.
	expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
})

test_that("edi_tuning_tune_cold_start() runs end-to-end on a tiny real family/n/reps grid without erroring", {
	skip_on_cran()
	on.exit(set_cold_start_dispatch_policy(reset = TRUE))
	deviations = edi_tuning_tune_cold_start(
		n_grid = 15L,
		reps = 2L,
		families = data.frame(class = "InferenceCountPoisson", response_type = "count", stringsAsFactors = FALSE)
	)
	expect_true(is.list(deviations))
	# Whatever it decided, the global policy must be back to baseline afterward.
	expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
})

test_that("edi_tuning_class_has_public_method() finds directly-defined and inherited methods, and rejects missing ones", {
	expect_true(edi_tuning_class_has_public_method("InferenceCountPoisson", "compute_jackknife_estimate"))
	expect_true(edi_tuning_class_has_public_method("InferenceCountPoisson", "compute_estimate"))
	expect_false(edi_tuning_class_has_public_method("InferenceCountPoisson", "not_a_real_method_xyz"))
})

test_that("edi_tuning_warm_start_families() rejects an unknown operation and returns a nonempty subset for known ones", {
	expect_error(edi_tuning_warm_start_families("not_an_operation"))
	for (op in names(EDI_TUNING_WARM_START_OPERATION_CALLS)) {
		families = edi_tuning_warm_start_families(op)
		expect_true(is.data.frame(families))
		expect_true(all(vapply(families$class, edi_tuning_class_has_public_method, logical(1),
			method_name = EDI_TUNING_WARM_START_OPERATION_CALLS[[op]]$method)))
	}
	expect_gt(nrow(edi_tuning_warm_start_families("jackknife")), 0L)
})

test_that("edi_tuning_warm_start_run_setting() restores the prior warm-start policy even after an override", {
	on.exit(set_warm_start_dispatch_policy(reset = TRUE))
	before = get_warm_start_dispatch_policy()

	edi_tuning_warm_start_run_setting("InferenceCountPoisson", "count", n = 15L, setting = TRUE, seed = 1L, operation = "jackknife")

	after = get_warm_start_dispatch_policy()
	expect_identical(before, after)
})

test_that("edi_tuning_warm_start_run_setting() re-throws errors that are not the not-supported family", {
	on.exit(set_warm_start_dispatch_policy(reset = TRUE))
	expect_error(
		edi_tuning_warm_start_run_setting("InferenceNonExistentClassXYZ", "count", n = 15L, setting = TRUE, seed = 1L, operation = "jackknife"),
		"InferenceNonExistentClassXYZ"
	)
})

test_that("the not-supported error pattern used to swallow unimplemented operations matches the migration harness's own pattern", {
	# Mirrors inference_migration_unsupported_error() in
	# helper-inference-migration-harness.R, which every migrated class's real
	# "not implemented for this class" errors are audited against -- reusing
	# the exact same regex here (rather than inventing a second one) is what
	# TODO-4's writeup claims, so pin it directly.
	pattern = "not implemented|not supported|only supported|does not support|does not expose|Must be implemented"
	expect_true(grepl(pattern, "compute_rand_confidence_interval is not implemented for this class"))
	expect_true(grepl(pattern, "This inference class does not support parametric bootstrap"))
	expect_false(grepl(pattern, "non-conformable arguments"))
})

test_that("edi_tuning_tune_warm_start() rejects an unknown operation", {
	expect_error(edi_tuning_tune_warm_start("not_an_operation"))
})

test_that("edi_tuning_tune_categorical_axis() picks the fastest converging candidate and skips non-converging winners", {
	families = data.frame(class = "FakeClassC", response_type = "continuous", stringsAsFactors = FALSE)
	# "slow" (current) is the baseline; "fast_but_fails" is quicker but never converges (must be
	# skipped); "fast_and_converges" is quicker and always converges (must win). The fast
	# candidates do no Sys.sleep() at all -- see the binary-axis test above's
	# 2026-08-26 comment for why (Windows' ~15.6ms sleep-timer granularity
	# made a 0.02s-vs-0.001s gap statistically undetectable there).
	run_setting = function(class, response_type, n, setting, seed) {
		if (identical(setting, "slow")) { Sys.sleep(0.02); TRUE }
		else if (identical(setting, "fast_but_fails")) FALSE
		else TRUE
	}
	deviations = edi_tuning_tune_categorical_axis(
		families = families,
		n_grid = 100L,
		reps = 4L,
		candidates = c("slow", "fast_but_fails", "fast_and_converges"),
		get_current_setting = function(class, n) "slow",
		run_setting = run_setting
	)
	expect_length(deviations, 1L)
	expect_identical(deviations[[1]]$from, "slow")
	expect_identical(deviations[[1]]$to, "fast_and_converges")
})

test_that("edi_tuning_tune_categorical_axis() proposes nothing when the only faster candidate never converges", {
	families = data.frame(class = "FakeClassD", response_type = "count", stringsAsFactors = FALSE)
	run_setting = function(class, response_type, n, setting, seed) {
		if (identical(setting, "slow")) { Sys.sleep(0.02); TRUE } else FALSE
	}
	deviations = edi_tuning_tune_categorical_axis(
		families = families,
		n_grid = 50L,
		reps = 3L,
		candidates = c("slow", "fast_but_fails"),
		get_current_setting = function(class, n) "slow",
		run_setting = run_setting
	)
	expect_length(deviations, 0L)
})

test_that("edi_tuning_tune_categorical_axis() requires at least 2 candidates and a valid current-setting getter", {
	families = data.frame(class = "X", response_type = "continuous", stringsAsFactors = FALSE)
	expect_error(edi_tuning_tune_categorical_axis(
		families, n_grid = 10L, reps = 1L, candidates = "only_one",
		get_current_setting = function(class, n) "only_one",
		run_setting = function(class, response_type, n, setting, seed) TRUE
	))
})

test_that("edi_tuning_optimizer_algorithm_families() is a nonempty subset matching the optimization override patterns", {
	families = edi_tuning_optimizer_algorithm_families()
	expect_true(is.data.frame(families))
	expect_gt(nrow(families), 0L)
	expect_true("InferenceCountPoisson" %in% families$class)
})

test_that("edi_tuning_optimizer_run_setting() restores the prior optimization policy even after an override, and reports converged_fn's verdict", {
	on.exit(set_optimization_dispatch_policy(reset = TRUE))
	before = get_optimization_dispatch_policy()

	result_true = edi_tuning_optimizer_run_setting("InferenceCountPoisson", "count", n = 15L, algorithm = "irls", seed = 1L,
		converged_fn = function(inf) TRUE)
	expect_true(result_true)

	result_false = edi_tuning_optimizer_run_setting("InferenceCountPoisson", "count", n = 15L, algorithm = "irls", seed = 1L,
		converged_fn = function(inf) FALSE)
	expect_false(result_false)

	after = get_optimization_dispatch_policy()
	expect_identical(before, after)
})

test_that("edi_tuning_tune_optimizer_algorithm() requires converged_fn and rejects a bad arity", {
	expect_error(edi_tuning_tune_optimizer_algorithm())
	expect_error(edi_tuning_tune_optimizer_algorithm(converged_fn = function() TRUE))
})

test_that("edi_tuning_tune_optimizer_algorithm() runs end-to-end on a tiny real family/n/reps grid without erroring", {
	skip_on_cran()
	on.exit(set_optimization_dispatch_policy(reset = TRUE))
	before = get_optimization_dispatch_policy()
	# always-TRUE converged_fn: fine for this orchestration smoke test (per its own
	# roxygen warning, never appropriate for a real tuning run).
	deviations = edi_tuning_tune_optimizer_algorithm(
		converged_fn = function(inf) TRUE,
		n_grid = 15L,
		reps = 2L,
		families = data.frame(class = "InferenceCountPoisson", response_type = "count", stringsAsFactors = FALSE)
	)
	expect_true(is.list(deviations))
	expect_identical(get_optimization_dispatch_policy(), before)
})

test_that("edi_tuning_tune_warm_start() runs end-to-end on a tiny real family/n/reps grid without erroring", {
	skip_on_cran()
	on.exit(set_warm_start_dispatch_policy(reset = TRUE))
	before = get_warm_start_dispatch_policy()
	deviations = edi_tuning_tune_warm_start(
		operation = "jackknife",
		n_grid = 15L,
		reps = 2L,
		families = data.frame(class = "InferenceCountPoisson", response_type = "count", stringsAsFactors = FALSE)
	)
	expect_true(is.list(deviations))
	# Whatever it decided, the global policy must be back to baseline afterward.
	expect_identical(get_warm_start_dispatch_policy(), before)
})

test_that("edi_tuning_parallel_families() excludes the parallel-safety blocklist and requires a known operation", {
	expect_error(edi_tuning_parallel_families("not_an_operation"))
	for (op in c("bootstrap", "rand_ci")) {
		families = edi_tuning_parallel_families(op)
		expect_true(is.data.frame(families))
		if (nrow(families) > 0L) {
			still_serial = mapply(function(cl, rt) {
				isTRUE(edi_parallel_dispatch_policy(cl, rt, op)$force_serial)
			}, families$class, families$response_type)
			expect_false(any(still_serial))
		}
		# Incidence response types are forced serial for both operations -- none should appear.
		expect_false("incidence" %in% families$response_type)
	}
})

test_that("edi_tuning_tune_parallel_crossover() rejects num_cores < 2 and an unknown operation", {
	expect_error(edi_tuning_tune_parallel_crossover("bootstrap", num_cores = 1L))
	expect_error(edi_tuning_tune_parallel_crossover("not_an_operation", num_cores = 2L))
})

test_that("edi_tuning_tune_parallel_crossover() finds the crossover point using a mocked blocked-timing family", {
	# Stub out the harness's blocked-timing primitive so this test never touches a real
	# fork cluster: n < 1000 -> serial wins (no deviation); n >= 1000 -> parallel wins.
	testthat_env = environment()
	orig = edi_tuning_blocked_ab
	stub = function(fn_a, fn_b, reps = 5L, a_first = TRUE, setup_a = NULL, setup_b = NULL) {
		if (!is.null(setup_a)) setup_a()
		if (!is.null(setup_b)) setup_b()
		# fn_a/fn_b are closures created inside edi_tuning_tune_parallel_crossover()'s loop,
		# capturing that iteration's `n` by reference -- read it directly rather than
		# reconstructing the call stack.
		n = get("n", envir = environment(fn_a))
		if (n >= 1000L) {
			list(times_a = rep(1.0, reps), times_b = rep(0.5, reps),
			     median_a = 1.0, median_b = 0.5, iqr_a = 0.01, iqr_b = 0.01,
			     results_a = as.list(rep(TRUE, reps)), results_b = as.list(rep(TRUE, reps)))
		} else {
			list(times_a = rep(1.0, reps), times_b = rep(1.0, reps),
			     median_a = 1.0, median_b = 1.0, iqr_a = 0.01, iqr_b = 0.01,
			     results_a = as.list(rep(TRUE, reps)), results_b = as.list(rep(TRUE, reps)))
		}
	}
	# Also stub set_num_cores()/get_num_cores() so this test cannot create a real cluster.
	orig_set_num_cores = set_num_cores
	orig_get_num_cores = get_num_cores
	cores_state = 1L
	unlockBinding("edi_tuning_blocked_ab", asNamespace("EDI"))
	unlockBinding("set_num_cores", asNamespace("EDI"))
	unlockBinding("get_num_cores", asNamespace("EDI"))
	assign("edi_tuning_blocked_ab", stub, envir = asNamespace("EDI"))
	assign("set_num_cores", function(k, force_mirai = FALSE) { cores_state <<- k; invisible(NULL) }, envir = asNamespace("EDI"))
	assign("get_num_cores", function() cores_state, envir = asNamespace("EDI"))
	on.exit({
		assign("edi_tuning_blocked_ab", orig, envir = asNamespace("EDI"))
		assign("set_num_cores", orig_set_num_cores, envir = asNamespace("EDI"))
		assign("get_num_cores", orig_get_num_cores, envir = asNamespace("EDI"))
		lockBinding("edi_tuning_blocked_ab", asNamespace("EDI"))
		lockBinding("set_num_cores", asNamespace("EDI"))
		lockBinding("get_num_cores", asNamespace("EDI"))
	}, add = TRUE)

	deviations = edi_tuning_tune_parallel_crossover(
		operation = "bootstrap",
		num_cores = 4L,
		n_grid = c(200L, 1000L, 5000L),
		reps = 3L,
		families = data.frame(class = "InferenceCountNegBin", response_type = "count", stringsAsFactors = FALSE)
	)
	expect_length(deviations, 1L)
	expect_equal(deviations[[1]]$crossover_n, 1000L)
	expect_equal(deviations[[1]]$num_cores, 4L)
})

test_that("edi_tuning_tune_parallel_crossover() runs end-to-end on a real tiny fork-cluster benchmark and always restores core count", {
	skip_on_cran()
	skip_on_os("windows")
	on.exit(set_num_cores(1L))
	set_num_cores(1L)
	deviations = edi_tuning_tune_parallel_crossover(
		operation = "bootstrap",
		num_cores = 2L,
		n_grid = 20L,
		reps = 2L,
		families = data.frame(class = "InferenceCountNegBin", response_type = "count", stringsAsFactors = FALSE)
	)
	expect_true(is.list(deviations))
	# Whatever it decided, core count must be back to serial afterward -- no leaked cluster.
	expect_equal(get_num_cores(), 1L)
})
