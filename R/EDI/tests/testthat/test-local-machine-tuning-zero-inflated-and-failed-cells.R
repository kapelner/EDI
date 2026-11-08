# tune_EDI_for_this_machine(effort = "standard") aborted after 57 of 1065 cells:
# the shared synthetic count recipe has no zeros (its smallest mean rounds to 1),
# and since 2026-11-04 a zero-inflated class's constructor stop()s on zero-free
# data. Two fixes are pinned here: (1) zero-augmented count classes get a
# synthetic response with structural zeros; (2) any cell that errors is skipped
# and recorded instead of aborting the whole run.

ns = asNamespace("EDI")
zinb = "InferenceCountZeroInflatedNegBin"

test_that("zero-augmented count classes are recognised; others are not", {
	f = get("edi_tuning_class_needs_zero_counts", envir = ns)
	for (cl in c(zinb, "InferenceCountZeroInflatedPoisson", "InferenceCountHurdlePoisson", "InferenceCountHurdleNegBin")) {
		expect_true(f(cl), info = cl)
	}
	for (cl in list("InferenceCountPoisson", "InferenceCountNegBin", "InferenceIncidLogRegr", "NoSuchClass", NULL)) {
		expect_false(f(cl))
	}
})

test_that("the tuner's synthetic count data has zeros for ZI classes and is unchanged otherwise", {
	synth = get("edi_tuning_synthetic_experiment", envir = ns)
	golden = get("inference_migration_complete_design", envir = ns)
	plain = synth("count", n = 50L, seed = 7L)
	expect_identical(plain$get_y(), golden("count", n = 50L, seed = 7L)$get_y())   # recipe untouched
	expect_false(any(plain$get_y() == 0))                                       # the root cause
	zi = synth("count", n = 50L, seed = 7L, class = zinb)
	expect_true(any(zi$get_y() == 0))
	expect_identical(zi$get_w(), plain$get_w())                                 # assignment unchanged
	expect_identical(zi$get_y(), synth("count", n = 50L, seed = 7L, class = zinb)$get_y())  # deterministic
	# Non-count response types ignore `class`.
	expect_identical(synth("continuous", n = 20L, seed = 3L, class = zinb)$get_y(),
	                 synth("continuous", n = 20L, seed = 3L)$get_y())
})

test_that("a ZINB warm-start benchmark cell no longer aborts on the identification stop()", {
	fams = data.frame(class = zinb, response_type = "count", stringsAsFactors = FALSE)
	res = suppressWarnings(get("edi_tuning_tune_warm_start", envir = ns)(
		operation = "bayesian_boot", n_grid = 30L, reps = 1L, families = fams))
	expect_type(res, "list")
	expect_null(attr(res, "failed_cells"))                                       # the cell ran cleanly
})

test_that("binary engine: an erroring cell is recorded and skipped, the run continues", {
	fams = data.frame(class = c("Bad", "Good"), response_type = "count", stringsAsFactors = FALSE)
	secs = numeric(0)
	res = get("edi_tuning_tune_binary_axis", envir = ns)(fams, c(10L, 20L), reps = 2L,
		get_current_setting = function(cl, n) FALSE,
		run_setting = function(cl, rt, n, setting, seed) {
			if (cl == "Bad") stop("not identified")
			if (setting) Sys.sleep(0) else Sys.sleep(0.02)
		},
		min_rel_improvement = 0, iqr_multiplier = 0,
		on_cell_done = function(s) secs <<- c(secs, s))
	expect_length(secs, 4L)                                                      # every cell still ticks the bar
	failed = attr(res, "failed_cells")
	expect_length(failed, 2L)
	expect_identical(vapply(failed, `[[`, character(1), "class"), c("Bad", "Bad"))
	expect_identical(vapply(failed, `[[`, integer(1), "n"), c(10L, 20L))
	expect_match(failed[[1]]$error, "not identified")
	expect_false("Bad" %in% vapply(res, `[[`, character(1), "class"))            # no deviation from a failed cell
})

test_that("categorical engine: an erroring candidate is recorded and the others still compete", {
	fams = data.frame(class = "A", response_type = "count", stringsAsFactors = FALSE)
	res = get("edi_tuning_tune_categorical_axis", envir = ns)(fams, 10L, reps = 2L,
		candidates = c("slow", "broken", "fast"),
		get_current_setting = function(cl, n) "slow",
		run_setting = function(cl, rt, n, alg, seed) {
			if (alg == "broken") stop("boom")
			Sys.sleep(if (alg == "slow") 0.02 else 0)
			TRUE
		},
		min_rel_improvement = 0, iqr_multiplier = 0)
	expect_length(res, 1L)
	expect_identical(res[[1]]$to, "fast")
	failed = attr(res, "failed_cells")
	expect_length(failed, 1L)
	expect_identical(failed[[1]]$to, "broken")
})

test_that("tune_EDI_for_this_machine survives a failing cell, warns, and keeps it out of the policy", {
	with_tuning_sandbox({
		orig = get("edi_tuning_cold_start_run_setting", envir = ns)
		fam = "InferenceIncidLogRegr"
		with_stub("edi_tuning_cold_start_run_setting", function(class, ...) {
			if (identical(class, fam)) stop("synthetic identification failure")
			orig(class, ...)
		}, {
			expect_warning(
				res <- tune_EDI_for_this_machine(effort = "standard", axes = "cold_start", families = fam,
				                                 n_grid = c(30L, 40L), reps = 1L, quiet = TRUE, dry_run = TRUE, force = TRUE),
				"2 benchmark cells failed"
			)
		})
		expect_s3_class(res, "EDILocalMachineTuning")
		expect_identical(res$n_failed_cells, 2L)
		failed = attr(res, "failed_cells")
		expect_identical(unique(vapply(failed, `[[`, character(1), "axis")), "cold_start")
		expect_identical(unique(vapply(failed, `[[`, character(1), "class")), fam)
		expect_null(res$policy_diffs$cold_start)
		expect_null(attr(attr(res, "raw_deviations")$cold_start$deviations, "failed_cells"))
		expect_match(paste(capture.output(print(res)), collapse = "\n"), "2 benchmark cells failed and were skipped", fixed = TRUE)
	})
})
