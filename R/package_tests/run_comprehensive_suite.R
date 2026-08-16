#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/run_comprehensive_suite.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)
artifact = function(name) repo_path("package_tests", name)

source(artifact("comprehensive_suite_runtime_tiers.R"))

runtime_tiers = build_comprehensive_suite_runtime_tiers()
valid_tiers = runtime_tiers$tier
args = commandArgs(trailingOnly = TRUE)
tier = if (length(args) >= 1L && nzchar(args[1L])) args[1L] else "smoke"
if (!tier %in% valid_tiers) {
	stop("Unsupported comprehensive suite tier: ", tier, ". Supported tiers: ", paste(valid_tiers, collapse = ", "), call. = FALSE)
}
tier_policy = tier_policy_for(tier, runtime_tiers)
target_filter = if (length(args) >= 2L && nzchar(args[2L])) args[2L] else ""
timeout_sec = if (length(args) >= 3L && nzchar(args[3L])) as.numeric(args[3L]) else as.numeric(tier_policy$default_timeout_sec[1])
force = any(args %in% c("--force", "force")) || Sys.getenv("COMPREHENSIVE_SUITE_FORCE", "0") %in% c("1", "true", "TRUE", "yes", "YES")

paths = list(
	results = artifact("comprehensive_suite_results.csv"),
	failures = artifact("comprehensive_suite_failures.csv"),
	public_argument_results = artifact("public_argument_combination_results.csv"),
	public_argument_failures = artifact("public_argument_combination_failures.csv"),
	workflow_coverage = artifact("comprehensive_suite_workflow_coverage.csv"),
	internal_surfaces = artifact("comprehensive_suite_internal_surfaces.csv")
)

required_dependency_artifacts = c(
	"public_api_inventory.csv",
	"checkmate_argument_contracts.csv",
	"public_argument_contract_registry.R",
	"public_argument_combination_constraints.R",
	"public_argument_combination_fixtures.R",
	"public_argument_combination_cases.csv",
	"public_argument_combination_results.csv",
	"public_argument_combination_coverage.csv",
	"public_argument_combination_failures.csv",
	"comprehensive_suite_registry.csv",
	"comprehensive_suite_baseline_audit.csv"
)

clean_chr = function(x) {
	x = as.character(x %||% "")
	x[is.na(x)] = ""
	x
}

read_optional_csv = function(path) {
	if (!file.exists(path) || isTRUE(file.info(path)$size == 0)) return(data.frame())
	first_line = readLines(path, n = 1L, warn = FALSE)
	if (!length(first_line) || identical(first_line, "\"\"")) return(data.frame())
	tryCatch(read.csv(path, stringsAsFactors = FALSE, na.strings = character()), error = function(e) data.frame())
}

bind_rows_fill = function(rows) {
	rows = rows[vapply(rows, function(x) is.data.frame(x) && nrow(x) > 0L, logical(1))]
	if (!length(rows)) return(data.frame())
	cols = unique(unlist(lapply(rows, names), use.names = FALSE))
	rows = lapply(rows, function(df) {
		for (col in setdiff(cols, names(df))) df[[col]] = NA
		df[, cols, drop = FALSE]
	})
	do.call(rbind, rows)
}

csv_nrow = function(path) {
	if (!file.exists(path) || isTRUE(file.info(path)$size == 0)) return(0L)
	nrow(read.csv(path, stringsAsFactors = FALSE, nrows = -1L))
}

latest_comprehensive_result_files = function(filter = "") {
	files = list.files(repo_path("package_tests"), pattern = "^comprehensive_tests_results.*[.]csv$", full.names = TRUE)
	if (nzchar(filter)) {
		matching = files[grepl(filter, basename(files), ignore.case = TRUE)]
		if (length(matching)) files = matching
	}
	files = files[file.exists(files) & file.info(files)$size > 0]
	files[order(file.info(files)$mtime, decreasing = TRUE)]
}

status_from_command = function(status, failures_written = 0L) {
	if (!identical(status, 0L)) return("error")
	if (tier %in% c("smoke", "ci") && failures_written > 0L) return("error")
	"ok"
}

# Defensive belt-and-suspenders check, independent of the numeric exit
# status: a subprocess that never got past its own startup (e.g.
# `library(EDI)` failing because the package isn't installed for whatever
# R session actually runs the subprocess) must not be recorded as "ok"
# even if its exit code was somehow captured as 0. Found during TODO-11
# (2026-08-13): a `comprehensive_harness` step recorded `status = "ok"`
# despite completing in 0.19s -- traced to a real, transient environment
# race (EDI momentarily installed, then not, via concurrent tooling), not
# a bug in the exit-status capture itself (confirmed by directly
# reproducing both a genuine subprocess failure, captured correctly as
# status 1, and the harness's own tryCatch/status_from_command logic
# working as designed) -- but this check stays cheap insurance against the
# next environment problem doing the same thing a different way.
subprocess_output_has_fatal_marker = function(output) {
	any(grepl("^Error in |^Execution halted$|there is no package called", output, perl = TRUE))
}

existing_results = read_optional_csv(paths$results)

step_completed = function(step) {
	if (force || !nrow(existing_results)) return(FALSE)
	rows = existing_results[
		existing_results$tier == tier &
			existing_results$target_filter == target_filter &
			existing_results$step == step &
			existing_results$status == "ok",
		, drop = FALSE
	]
	nrow(rows) > 0L
}

result_row = function(step, runner, status, start_time, end_time, output_file = "", failure_file = "",
	rows_written = 0L, failures_written = 0L, resumed = FALSE, command = "", error_message = "") {
	data.frame(
		case_id = paste("comprehensive_suite", tier, ifelse(nzchar(target_filter), gsub("[^A-Za-z0-9]+", "_", target_filter), "all"), step, sep = "__"),
		tier = tier,
		target_filter = target_filter,
		step = step,
		runner = runner,
		status = status,
		start_time = format(start_time, "%Y-%m-%d %H:%M:%S %Z"),
		end_time = format(end_time, "%Y-%m-%d %H:%M:%S %Z"),
		duration_time_sec = as.numeric(difftime(end_time, start_time, units = "secs")),
		output_file = output_file,
		failure_file = failure_file,
		rows_written = as.integer(rows_written),
		failures_written = as.integer(failures_written),
		resumed = isTRUE(resumed),
		runtime_policy = clean_chr(tier_policy$description[1]),
		argument_combination_tier = clean_chr(tier_policy$argument_combination_tier[1]),
		comprehensive_harness_mode = clean_chr(tier_policy$comprehensive_harness_mode[1]),
		resampling_scale = clean_chr(tier_policy$resampling_scale[1]),
		command = command,
		error_message = error_message,
		stringsAsFactors = FALSE
	)
}

append_result = function(row) {
	current = read_optional_csv(paths$results)
	if (nrow(current)) {
		current = current[!(current$tier == row$tier & current$target_filter == row$target_filter & current$step == row$step), , drop = FALSE]
	}
	current = bind_rows_fill(list(current, row))
	current = current[order(current$tier, current$target_filter, current$step), , drop = FALSE]
	write.csv(current, paths$results, row.names = FALSE)
	failures = current[current$status != "ok" | current$failures_written > 0L, , drop = FALSE]
	write.csv(failures, paths$failures, row.names = FALSE)
	assign("existing_results", current, envir = .GlobalEnv)
	invisible(row)
}

record_resumed_step = function(step, runner, output_file = "", failure_file = "") {
	now = Sys.time()
	previous = existing_results[
		existing_results$tier == tier &
			existing_results$target_filter == target_filter &
			existing_results$step == step &
			existing_results$status == "ok",
		, drop = FALSE
	]
	if (nrow(previous)) previous = previous[nrow(previous), , drop = FALSE]
	if (nrow(previous) && !nzchar(output_file)) output_file = clean_chr(previous$output_file[1])
	if (nrow(previous) && !nzchar(failure_file)) failure_file = clean_chr(previous$failure_file[1])
	rows_written = if (nrow(previous) && (!nzchar(output_file) || grepl(";", output_file, fixed = TRUE))) {
		as.integer(previous$rows_written[1])
	} else {
		csv_nrow(output_file)
	}
	failures_written = if (nrow(previous) && (!nzchar(failure_file) || grepl(";", failure_file, fixed = TRUE))) {
		as.integer(previous$failures_written[1])
	} else {
		csv_nrow(failure_file)
	}
	append_result(result_row(
		step = step,
		runner = runner,
		status = "ok",
		start_time = now,
		end_time = now,
		output_file = output_file,
		failure_file = failure_file,
		rows_written = rows_written,
		failures_written = failures_written,
		resumed = TRUE,
		command = "resumed existing successful step"
	))
}

run_command_step = function(step, runner, command, command_args, output_file = "", failure_file = "") {
	if (step_completed(step)) {
		message("Skipping completed step: ", step)
		return(record_resumed_step(step, runner, output_file, failure_file))
	}
	start = Sys.time()
	output = character()
	status = tryCatch({
		output <<- suppressWarnings(system2(command, command_args, stdout = TRUE, stderr = TRUE, timeout = timeout_sec))
		attr(output, "status") %||% 0L
	}, warning = function(w) {
		output <<- c(output, conditionMessage(w))
		attr(output, "status") %||% 124L
	}, error = function(e) {
		output <<- conditionMessage(e)
		1L
	})
	end = Sys.time()
	failures_written = csv_nrow(failure_file)
	effective_status = if (identical(as.integer(status), 0L) && subprocess_output_has_fatal_marker(output)) 1L else as.integer(status)
	row = result_row(
		step = step,
		runner = runner,
		status = status_from_command(effective_status, failures_written),
		start_time = start,
		end_time = end,
		output_file = output_file,
		failure_file = failure_file,
		rows_written = csv_nrow(output_file),
		failures_written = failures_written,
		command = paste(c(command, command_args), collapse = " "),
		error_message = if (!identical(effective_status, 0L)) paste(tail(output, 8L), collapse = " | ") else ""
	)
	append_result(row)
	if (!identical(row$status, "ok")) stop("Comprehensive suite step failed: ", step, call. = FALSE)
	row
}

validate_dependency_step = function() {
	step = "dependency_gate"
	if (step_completed(step)) {
		message("Skipping completed step: ", step)
		return(record_resumed_step(step, "validate_argument_checking_dependency"))
	}
	start = Sys.time()
	missing = required_dependency_artifacts[!file.exists(file.path(repo_root, "package_tests", required_dependency_artifacts))]
	status = if (length(missing)) "error" else "ok"
	row = result_row(
		step = step,
		runner = "validate_argument_checking_dependency",
		status = status,
		start_time = start,
		end_time = Sys.time(),
		rows_written = length(required_dependency_artifacts) - length(missing),
		error_message = if (length(missing)) paste("Missing dependency artifacts:", paste(missing, collapse = ", ")) else ""
	)
	append_result(row)
	if (length(missing)) stop(row$error_message, call. = FALSE)
	row
}

run_argument_combinations_step = function() {
	argument_tier = clean_chr(tier_policy$argument_combination_tier[1])
	command_args = c(artifact("run_public_argument_combinations.R"), argument_tier)
	if (nzchar(target_filter)) command_args = c(command_args, target_filter)
	command_args = c(command_args, "", as.character(timeout_sec))
	run_command_step(
		"argument_combinations",
		"run_public_argument_combinations.R",
		"Rscript",
		command_args,
		paths$public_argument_results,
		paths$public_argument_failures
	)
}

run_workflow_step = function() {
	workflow_tier = clean_chr(tier_policy$workflow_tier[1])
	run_command_step(
		"public_workflow_coverage",
		"run_public_workflow_coverage.R",
		"Rscript",
		c(artifact("run_public_workflow_coverage.R"), workflow_tier, paths$workflow_coverage),
		paths$workflow_coverage,
		""
	)
}

run_internal_step = function() {
	run_command_step(
		"internal_safety_nets",
		"comprehensive_suite_internal_surfaces.R",
		"Rscript",
		c(artifact("comprehensive_suite_internal_surfaces.R"), paths$internal_surfaces),
		paths$internal_surfaces,
		""
	)
}

run_comprehensive_harness_step = function() {
	step = "comprehensive_harness"
	if (identical(clean_chr(tier_policy$comprehensive_harness_mode[1]), "import_existing_results")) {
		if (step_completed(step)) {
			message("Skipping completed step: ", step)
			return(record_resumed_step(step, "comprehensive_tests.R import"))
		}
		start = Sys.time()
		files = latest_comprehensive_result_files(target_filter)
		status = if (length(files)) "ok" else "error"
		row = result_row(
			step = step,
			runner = "comprehensive_tests.R import",
			status = status,
			start_time = start,
			end_time = Sys.time(),
			output_file = paste(file.path("package_tests", basename(head(files, 5L))), collapse = ";"),
			rows_written = sum(vapply(head(files, 5L), csv_nrow, integer(1))),
			command = "import existing comprehensive_tests_results*.csv for smoke/ci integration",
			error_message = if (length(files)) "" else "No existing comprehensive_tests_results*.csv files available to import."
		)
		append_result(row)
		if (!identical(status, "ok")) stop(row$error_message, call. = FALSE)
		return(row)
	}
	response_filter = if (nzchar(target_filter) && target_filter %in% c("continuous", "incidence", "proportion", "count", "survival", "ordinal")) target_filter else "continuous"
	inference_filter = if (nzchar(target_filter) && !target_filter %in% c("continuous", "incidence", "proportion", "count", "survival", "ordinal")) target_filter else "NA"
	nrep = if (identical(tier, "release")) "2" else "1"
	family_filter = if (identical(tier, "release")) "bootstrap" else "estimate"
	run_command_step(
		step,
		"comprehensive_tests.R",
		"Rscript",
		c(artifact("comprehensive_tests.R"), nrep, "2", response_filter, "Bernoulli", inference_filter, "NA", "0", "1", family_filter),
		"",
		""
	)
}

run_comprehensive_suite = function() {
	validate_dependency_step()
	run_argument_combinations_step()
	run_comprehensive_harness_step()
	run_workflow_step()
	run_internal_step()
	results = read_optional_csv(paths$results)
	selected = results[results$tier == tier & results$target_filter == target_filter, , drop = FALSE]
	failures = selected[selected$status != "ok" | selected$failures_written > 0L, , drop = FALSE]
	write.csv(failures, paths$failures, row.names = FALSE)
	if (nrow(failures)) stop("Comprehensive suite completed with ", nrow(failures), " failing step rows.", call. = FALSE)
	invisible(selected)
}

selected_results = run_comprehensive_suite()
message("comprehensive suite ", tier, " wrote ", nrow(selected_results), " unified step rows to ", paths$results)
message("comprehensive suite failures written to ", paths$failures)
