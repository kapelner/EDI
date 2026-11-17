#!/usr/bin/env Rscript
# R side of the README / vignette / article drift audit (.github/scripts/audits/readme_drift.py).
# Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 4.
#
#   Rscript readme_drift_run.R <chunks.json> <out.json>
#
# Runs one document's R chunks, in order, in this fresh session (the way knitr would, without
# knitr): every top-level expression is evaluated in one shared environment, visible values are
# printed, and printed output, messages, warnings and errors are recorded per chunk. A chunk that
# errors does not stop the document. The JSON is rewritten after every chunk, so a run the caller
# kills at its time limit still shows how far it got. Expressions that install packages or open
# a viewer are skipped (recorded as skipped). Never builds or installs EDI.

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("usage: readme_drift_run.R <chunks.json> <out.json>")
suppressPackageStartupMessages(library(jsonlite))
spec = jsonlite::fromJSON(args[1], simplifyVector = FALSE)
out_path = args[2]
max_lines = 300L
max_chars = 30000L
skip_re = "(install\\.packages|install_github|remotes::|devtools::|pak::|BiocManager::|vignette\\(|browseVignettes|browseURL|utils::browseURL|help\\(|demo\\()"

res = list(doc = spec$doc, chunks = list(), started = format(Sys.time(), tz = "UTC", usetz = TRUE))
write_out = function() {
	writeLines(jsonlite::toJSON(res, auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE, digits = NA), out_path)
}
trim = function(x) {
	if (length(x) > max_lines) x = c(utils::head(x, max_lines), sprintf("... (%d more lines)", length(x) - max_lines))
	s = paste(x, collapse = "\n")
	if (nchar(s) > max_chars) s = paste0(substr(s, 1, max_chars), "\n... (truncated)")
	s
}

`%||%` = function(a, b) if (is.null(a)) b else a
env = new.env(parent = globalenv())
grDevices::pdf(NULL)
for (ch in spec$chunks) {
	rec = list(index = ch$index, label = ch$label, start_line = ch$start_line, eval = isTRUE(ch$eval),
		output = "", messages = list(), warnings = list(), error = NULL, skipped = list(), elapsed = NA)
	if (!isTRUE(ch$eval)) {
		rec$output = "(not run: eval = FALSE)"
		res$chunks[[length(res$chunks) + 1L]] = rec
		write_out()
		next
	}
	exprs = tryCatch(parse(text = ch$code, keep.source = TRUE), error = function(e) e)
	if (inherits(exprs, "error")) {
		rec$error = paste("could not parse:", conditionMessage(exprs))
		res$chunks[[length(res$chunks) + 1L]] = rec
		write_out()
		next
	}
	srcs = vapply(attr(exprs, "srcref") %||% vector("list", length(exprs)), function(s) {
		if (is.null(s)) "" else paste(as.character(s), collapse = "\n")
	}, "")
	msgs = character()
	warns = character()
	t0 = proc.time()[["elapsed"]]
	out = utils::capture.output({
		for (k in seq_along(exprs)) {
			src = if (nzchar(srcs[k])) srcs[k] else paste(deparse(exprs[[k]]), collapse = "\n")
			if (grepl(skip_re, src)) {
				rec$skipped[[length(rec$skipped) + 1L]] = src
				next
			}
			cat(paste0("> ", gsub("\n", "\n+ ", src)), "\n", sep = "")
			err = NULL
			withCallingHandlers(
				tryCatch({
					v = withVisible(eval(exprs[[k]], env))
					if (v$visible) print(v$value)
				}, error = function(e) err <<- conditionMessage(e)),
				warning = function(w) {
					warns <<- c(warns, conditionMessage(w))
					cat("Warning: ", conditionMessage(w), "\n", sep = "")
					invokeRestart("muffleWarning")
				},
				message = function(m) {
					msgs <<- c(msgs, conditionMessage(m))
					cat(conditionMessage(m))
					invokeRestart("muffleMessage")
				}
			)
			if (!is.null(err)) {
				cat("Error: ", err, "\n", sep = "")
				rec$error = err
				break
			}
		}
	})
	rec$elapsed = proc.time()[["elapsed"]] - t0
	rec$output = trim(out)
	rec$messages = as.list(utils::head(unique(msgs), 20))
	rec$warnings = as.list(utils::head(unique(warns), 20))
	res$chunks[[length(res$chunks) + 1L]] = rec
	write_out()
}
res$finished = TRUE
write_out()
