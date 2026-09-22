library(testthat)
library(EDI)

# edi_tuning_tune_categorical_axis(): beyond the basic "fastest converging candidate wins" case -- (a) get_current_setting(class, n) is consulted once per
# (family, n) cell and the current setting is never timed as its own candidate, (b) seed_fn(class, n) is called per cell and its seed reaches run_setting on
# both the baseline and candidate sides, (c) on_cell_done() fires exactly once per cell (not per candidate) with a non-negative elapsed time, (d) when
# several candidates win, the one with the largest relative improvement is proposed, and the deviation record carries the documented fields, (e) cells
# are independent (per-cell current setting differs).

skip_on_os("windows")
tune <- get("edi_tuning_tune_categorical_axis", envir = asNamespace("EDI"))
fams <- data.frame(class = c("FakeA", "FakeB"), response_type = c("continuous", "count"), stringsAsFactors = FALSE)

test_that("cells: current-setting getter called per (class, n); seed_fn per cell; seeds reach both sides; on_cell_done once per cell", {
	get_calls <- list(); seed_calls <- list(); done <- numeric(); seen <- list()
	dev <- tune(
		families = fams, n_grid = c(50L, 200L), reps = 2L, candidates = c("s1", "s2"),
		get_current_setting = function(class, n) { get_calls[[length(get_calls) + 1L]] <<- c(class, n); "s1" },
		run_setting = function(class, response_type, n, setting, seed) { seen[[length(seen) + 1L]] <<- list(class, n, setting, seed); TRUE },
		seed_fn = function(class, n) { seed_calls[[length(seed_calls) + 1L]] <<- c(class, n); 1000L + n },
		on_cell_done = function(secs) done <<- c(done, secs))
	expect_length(get_calls, 4L)                                                     # 2 families x 2 n
	expect_equal(vapply(get_calls, function(x) paste(x, collapse = "/"), ""), c("FakeA/50", "FakeA/200", "FakeB/50", "FakeB/200"))
	expect_length(seed_calls, 4L)
	expect_length(done, 4L); expect_true(all(done >= 0))
	# per cell: baseline "s1" and candidate "s2" each run reps (= 2) times, all with that cell's seed; "s1" is never a candidate
	for (cell in list(list("FakeA", 50L), list("FakeB", 200L))) {
		runs <- Filter(function(r) identical(r[[1]], cell[[1]]) && identical(r[[2]], cell[[2]]), seen)
		expect_length(runs, 4L)
		expect_setequal(vapply(runs, function(r) r[[3]], ""), c("s1", "s2"))
		expect_true(all(vapply(runs, function(r) identical(r[[4]], 1000L + cell[[2]]), NA)))
		expect_equal(sum(vapply(runs, function(r) r[[3]] == "s1", NA)), 2L); expect_equal(sum(vapply(runs, function(r) r[[3]] == "s2", NA)), 2L)
	}
})

test_that("with several winning candidates the largest relative improvement is proposed; record fields are complete; cells are independent", {
	dev <- tune(
		families = fams, n_grid = 100L, reps = 4L, candidates = c("slow", "quick", "instant"),
		get_current_setting = function(class, n) if (class == "FakeA") "slow" else "instant",
		run_setting = function(class, response_type, n, setting, seed) {
			if (identical(setting, "slow")) Sys.sleep(0.03) else if (identical(setting, "quick")) Sys.sleep(0.012)
			TRUE
		})
	# FakeA: current slow, both quick and instant win, instant is better. FakeB: current instant, nothing beats it.
	expect_length(dev, 1L)
	d <- dev[[1]]
	expect_identical(d$class, "FakeA"); expect_identical(d$response_type, "continuous"); expect_identical(d$n, 100L)
	expect_identical(d$from, "slow"); expect_identical(d$to, "instant")
	expect_true(all(c("rel_improvement", "median_baseline", "median_candidate") %in% names(d)))
	expect_gt(d$median_baseline, d$median_candidate); expect_gt(d$rel_improvement, 0.5)
	expect_equal(d$rel_improvement, (d$median_baseline - d$median_candidate) / d$median_baseline, tolerance = 1e-8)
})

test_that("default seed function is edi_tuning_default_seed(class, n) and the argument validation rejects bad inputs", {
	seeds <- list()
	tune(families = fams[1, ], n_grid = 30L, reps = 1L, candidates = c("a", "b"), get_current_setting = function(class, n) "a",
		run_setting = function(class, response_type, n, setting, seed) { seeds[[length(seeds) + 1L]] <<- seed; TRUE })
	expect_true(all(vapply(seeds, function(s) identical(s, get("edi_tuning_default_seed", envir = asNamespace("EDI"))("FakeA", 30L)), NA)))
	expect_error(tune(fams, 30L, 1L, "only_one", function(class, n) "x", function(...) TRUE))
	expect_error(tune(fams, 30L, 1L, c("a", "a"), function(class, n) "a", function(...) TRUE))
	expect_error(tune(fams, 30L, 1L, c("a", "b"), function(class) "a", function(...) TRUE))
	expect_error(tune(fams[, "class", drop = FALSE], 30L, 1L, c("a", "b"), function(class, n) "a", function(...) TRUE))
})
