#!/usr/bin/env Rscript
# Regression check for the path audit (path_audits.html +
# path_audits_nonestimability_defaults.csv) against a committed baseline.
#
# path_audits_source.R renders path_audits.html from (a) the live registry of
# the INSTALLED EDI package (theoretical support: NTS / not implemented /
# N/A cells), (b) the slow-path registries (SLOW cells) and (c) the pooled
# non-filtered comprehensive_tests_results_nc_*.csv sitting next to the
# script (observed estimability per class x method). This script compares a
# newly generated pair of outputs with the versions at a git ref (default
# HEAD) and classifies every cell / row as worse, improved, changed or
# unchanged:
#
#   HTML grid cells, keyed by (table, class, row label = Response or Formula,
#   column path such as "Exact > Randomization > vanilla > ci"):
#     support_removed    attempted/SLOW/guaranteed -> NTS / N/A / not implemented
#     cell_removed       the cell (or the whole class row) is gone
#     guarantee_lost     dark-green "guaranteed" -> anything else supported
#     became_slow        attempted -> SLOW (the path is no longer exercised)
#     lost_observations  observed rate -> "unknown" (no result rows any more)
#     estimability_drop  observed estimable rate fell by more than --rate-tol
#                        (only when both sides have at least --min-n rows),
#                        or fell to exactly 0% from above 0%
#   defaults CSV rows, keyed by (base_class, function_run):
#     row_removed / became_design_refused / nonestimable_rate_up (> --rate-tol,
#     both n >= --min-n, or newly 100% nonestimable)
# The mirror-image transitions are reported as improved; any other state
# change (e.g. NTS <-> not implemented) is "changed" and never fails.
#
# A worsening fails the check (exit 1) unless it matches a row of the
# allowlist (default path_audits_regression_allowlist.csv next to this file):
# every intentional 1.0.5 change that may legitimately make a cell worse is
# listed there with its TODO and reason. Matching: `source` (cells, defaults
# or *), and the regexes class_regex / row_regex / column_regex (perl, empty
# row_regex = any row; class_regex and column_regex must be non-empty so an
# entry can never be a blanket pass), plus `kinds` (a |-separated list of the
# kinds above, or *). Class names are matched WITHOUT the "Inference" prefix
# (the HTML shows them that way); for the defaults CSV the column is the
# function_run and row_regex is ignored (its rows pool every response type),
# so an entry whose class_regex is broad and whose precision comes from
# row_regex must use source = cells. Allowlist entries that matched
# nothing are listed (informational, they do not fail the check).
#
# Counting-rule changes: path_audits_source.R stamps the version of its row-
# counting rule (PATH_AUDIT_COUNTING_RULE) into the HTML (an
# "edi-path-audit-counting-rule" comment) and the defaults CSV
# (`counting_rule` column); outputs without a stamp are rule "pre-2026-10-23".
# An allowlist row with a non-empty `counting_rule_change` column applies only
# when the baseline's rule differs from the new outputs' rule AND the new rule
# equals that value, and it may only list the rate kinds (estimability_drop,
# nonestimable_rate_up). It is one-time by construction: once outputs written
# under the new rule are committed as the baseline, both sides carry the same
# rule and the row matches nothing. Such a row is the only kind allowed a
# broad class_regex outside `source = cells`.
#
# Note on the defaults CSV: path_audits_source.R rewrites it only when the
# pooled result row count exceeds the cached snapshot's (a high-water mark)
# or the snapshot was written under another counting rule, so after a
# pruning or a partial merge it may legitimately stay byte-equal
# to the baseline. The HTML is always regenerated and carries the rates of
# every rendered cell, so the HTML comparison is the primary check.
#
# Usage (from anywhere):
#   Rscript R/package_tests/compare_path_audits.R \
#     [--baseline-ref HEAD] [--baseline-dir DIR] [--new-dir R/package_tests] \
#     [--allowlist FILE] [--rate-tol 0.02] [--min-n 30] [--out-dir DIR]
# --baseline-dir reads the baseline files from a directory instead of git.
# --out-dir writes path_audits_compare_{cells,defaults}.csv (every non-
# unchanged row with its classification and allowlist id).
# Exit status: 0 = no unallowlisted worsening, 1 = at least one, 2 = usage or
# input error. Base R only, no EDI install needed (it only reads files).

pa_html_unescape = function(x) {
	x = gsub("<[^>]*>", "", x)
	x = gsub("&delta;", "\u03b4", x, fixed = TRUE)
	x = gsub("&lt;", "<", x, fixed = TRUE)
	x = gsub("&gt;", ">", x, fixed = TRUE)
	x = gsub("&quot;", "\"", x, fixed = TRUE)
	x = gsub("&#39;", "'", x, fixed = TRUE)
	x = gsub("&amp;", "&", x, fixed = TRUE)
	trimws(x)
}

pa_attr = function(attrs, name) {
	m = regmatches(attrs, regexec(paste0("\\b", name, "=\"([^\"]*)\""), attrs))
	vapply(m, function(z) if (length(z) == 2L) z[2L] else NA_character_, character(1))
}

# All <tr> rows of one <table> chunk, each as a list of cells (tag, attrs,
# inner html, colspan, rowspan) plus the row's class attribute.
pa_parse_rows = function(table_html) {
	trs = regmatches(table_html, gregexpr("(?s)<tr\\b[^>]*>.*?</tr>", table_html, perl = TRUE))[[1L]]
	lapply(trs, function(tr) {
		open = regmatches(tr, regexpr("^<tr\\b[^>]*>", tr, perl = TRUE))
		cells_raw = regmatches(tr, gregexpr("(?s)<(td|th)\\b([^>]*)>(.*?)</\\1>", tr, perl = TRUE))[[1L]]
		cells = lapply(cells_raw, function(cell) {
			m = regmatches(cell, regexec("(?s)^<(td|th)\\b([^>]*)>(.*?)</(td|th)>$", cell, perl = TRUE))[[1L]]
			attrs = m[3L]
			cs = suppressWarnings(as.integer(pa_attr(attrs, "colspan")))
			rs = suppressWarnings(as.integer(pa_attr(attrs, "rowspan")))
			list(tag = m[2L], attrs = attrs, inner = m[4L],
				colspan = if (is.na(cs)) 1L else cs, rowspan = if (is.na(rs)) 1L else rs)
		})
		list(class = pa_attr(open, "class"), cells = cells)
	})
}

# Lay rows out on a grid honouring colspan/rowspan. Returns a list of rows,
# each a list of cells indexed by grid column (a spanning cell is repeated).
pa_grid = function(rows) {
	pending = list()   # by column index: list(cell, remaining)
	out = vector("list", length(rows))
	for (ri in seq_along(rows)) {
		placed = list()
		col = 1L
		take_pending = function() {
			while (col <= length(pending) && !is.null(pending[[col]]) && pending[[col]]$remaining > 0L) {
				placed[[col]] <<- pending[[col]]$cell
				pending[[col]]$remaining <<- pending[[col]]$remaining - 1L
				col <<- col + 1L
			}
		}
		for (cell in rows[[ri]]$cells) {
			take_pending()
			for (k in seq_len(cell$colspan)) {
				placed[[col]] = cell
				if (cell$rowspan > 1L) {
					if (length(pending) < col) length(pending) = col
					pending[[col]] = list(cell = cell, remaining = cell$rowspan - 1L)
				}
				col = col + 1L
			}
		}
		take_pending()
		out[[ri]] = placed
	}
	out
}

pa_cell_state = function(title, text) {
	t = if (is.na(title)) "" else title
	rate = NA_real_; nonest = NA_integer_; n = NA_integer_
	state = if (startsWith(t, "Theoretically guaranteed")) "guaranteed"
		else if (startsWith(t, "Attempted, empirical estimability unknown")) "unknown"
		else if (grepl("^Attempted, .* estimable observed", t)) "observed"
		else if (startsWith(t, "Skipped or lightly tested")) "slow"
		else if (startsWith(t, "Not theoretically supported")) "nts"
		else if (startsWith(t, "Not applicable")) "na"
		else if (startsWith(t, "Not implemented")) "not_implemented"
		else if (!nzchar(t) && !nzchar(text)) "blank"
		else paste0("other:", if (nzchar(t)) t else text)
	if (identical(state, "observed")) {
		r = regmatches(t, regexec("approx estimable rate ([0-9.]+)%", t))[[1L]]
		if (length(r) == 2L) rate = as.numeric(r[2L]) / 100
		k = regmatches(t, regexec("\\(([0-9]+)/([0-9]+) rows\\)", t))[[1L]]
		if (length(k) == 3L) { nonest = as.integer(k[2L]); n = as.integer(k[3L]) }
	}
	list(state = state, rate = rate, nonestimable = nonest, n = n)
}

# Long table of every data cell of every audit grid table in the HTML.
parse_path_audits_html = function(html) {
	if (length(html) > 1L) html = paste(html, collapse = "\n")
	h3 = gregexpr("(?s)<h3\\b[^>]*>.*?</h3>", html, perl = TRUE)[[1L]]
	h3_pos = if (h3[1L] > 0L) as.integer(h3) else integer()
	h3_txt = if (length(h3_pos)) pa_html_unescape(regmatches(html, list(h3))[[1L]]) else character()
	tab = gregexpr("(?s)<table\\b.*?</table>", html, perl = TRUE)[[1L]]
	if (tab[1L] < 0L) stop("no <table> found in path audit HTML")
	tables = regmatches(html, list(tab))[[1L]]
	pieces = list()
	for (ti in seq_along(tables)) {
		rows = pa_parse_rows(tables[[ti]])
		row_class = vapply(rows, function(r) if (is.na(r$class)) "" else r$class, character(1))
		hdr = grepl("^hdr[0-9]+$", row_class)
		if (!any(hdr)) next   # e.g. the "<1% Estimable Paths" list
		before = h3_pos[h3_pos < tab[ti]]
		title = if (length(before)) h3_txt[length(before)] else paste0("table", ti)
		grid = pa_grid(rows)
		hgrid = grid[hdr]
		ncol = max(vapply(hgrid, length, integer(1)))
		col_names = vapply(seq_len(ncol), function(j) {
			labs = vapply(hgrid, function(r) if (j <= length(r) && !is.null(r[[j]])) pa_html_unescape(r[[j]]$inner) else "", character(1))
			labs = labs[nzchar(labs)]
			labs = labs[c(TRUE, labs[-1L] != labs[-length(labs)])]
			paste(labs, collapse = " > ")
		}, character(1))
		dup = duplicated(col_names) | duplicated(col_names, fromLast = TRUE)
		if (any(dup)) {
			seen = ave(seq_along(col_names), col_names, FUN = seq_along)
			col_names[dup] = paste0(col_names[dup], " #", seen[dup])
		}
		section = ""
		for (ri in which(!hdr)) {
			if (identical(row_class[ri], "section-row")) {
				section = pa_html_unescape(rows[[ri]]$cells[[1L]]$inner)
				next
			}
			cells = grid[[ri]]
			if (length(cells) < 3L) next
			cls = pa_html_unescape(cells[[1L]]$inner)
			row_label = pa_html_unescape(cells[[2L]]$inner)
			states = lapply(3:length(cells), function(j) {
				cell = cells[[j]]
				if (is.null(cell)) return(pa_cell_state(NA_character_, ""))
				pa_cell_state(pa_html_unescape(pa_attr(cell$attrs, "title")), pa_html_unescape(cell$inner))
			})
			pieces[[length(pieces) + 1L]] = data.frame(
				table = title, section = section, class = cls, row_label = row_label,
				column = col_names[3:length(cells)],
				state = vapply(states, `[[`, character(1), "state"),
				rate = vapply(states, `[[`, numeric(1), "rate"),
				nonestimable = vapply(states, `[[`, integer(1), "nonestimable"),
				n = vapply(states, `[[`, integer(1), "n"),
				stringsAsFactors = FALSE
			)
		}
	}
	if (!length(pieces)) stop("no audit grid table found in path audit HTML")
	out = do.call(rbind, pieces)
	key = paste(out$table, out$class, out$row_label, out$column, sep = "||")
	if (anyDuplicated(key)) stop("duplicate cell keys in path audit HTML: ", paste(utils::head(unique(key[duplicated(key)]), 5L), collapse = "; "))
	rownames(out) = NULL
	out
}

read_path_audits_defaults = function(text) {
	d = utils::read.csv(text = paste(text, collapse = "\n"), stringsAsFactors = FALSE)
	need = c("base_class", "function_run", "n", "nonestimable", "rate")
	miss = setdiff(need, names(d))
	if (length(miss)) stop("defaults CSV lacks columns: ", paste(miss, collapse = ", "))
	if (!"design_refused" %in% names(d)) d$design_refused = FALSE
	d$design_refused = as.logical(d$design_refused) %in% TRUE
	d$n = as.numeric(d$n); d$nonestimable = as.numeric(d$nonestimable); d$rate = as.numeric(d$rate)
	d[, c(need, "design_refused")]
}

PA_RULE_UNSTAMPED = "pre-2026-10-23"
PA_RATE_KINDS = c("estimability_drop", "nonestimable_rate_up")

pa_html_counting_rule = function(html) {
	m = regmatches(html, regexpr("edi-path-audit-counting-rule: *[^ >]+", html))
	if (!length(m)) return(PA_RULE_UNSTAMPED)
	sub("^edi-path-audit-counting-rule: *", "", m[1L])
}

pa_defaults_counting_rule = function(text) {
	d = utils::read.csv(text = paste(text, collapse = "\n"), stringsAsFactors = FALSE, colClasses = "character")
	if (!"counting_rule" %in% names(d) || !nrow(d)) return(PA_RULE_UNSTAMPED)
	r = unique(d$counting_rule[nzchar(d$counting_rule)])
	if (!length(r)) PA_RULE_UNSTAMPED else r[1L]
}

PA_SUPPORTED = c("guaranteed", "observed", "unknown", "slow")
PA_UNSUPPORTED = c("nts", "na", "not_implemented")

pa_classify_cell = function(b, nw, b_rate, n_rate, b_n, n_n, rate_tol, min_n) {
	if (is.na(nw)) return(c("worse", "cell_removed"))
	if (is.na(b)) return(c("improved", "cell_added"))
	if (identical(b, nw)) {
		if (!identical(b, "observed")) return(c("unchanged", ""))
		if (is.na(b_rate) || is.na(n_rate)) return(c("unchanged", ""))
		d = n_rate - b_rate
		if (n_rate == 0 && b_rate > 0) return(c("worse", "estimability_drop"))
		big = !is.na(b_n) && !is.na(n_n) && b_n >= min_n && n_n >= min_n
		if (big && d < -rate_tol) return(c("worse", "estimability_drop"))
		if (b_rate == 0 && n_rate > 0) return(c("improved", "estimability_gain"))
		if (big && d > rate_tol) return(c("improved", "estimability_gain"))
		return(c("unchanged", ""))
	}
	if (b %in% PA_SUPPORTED && nw %in% PA_UNSUPPORTED) return(c("worse", "support_removed"))
	if (b %in% PA_UNSUPPORTED && nw %in% PA_SUPPORTED) return(c("improved", "support_added"))
	if (identical(b, "guaranteed")) return(c("worse", "guarantee_lost"))
	if (identical(nw, "guaranteed")) return(c("improved", "guarantee_gained"))
	if (nw == "slow" && b %in% c("observed", "unknown")) return(c("worse", "became_slow"))
	if (b == "slow" && nw %in% c("observed", "unknown")) return(c("improved", "slow_lifted"))
	if (b == "observed" && nw == "unknown") return(c("worse", "lost_observations"))
	if (b == "unknown" && nw == "observed") return(c("improved", "gained_observations"))
	c("changed", "state_changed")
}

compare_path_audit_cells = function(base, new, rate_tol = 0.02, min_n = 30) {
	key = function(d) paste(d$table, d$class, d$row_label, d$column, sep = "||")
	base$key = key(base); new$key = key(new)
	keys = union(base$key, new$key)
	bi = match(keys, base$key); ni = match(keys, new$key)
	pick = function(d, i, col) d[[col]][i]
	out = data.frame(
		table = ifelse(is.na(bi), pick(new, ni, "table"), pick(base, bi, "table")),
		class = ifelse(is.na(bi), pick(new, ni, "class"), pick(base, bi, "class")),
		row_label = ifelse(is.na(bi), pick(new, ni, "row_label"), pick(base, bi, "row_label")),
		column = ifelse(is.na(bi), pick(new, ni, "column"), pick(base, bi, "column")),
		base_state = pick(base, bi, "state"), new_state = pick(new, ni, "state"),
		base_rate = pick(base, bi, "rate"), new_rate = pick(new, ni, "rate"),
		base_n = pick(base, bi, "n"), new_n = pick(new, ni, "n"),
		stringsAsFactors = FALSE
	)
	cls = mapply(pa_classify_cell, out$base_state, out$new_state, out$base_rate, out$new_rate,
		out$base_n, out$new_n, MoreArgs = list(rate_tol = rate_tol, min_n = min_n), SIMPLIFY = FALSE, USE.NAMES = FALSE)
	out$change = vapply(cls, `[`, character(1), 1L)
	out$kind = vapply(cls, `[`, character(1), 2L)
	out
}

compare_path_audit_defaults = function(base, new, rate_tol = 0.02, min_n = 30) {
	key = function(d) paste(d$base_class, d$function_run, sep = "||")
	kb = key(base); kn = key(new)
	keys = union(kb, kn)
	bi = match(keys, kb); ni = match(keys, kn)
	out = data.frame(
		class = ifelse(is.na(bi), new$base_class[ni], base$base_class[bi]),
		row_label = "",
		column = ifelse(is.na(bi), new$function_run[ni], base$function_run[bi]),
		base_n = base$n[bi], new_n = new$n[ni],
		base_rate = base$rate[bi], new_rate = new$rate[ni],
		base_refused = base$design_refused[bi], new_refused = new$design_refused[ni],
		stringsAsFactors = FALSE
	)
	change = character(nrow(out)); kind = character(nrow(out))
	for (i in seq_len(nrow(out))) {
		r = out[i, ]
		res = if (is.na(bi[i])) c("improved", "row_added")
			else if (is.na(ni[i])) c("worse", "row_removed")
			else if (isTRUE(r$new_refused) && !isTRUE(r$base_refused)) c("worse", "became_design_refused")
			else if (isTRUE(r$base_refused) && !isTRUE(r$new_refused)) c("improved", "design_refusal_lifted")
			else if (is.na(r$base_rate) || is.na(r$new_rate)) c("unchanged", "")
			else {
				d = r$new_rate - r$base_rate
				big = r$base_n >= min_n && r$new_n >= min_n
				if (r$new_rate == 1 && r$base_rate < 1) c("worse", "nonestimable_rate_up")
				else if (big && d > rate_tol) c("worse", "nonestimable_rate_up")
				else if (r$base_rate == 1 && r$new_rate < 1) c("improved", "nonestimable_rate_down")
				else if (big && d < -rate_tol) c("improved", "nonestimable_rate_down")
				else c("unchanged", "")
			}
		change[i] = res[1L]; kind[i] = res[2L]
	}
	out$change = change; out$kind = kind
	out
}

read_path_audit_allowlist = function(path) {
	if (is.null(path) || !nzchar(path) || !file.exists(path)) {
		return(data.frame(id = character(), source = character(), class_regex = character(), row_regex = character(),
			column_regex = character(), kinds = character(), tracked_in = character(), reason = character(),
			counting_rule_change = character(), stringsAsFactors = FALSE))
	}
	a = utils::read.csv(path, stringsAsFactors = FALSE, colClasses = "character", na.strings = character())
	need = c("id", "source", "class_regex", "row_regex", "column_regex", "kinds", "tracked_in", "reason")
	miss = setdiff(need, names(a))
	if (length(miss)) stop("allowlist lacks columns: ", paste(miss, collapse = ", "))
	bad = !nzchar(trimws(a$class_regex)) | !nzchar(trimws(a$column_regex)) | !nzchar(trimws(a$reason)) | !nzchar(trimws(a$tracked_in))
	if (any(bad)) stop("allowlist rows need non-empty class_regex, column_regex, tracked_in and reason: ", paste(a$id[bad], collapse = ", "))
	if (anyDuplicated(a$id)) stop("duplicate allowlist ids: ", paste(unique(a$id[duplicated(a$id)]), collapse = ", "))
	if (!all(a$source %in% c("cells", "defaults", "*"))) stop("allowlist source must be cells, defaults or *")
	if (!"counting_rule_change" %in% names(a)) a$counting_rule_change = rep("", nrow(a))
	a$counting_rule_change = trimws(a$counting_rule_change)
	rule_rows = nzchar(a$counting_rule_change)
	if (any(rule_rows)) {
		ok = vapply(strsplit(a$kinds[rule_rows], "|", fixed = TRUE), function(k) all(trimws(k) %in% PA_RATE_KINDS), logical(1))
		if (!all(ok)) stop("counting_rule_change rows may only list the rate kinds (", paste(PA_RATE_KINDS, collapse = ", "), "): ",
			paste(a$id[rule_rows][!ok], collapse = ", "))
	}
	a
}

# Adds `allowlisted` (id of the first matching entry, "" if none) to the
# worse rows of a comparison; returns list(cmp, used_ids). `rule_change` is
# the new counting rule when it differs from the baseline's, else NULL; rows
# with a non-empty counting_rule_change apply only when it equals that value.
apply_path_audit_allowlist = function(cmp, allow, source, rule_change = NULL) {
	cmp$allowlisted = ""
	used = character()
	if (!nrow(cmp) || !nrow(allow)) return(list(cmp = cmp, used = used))
	cls = sub("^Inference", "", cmp$class)
	for (i in which(cmp$change == "worse")) {
		for (j in seq_len(nrow(allow))) {
			a = allow[j, ]
			if (!(a$source %in% c("*", source))) next
			crc = if (is.null(a$counting_rule_change)) "" else a$counting_rule_change
			if (!is.na(crc) && nzchar(crc) && !identical(crc, rule_change)) next
			kinds = trimws(strsplit(a$kinds, "|", fixed = TRUE)[[1L]])
			if (!("*" %in% kinds || cmp$kind[i] %in% kinds)) next
			if (!grepl(a$class_regex, cls[i], perl = TRUE)) next
			if (!grepl(a$column_regex, cmp$column[i], perl = TRUE)) next
			if (identical(source, "cells") && nzchar(a$row_regex) && !grepl(a$row_regex, cmp$row_label[i], perl = TRUE)) next
			cmp$allowlisted[i] = a$id
			used = c(used, a$id)
			break
		}
	}
	list(cmp = cmp, used = unique(used))
}

pa_git_show = function(repo, ref, rel) {
	out = suppressWarnings(system2("git", c("-C", repo, "show", paste0(ref, ":", rel)), stdout = TRUE, stderr = FALSE))
	st = attr(out, "status")
	if (!is.null(st) && st != 0L) stop(sprintf("git show %s:%s failed (status %s)", ref, rel, st))
	out
}

pa_summary_lines = function(cmp, label) {
	tab = table(factor(cmp$change, levels = c("worse", "improved", "changed", "unchanged")))
	c(sprintf("%s: %s", label, paste(sprintf("%s=%d", names(tab), as.integer(tab)), collapse = " ")),
		if (any(cmp$change == "worse")) {
			k = table(cmp$kind[cmp$change == "worse"], ifelse(nzchar(cmp$allowlisted[cmp$change == "worse"]), "allowlisted", "UNALLOWLISTED"))
			sprintf("  worse %-24s %s", rownames(k), apply(k, 1L, function(z) paste(sprintf("%s=%d", colnames(k), z), collapse = " ")))
		})
}

run_compare_path_audits = function(args = commandArgs(trailingOnly = TRUE)) {
	opt = list(baseline_ref = "HEAD", baseline_dir = NULL, new_dir = NULL, allowlist = NULL,
		rate_tol = 0.02, min_n = 30, out_dir = NULL, max_print = 60L)
	i = 1L
	while (i <= length(args)) {
		a = args[i]
		val = if (i < length(args)) args[i + 1L] else NA_character_
		switch(a,
			"--baseline-ref" = { opt$baseline_ref = val; i = i + 1L },
			"--baseline-dir" = { opt$baseline_dir = val; i = i + 1L },
			"--new-dir" = { opt$new_dir = val; i = i + 1L },
			"--allowlist" = { opt$allowlist = val; i = i + 1L },
			"--rate-tol" = { opt$rate_tol = as.numeric(val); i = i + 1L },
			"--min-n" = { opt$min_n = as.numeric(val); i = i + 1L },
			"--out-dir" = { opt$out_dir = val; i = i + 1L },
			"--max-print" = { opt$max_print = as.integer(val); i = i + 1L },
			"--help" = { cat("see the header of compare_path_audits.R\n"); return(0L) },
			{ message("unknown argument: ", a); return(2L) }
		)
		if (!is.null(val) && is.na(val) && a != "--help") { message("missing value for ", a); return(2L) }
		i = i + 1L
	}
	script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]
	here = if (is.na(script_arg)) file.path("R", "package_tests") else dirname(normalizePath(sub("^--file=", "", script_arg)))
	if (is.null(opt$new_dir)) opt$new_dir = here
	if (is.null(opt$allowlist)) opt$allowlist = file.path(here, "path_audits_regression_allowlist.csv")
	html_name = "path_audits.html"; csv_name = "path_audits_nonestimability_defaults.csv"
	res = tryCatch({
		if (!is.null(opt$baseline_dir)) {
			base_html = readLines(file.path(opt$baseline_dir, html_name), warn = FALSE, encoding = "UTF-8")
			base_csv = readLines(file.path(opt$baseline_dir, csv_name), warn = FALSE)
			base_label = opt$baseline_dir
		} else {
			repo = system2("git", c("-C", here, "rev-parse", "--show-toplevel"), stdout = TRUE)
			rel = sub(paste0("^", normalizePath(repo), "/?"), "", normalizePath(here))
			base_html = pa_git_show(repo, opt$baseline_ref, file.path(rel, html_name))
			base_csv = pa_git_show(repo, opt$baseline_ref, file.path(rel, csv_name))
			base_label = paste0("git ", opt$baseline_ref)
		}
		new_html = readLines(file.path(opt$new_dir, html_name), warn = FALSE, encoding = "UTF-8")
		new_csv = readLines(file.path(opt$new_dir, csv_name), warn = FALSE)
		allow = read_path_audit_allowlist(opt$allowlist)
		list(base_html = base_html, base_csv = base_csv, base_label = base_label,
			new_html = new_html, new_csv = new_csv, allow = allow,
			base_rule_html = pa_html_counting_rule(paste(base_html, collapse = "\n")),
			new_rule_html = pa_html_counting_rule(paste(new_html, collapse = "\n")),
			base_rule_csv = pa_defaults_counting_rule(base_csv), new_rule_csv = pa_defaults_counting_rule(new_csv))
	}, error = function(e) { message("compare_path_audits: ", conditionMessage(e)); NULL })
	if (is.null(res)) return(2L)
	cells = compare_path_audit_cells(parse_path_audits_html(res$base_html), parse_path_audits_html(res$new_html), opt$rate_tol, opt$min_n)
	defs = compare_path_audit_defaults(read_path_audits_defaults(res$base_csv), read_path_audits_defaults(res$new_csv), opt$rate_tol, opt$min_n)
	rule_cells = if (identical(res$base_rule_html, res$new_rule_html)) NULL else res$new_rule_html
	rule_defs = if (identical(res$base_rule_csv, res$new_rule_csv)) NULL else res$new_rule_csv
	ac = apply_path_audit_allowlist(cells, res$allow, "cells", rule_cells)
	ad = apply_path_audit_allowlist(defs, res$allow, "defaults", rule_defs)
	cells = ac$cmp; defs = ad$cmp
	cat(sprintf("path audit comparison: baseline = %s, new = %s, rate_tol = %g, min_n = %g\n",
		res$base_label, normalizePath(opt$new_dir), opt$rate_tol, opt$min_n))
	if (!is.null(rule_cells) || !is.null(rule_defs)) {
		cat(sprintf("counting rule changed: html %s -> %s, defaults CSV %s -> %s; rate drops are matched against counting_rule_change allowlist rows only for this comparison\n",
			res$base_rule_html, res$new_rule_html, res$base_rule_csv, res$new_rule_csv))
	}
	cat(pa_summary_lines(cells, "cells   "), sep = "\n")
	cat(pa_summary_lines(defs, "defaults"), sep = "\n")
	if (identical(res$base_csv, res$new_csv)) {
		cat("defaults CSV is byte-identical to the baseline (it is only rewritten when the pooled row count grows)\n")
	}
	bad_cells = cells[cells$change == "worse" & !nzchar(cells$allowlisted), ]
	bad_defs = defs[defs$change == "worse" & !nzchar(defs$allowlisted), ]
	fmt_rate = function(r, n) ifelse(is.na(r), "-", sprintf("%.3f(n=%s)", r, ifelse(is.na(n), "?", format(n, scientific = FALSE))))
	show = function(d, lines, label) {
		if (!nrow(d)) return(invisible())
		cat(sprintf("\nUNALLOWLISTED worse %s (%d; first %d; --out-dir writes all):\n", label, nrow(d), min(nrow(d), opt$max_print)))
		cat(utils::head(lines, opt$max_print), sep = "\n")
	}
	show(bad_cells, sprintf("  [%s] %s | %s | %s: %s %s -> %s, %s -> %s",
		ifelse(bad_cells$table == "Regression Procedures", "reg", "nonreg"), bad_cells$class, bad_cells$row_label,
		bad_cells$column, bad_cells$kind, bad_cells$base_state, bad_cells$new_state,
		fmt_rate(bad_cells$base_rate, bad_cells$base_n), fmt_rate(bad_cells$new_rate, bad_cells$new_n)), "cells (estimable rate)")
	show(bad_defs, sprintf("  %s | %s: %s, %s -> %s", bad_defs$class, bad_defs$column, bad_defs$kind,
		fmt_rate(bad_defs$base_rate, bad_defs$base_n), fmt_rate(bad_defs$new_rate, bad_defs$new_n)), "defaults rows (nonestimable rate)")
	unused = setdiff(res$allow$id, c(ac$used, ad$used))
	if (length(unused)) cat(sprintf("\nallowlist entries that matched nothing (informational): %s\n", paste(unused, collapse = ", ")))
	if (!is.null(opt$out_dir)) {
		dir.create(opt$out_dir, recursive = TRUE, showWarnings = FALSE)
		utils::write.csv(cells[cells$change != "unchanged", ], file.path(opt$out_dir, "path_audits_compare_cells.csv"), row.names = FALSE)
		utils::write.csv(defs[defs$change != "unchanged", ], file.path(opt$out_dir, "path_audits_compare_defaults.csv"), row.names = FALSE)
		cat(sprintf("wrote %s\n", file.path(opt$out_dir, c("path_audits_compare_cells.csv", "path_audits_compare_defaults.csv"))), sep = "")
	}
	n_bad = nrow(bad_cells) + nrow(bad_defs)
	cat(sprintf("\nRESULT: %s (%d unallowlisted worsening(s))\n", if (n_bad) "FAIL" else "PASS", n_bad))
	if (n_bad) 1L else 0L
}

if (sys.nframe() == 0L) {
	quit(save = "no", status = run_compare_path_audits())
}
