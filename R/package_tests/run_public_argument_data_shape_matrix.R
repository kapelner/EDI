#!/usr/bin/env Rscript

# Data-shape option matrix (v1.0.6-TODO-97): pairwise cells over design, response type, n = NULL
# (mid-stream and at the end), unequal block/cluster sizes, censoring type, a missing covariate,
# effect size and inference class, plus the InferenceRandCustom statistic block. Cells come from
# generate_public_argument_data_shape_cases() and run through run_case() like every other
# argument-combination case; see public_argument_combination_runner.md ("Data-shape matrix").
#
# Usage (from R/):
#   Rscript package_tests/run_public_argument_data_shape_matrix.R [out_dir] [cell_filter] [max_cells] [timeout_sec]
# out_dir defaults to package_tests/ (files public_argument_combination_data_shape_*.csv);
# cell_filter is a regular expression on the fixture id or inference class ("" = all cells).
# Runs against the installed EDI, or the source tree when EDI_DATA_SHAPE_LOAD_ALL=1
# (pkgload::load_all(compile = FALSE); never compiles).

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/run_public_argument_data_shape_matrix.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

if (identical(Sys.getenv("EDI_DATA_SHAPE_LOAD_ALL"), "1")) {
	suppressMessages(pkgload::load_all(file.path(repo_root, "EDI"), compile = FALSE, quiet = TRUE))
}

source(file.path(repo_root, "package_tests", "generate_public_argument_combinations.R"))
source(file.path(repo_root, "package_tests", "run_public_argument_combinations.R"))

# Outcomes a cell may not have: the call must give finite output, an NA it warns about, or a clear
# error. recorded_na fails too: the user sees an NA and no warning (the v1.0.6-TODO-95 rule).
data_shape_failing_outcomes = c("silent_na", "recorded_na", "unclear_error", "nonfinite")

# Failures already filed as open release TODOs. A row matches when every given field matches its
# regular expression (fixture_id, target = Class::method, argument_signature, receiver_args,
# error_message). A clear error can still be listed when it is the wrong error (for example a message
# that names an argument the class does not take). Keep each row tied to an open TODO
# (calibration-acceptance rule); delete it when the TODO closes.
data_shape_known_issues = function() {
	rows = list(
		list(todo = "v1.0.6-TODO-74", fixture_id = "^data_shape__fixed_blocked_cluster__", target = "::compute_jackknife_wald_confidence_interval$"),
		list(todo = "v1.0.6-TODO-82", target = "^InferenceRandCustom::", argument_signature = "na\\.rm=FALSE", receiver_args = "sometimes_na")
	)
	rows
}

annotate_known_issues = function(results, cases) {
	receiver_args = cases$receiver_args[match(results$case_id, cases$case_id)]
	receiver_args[is.na(receiver_args)] = ""
	fields = list(
		fixture_id = results$fixture_id,
		target = paste(results$class_name, results$method_name, sep = "::"),
		argument_signature = results$argument_signature,
		receiver_args = receiver_args,
		error_message = results$error_message
	)
	known = rep("", nrow(results))
	for (issue in data_shape_known_issues()) {
		hit = rep(TRUE, nrow(results))
		for (field in setdiff(names(issue), "todo")) hit = hit & grepl(issue[[field]], fields[[field]])
		known[hit & !nzchar(known)] = issue$todo
	}
	results$known_todo = known
	results
}

data_shape_failures = function(results) {
	failing = results$output_outcome %in% data_shape_failing_outcomes | grepl("^failed:", results$invariant_status)
	if ("known_todo" %in% names(results)) failing = failing | (nzchar(results$known_todo) & results$output_outcome != "finite")
	results[failing, , drop = FALSE]
}

data_shape_outcome_summary = function(results) {
	tab = as.data.frame.matrix(table(results$class_name, factor(results$output_outcome,
		levels = c("finite", "warned_na", "recorded_na", "silent_na", "nonfinite", "non_numeric", "clear_error", "unclear_error", "unsupported", "not_run"))))
	tab = cbind(class_name = row.names(tab), tab, invariant_failures = as.integer(tapply(grepl("^failed:", results$invariant_status), results$class_name, sum)[row.names(tab)]))
	row.names(tab) = NULL
	tab
}

run_public_argument_data_shape_matrix = function(out_dir = file.path(repo_root, "package_tests"), cell_filter = NULL, max_cells = NULL, timeout_sec = 60) {
	dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
	paths = list(
		cases = file.path(out_dir, "public_argument_combination_data_shape_cases.csv"),
		results = file.path(out_dir, "public_argument_combination_data_shape_results.csv"),
		failures = file.path(out_dir, "public_argument_combination_data_shape_failures.csv"),
		summary = file.path(out_dir, "public_argument_combination_data_shape_summary.csv")
	)
	cases = generate_public_argument_data_shape_cases(tier = "nightly", cell_filter = cell_filter, max_cells = max_cells)
	write.csv(cases, paths$cases, row.names = FALSE)
	# The runner's own failures file counts every error; this matrix accepts a clear error, so its
	# failures are rewritten below.
	results = run_public_argument_combinations(tier = "nightly", timeout_sec = timeout_sec,
		cases_file = paths$cases, results_file = paths$results, failures_file = paths$failures)
	results = annotate_known_issues(results[results$case_id %in% cases$case_id, , drop = FALSE], cases)
	write.csv(results, paths$results, row.names = FALSE)
	write.csv(data_shape_failures(results), paths$failures, row.names = FALSE)
	write.csv(data_shape_outcome_summary(results), paths$summary, row.names = FALSE)
	invisible(list(cases = cases, results = results, paths = paths))
}

main = function() {
	args = commandArgs(trailingOnly = TRUE)
	arg = function(i) if (length(args) >= i && !is.na(args[i]) && nzchar(args[i])) args[i] else NULL
	out = run_public_argument_data_shape_matrix(
		out_dir = arg(1L) %||% file.path(repo_root, "package_tests"),
		cell_filter = arg(2L),
		max_cells = if (!is.null(arg(3L))) as.integer(arg(3L)) else NULL,
		timeout_sec = if (!is.null(arg(4L))) as.numeric(arg(4L)) else 60
	)
	res = out$results
	message("Data-shape matrix: ", nrow(res), " cases; outcomes: ",
		paste(names(table(res$output_outcome)), table(res$output_outcome), sep = "=", collapse = ", "))
	message("Failing cases (", paste(data_shape_failing_outcomes, collapse = "/"), " or a failed invariant): ", nrow(data_shape_failures(res)))
}

called_as_data_shape_script = function() {
	file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% ""
	identical(basename(sub("^--file=", "", file_arg)), "run_public_argument_data_shape_matrix.R")
}

if (called_as_data_shape_script()) {
	main()
}
