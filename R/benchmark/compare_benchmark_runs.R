#!/usr/bin/env Rscript
# Compare two runs of the model-fit benchmark reports and flag EDI-side
# slowdowns.  Base R only: no EDI, no compile, no benchmark run.
#
# Inputs are any of the report files the two benchmark scripts write:
#   R/package_metadata/benchmark_model_fits.md          (combined R + Python)
#   R/package_metadata/benchmark_model_fits_R.html      (R only)
#   python/benchmark/benchmark_model_fits_python.html   (Python only)
# A file can also be read from git history as git:<ref>:<repo-relative path>,
# e.g. git:HEAD:R/package_metadata/benchmark_model_fits.md.
#
# Rows are matched on (part, section, first column, Response, Canonical Pkg,
# Canonical Func); a repeated key gets an occurrence suffix (#2, #3, ...).
# Part is "R" or "Python" (from the "## R Benchmarks" / "## Python Benchmarks"
# headings, else from the file name).  Section is one of models, wald,
# utility, procedures, designs (the names --sections of
# benchmark_model_fits.R uses); other tables get a slug of their heading.
#
# A row is a REGRESSION when new EDI time / old EDI time >= --ratio AND
# new - old >= --min-delta-ms, or LOST when it had an EDI time and now is NA.
# Rows matching an --allow regex (on the row label or full key) are reported
# as "explained" and do not fail the run.  --normalize-host divides each EDI
# ratio by the part's host factor (median new/old ratio of the Canonical
# Time column, which no EDI change affects) before applying --ratio.
#
# Usage (from the repo root or anywhere; paths are taken as given):
#   Rscript R/benchmark/compare_benchmark_runs.R \
#     --old git:HEAD:R/package_metadata/benchmark_model_fits.md \
#     --new R/package_metadata/benchmark_model_fits.md \
#     [--ratio 1.25] [--min-delta-ms 0.05] [--normalize-host] \
#     [--sections models,wald,...] [--part R|Python] \
#     [--allow REGEX]... [--fail-on-removed] [--tsv out.tsv]
#
# Exit status: 0 no unexplained regression, 1 at least one, 2 usage/parse error.

BENCHMARK_COMPARE_SECTION_MAP = c(
	"results" = "models",
	"point-estimate results" = "models",
	"wald test performance" = "wald",
	"wald test performance (full inference)" = "wald",
	"wald test performance / full inference" = "wald",
	"utility / math kernel performance" = "utility",
	"resampling-based inference procedure performance" = "procedures",
	"design generation performance" = "designs"
)

benchmark_compare_strip_html = function(x) {
	x = gsub("<[^>]+>", "", x, perl = TRUE)
	x = gsub("&lt;", "<", x, fixed = TRUE)
	x = gsub("&gt;", ">", x, fixed = TRUE)
	x = gsub("&quot;", "\"", x, fixed = TRUE)
	x = gsub("&#39;", "'", x, fixed = TRUE)
	x = gsub("&nbsp;", " ", x, fixed = TRUE)
	x = gsub("&amp;", "&", x, fixed = TRUE)
	trimws(gsub("[[:space:]]+", " ", x, perl = TRUE))
}

benchmark_compare_section_key = function(heading) {
	h = tolower(benchmark_compare_strip_html(heading))
	# "Point-Estimate Results (32 of 46 rows timed, 14 Baseline Gaps)" and
	# "Utility / Math Kernel Performance (14 of 14 functions timed)": the
	# counts change between runs, so drop them before matching.
	h = trimws(sub("\\s*\\([0-9]+ of [0-9]+[^)]*\\)\\s*$", "", h, perl = TRUE))
	if (h %in% names(BENCHMARK_COMPARE_SECTION_MAP)) {
		return(unname(BENCHMARK_COMPARE_SECTION_MAP[h]))
	}
	slug = gsub("[^a-z0-9]+", "-", h)
	gsub("^-+|-+$", "", slug)
}

benchmark_compare_parse_number = function(x) {
	x = gsub("[,x[:space:]]", "", x)
	out = suppressWarnings(as.numeric(x))
	out[!is.finite(out)] = NA_real_
	out
}

benchmark_compare_default_part = function(source_name) {
	if (grepl("python", basename(source_name), ignore.case = TRUE)) "Python" else "R"
}

benchmark_compare_read = function(spec) {
	if (startsWith(spec, "git:")) {
		ref_path = substring(spec, 5L)
		out = suppressWarnings(system2("git", c("show", shQuote(ref_path)), stdout = TRUE, stderr = TRUE))
		status = attr(out, "status")
		if (!is.null(status) && status != 0L) {
			stop("git show ", ref_path, " failed: ", paste(out, collapse = " "))
		}
		return(out)
	}
	if (!file.exists(spec)) stop("benchmark report not found: ", spec)
	readLines(spec, warn = FALSE)
}

benchmark_compare_match_all = function(pattern, text) {
	m = gregexpr(pattern, text, perl = TRUE)[[1L]]
	if (m[1L] == -1L) return(list(start = integer(0), text = character(0), groups = NULL))
	starts = attr(m, "capture.start")
	lens = attr(m, "capture.length")
	groups = NULL
	if (!is.null(starts) && ncol(starts) > 0L) {
		groups = matrix(substring(text, starts, starts + lens - 1L), nrow = nrow(starts))
	}
	list(start = as.integer(m), text = regmatches(text, list(m))[[1L]], groups = groups)
}

benchmark_compare_parse_table = function(table_html) {
	rows = benchmark_compare_match_all("(?s)<tr\\b[^>]*>(.*?)</tr>", table_html)
	header = NULL
	body = list()
	for (i in seq_along(rows$text)) {
		inner = rows$groups[i, 1L]
		th = benchmark_compare_match_all("(?s)<th\\b[^>]*>(.*?)</th>", inner)
		td = benchmark_compare_match_all("(?s)<td\\b[^>]*>(.*?)</td>", inner)
		if (length(td$text) == 0L && length(th$text) > 0L) {
			header = benchmark_compare_strip_html(th$groups[, 1L])
		} else if (length(td$text) > 0L) {
			body[[length(body) + 1L]] = benchmark_compare_strip_html(td$groups[, 1L])
		}
	}
	list(header = header, body = body)
}

# Parse one report into a data.frame with one row per timed table row, plus
# attributes "context" (per-part generated stamp and EDI_PORTABLE flag) and
# "selected_sections" (the R script's "_Selected sections:" line, if any).
parse_benchmark_report = function(lines, source_name = "report") {
	text = paste(lines, collapse = "\n")
	default_part = benchmark_compare_default_part(source_name)
	md_head = benchmark_compare_match_all("(?m)^(#{1,6})[ \\t]+([^\\n]*?)[ \\t]*$", text)
	html_head = benchmark_compare_match_all("(?s)<h([1-6])\\b[^>]*>(.*?)</h\\1>", text)
	tables = benchmark_compare_match_all("(?s)<table\\b.*?</table>", text)
	generated = benchmark_compare_match_all("Generated:\\s*([^_<\\n]+)", text)
	portable = benchmark_compare_match_all("Build env at build:[^E\\n]*EDI_PORTABLE=([0-9])", text)
	selected = benchmark_compare_match_all("_Selected sections:\\s*([^_\\n]+)_", text)

	events = rbind(
		data.frame(pos = md_head$start, type = rep("heading", length(md_head$start)),
		           value = if (is.null(md_head$groups)) character(0) else md_head$groups[, 2L],
		           stringsAsFactors = FALSE),
		data.frame(pos = html_head$start, type = rep("heading", length(html_head$start)),
		           value = if (is.null(html_head$groups)) character(0) else html_head$groups[, 2L],
		           stringsAsFactors = FALSE),
		data.frame(pos = tables$start, type = rep("table", length(tables$start)),
		           value = tables$text, stringsAsFactors = FALSE),
		data.frame(pos = generated$start, type = rep("generated", length(generated$start)),
		           value = if (is.null(generated$groups)) character(0) else trimws(generated$groups[, 1L]),
		           stringsAsFactors = FALSE),
		data.frame(pos = portable$start, type = rep("portable", length(portable$start)),
		           value = if (is.null(portable$groups)) character(0) else portable$groups[, 1L],
		           stringsAsFactors = FALSE)
	)
	events = events[order(events$pos), , drop = FALSE]

	part = default_part
	section = "unsectioned"
	context = list()
	out = list()
	for (i in seq_len(nrow(events))) {
		ev = events[i, ]
		if (ev$type == "heading") {
			h = benchmark_compare_strip_html(ev$value)
			if (grepl("^R Benchmarks$", h)) { part = "R"; next }
			if (grepl("^Python Benchmarks$", h)) { part = "Python"; next }
			section = benchmark_compare_section_key(h)
		} else if (ev$type == "generated") {
			if (is.null(context[[part]]$generated)) context[[part]]$generated = ev$value
		} else if (ev$type == "portable") {
			if (is.null(context[[part]]$edi_portable)) context[[part]]$edi_portable = ev$value
		} else if (ev$type == "table") {
			tab = benchmark_compare_parse_table(ev$value)
			hdr = tab$header
			if (is.null(hdr)) next
			edi_col = match("EDI Time (ms)", hdr)
			if (is.na(edi_col)) next
			can_col = match("Canonical Time (ms)", hdr)
			resp_col = match("Response", hdr)
			pkg_col = match("Canonical Pkg", hdr)
			func_col = match("Canonical Func", hdr)
			cell = function(r, j) if (is.na(j) || j > length(r)) "" else r[[j]]
			for (r in tab$body) {
				out[[length(out) + 1L]] = data.frame(
					part = part, section = section, label = cell(r, 1L),
					response = cell(r, resp_col), canonical_pkg = cell(r, pkg_col),
					canonical_func = cell(r, func_col),
					edi_ms = benchmark_compare_parse_number(cell(r, edi_col)),
					canonical_ms = benchmark_compare_parse_number(cell(r, can_col)),
					stringsAsFactors = FALSE
				)
			}
		}
	}
	df = if (length(out)) do.call(rbind, out) else data.frame(
		part = character(0), section = character(0), label = character(0),
		response = character(0), canonical_pkg = character(0), canonical_func = character(0),
		edi_ms = numeric(0), canonical_ms = numeric(0), stringsAsFactors = FALSE)
	base_key = paste(df$part, df$section, df$label, df$response, df$canonical_pkg, df$canonical_func, sep = " | ")
	occurrence = stats::ave(seq_along(base_key), base_key, FUN = seq_along)
	df$key = ifelse(occurrence > 1L, paste0(base_key, " #", occurrence), base_key)
	rownames(df) = NULL
	attr(df, "context") = context
	attr(df, "selected_sections") = if (length(selected$start)) trimws(selected$groups[1L, 1L]) else NA_character_
	attr(df, "source") = source_name
	df
}

benchmark_compare_host_factor = function(merged) {
	parts = unique(merged$part)
	vapply(parts, function(p) {
		m = merged[merged$part == p, , drop = FALSE]
		ok = is.finite(m$canonical_ms_old) & is.finite(m$canonical_ms_new) & m$canonical_ms_old > 0
		if (!any(ok)) NA_real_ else stats::median(m$canonical_ms_new[ok] / m$canonical_ms_old[ok])
	}, numeric(1L))
}

# old/new: data.frames from parse_benchmark_report().
compare_benchmark_reports = function(old, new, ratio = 1.25, min_delta_ms = 0.05,
                                     normalize_host = FALSE, allow = character(0),
                                     sections = NULL, parts = NULL) {
	stopifnot(is.numeric(ratio), length(ratio) == 1L, ratio > 1,
	          is.numeric(min_delta_ms), length(min_delta_ms) == 1L, min_delta_ms >= 0)
	keep = function(d) {
		if (!is.null(sections)) d = d[d$section %in% sections, , drop = FALSE]
		if (!is.null(parts)) d = d[d$part %in% parts, , drop = FALSE]
		d
	}
	old = keep(old)
	new = keep(new)
	cols = c("key", "part", "section", "label", "edi_ms", "canonical_ms")
	merged = merge(old[, cols], new[, cols], by = c("key", "part", "section", "label"),
	               all = TRUE, suffixes = c("_old", "_new"))
	in_old = merged$key %in% old$key
	in_new = merged$key %in% new$key
	host = benchmark_compare_host_factor(merged[in_old & in_new, , drop = FALSE])
	hf = if (normalize_host) unname(host[merged$part]) else rep(1, nrow(merged))
	hf[!is.finite(hf) | hf <= 0] = 1

	o = merged$edi_ms_old
	n = merged$edi_ms_new
	merged$ratio = ifelse(is.finite(o) & is.finite(n) & o > 0, n / o, NA_real_)
	merged$adj_ratio = merged$ratio / hf
	merged$delta_ms = n - o * hf
	status = rep("ok", nrow(merged))
	status[!in_new] = "removed"
	status[!in_old] = "added"
	both = in_old & in_new
	status[both & !is.finite(o) & !is.finite(n)] = "na-both"
	status[both & is.finite(o) & !is.finite(n)] = "lost"
	status[both & !is.finite(o) & is.finite(n)] = "gained"
	timed = both & is.finite(merged$adj_ratio)
	status[timed & merged$adj_ratio >= ratio & merged$delta_ms >= min_delta_ms] = "regression"
	status[timed & merged$adj_ratio <= 1 / ratio & -merged$delta_ms >= min_delta_ms] = "improved"
	allowed = rep(FALSE, nrow(merged))
	for (pat in allow) {
		allowed = allowed | grepl(pat, merged$label, perl = TRUE) | grepl(pat, merged$key, perl = TRUE)
	}
	merged$explained = allowed & status %in% c("regression", "lost")
	merged$status = status
	merged = merged[order(merged$part, merged$section, merged$label, merged$key), , drop = FALSE]
	rownames(merged) = NULL
	failing = merged$status %in% c("regression", "lost") & !merged$explained
	list(
		rows = merged,
		host_factor = host,
		n_regressions = sum(failing),
		n_explained = sum(merged$explained),
		n_removed = sum(merged$status == "removed"),
		settings = list(ratio = ratio, min_delta_ms = min_delta_ms, normalize_host = normalize_host,
		                allow = allow, sections = sections, parts = parts)
	)
}

format_benchmark_comparison = function(result, old = NULL, new = NULL, show_ok = FALSE) {
	r = result$rows
	s = result$settings
	fmt = function(x) ifelse(is.finite(x), formatC(x, format = "f", digits = 2), "NA")
	lines = c(
		sprintf("Benchmark comparison: flag EDI time ratio >= %.2fx and delta >= %g ms%s",
		        s$ratio, s$min_delta_ms, if (s$normalize_host) " (host-normalized)" else ""),
		if (!is.null(old)) sprintf("  old: %s", attr(old, "source")),
		if (!is.null(new)) sprintf("  new: %s", attr(new, "source"))
	)
	for (side in list(list("old", old), list("new", new))) {
		d = side[[2L]]
		if (is.null(d)) next
		ctx = attr(d, "context")
		for (p in names(ctx)) {
			lines = c(lines, sprintf("  %s %s: generated %s; EDI_PORTABLE=%s", side[[1L]], p,
			                         if (is.null(ctx[[p]]$generated)) "?" else ctx[[p]]$generated,
			                         if (is.null(ctx[[p]]$edi_portable)) "?" else ctx[[p]]$edi_portable))
		}
		sel = attr(d, "selected_sections")
		if (!is.na(sel)) lines = c(lines, sprintf("  %s selected sections: %s", side[[1L]], sel))
	}
	if (!is.null(old) && !is.null(new)) {
		co = attr(old, "context"); cn = attr(new, "context")
		for (p in intersect(names(co), names(cn))) {
			if (!is.null(co[[p]]$edi_portable) && !is.null(cn[[p]]$edi_portable) &&
			    !identical(co[[p]]$edi_portable, cn[[p]]$edi_portable)) {
				lines = c(lines, sprintf("  WARNING: %s build flags differ (EDI_PORTABLE %s -> %s); timings are not like-for-like.",
				                         p, co[[p]]$edi_portable, cn[[p]]$edi_portable))
			}
		}
	}
	for (p in names(result$host_factor)) {
		lines = c(lines, sprintf("  host factor %s (median canonical new/old): %s", p, fmt(result$host_factor[[p]])))
	}
	tab = table(factor(r$status, levels = c("ok", "improved", "regression", "lost", "gained", "added", "removed", "na-both")))
	lines = c(lines, paste0("  rows: ", paste(names(tab), as.integer(tab), sep = "=", collapse = ", ")))
	show = r$status %in% c("regression", "lost", "improved", "gained", "added", "removed") | show_ok
	if (any(show)) {
		lines = c(lines, "", sprintf("%-11s %-6s %-10s %10s %10s %7s  %s", "status", "part", "section", "old_ms", "new_ms", "ratio", "row"))
		rs = r[show, , drop = FALSE]
		ord = order(match(rs$status, c("regression", "lost", "removed", "added", "gained", "improved", "ok")), -ifelse(is.finite(rs$adj_ratio), rs$adj_ratio, 0))
		rs = rs[ord, , drop = FALSE]
		for (i in seq_len(nrow(rs))) {
			st = rs$status[i]
			if (rs$explained[i]) st = paste0(st, "*")
			row_label = sub("^[^|]+\\|[^|]+\\| ", "", rs$key[i])
			lines = c(lines, sprintf("%-11s %-6s %-10s %10s %10s %7s  %s", st, rs$part[i], rs$section[i],
			                         fmt(rs$edi_ms_old[i]), fmt(rs$edi_ms_new[i]),
			                         ifelse(is.finite(rs$adj_ratio[i]), sprintf("%.2fx", rs$adj_ratio[i]), "-"),
			                         row_label))
		}
		if (any(rs$explained)) lines = c(lines, "  (* = matched an --allow pattern; does not fail the run)")
	}
	lines = c(lines, "", sprintf("RESULT: %s (%d unexplained regression/lost row(s), %d explained, %d removed)",
	                             if (result$n_regressions > 0L) "REGRESSIONS FOUND" else "PASS",
	                             result$n_regressions, result$n_explained, result$n_removed))
	lines
}

benchmark_compare_main = function(args = commandArgs(trailingOnly = TRUE)) {
	usage = "usage: compare_benchmark_runs.R --old FILE|git:REF:PATH --new FILE|git:REF:PATH [--ratio 1.25] [--min-delta-ms 0.05] [--normalize-host] [--sections a,b] [--part R|Python] [--allow REGEX]... [--fail-on-removed] [--show-ok] [--tsv FILE]"
	opts = list(ratio = 1.25, min_delta_ms = 0.05, normalize_host = FALSE, allow = character(0),
	            sections = NULL, parts = NULL, fail_on_removed = FALSE, show_ok = FALSE, tsv = NULL,
	            old = NULL, new = NULL)
	i = 1L
	value = function() {
		if (i + 1L > length(args)) stop("missing value for ", args[i])
		args[i + 1L]
	}
	while (i <= length(args)) {
		a = args[i]
		if (grepl("^--[a-z-]+=", a)) {
			args = c(args[seq_len(i - 1L)], sub("=.*$", "", a), sub("^[^=]*=", "", a), args[-seq_len(i)])
			a = args[i]
		}
		switch(a,
			"--old" = { opts$old = value(); i = i + 1L },
			"--new" = { opts$new = value(); i = i + 1L },
			"--ratio" = { opts$ratio = as.numeric(value()); i = i + 1L },
			"--min-delta-ms" = { opts$min_delta_ms = as.numeric(value()); i = i + 1L },
			"--normalize-host" = { opts$normalize_host = TRUE },
			"--allow" = { opts$allow = c(opts$allow, value()); i = i + 1L },
			"--sections" = { opts$sections = trimws(strsplit(value(), ",", fixed = TRUE)[[1L]]); i = i + 1L },
			"--part" = { opts$parts = trimws(strsplit(value(), ",", fixed = TRUE)[[1L]]); i = i + 1L },
			"--fail-on-removed" = { opts$fail_on_removed = TRUE },
			"--show-ok" = { opts$show_ok = TRUE },
			"--tsv" = { opts$tsv = value(); i = i + 1L },
			"--help" = { cat(usage, "\n"); return(0L) },
			stop("unknown argument: ", a)
		)
		i = i + 1L
	}
	if (is.null(opts$old) || is.null(opts$new)) stop(usage)
	if (!is.finite(opts$ratio) || !is.finite(opts$min_delta_ms)) stop("--ratio and --min-delta-ms must be numbers")
	old = parse_benchmark_report(benchmark_compare_read(opts$old), opts$old)
	new = parse_benchmark_report(benchmark_compare_read(opts$new), opts$new)
	if (nrow(old) == 0L) stop("no timing tables found in ", opts$old)
	if (nrow(new) == 0L) stop("no timing tables found in ", opts$new)
	res = compare_benchmark_reports(old, new, ratio = opts$ratio, min_delta_ms = opts$min_delta_ms,
	                                normalize_host = opts$normalize_host, allow = opts$allow,
	                                sections = opts$sections, parts = opts$parts)
	cat(format_benchmark_comparison(res, old, new, show_ok = opts$show_ok), sep = "\n")
	if (!is.null(opts$tsv)) {
		utils::write.table(res$rows, opts$tsv, sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
		cat("Wrote ", opts$tsv, "\n", sep = "")
	}
	failed = res$n_regressions > 0L || (opts$fail_on_removed && res$n_removed > 0L)
	if (failed) 1L else 0L
}

if (sys.nframe() == 0L) {
	status = tryCatch(benchmark_compare_main(), error = function(e) {
		message("compare_benchmark_runs.R: ", conditionMessage(e))
		2L
	})
	quit(save = "no", status = status)
}
