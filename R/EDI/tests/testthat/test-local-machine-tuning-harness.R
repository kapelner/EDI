# Tests for local_machine_optimization.md TODO-3: the benchmark harness
# primitives (family enumeration, synthetic-data generation, interleaved A/B
# timing, the acceptance rule, effort tiering). No per-axis tuner wiring yet
# (TODO-4) -- these are the generic pieces every axis tuner will share.

test_that("edi_tuning_live_families() enumerates concrete, single-response-type inference classes", {
	families = edi_tuning_live_families()
	expect_true(is.data.frame(families))
	expect_setequal(names(families), c("class", "response_type"))
	expect_gt(nrow(families), 50L)
	expect_false(anyDuplicated(families$class) > 0L)
	expect_true(all(families$response_type %in%
		c("continuous", "incidence", "count", "proportion", "ordinal", "survival")))
	# Abstract/mixin bases (no single response type) must not appear.
	expect_false("InferenceAsympLik" %in% families$class)
	expect_false("InferenceRand" %in% families$class)
	# A representative concrete class from each family should appear.
	expect_true("InferenceCountPoisson" %in% families$class)
	expect_true("InferenceSurvivalCoxPHRegr" %in% families$class)
})

test_that("edi_tuning_synthetic_experiment() builds a complete design for every response type", {
	for (rt in c("continuous", "incidence", "count", "proportion", "ordinal", "survival")) {
		des = edi_tuning_synthetic_experiment(rt, n = 20L, seed = 1L)
		expect_true(inherits(des, "R6"))
	}
})

test_that("edi_tuning_synthetic_experiment() is deterministic under a fixed seed and does not leak RNG state", {
	des1 = edi_tuning_synthetic_experiment("continuous", n = 15L, seed = 42L)
	des2 = edi_tuning_synthetic_experiment("continuous", n = 15L, seed = 42L)
	expect_equal(
		des1$.__enclos_env__$private$w,
		des2$.__enclos_env__$private$w
	)

	old_seed = .Random.seed
	set.seed(999L)
	before = .Random.seed
	invisible(edi_tuning_synthetic_experiment("count", n = 10L, seed = 7L))
	after = .Random.seed
	expect_equal(before, after)
	assign(".Random.seed", old_seed, envir = .GlobalEnv)
})

test_that("edi_tuning_interleaved_ab() times both settings interleaved with correct medians/IQRs", {
	sleep_short = function() Sys.sleep(0.001)
	sleep_long = function() Sys.sleep(0.02)
	res = edi_tuning_interleaved_ab(sleep_short, sleep_long, reps = 4L)
	expect_length(res$times_a, 4L)
	expect_length(res$times_b, 4L)
	expect_equal(res$median_a, stats::median(res$times_a))
	expect_equal(res$median_b, stats::median(res$times_b))
	expect_equal(res$iqr_a, stats::IQR(res$times_a))
	expect_equal(res$iqr_b, stats::IQR(res$times_b))
	expect_lt(res$median_a, res$median_b)
})

test_that("edi_tuning_interleaved_ab() validates its inputs", {
	expect_error(edi_tuning_interleaved_ab(function() NULL, function() NULL, reps = 0L))
	expect_error(edi_tuning_interleaved_ab("not a function", function() NULL, reps = 1L))
})

test_that("edi_tuning_interleaved_ab() captures each call's return value in call order", {
	res = edi_tuning_interleaved_ab(function() "a-result", function() "b-result", reps = 3L)
	expect_equal(res$results_a, list("a-result", "a-result", "a-result"))
	expect_equal(res$results_b, list("b-result", "b-result", "b-result"))
})

test_that("edi_tuning_blocked_ab() runs all of A then all of B (or reversed) as contiguous blocks, not interleaved", {
	order_log = character(0)
	fn_a = function() { order_log <<- c(order_log, "a"); Sys.sleep(0.001) }
	fn_b = function() { order_log <<- c(order_log, "b"); Sys.sleep(0.001) }

	order_log = character(0)
	res1 = edi_tuning_blocked_ab(fn_a, fn_b, reps = 3L, a_first = TRUE)
	expect_equal(order_log, c("a", "a", "a", "b", "b", "b"))
	expect_length(res1$times_a, 3L)
	expect_length(res1$times_b, 3L)

	order_log = character(0)
	res2 = edi_tuning_blocked_ab(fn_a, fn_b, reps = 2L, a_first = FALSE)
	expect_equal(order_log, c("b", "b", "a", "a"))
})

test_that("edi_tuning_blocked_ab() calls each side's setup exactly once, before that side's block", {
	log = character(0)
	res = edi_tuning_blocked_ab(
		fn_a = function() log <<- c(log, "a-call"),
		fn_b = function() log <<- c(log, "b-call"),
		reps = 3L,
		a_first = TRUE,
		setup_a = function() log <<- c(log, "setup-a"),
		setup_b = function() log <<- c(log, "setup-b")
	)
	expect_equal(log, c("setup-a", "a-call", "a-call", "a-call", "setup-b", "b-call", "b-call", "b-call"))
})

test_that("edi_tuning_blocked_ab() reports correct medians/IQRs and validates its inputs", {
	res = edi_tuning_blocked_ab(function() Sys.sleep(0.001), function() Sys.sleep(0.02), reps = 4L)
	expect_equal(res$median_a, stats::median(res$times_a))
	expect_equal(res$median_b, stats::median(res$times_b))
	expect_equal(res$iqr_a, stats::IQR(res$times_a))
	expect_equal(res$iqr_b, stats::IQR(res$times_b))
	expect_lt(res$median_a, res$median_b)
	expect_error(edi_tuning_blocked_ab(function() NULL, function() NULL, reps = 0L))
	expect_error(edi_tuning_blocked_ab(function() NULL, function() NULL, a_first = "not a flag"))
})

test_that("edi_tuning_accept_candidate() accepts a clean win past both the 5% and 2xIQR thresholds", {
	baseline = c(1.00, 1.02, 0.98, 1.01, 0.99)
	candidate = c(0.80, 0.81, 0.79, 0.80, 0.80)
	res = edi_tuning_accept_candidate(baseline, candidate)
	expect_true(res$accept)
	expect_equal(res$median_baseline, 1.00)
	expect_equal(res$median_candidate, 0.80)
	expect_equal(res$rel_improvement, 0.20, tolerance = 1e-8)
})

test_that("edi_tuning_accept_candidate() rejects a win below the 5% relative-improvement floor", {
	baseline = rep(1.00, 5L)
	candidate = rep(0.97, 5L)
	res = edi_tuning_accept_candidate(baseline, candidate)
	expect_false(res$accept)
	expect_equal(res$rel_improvement, 0.03, tolerance = 1e-8)
})

test_that("edi_tuning_accept_candidate() rejects a >=5% median win that doesn't clear 2xIQR noise", {
	baseline = rep(1.00, 5L)
	# 10% median improvement, but candidate's own IQR is wide enough to swallow it.
	candidate = c(0.60, 0.95, 0.90, 1.10, 0.95)
	res = edi_tuning_accept_candidate(baseline, candidate)
	expect_gte(res$rel_improvement, 0.05)
	expect_false(res$accept)
	expect_lte(res$median_baseline - res$median_candidate, res$noise_margin)
})

test_that("edi_tuning_accept_candidate() rejects a tie and a regression", {
	baseline = rep(1.00, 5L)
	expect_false(edi_tuning_accept_candidate(baseline, rep(1.00, 5L))$accept)
	expect_false(edi_tuning_accept_candidate(baseline, rep(1.10, 5L))$accept)
})

test_that("edi_tuning_effort_presets() defines quick/standard/thorough with increasing rigor", {
	presets = edi_tuning_effort_presets()
	expect_setequal(names(presets), c("quick", "standard", "thorough"))
	for (level in names(presets)) {
		p = presets[[level]]
		expect_true(all(c("n_grid", "reps", "families") %in% names(p)))
		expect_true(is.numeric(p$n_grid))
		expect_gte(min(p$n_grid), 1L)
	}
	expect_lt(presets$quick$reps, presets$standard$reps)
	expect_lt(presets$standard$reps, presets$thorough$reps)
	expect_lte(length(presets$quick$n_grid), length(presets$standard$n_grid))
	expect_lte(length(presets$standard$n_grid), length(presets$thorough$n_grid))
	expect_identical(presets$quick$families, "top_effect_size")
	expect_identical(presets$standard$families, "all")
	expect_identical(presets$thorough$families, "all")
})
