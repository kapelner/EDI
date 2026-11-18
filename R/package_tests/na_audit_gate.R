#!/usr/bin/env Rscript
# NA audit gate (v1.0.6-TODO-95), shared by check_comprehensive_suite_quality_gates.R
# and check_public_argument_combination_quality_gates.R.
#
# Rule: a case whose inputs are finite and whose estimate, CI bound or p-value comes back
# NA/NaN/Inf without a warning or an error is a FAILURE (gate "silent_na_output", hard).
# It is not "unsupported". The only ways past the gate are rows of na_audit_allowlist.csv:
#   kind = "todo"         the NA is a known bug; `todo` cites an OPEN release-prefixed TODO
#                         (v1.0.6-TODO-74). The gate checks the release plans and fails the
#                         allowlist row itself once that TODO is closed or missing, so a fixed
#                         bug's row has to be pruned (same rule as calibration acceptance).
#   kind = "intentional"  a documented NA return that warns (e.g. a "not estimable" path).
#                         `warning_class` names the warning it raises. A matching row that came
#                         back NA with NO warning still fails: the allowlist row says it warns.
#
# What the gate can see:
#   comprehensive suite  comprehensive_tests.R writes NA/NaN/Inf results as status "ok" with
#                        error_message "Invalid output detected (NA/NaN/Inf) in <fn>; warnings=..."
#                        ("none", or the warning classes the call raised). The big per-response
#                        result CSVs are gitignored, so `Rscript na_audit_gate.R digest` folds them
#                        into the small comprehensive_suite_na_audit.csv that the checker reads.
#                        Rows written before the "; warnings=" suffix existed (before 2026-11-18)
#                        cannot say whether a warning fired: they are "unknown" and go to the
#                        "na_output_warning_status_unknown" gate (hard_later) until regenerated.
#                        NAs the object declared through is_nonestimable() ("Explicitly
#                        non-estimable ...") and the harness's ordinal asymptotic-p-value allowance
#                        ("Allowed missing output ...") are "declared" and only reported.
#   argument combos      run_public_argument_combinations.R records output_outcome per result row
#                        (silent_na / recorded_na / warned_na / nonfinite / finite / ...). recorded_na
#                        (no warning, only a reason stored on the object) counts as silent: that is
#                        how v1.0.6-TODO-75 got through. A data-shape fixture with a missing
#                        covariate (inputs not finite) gets its own gate, silent_na_output_missing_input
#                        (v1.0.6-TODO-97 holds every cell to "finite output or a clear error").

`%||%` = function(x, y) if (is.null(x)) y else x

na_audit_allowlist_cols = c("scope", "class_pattern", "function_pattern", "context_pattern", "kind", "todo", "warning_class", "reason")
na_audit_digest_cols = c("response_type", "design", "beta_T", "class_name", "function_run", "n_rows", "n_na_silent", "n_na_warned", "n_na_unknown", "n_na_declared", "warning_classes", "example")
na_audit_estimand_function_regex = "estimate|confidence_interval|pval"

na_audit_chr = function(x) {
	x = as.character(x %||% character())
	x[is.na(x)] = ""
	x
}

na_audit_read_csv = function(path, cols) {
	empty = as.data.frame(setNames(replicate(length(cols), character(), simplify = FALSE), cols), stringsAsFactors = FALSE)
	if (!file.exists(path) || isTRUE(file.info(path)$size == 0)) return(empty)
	out = utils::read.csv(path, stringsAsFactors = FALSE, na.strings = character(), colClasses = "character")
	for (col in setdiff(cols, names(out))) out[[col]] = rep("", nrow(out))
	out
}

na_audit_read_allowlist = function(path) na_audit_read_csv(path, na_audit_allowlist_cols)

# ---------------------------------------------------------------------------------------
# TODO references and their open/closed state in the release plans.
# ---------------------------------------------------------------------------------------

# "v1.0.6-TODO-74", "v1.0.6 TODO-74" -> "v1.0.6-TODO-74"; anything else is not a citation.
na_audit_todo_refs = function(text) {
	text = na_audit_chr(text)
	hits = regmatches(text, gregexpr("v[0-9]+(\\.[0-9]+)+[- ]TODO-[0-9]+", text, perl = TRUE))
	lapply(hits, function(h) unique(sub(" TODO-", "-TODO-", h, fixed = TRUE)))
}

# Every TODO with an unchecked box ("- [ ] TODO-<n>") in release_v<a>_<b>_<c>.md, as
# "v<a>.<b>.<c>-TODO-<n>". A TODO that also appears checked elsewhere in the same file
# (moved and closed) still counts as open while any unchecked entry remains.
na_audit_open_todos = function(release_dir) {
	files = list.files(release_dir, pattern = "^release_v[0-9_]+\\.md$", full.names = TRUE)
	out = character()
	for (f in files) {
		version = gsub("_", ".", sub("^release_v([0-9_]+)\\.md$", "\\1", basename(f)))
		lines = readLines(f, warn = FALSE)
		open = regmatches(lines, regexpr("^\\s*[-*] \\[ \\] TODO-[0-9]+", lines, perl = TRUE))
		if (length(open)) out = c(out, paste0("v", version, "-TODO-", sub("^.*TODO-", "", open)))
	}
	unique(out)
}

# Problems with the allowlist itself, as data.frame(row, detail).
na_audit_validate_allowlist = function(allowlist, open_todos) {
	problems = list()
	add = function(i, detail) problems[[length(problems) + 1L]] <<- data.frame(row = i, detail = detail, stringsAsFactors = FALSE)
	if (!nrow(allowlist)) return(data.frame(row = integer(), detail = character(), stringsAsFactors = FALSE))
	refs = na_audit_todo_refs(allowlist$todo)
	for (i in seq_len(nrow(allowlist))) {
		kind = allowlist$kind[i]
		if (!allowlist$scope[i] %in% c("comprehensive", "argument_combination", "both")) {
			add(i, paste0("scope must be comprehensive, argument_combination or both (got '", allowlist$scope[i], "')."))
		}
		if (!nzchar(allowlist$reason[i])) add(i, "reason is empty.")
		for (pat in c(allowlist$class_pattern[i], allowlist$function_pattern[i], allowlist$context_pattern[i])) {
			if (inherits(tryCatch(grepl(pat, "", perl = TRUE), error = function(e) e), "error")) add(i, paste0("invalid regex '", pat, "'."))
		}
		if (identical(kind, "todo")) {
			if (!length(refs[[i]])) {
				add(i, "kind=todo must cite a release-prefixed TODO in `todo` (e.g. v1.0.6-TODO-74).")
			} else if (!any(refs[[i]] %in% open_todos)) {
				add(i, paste0("cites ", paste(refs[[i]], collapse = ", "), ", which is not an open TODO in the release plans: the bug is fixed or the TODO moved. Prune or repoint this row."))
			}
		} else if (identical(kind, "intentional")) {
			if (!nzchar(allowlist$warning_class[i])) add(i, "kind=intentional must name the warning_class the NA return raises.")
		} else {
			add(i, paste0("kind must be todo or intentional (got '", kind, "')."))
		}
	}
	if (!length(problems)) return(data.frame(row = integer(), detail = character(), stringsAsFactors = FALSE))
	do.call(rbind, problems)
}

# Index of the first allowlist row that matches each case (NA_integer_ when none).
# class_pattern and function_pattern must match the whole name; context_pattern is searched
# for in the context string ("response_type=..;design=.." or "fixture=..;args=..").
# An empty pattern matches anything. A kind=intentional row also needs its warning_class
# among the case's observed warning classes, when they are known (`warning_classes`, comma
# separated; "" = not recorded or none, which the caller sorts out).
na_audit_match = function(scope, class_name, function_run, context, allowlist, warning_classes = rep("", length(class_name))) {
	n = length(class_name)
	out = rep(NA_integer_, n)
	if (!nrow(allowlist) || !n) return(out)
	full = function(pat, x) if (!nzchar(pat)) rep(TRUE, length(x)) else grepl(paste0("^(?:", pat, ")$"), x, perl = TRUE)
	part = function(pat, x) if (!nzchar(pat)) rep(TRUE, length(x)) else grepl(pat, x, perl = TRUE)
	for (i in seq_len(nrow(allowlist))) {
		if (!allowlist$scope[i] %in% c(scope, "both")) next
		hit = tryCatch(
			is.na(out) & full(allowlist$class_pattern[i], class_name) & full(allowlist$function_pattern[i], function_run) & part(allowlist$context_pattern[i], context),
			error = function(e) rep(FALSE, n)
		)
		if (identical(allowlist$kind[i], "intentional")) {
			wanted = allowlist$warning_class[i]
			seen = strsplit(na_audit_chr(warning_classes), ",", fixed = TRUE)
			# A class-wide row (class_pattern "" or ".*") is a claim about the warning, not the
			# class, so it only accepts cases whose warning classes were recorded.
			generic = allowlist$class_pattern[i] %in% c("", ".*")
			hit = hit & vapply(seen, function(w) if (!length(w)) !generic else wanted %in% w, logical(1))
		}
		out[hit] = i
	}
	out
}

# ---------------------------------------------------------------------------------------
# Comprehensive suite: classify result rows and fold the big CSVs into the digest.
# ---------------------------------------------------------------------------------------

# One of "silent", "warned", "unknown", "declared" or "" (not an NA row) per row.
na_audit_classify_comprehensive = function(status, error_message, result, function_run) {
	status = na_audit_chr(status)
	msg = na_audit_chr(error_message)
	result = na_audit_chr(result)
	is_estimand = grepl(na_audit_estimand_function_regex, na_audit_chr(function_run))
	invalid = startsWith(msg, "Invalid output detected")
	out = rep("", length(msg))
	out[invalid & grepl("; warnings=none", msg, fixed = TRUE)] = "silent"
	out[invalid & grepl("; warnings=", msg, fixed = TRUE) & !grepl("; warnings=none", msg, fixed = TRUE)] = "warned"
	out[invalid & !grepl("; warnings=", msg, fixed = TRUE)] = "unknown"
	out[grepl("non-estimable", msg, ignore.case = TRUE) | startsWith(msg, "Allowed missing output")] = "declared"
	# An "ok" row with neither a value nor a reason is a silent NA too.
	out[status == "ok" & !nzchar(msg) & result %in% c("", "NA", "NaN", "Inf", "-Inf")] = "silent"
	out[!is_estimand | status != "ok"] = ""
	out
}

na_audit_warning_classes = function(error_message) {
	msg = na_audit_chr(error_message)
	ifelse(grepl("; warnings=", msg, fixed = TRUE), sub("^.*; warnings=", "", msg), "")
}

# Folds comprehensive_tests_results_nc_*.csv into one row per
# (response_type, design, class, function_run) that has any NA row. beta_T is folded
# in (the values seen, ";"-joined) to keep the committed digest small (~0.8 MB, was
# ~2 MB with one row per beta_T and an inference_labels column nothing read).
build_comprehensive_na_digest = function(results_files) {
	if (!requireNamespace("data.table", quietly = TRUE)) stop("data.table is needed to build the NA digest.", call. = FALSE)
	cols = c("function_run", "rep", "beta_T", "dataset", "response_type", "design", "inference_class", "status", "error_message", "result")
	parts = list()
	for (f in results_files) {
		header = names(data.table::fread(f, nrows = 0L, showProgress = FALSE))
		x = data.table::fread(f, select = intersect(cols, header), colClasses = "character", showProgress = FALSE)
		for (col in setdiff(cols, names(x))) data.table::set(x, j = col, value = "")
		x[, na_kind := na_audit_classify_comprehensive(status, error_message, result, function_run)]
		x = x[na_kind != ""]
		if (!nrow(x)) next
		x[, class_name := sub(" .*$", "", inference_class)]
		x[, warning_class := na_audit_warning_classes(error_message)]
		parts[[length(parts) + 1L]] = x[, list(
			beta_T = paste(sort(unique(beta_T)), collapse = ";"),
			n_rows = .N,
			n_na_silent = sum(na_kind == "silent"),
			n_na_warned = sum(na_kind == "warned"),
			n_na_unknown = sum(na_kind == "unknown"),
			n_na_declared = sum(na_kind == "declared"),
			warning_classes = paste(sort(unique(unlist(strsplit(warning_class[nzchar(warning_class) & warning_class != "none"], ",", fixed = TRUE)))), collapse = ","),
			example = {
				ix = which(na_kind != "declared")[1L]
				if (is.na(ix)) ix = 1L
				paste0("dataset=", dataset[ix], ";rep=", rep[ix])
			}
		), by = list(response_type, design, class_name, function_run)]
		rm(x)
		gc(verbose = FALSE)
	}
	if (!length(parts)) {
		return(as.data.frame(setNames(replicate(length(na_audit_digest_cols), character(), simplify = FALSE), na_audit_digest_cols), stringsAsFactors = FALSE))
	}
	out = as.data.frame(data.table::rbindlist(parts))
	out = out[order(out$response_type, out$class_name, out$function_run, out$design), na_audit_digest_cols, drop = FALSE]
	row.names(out) = NULL
	out
}

# ---------------------------------------------------------------------------------------
# Gate rows. `cases` has one row per (case or digest group) with columns
# class_name, function_run, context, group (the gate-row key's value_expr), n_silent,
# n_warned, n_unknown, n_declared, warning_classes, detail_unit (e.g. the design or fixture).
# Returns data.frame(gate, severity, target, arg, value_expr, detail, exemption_type,
# exemption_reason).
# ---------------------------------------------------------------------------------------

na_audit_empty_rows = function() {
	data.frame(gate = character(), severity = character(), target = character(), arg = character(), value_expr = character(),
		detail = character(), exemption_type = character(), exemption_reason = character(), stringsAsFactors = FALSE)
}

na_audit_gate_rows = function(cases, allowlist, open_todos, scope) {
	rows = list()
	problems = na_audit_validate_allowlist(allowlist, open_todos)
	if (nrow(problems)) {
		rows[[length(rows) + 1L]] = data.frame(
			gate = "na_allowlist_invalid", severity = "hard",
			target = paste0("na_audit_allowlist.csv row ", problems$row),
			arg = allowlist$class_pattern[problems$row], value_expr = allowlist$function_pattern[problems$row],
			detail = problems$detail, exemption_type = "", exemption_reason = "", stringsAsFactors = FALSE
		)
	}
	bad_rows = unique(problems$row)
	usable = allowlist
	if (length(bad_rows)) usable$scope[bad_rows] = "__invalid__"
	if (nrow(cases)) {
		for (col in c("n_silent", "n_warned", "n_unknown", "n_declared")) {
			v = suppressWarnings(as.integer(cases[[col]]))
			v[is.na(v)] = 0L
			cases[[col]] = v
		}
		cases$input_has_missing = if ("input_has_missing" %in% names(cases)) cases$input_has_missing %in% TRUE else rep(FALSE, nrow(cases))
		cases$match = na_audit_match(scope, cases$class_name, cases$function_run, cases$context, usable, cases$warning_classes)
		cases$kind = ifelse(is.na(cases$match), "", usable$kind[cases$match])
		cases$category = ifelse(cases$n_silent > 0L, "silent", ifelse(cases$n_unknown > 0L, "unknown", ifelse(cases$n_warned > 0L, "warned", ifelse(cases$n_declared > 0L, "declared", ""))))
		cases = cases[nzchar(cases$category), , drop = FALSE]
		cases$gate = ifelse(cases$category == "declared", "declared_nonestimable_na_output",
			ifelse(cases$kind == "todo", "na_output_allowlisted_todo",
			ifelse(cases$kind == "intentional" & cases$category != "silent", "na_output_allowlisted_intentional",
			ifelse(cases$category == "silent" & cases$input_has_missing, "silent_na_output_missing_input",
			ifelse(cases$category == "silent", "silent_na_output",
			ifelse(cases$category == "unknown", "na_output_warning_status_unknown", "warned_na_output_not_allowlisted"))))))
		cases$severity = ifelse(cases$gate %in% c("silent_na_output", "silent_na_output_missing_input"), "hard",
			ifelse(cases$gate == "na_output_warning_status_unknown", "hard_later", "report"))
		cases$target = paste(cases$class_name, cases$function_run, sep = "::")
		key = paste(cases$gate, cases$target, cases$group, ifelse(is.na(cases$match), 0L, cases$match), sep = "\r")
		for (k in unique(key)) {
			g = cases[key == k, , drop = FALSE]
			m = g$match[1L]
			units = unique(g$detail_unit)
			wcls = unique(unlist(strsplit(g$warning_classes[nzchar(g$warning_classes)], ",", fixed = TRUE)))
			detail = sprintf("NA rows: %d silent, %d warned, %d warning status unknown, %d declared non-estimable; in %s%s",
				sum(g$n_silent), sum(g$n_warned, na.rm = TRUE), sum(g$n_unknown, na.rm = TRUE), sum(g$n_declared, na.rm = TRUE),
				paste(utils::head(units, 8L), collapse = ", "), if (length(units) > 8L) sprintf(" (+%d more)", length(units) - 8L) else "")
			if (length(wcls)) detail = paste0(detail, "; warnings: ", paste(wcls, collapse = ","))
			if (g$gate[1L] %in% c("silent_na_output", "silent_na_output_missing_input") && !is.na(m) && identical(usable$kind[m], "intentional")) {
				detail = paste0(detail, "; allowlisted as intentional (", usable$warning_class[m], ") but returned NA with no warning")
			}
			rows[[length(rows) + 1L]] = data.frame(
				gate = g$gate[1L], severity = g$severity[1L], target = g$target[1L], arg = "", value_expr = g$group[1L],
				detail = detail,
				exemption_type = if (is.na(m)) "" else usable$kind[m],
				exemption_reason = if (is.na(m)) "" else trimws(paste(usable$todo[m], usable$warning_class[m], usable$reason[m])),
				stringsAsFactors = FALSE
			)
		}
		used = unique(cases$match[!is.na(cases$match)])
	} else {
		used = integer()
	}
	in_scope = which(allowlist$scope %in% c(scope, "both") & !seq_len(nrow(allowlist)) %in% bad_rows)
	unused = setdiff(in_scope, used)
	if (nrow(cases) && length(unused)) {
		rows[[length(rows) + 1L]] = data.frame(
			gate = "na_allowlist_unused", severity = "report",
			target = paste0("na_audit_allowlist.csv row ", unused),
			arg = allowlist$class_pattern[unused], value_expr = allowlist$function_pattern[unused],
			detail = paste("Allowlist row matched no NA output in this artifact set:", allowlist$todo[unused], allowlist$reason[unused]),
			exemption_type = "", exemption_reason = "", stringsAsFactors = FALSE
		)
	}
	if (!length(rows)) return(na_audit_empty_rows())
	out = do.call(rbind, rows)
	row.names(out) = NULL
	out
}

# Digest rows -> gate cases (comprehensive scope).
na_audit_cases_from_digest = function(digest) {
	if (!nrow(digest)) {
		return(data.frame(class_name = character(), function_run = character(), context = character(), group = character(),
			n_silent = integer(), n_warned = integer(), n_unknown = integer(), n_declared = integer(),
			warning_classes = character(), detail_unit = character(), stringsAsFactors = FALSE))
	}
	data.frame(
		class_name = na_audit_chr(digest$class_name),
		function_run = na_audit_chr(digest$function_run),
		context = paste0("response_type=", digest$response_type, ";design=", digest$design, ";beta_T=", digest$beta_T),
		group = na_audit_chr(digest$response_type),
		n_silent = digest$n_na_silent, n_warned = digest$n_na_warned,
		n_unknown = digest$n_na_unknown, n_declared = digest$n_na_declared,
		warning_classes = na_audit_chr(digest$warning_classes),
		detail_unit = na_audit_chr(digest$design),
		stringsAsFactors = FALSE
	)
}

# Public-argument-combination result rows -> gate cases. Reads the runner's output_outcome
# column (run_public_argument_combinations.R, classify_output_outcome(), added with
# v1.0.6-TODO-97): silent_na (NA, no warning, no recorded reason) and recorded_na (all NA, no
# warning, only a reason the receiver recorded: is_nonestimable() or procedure_failure_reason,
# which the user never sees; v1.0.6-TODO-75 got through exactly this way) are silent;
# warned_na and nonfinite (Inf, or partial NA that EDI explained) are reported only.
# Returns NULL when the results predate output_outcome (nothing can be evaluated).
na_audit_cases_from_argument_results = function(results) {
	if (!"output_outcome" %in% names(results)) return(NULL)
	outcome = na_audit_chr(results$output_outcome)
	r = results[outcome %in% c("silent_na", "recorded_na", "warned_na", "nonfinite"), , drop = FALSE]
	outcome = na_audit_chr(r$output_outcome)
	fn = ifelse(nzchar(na_audit_chr(r$method_name)), na_audit_chr(r$method_name), na_audit_chr(r$function_name))
	cls = ifelse(nzchar(na_audit_chr(r$class_name)), na_audit_chr(r$class_name), na_audit_chr(r$function_name))
	keep = grepl(na_audit_estimand_function_regex, fn)
	r = r[keep, , drop = FALSE]
	data.frame(
		class_name = cls[keep],
		function_run = fn[keep],
		context = paste0("fixture=", na_audit_chr(r$fixture_id), ";args=", na_audit_chr(r$argument_signature)),
		group = na_audit_chr(r$fixture_id),
		n_silent = as.integer(outcome[keep] %in% c("silent_na", "recorded_na")),
		n_warned = as.integer(outcome[keep] %in% c("warned_na", "nonfinite")),
		n_unknown = 0L,
		n_declared = 0L,
		warning_classes = "",
		detail_unit = na_audit_chr(r$case_id),
		input_has_missing = na_audit_fixture_has_missing_input(r$fixture_id),
		stringsAsFactors = FALSE
	)
}

# TRUE for a data-shape fixture (v1.0.6-TODO-97) with missing_covariate = "yes". The id is
# "data_shape__" + the axis values joined by "__" in data_shape_fixture_axes() order (design,
# response_type, sample_size, group_sizes, censoring, missing_covariate, effect;
# public_argument_combination_fixtures.R), so missing_covariate is the 6th field. Its inputs
# are not finite, so a silent NA there goes to its own gate (silent_na_output_missing_input).
na_audit_fixture_has_missing_input = function(fixture_id) {
	id = na_audit_chr(fixture_id)
	parts = strsplit(sub("^data_shape__", "", id), "__", fixed = TRUE)
	vapply(seq_along(id), function(i) startsWith(id[i], "data_shape__") && length(parts[[i]]) == 7L && identical(parts[[i]][6L], "yes"), logical(1))
}

# ---------------------------------------------------------------------------------------
# Script mode: `Rscript na_audit_gate.R digest [results_dir]` rebuilds
# comprehensive_suite_na_audit.csv from comprehensive_tests_results_nc_*.csv (unfiltered).
# ---------------------------------------------------------------------------------------

na_audit_main = function() {
	args = commandArgs(trailingOnly = TRUE)
	if (!length(args) || !identical(args[1L], "digest")) stop("usage: Rscript na_audit_gate.R digest [results_dir]", call. = FALSE)
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
	here = dirname(normalizePath(script, mustWork = TRUE))
	results_dir = if (length(args) >= 2L) args[2L] else here
	files = list.files(results_dir, pattern = "^comprehensive_tests_results_nc_[0-9]+_[a-z]+\\.csv$", full.names = TRUE)
	if (!length(files)) stop("No comprehensive_tests_results_nc_*.csv in ", results_dir, call. = FALSE)
	# One file per response type: the newest (an older nc_8 run must not double-count).
	response = sub("^comprehensive_tests_results_nc_[0-9]+_([a-z]+)\\.csv$", "\\1", basename(files))
	files = files[order(response, -as.numeric(file.info(files)$mtime))]
	files = files[!duplicated(sub("^comprehensive_tests_results_nc_[0-9]+_([a-z]+)\\.csv$", "\\1", basename(files)))]
	message("Reading: ", paste(basename(files), collapse = ", "))
	library(data.table)
	digest = build_comprehensive_na_digest(files)
	out = file.path(here, "comprehensive_suite_na_audit.csv")
	data.table::fwrite(digest, out)  # quotes only where needed
	message("Wrote ", nrow(digest), " NA digest rows from ", length(files), " result file(s) to ", out)
}

if (identical(basename(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L] %||% "")), "na_audit_gate.R")) {
	na_audit_main()
}
