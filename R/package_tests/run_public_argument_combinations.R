#!/usr/bin/env Rscript

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/run_public_argument_combinations.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "generate_public_argument_combinations.R"))
source(file.path(repo_root, "package_tests", "public_argument_combination_invariants.R"))

cases_path = file.path(repo_root, "package_tests", "public_argument_combination_cases.csv")
results_path = file.path(repo_root, "package_tests", "public_argument_combination_results.csv")
failures_path = file.path(repo_root, "package_tests", "public_argument_combination_failures.csv")

runner_statuses = c("ok", "error", "unsupported", "skipped_slow", "skipped_dependency", "invalid_registry")

parse_runner_args = function(args = commandArgs(trailingOnly = TRUE)) {
	list(
		tier = if (length(args) >= 1L && !is.na(args[1L]) && nzchar(args[1L])) args[1L] else "smoke",
		class_filter = if (length(args) >= 2L && !is.na(args[2L]) && nzchar(args[2L])) args[2L] else NULL,
		method_filter = if (length(args) >= 3L && !is.na(args[3L]) && nzchar(args[3L])) args[3L] else NULL,
		timeout_sec = if (length(args) >= 4L && !is.na(args[4L]) && nzchar(args[4L])) as.numeric(args[4L]) else 20
	)
}

load_cases = function(path = cases_path) {
	if (!file.exists(path)) {
		stop("Missing package_tests/public_argument_combination_cases.csv. Run Phase 5 first.", call. = FALSE)
	}
	read_csv_fast(path, stringsAsFactors = FALSE, na.strings = character())
}

filter_cases = function(cases, tier = "smoke", class_filter = NULL, method_filter = NULL) {
	cases = cases[cases$tier == tier, , drop = FALSE]
	if (!is.null(class_filter)) {
		cases = cases[grepl(class_filter, cases$class_name) | grepl(class_filter, cases$function_name) | grepl(class_filter, cases$target), , drop = FALSE]
	}
	if (!is.null(method_filter)) {
		cases = cases[grepl(method_filter, cases$method_name) | grepl(method_filter, cases$function_name) | grepl(method_filter, cases$target), , drop = FALSE]
	}
	row.names(cases) = NULL
	cases
}

# Every column but duration_time_sec is text, and result_row() writes "" (never
# NA) into all of them. Read them back as character: without colClasses an
# all-blank column (function_name on r6 methods) comes back logical NA, is
# written as NA, and the next resume reads that as the string "NA", so the
# committed CSV flipped "" -> NA -> "NA" on successive regenerates (2026-11-15).
read_existing_results = function(path = results_path) {
	if (!file.exists(path)) return(NULL)
	header = names(read_csv_fast(path, stringsAsFactors = FALSE, nrows = 0L))
	text_cols = setdiff(header, "duration_time_sec")
	read_csv_fast(path, stringsAsFactors = FALSE, na.strings = character(),
		colClasses = stats::setNames(rep("character", length(text_cols)), text_cols))
}

split_semicolon_signature = function(signature) {
	if (!nzchar(signature) || identical(signature, "<default>")) return(character())
	parts = strsplit(signature, ";", fixed = TRUE)[[1L]]
	parts[nzchar(parts)]
}

args_from_signature = function(signature, fixture) {
	parts = split_semicolon_signature(signature)
	if (!length(parts)) return(list())
	out = list()
	for (part in parts) {
		key = sub("=.*$", "", part)
		value_expr = sub("^[^=]*=", "", part)
		# A bare <fixture> placeholder means the registry knows no legal value for this
		# argument (e.g. choices from a private field): leave it at its formal default.
		if (identical(trimws(value_expr), "<fixture>")) next
		out[[key]] = eval_value_expr(value_expr, fixture)
	}
	out
}

output_type = function(x) {
	if (is.null(x)) return("NULL")
	paste(class(x), collapse = "/")
}

output_shape = function(x) {
	if (is.null(x)) return("NULL")
	dims = dim(x)
	if (!is.null(dims)) return(paste(dims, collapse = "x"))
	if (length(x) == 1L) return("scalar")
	paste0("length=", length(x))
}

capture_call = function(fun, args, timeout_sec) {
	warnings = character()
	messages = character()
	start = proc.time()[["elapsed"]]
	old_limit = getOption("expressions")
	result = NULL
	error_message = ""
	status = "ok"
	tryCatch({
		setTimeLimit(elapsed = timeout_sec, transient = TRUE)
		on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)
		# `=`, not `<<-`: this expression runs in this frame, so `<<-` wrote to the global env
		# and every case returned NULL to the invariants.
		result = withCallingHandlers(
			do.call(fun, args),
			warning = function(w) {
				warnings <<- c(warnings, conditionMessage(w))
				invokeRestart("muffleWarning")
			},
			message = function(m) {
				messages <<- c(messages, conditionMessage(m))
				invokeRestart("muffleMessage")
			}
		)
	}, error = function(e) {
		status <<- "error"
		error_message <<- conditionMessage(e)
	})
	duration = proc.time()[["elapsed"]] - start
	options(expressions = old_limit)
	list(
		status = status,
		result = result,
		duration_time_sec = duration,
		warning_message = paste(unique(warnings), collapse = " | "),
		message_text = paste(unique(messages), collapse = " | "),
		error_message = error_message
	)
}

construct_r6_receiver = function(case_row, fixture) {
	if (case_row$class_name %in% class(fixture$design) && case_row$method_name %in% names(fixture$design)) {
		return(fixture$design)
	}
	constructor = tryCatch(getExportedValue("EDI", case_row$class_name), error = function(e) NULL)
	if (is.null(constructor) || is.null(constructor$new)) {
		stop("Cannot resolve exported R6 class: ", case_row$class_name, call. = FALSE)
	}
	obj = tryCatch(constructor$new(des_obj = fixture$design), error = function(e) NULL)
	if (is.null(obj)) obj = tryCatch(constructor$new(fixture$design), error = function(e) NULL)
	if (is.null(obj)) stop("Cannot construct receiver for public R6 class: ", case_row$class_name, call. = FALSE)
	if (!case_row$method_name %in% names(obj)) {
		stop("Public method not found on receiver: ", case_row$method_name, call. = FALSE)
	}
	obj
}

# Data-shape cases (v1.0.7-TODO-41) build their receiver with the constructor arguments in
# receiver_args (e.g. InferenceRandCustom's statistic). Unlike construct_r6_receiver(), a refusal
# here is the case's own outcome, not "unsupported": a design that cannot be analyzed at all (n =
# NULL, v1.0.6-TODO-39) fails in Inference*$new(). A class the design says does not apply to it
# (Design$applicable_inference_class_names()) is "unsupported".
construct_data_shape_receiver = function(case_row, fixture) {
	applicable = tryCatch(fixture$design$applicable_inference_class_names(), error = function(e) NULL)
	if (!is.null(applicable) && !case_row$class_name %in% applicable && !identical(case_row$class_name, "InferenceRandCustom")) {
		stop("Cannot construct receiver: ", case_row$class_name, " is not applicable to this design", call. = FALSE)
	}
	constructor = getExportedValue("EDI", case_row$class_name)
	# read.csv turns an empty receiver_args into logical NA, which %||% does not replace.
	receiver_args = case_row$receiver_args
	if (is.null(receiver_args) || length(receiver_args) == 0L || is.na(receiver_args[1L])) receiver_args = ""
	extra = args_from_signature(as.character(receiver_args), fixture)
	obj = tryCatch(
		do.call(constructor$new, c(list(des_obj = fixture$design), extra)),
		error = function(e) stop("constructing ", case_row$class_name, ": ", conditionMessage(e), call. = FALSE)
	)
	if (is.function(obj$set_seed)) obj$set_seed(20261118L)
	obj
}

is_data_shape_case = function(case_row) {
	identical(as.character(case_row$argument_coverage_kind %||% ""), "data_shape")
}

execute_valid_case = function(case_row, fixture, timeout_sec) {
	args = args_from_signature(case_row$argument_signature, fixture)
	if (is_data_shape_case(case_row)) {
		receiver = tryCatch(construct_data_shape_receiver(case_row, fixture), error = function(e) e)
		if (inherits(receiver, "error")) {
			msg = conditionMessage(receiver)
			return(list(status = if (startsWith(msg, "Cannot construct receiver")) "unsupported" else "error",
				result = NULL, duration_time_sec = 0, warning_message = "", message_text = "", error_message = msg))
		}
		if (!is.function(receiver[[case_row$method_name]])) {
			return(list(status = "unsupported", result = NULL, duration_time_sec = 0, warning_message = "", message_text = "",
				error_message = paste(case_row$class_name, "has no public method", case_row$method_name)))
		}
		out = capture_call(receiver[[case_row$method_name]], args, timeout_sec)
		out$receiver = receiver
		return(out)
	}
	if (identical(case_row$api_kind, "r6_public_method")) {
		receiver = construct_r6_receiver(case_row, fixture)
		out = capture_call(receiver[[case_row$method_name]], args, timeout_sec)
		out$receiver = receiver
		return(out)
	}
	if (identical(case_row$api_kind, "function")) {
		fun = getExportedValue("EDI", case_row$function_name)
		return(capture_call(fun, args, timeout_sec))
	}
	list(
		status = "error",
		result = NULL,
		duration_time_sec = 0,
		warning_message = "",
		message_text = "",
		error_message = paste("Unsupported api_kind for execution:", case_row$api_kind)
	)
}

result_row = function(case_row, status, duration_time_sec = 0, warning_message = "", message_text = "", output = NULL, invariant_status = "skipped", error_message = "", output_outcome = "not_run", na_reason = "") {
	clean = function(x) {
		x = as.character(x %||% "")
		ifelse(is.na(x), "", x)
	}
	data.frame(
		case_id = clean(case_row$case_id),
		api_kind = clean(case_row$api_kind),
		class_name = clean(case_row$class_name),
		function_name = clean(case_row$function_name),
		method_name = clean(case_row$method_name),
		fixture_id = clean(case_row$fixture_id),
		argument_signature = clean(case_row$argument_signature),
		tier = clean(case_row$tier),
		status = status,
		duration_time_sec = as.numeric(duration_time_sec),
		warning_message = warning_message,
		message_text = message_text,
		output_type = output_type(output),
		output_shape = output_shape(output),
		invariant_status = invariant_status,
		error_message = error_message,
		output_outcome = output_outcome,
		na_reason = na_reason,
		stringsAsFactors = FALSE
	)
}

# What the call produced, as one token, so a gate can count each kind (v1.0.6-TODO-54 / v1.0.7-TODO-41):
#   finite         numeric output, every value finite
#   warned_na      all-NA output with a warning from this call
#   recorded_na    all-NA output with no warning, but a reason the receiver recorded
#                  (is_nonestimable(), procedure_failure_reason): the user sees nothing
#   silent_na      some NA/NaN output with no warning and no recorded reason
#   nonfinite      Inf, or partly-NA output that EDI explained
#   non_numeric    a non-numeric return (lists, objects)
#   clear_error    an error raised by EDI's own checks
#   unclear_error  an error from R or C++ internals (see internal_error_patterns), i.e. EDI did
#                  not anticipate the input
#   unsupported    the case could not be set up on this fixture (not an EDI result)
#   not_run        a constraint rejected the case
internal_error_patterns = c(
	"missing value where TRUE/FALSE needed", "argument is of length zero", "argument of length 0",
	"subscript out of bounds", "non-numeric argument", "object of type '[a-z]+' is not subsettable",
	"invalid '[a-z]+' type", "NA/NaN/Inf in foreign function call", "unused argument",
	"attempt to apply non-function", "arguments imply differing number of rows",
	"replacement has [0-9]+ rows?", "object '[^']+' not found", "could not find function",
	"incorrect number of dimensions", "\\$ operator is invalid", "invalid argument to unary operator",
	"non-conformable", "the condition has length > 1", "undefined columns selected",
	"[Ii]ndex out of bounds", "std::", "Mat::", "is not a function", "invalid subscript type",
	"no applicable method", "dims \\[product", "length of 'dimnames'", "cannot coerce", "infinite or missing values in 'x'"
)

# The reason a receiver recorded for an NA, when it recorded one (is_nonestimable() or
# procedure_failure_reason), as "procedure=reason;...". Lets a recorded_na row say why without a
# warning having been shown.
recorded_na_reason = function(executed) {
	rec = executed$receiver
	if (is.null(rec)) return("")
	parts = character()
	if (is.function(rec$is_nonestimable) && isTRUE(tryCatch(rec$is_nonestimable(), error = function(e) FALSE))) {
		parts = c(parts, paste0("nonestimable=", tryCatch(rec$get_nonestimable_reason() %||% "", error = function(e) "")))
	}
	pf = tryCatch(rec$.__enclos_env__$private$cached_values$procedure_failure_reason, error = function(e) NULL)
	if (is.list(pf) && length(pf)) parts = c(parts, paste(names(pf), vapply(pf, function(x) paste(as.character(x), collapse = ","), character(1)), sep = "="))
	paste(parts, collapse = ";")
}

classify_output_outcome = function(executed) {
	status = executed$status %||% "error"
	if (identical(status, "unsupported")) return("unsupported")
	if (!identical(status, "ok")) {
		msg = executed$error_message %||% ""
		internal = any(vapply(internal_error_patterns, function(p) grepl(p, msg), logical(1)))
		return(if (internal) "unclear_error" else "clear_error")
	}
	out = executed$result
	if (!is.numeric(out) || !length(out)) return("non_numeric")
	if (all(is.finite(out))) return("finite")
	explained = receiver_explains_na(executed)
	if (any(is.na(out)) && !explained) return("silent_na")
	if (all(is.na(out))) return(if (nzchar(executed$warning_message %||% "")) "warned_na" else "recorded_na")
	"nonfinite"
}

# An all-NA result is documented non-estimability when EDI said why: a warning from this
# call, or a reason the receiver recorded (is_nonestimable(), or a per-procedure failure
# reason such as bootstrap_bca_adjustment_on_boundary or
# bootstrap_degenerate_confidence_interval). Some warnings are issued once per object, so
# a later NA on the same object has only the recorded reason.
receiver_explains_na = function(executed) {
	if (nzchar(executed$warning_message %||% "")) return(TRUE)
	rec = executed$receiver
	if (is.null(rec)) return(FALSE)
	if (is.function(rec$is_nonestimable) && isTRUE(tryCatch(rec$is_nonestimable(), error = function(e) FALSE))) return(TRUE)
	pf = tryCatch(rec$.__enclos_env__$private$cached_values$procedure_failure_reason, error = function(e) NULL)
	is.list(pf) && length(pf) > 0L
}

run_case = function(case_row, fixtures, timeout_sec = 20) {
	if (!identical(case_row$constraint_status, "valid")) {
		return(result_row(
			case_row,
			status = case_row$constraint_status,
			error_message = case_row$constraint_reason
		))
	}
	fixture = fixtures[[case_row$fixture_id]]
	if (is.null(fixture)) {
		return(result_row(case_row, status = "error", error_message = paste("Missing fixture:", case_row$fixture_id)))
	}
	# A data-shape fixture EDI refused to build (e.g. KK21 with n = NULL): every case on it carries
	# that error.
	if (!is.null(fixture$build_error)) {
		failed = list(status = "error", error_message = paste("building fixture:", fixture$build_error))
		return(result_row(case_row, status = "error", invariant_status = "skipped",
			error_message = failed$error_message, output_outcome = classify_output_outcome(failed)))
	}
	# Setup errors (building the receiver or the arguments) belong to this case, not the run.
	# A receiver no fixture can build (a design class without a fixture of its own, e.g.
	# DesignFixedFactorial on the Bernoulli fallback) is "unsupported", not an EDI error.
	executed = tryCatch(execute_valid_case(case_row, fixture, timeout_sec), error = function(e) {
		msg = conditionMessage(e)
		list(status = if (startsWith(msg, "Cannot construct receiver")) "unsupported" else "error",
			result = NULL, duration_time_sec = 0, warning_message = "", message_text = "", error_message = msg)
	})
	invariant_status = if (identical(executed$status, "unsupported")) "skipped" else
		check_invariants(executed$result, executed$status, case_row$invariants, context = list(
			documented_nonestimable_behavior = is.numeric(executed$result) && length(executed$result) > 0L &&
				all(is.na(executed$result)) && receiver_explains_na(executed),
			effect = fixture$metadata$effect %||% NULL))
	outcome = classify_output_outcome(executed)
	result_row(
		case_row,
		status = executed$status,
		duration_time_sec = executed$duration_time_sec,
		warning_message = executed$warning_message,
		message_text = executed$message_text,
		output = executed$result,
		invariant_status = invariant_status,
		error_message = executed$error_message,
		output_outcome = outcome,
		na_reason = if (outcome %in% c("recorded_na", "warned_na", "nonfinite", "silent_na")) recorded_na_reason(executed) else ""
	)
}

run_public_argument_combinations = function(tier = "smoke", class_filter = NULL, method_filter = NULL, timeout_sec = 20, cases_file = cases_path, results_file = results_path, failures_file = failures_path) {
	load_edi_for_fixtures()
	cases = filter_cases(load_cases(cases_file), tier, class_filter, method_filter)
	if (!nrow(cases)) stop("No generated cases selected.", call. = FALSE)
	existing = read_existing_results(results_file)
	completed = if (is.null(existing)) character() else existing$case_id
	to_run = cases[!cases$case_id %in% completed, , drop = FALSE]
	fixture_ids = unique(to_run$fixture_id)
	fixtures = if (length(fixture_ids)) build_public_argument_fixtures(tier = tier, fixture_ids = fixture_ids) else list()
	new_results = lapply(seq_len(nrow(to_run)), function(i) run_case(to_run[i, , drop = FALSE], fixtures, timeout_sec))
	new_results = if (length(new_results)) do.call(rbind, new_results) else NULL
	# Results written before output_outcome existed (v1.0.7-TODO-41) get it blank on resume, and
	# columns a caller appended (the data-shape matrix's known_todo) are kept, blank on new rows.
	if (!is.null(existing) && !is.null(new_results)) {
		for (col in setdiff(names(new_results), names(existing))) existing[[col]] = ""
		for (col in setdiff(names(existing), names(new_results))) new_results[[col]] = ""
		new_results = new_results[, names(existing), drop = FALSE]
	}
	results = if (!is.null(existing) && !is.null(new_results)) rbind(existing, new_results) else existing %||% new_results
	results = results[match(unique(results$case_id), results$case_id), , drop = FALSE]
	row.names(results) = NULL
	write.csv(results, results_file, row.names = FALSE)
	failures = results[results$status == "error" | grepl("^failed:", results$invariant_status), , drop = FALSE]
	write.csv(failures, failures_file, row.names = FALSE)
	invisible(results)
}

main = function() {
	parsed = parse_runner_args()
	results = run_public_argument_combinations(
		tier = parsed$tier,
		class_filter = parsed$class_filter,
		method_filter = parsed$method_filter,
		timeout_sec = parsed$timeout_sec
	)
	message("Wrote ", nrow(results), " public argument combination result rows.")
	message("Unexpected errors: ", sum(results$status == "error"))
	if (parsed$tier %in% c("ci", "smoke") && any(results$status == "error")) {
		quit(status = 1L)
	}
}

called_as_runner_script = function() {
	file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% ""
	identical(basename(sub("^--file=", "", file_arg)), "run_public_argument_combinations.R")
}

if (called_as_runner_script()) {
	main()
}
