# Tests for local_machine_optimization.md TODO-8: the correctness gate.
# The verify_*_deviation() functions do real re-fits (small n, cheap classes);
# edi_tuning_apply_correctness_gate() itself is tested with a mocked verify_fn
# so the accept/discard/warning logic doesn't depend on real model output.

test_that("edi_tuning_values_agree() compares elementwise within tolerance, order-insensitively, and treats length mismatch/empty as unverifiable", {
	expect_true(edi_tuning_values_agree(c(1, 2), c(2, 1)))          # order-insensitive
	expect_true(edi_tuning_values_agree(1.0000001, 1.0000002, tol = 1e-4))
	expect_false(edi_tuning_values_agree(1, 1.1, tol = 1e-6))
	expect_false(edi_tuning_values_agree(numeric(0), numeric(0)))    # empty -> unverifiable
	expect_false(edi_tuning_values_agree(c(1, 2), c(1, 2, 3)))       # length mismatch -> unverifiable
	expect_true(edi_tuning_values_agree(100, 100 * (1 + 1e-8), tol = 1e-6))  # relative tolerance scales with magnitude
})

test_that("edi_tuning_safe_point_estimate() extracts a finite scalar from a real Inference object, and NA on failure", {
	des = edi_tuning_synthetic_experiment("count", n = 30L, seed = 1L)
	inf = InferenceCountPoisson$new(des)
	est = edi_tuning_safe_point_estimate(inf)
	expect_true(is.numeric(est) && length(est) == 1L && is.finite(est))

	broken = list(compute_estimate = function(...) stop("boom"))
	expect_true(is.na(edi_tuning_safe_point_estimate(broken)))
})

test_that("edi_tuning_safe_numeric_values() flattens and filters to finite numerics, or numeric(0) on failure", {
	expect_equal(edi_tuning_safe_numeric_values(list(lower = 1, upper = 2)), c(1, 2))
	expect_equal(edi_tuning_safe_numeric_values(c(a = 1, b = NA, c = Inf, d = 3)), c(1, 3))
	expect_equal(edi_tuning_safe_numeric_values(NULL), numeric(0))
})

test_that("edi_tuning_verify_cold_start_deviation() confirms a real deviation whose from/to are actually identical (sanity: agree=TRUE is reachable)", {
	dev = list(class = "InferenceCountPoisson", response_type = "count", n = 30L, from = FALSE, to = FALSE)
	v = edi_tuning_verify_cold_start_deviation(dev)
	expect_true(v$agree)
	expect_equal(v$value_from, v$value_to)
})

test_that("edi_tuning_verify_optimizer_deviation() confirms a real from==to comparison and reproduces the same seed/data both times", {
	dev = list(class = "InferenceCountPoisson", response_type = "count", n = 40L, from = "irls", to = "irls")
	v = edi_tuning_verify_optimizer_deviation(dev)
	expect_true(v$agree)
})

test_that("edi_tuning_verify_parallel_deviation() compares the point estimate, not the resampling CI, and passes for a real family", {
	dev = list(class = "InferenceCountPoisson", response_type = "count", crossover_n = 40L)
	v = edi_tuning_verify_parallel_deviation(dev)
	expect_true(v$agree)
	expect_true(is.finite(v$value_from) && is.finite(v$value_to))
})

test_that("edi_tuning_verify_warm_start_deviation() resets the RNG identically before each side and confirms a real from==to comparison", {
	dev = list(class = "InferenceCountPoisson", response_type = "count", n = 40L, from = TRUE, to = TRUE)
	v = edi_tuning_verify_warm_start_deviation(dev, operation = "jackknife")
	expect_true(v$agree)
	expect_gt(length(v$value_from), 0L)
})

test_that("edi_tuning_apply_correctness_gate() keeps agreeing deviations and discards+warns on disagreeing/erroring ones", {
	devs = list(
		list(class = "Agree1", n = 10L, from = FALSE, to = TRUE),
		list(class = "Disagree1", n = 20L, from = FALSE, to = TRUE),
		list(class = "Errors1", n = 30L, from = FALSE, to = TRUE)
	)
	verify_fn = function(dev) {
		if (dev$class == "Agree1") return(list(agree = TRUE, value_from = 1, value_to = 1))
		if (dev$class == "Disagree1") return(list(agree = FALSE, value_from = 1, value_to = 2))
		stop("simulated verification failure")
	}
	warnings_seen = character(0)
	result = withCallingHandlers(
		edi_tuning_apply_correctness_gate(devs, verify_fn, "test axis"),
		warning = function(w) { warnings_seen <<- c(warnings_seen, conditionMessage(w)); invokeRestart("muffleWarning") }
	)
	expect_length(warnings_seen, 2L)
	expect_true(any(grepl("Disagree1", warnings_seen)))
	expect_true(any(grepl("Errors1", warnings_seen)))
	expect_length(result$kept, 1L)
	expect_equal(result$kept[[1]]$class, "Agree1")
	expect_length(result$discarded, 2L)
	expect_setequal(vapply(result$discarded, `[[`, character(1), "class"), c("Disagree1", "Errors1"))
	expect_false(isTRUE(result$discarded[[which(vapply(result$discarded, `[[`, character(1), "class") == "Errors1")]]$agree))
})

test_that("edi_tuning_apply_correctness_gate() emits no warnings and keeps everything when all deviations agree", {
	devs = list(list(class = "X", n = 5L))
	expect_no_warning(result <- edi_tuning_apply_correctness_gate(devs, function(dev) list(agree = TRUE, value_from = 1, value_to = 1), "axis"))
	expect_length(result$kept, 1L)
	expect_length(result$discarded, 0L)
})

test_that("tune_EDI_for_this_machine() runs the correctness gate: a stubbed disagreeing deviation is discarded, warned about, and excluded from the file", {
	stub_cold_disagree = function(n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
		for (cl in families$class) for (n in n_grid) if (!is.null(on_cell_done)) on_cell_done(0.01)
		list(list(class = "InferenceCountPoisson", response_type = "count", n = n_grid[[1]], from = FALSE, to = TRUE, rel_improvement = 0.2, median_baseline = 1, median_candidate = 0.8))
	}
	with_tuning_sandbox(with_stub("edi_tuning_tune_cold_start", stub_cold_disagree,
		with_stub("edi_tuning_verify_cold_start_deviation", function(dev) list(agree = FALSE, value_from = 1, value_to = 999), {
			expect_warning(
				res <- tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
					n_grid = 50L, reps = 1L, quiet = TRUE, dry_run = TRUE),
				"correctness gate"
			)
			expect_null(res$policy_diffs$cold_start)
			expect_equal(res$n_discarded_by_correctness_gate, 1L)
			expect_length(attr(res, "discarded_by_correctness_gate")$cold_start, 1L)
			expect_false(edi_cold_start_dispatch_policy("InferenceCountPoisson"))
		})
	))
})

test_that("tune_EDI_for_this_machine() prints the correctness-gate discard count when nonzero", {
	stub_cold_disagree = function(n_grid, reps, families = NULL, on_cell_done = NULL, ...) {
		for (cl in families$class) for (n in n_grid) if (!is.null(on_cell_done)) on_cell_done(0.01)
		list(list(class = "InferenceCountPoisson", response_type = "count", n = n_grid[[1]], from = FALSE, to = TRUE, rel_improvement = 0.2, median_baseline = 1, median_candidate = 0.8))
	}
	with_tuning_sandbox(with_stub("edi_tuning_tune_cold_start", stub_cold_disagree,
		with_stub("edi_tuning_verify_cold_start_deviation", function(dev) list(agree = FALSE, value_from = 1, value_to = 999), {
			out = suppressWarnings(capture.output(
				tune_EDI_for_this_machine(effort = "quick", axes = "cold_start", families = "InferenceCountPoisson",
					n_grid = 50L, reps = 1L, dry_run = TRUE)
			))
			expect_true(any(grepl("discarded by the correctness gate", out)))
		})
	))
})
