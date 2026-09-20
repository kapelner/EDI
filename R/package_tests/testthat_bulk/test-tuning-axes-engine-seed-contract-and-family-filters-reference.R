library(testthat)
library(EDI)

# Engine-level contracts of the local-machine tuning axes that the mocked-timing
# tests do not pin: the default seed formula, seed sharing between the baseline
# and candidate runs, on_cell_done firing once per (family, n) cell, how a
# non-TRUE current setting is interpreted, argument validation, the
# warm-start / parallel family filters against independent recomputations, and
# the jackknife exclusion of the zero-one-inflated beta class.

ns <- function(x) get(x, envir = asNamespace("EDI"))

test_that("the default seed is 20260821 + (sum of the class's code points mod 10000) + n", {
	f <- ns("edi_tuning_default_seed")
	expect_equal(f("A", 10L), 20260821L + 65L + 10L)
	expect_equal(f("AB", 0L), 20260821L + 65L + 66L)
	long <- strrep("z", 100)                       # 100 * 122 = 12200 -> mod 10000 = 2200
	expect_equal(f(long, 5L), 20260821L + 2200L + 5L)
	expect_equal(f("InferenceIncidLogRegr", 50L),
		20260821L + (sum(utf8ToInt("InferenceIncidLogRegr")) %% 10000L) + 50L)
	expect_false(f("Ab", 1L) == f("bA", 2L))       # n participates
	expect_equal(f("Ab", 7L), f("bA", 7L))          # permutations of a name collide (sum-based)
})

test_that("baseline and candidate share one seed per cell, and a custom seed_fn overrides the default", {
	fam <- data.frame(class = c("FakeA", "FakeB"), response_type = "continuous", stringsAsFactors = FALSE)
	log <- list()
	run <- function(class, response_type, n, setting, seed) {
		log[[length(log) + 1L]] <<- list(class = class, n = n, setting = setting, seed = seed)
		invisible(NULL)
	}
	tune <- ns("edi_tuning_tune_binary_axis")
	tune(fam, c(10L, 20L), reps = 3L, get_current_setting = function(cl, n) TRUE, run_setting = run)
	def <- ns("edi_tuning_default_seed")
	for (e in log) expect_equal(e$seed, def(e$class, e$n))
	# Both settings are exercised within every cell, equally often.
	for (cl in c("FakeA", "FakeB")) for (n in c(10L, 20L)) {
		cell <- Filter(function(e) e$class == cl && e$n == n, log)
		expect_equal(sum(vapply(cell, function(e) e$setting, logical(1))), length(cell) / 2)
	}
	log <- list()
	tune(fam[1, ], 10L, reps = 2L, get_current_setting = function(cl, n) TRUE, run_setting = run,
		seed_fn = function(class, n) 999L)
	expect_true(all(vapply(log, function(e) e$seed, numeric(1)) == 999L))
})

test_that("on_cell_done fires once per (family, n) cell with a non-negative duration", {
	fam <- data.frame(class = c("FakeA", "FakeB", "FakeC"), response_type = "count", stringsAsFactors = FALSE)
	secs <- numeric(0)
	ns("edi_tuning_tune_binary_axis")(fam, c(5L, 6L), reps = 2L,
		get_current_setting = function(cl, n) FALSE, run_setting = function(...) NULL,
		on_cell_done = function(s) secs <<- c(secs, s))
	expect_length(secs, 6L)
	expect_true(all(secs >= 0))
	# Empty family table: no cells, no callbacks, empty result.
	secs <- numeric(0)
	res <- ns("edi_tuning_tune_binary_axis")(fam[0, ], 5L, reps = 2L,
		get_current_setting = function(cl, n) FALSE, run_setting = function(...) NULL,
		on_cell_done = function(s) secs <<- c(secs, s))
	expect_identical(res, list())
	expect_length(secs, 0L)
})

test_that("a non-TRUE current setting is treated as FALSE, so the candidate is TRUE", {
	fam <- data.frame(class = "FakeA", response_type = "continuous", stringsAsFactors = FALSE)
	# The TRUE side is fast (no sleep), the FALSE side slow: flipping NA/FALSE -> TRUE wins.
	run <- function(class, response_type, n, setting, seed) if (!isTRUE(setting)) Sys.sleep(0.02)
	for (cur in list(NA, FALSE, NULL)) {
		d <- ns("edi_tuning_tune_binary_axis")(fam, 10L, reps = 4L,
			get_current_setting = local({ cur <- cur; function(cl, n) cur }), run_setting = run)
		expect_length(d, 1L)
		expect_false(d[[1]]$from)
		expect_true(d[[1]]$to)
		expect_setequal(names(d[[1]]), c("class", "response_type", "n", "from", "to",
			"rel_improvement", "median_baseline", "median_candidate"))
		expect_equal(d[[1]]$n, 10L)
		expect_gt(d[[1]]$median_baseline, d[[1]]$median_candidate)
	}
})

test_that("the engine validates its arguments", {
	tune <- ns("edi_tuning_tune_binary_axis")
	ok <- data.frame(class = "A", response_type = "count", stringsAsFactors = FALSE)
	gs <- function(cl, n) TRUE
	rs <- function(...) NULL
	expect_error(tune(data.frame(class = "A"), 10L, 2L, gs, rs))                       # missing response_type
	expect_error(tune(ok, integer(0), 2L, gs, rs))                                     # empty grid
	expect_error(tune(ok, 0L, 2L, gs, rs))                                             # n below 1
	expect_error(tune(ok, 10L, 2L, function(cl) TRUE, rs))                             # getter must take 2 args
	expect_error(tune(ok, 10L, 2L, gs, rs, on_cell_done = function() NULL))            # callback must take 1 arg
})

test_that("warm-start families equal an independent has-method-and-not-excluded recomputation", {
	live <- ns("edi_tuning_live_families")()
	calls <- ns("EDI_TUNING_WARM_START_OPERATION_CALLS")
	excl <- ns("EDI_TUNING_WARM_START_OPERATION_EXCLUSIONS")
	has_method <- function(cl, m) {
		g <- get(cl, envir = asNamespace("EDI"))
		while (!is.null(g)) { if (m %in% names(g$public_methods)) return(TRUE); g <- g$get_inherit() }
		FALSE
	}
	for (op in names(calls)) {
		got <- ns("edi_tuning_warm_start_families")(op)
		ref <- live$class[vapply(live$class, has_method, logical(1), m = calls[[op]]$method)]
		ref <- setdiff(ref, excl[[op]])
		expect_setequal(got$class, ref)
		expect_equal(got$response_type, live$response_type[match(got$class, live$class)], info = op)
	}
	jk <- ns("edi_tuning_warm_start_families")("jackknife")
	expect_false("InferencePropZeroOneInflatedBetaRegr" %in% jk$class)
	nb <- ns("edi_tuning_warm_start_families")("non_param_boot")
	if ("InferencePropZeroOneInflatedBetaRegr" %in% live$class)
		expect_true("InferencePropZeroOneInflatedBetaRegr" %in% nb$class)
})

test_that("parallel families are exactly the warm-start families for the mapped operation minus force-serial combinations", {
	map <- ns("EDI_TUNING_PARALLEL_OPERATION_TO_WARM_START_OPERATION")
	expect_equal(unname(map[c("bootstrap", "rand_ci")]), c("non_param_boot", "rand"))
	for (op in names(map)) {
		ws <- ns("edi_tuning_warm_start_families")(map[[op]])
		got <- ns("edi_tuning_parallel_families")(op)
		ser <- vapply(seq_len(nrow(ws)), function(i)
			isTRUE(ns("edi_parallel_dispatch_policy")(ws$class[i], ws$response_type[i], op)$force_serial), logical(1))
		expect_equal(paste(got$class, got$response_type), paste(ws$class[!ser], ws$response_type[!ser]), info = op)
	}
	expect_error(ns("edi_tuning_parallel_families")("nonsense"))
})
