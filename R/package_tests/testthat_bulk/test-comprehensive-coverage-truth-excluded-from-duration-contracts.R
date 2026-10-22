library(testthat)
library(EDI)

# v1.0.5 TODO-127: comprehensive_tests.R's safe_call() must not bill the
# coverage-truth Monte Carlo simulation (get_coverage_truth(), reached from
# handle_success() via is_truth_anomalous_result()) to the method being timed.
# This test pulls safe_call() and the handle_success() helpers out of
# run_inference_checks_impl() by parsing the harness (sourcing it would start
# the suite), stubs everything else, and replaces get_coverage_truth() with a
# slow first call. The recorded duration of the first result must exclude it.

comprehensive_path <- testthat::test_path("..", "comprehensive_tests.R")
comprehensive_exprs <- parse(comprehensive_path)

is_named_assignment <- function(expr) {
	is.call(expr) &&
		(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) &&
		is.name(expr[[2L]])
}

impl_body_assignments <- function(names, envir) {
	impl <- NULL
	for (expr in comprehensive_exprs) {
		if (is_named_assignment(expr) && identical(as.character(expr[[2L]]), "run_inference_checks_impl")) {
			impl <- expr[[3L]]
			break
		}
	}
	if (is.null(impl)) stop("run_inference_checks_impl not found in comprehensive_tests.R")
	body_exprs <- as.list(impl[[3L]])[-1L]
	remaining <- names
	for (expr in body_exprs) {
		if (!is_named_assignment(expr)) next
		name <- as.character(expr[[2L]])
		if (!(name %in% remaining)) next
		eval(expr, envir = envir)
		remaining <- setdiff(remaining, name)
	}
	if (length(remaining)) stop("Missing run_inference_checks_impl assignment(s): ", paste(remaining, collapse = ", "))
	invisible(envir)
}

TRUTH_SLEEP_SEC <- 1.5
METHOD_SLEEP_SEC <- 0.05

safe_call_fixture <- function(fork) {
	e <- new.env(parent = globalenv())
	# Fake R6-shaped inference object: fork=FALSE snapshots and restores the
	# plain fields of the object, its private env, its design and the
	# design's private env.
	des <- new.env()
	des$.__enclos_env__ <- list2env(list(private = new.env()))
	priv <- new.env()
	priv$des_obj <- des
	inf <- new.env()
	inf$.__enclos_env__ <- list2env(list(private = priv))
	inf$num_cores <- 1L
	e$seq_des_inf <- inf

	e$rep_curr <- 1L
	e$beta_T <- 0.5
	e$dataset_name <- "toy"
	e$dataset_n_rows <- 10L
	e$dataset_n_cols <- 1L
	e$response_type <- "continuous"
	e$design_type <- "Bernoulli"
	e$inference_result_label <- "InferenceToy (model_formula=~1)"
	e$pending_rep_header <- NULL
	e$pending_beta_header <- NULL
	e$pending_dataset_header <- NULL
	e$pending_response_header <- NULL
	e$pending_design_header <- NULL
	e$pending_banner <- NULL
	e$FUNCTION_TIMEOUT_SEC <- 60
	e$SAFE_CALL_FORK <- fork
	e$skip_repeat_after_timeout <- FALSE
	e$NUM_CORES <- 1L
	e$WATCHDOG_SUPERVISOR_PID <- NA_integer_
	e$WATCHDOG_MARKER <- ""
	e$watchdog_outcomes <- list()
	e$REUSE_RESAMPLING_DRAWS <- FALSE
	e$REUSED_RESAMPLING_CACHES <- character()
	e$SUSPEND_GAP_SEC <- 30
	e$SUSPEND_MAX_RERUNS <- 0L

	e$is_row_completed <- function(...) FALSE
	e$is_slow_operation <- function(...) FALSE
	e$is_confirmed_timeout <- function(...) FALSE
	e$mark_confirmed_timeout <- function(...) invisible(NULL)
	e$record_comprehensive_attempt_event <- function(...) invisible(NULL)
	e$build_result_key <- function(...) "toy-key"
	e$comprehensive_watchdog_write_rds <- function(...) invisible(NULL)
	e$snap_small_numeric_to_zero <- function(x) x
	e$estimate_error_annotation <- function(...) ""

	# Slow on the first call per key, cached afterwards -- the shape of the
	# real MC truth cache.
	e$truth_calls <- 0L
	e$truth_cache <- new.env(parent = emptyenv())
	e$get_coverage_truth <- function(inference_class, dataset_name, beta_T_val, response_type_hint = NA_character_) {
		e$truth_calls <- e$truth_calls + 1L
		key <- paste(inference_class, dataset_name, beta_T_val)
		if (!exists(key, envir = e$truth_cache, inherits = FALSE)) {
			Sys.sleep(TRUTH_SLEEP_SEC)
			assign(key, beta_T_val, envir = e$truth_cache)
		}
		get(key, envir = e$truth_cache, inherits = FALSE)
	}

	e$recorded <- list()
	e$record_result <- function(dataset_name, dataset_n_rows, dataset_n_cols, response_type, design_type,
		inference_class, function_run, result, status, duration_time_sec,
		error_message = NA_character_, start_epoch = NA_real_, end_epoch = NA_real_) {
		e$recorded[[length(e$recorded) + 1L]] <- list(
			function_run = function_run, result = result, status = status,
			duration_time_sec = duration_time_sec, error_message = error_message,
			end_epoch = end_epoch
		)
		invisible(NULL)
	}

	impl_body_assignments(c(
		"has_invalid_numeric",
		"is_rejected_zero_zero_confidence_interval",
		"is_truth_anomalous_result",
		"is_allowed_missing_output",
		"is_explicitly_nonestimable",
		"should_record_nonestimable_as_missing",
		"nonestimable_error_message",
		"safe_call"
	), e)
	e
}

expect_truth_excluded <- function(fork) {
	e <- safe_call_fixture(fork)
	capture.output(suppressMessages({
		wall_1 <- system.time(e$safe_call("compute_estimate", { Sys.sleep(METHOD_SLEEP_SEC); 0.25 }))[["elapsed"]]
		e$safe_call("compute_asymp_confidence_interval", { Sys.sleep(METHOD_SLEEP_SEC); c(0.1, 0.9) })
	}))

	# The slow truth really ran inside the first call (so the old code would
	# have billed it) ...
	expect_gte(e$truth_calls, 1L)
	expect_gte(wall_1, TRUTH_SLEEP_SEC)
	expect_length(e$recorded, 2L)
	first <- e$recorded[[1L]]
	second <- e$recorded[[2L]]
	expect_identical(first$function_run, "compute_estimate")
	expect_identical(first$status, "ok")
	expect_equal(as.numeric(first$result), 0.25)
	expect_identical(second$function_run, "compute_asymp_confidence_interval")
	# ... but the first recorded duration covers only the method itself, like
	# the second (cached-truth) one does.
	expect_gte(first$duration_time_sec, METHOD_SLEEP_SEC * 0.5)
	expect_lt(first$duration_time_sec, TRUTH_SLEEP_SEC * 0.5)
	expect_lt(second$duration_time_sec, TRUTH_SLEEP_SEC * 0.5)
	# The sleep-adjustment window ends with the method too, not after the truth.
	expect_true(is.finite(first$end_epoch))
}

test_that("fork=FALSE: the coverage-truth simulation is not billed to the first timed result (TODO-127)", {
	expect_truth_excluded(fork = FALSE)
})

test_that("fork=TRUE: the coverage-truth simulation is not billed to the first timed result (TODO-127)", {
	skip_on_os("windows")
	expect_truth_excluded(fork = TRUE)
})
