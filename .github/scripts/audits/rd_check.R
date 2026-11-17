#!/usr/bin/env Rscript
# R side of the Rd audit (.github/scripts/audits/rd.py). Writes JSON; the Python module turns it
# into findings. Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 2.
#
#   Rscript rd_check.R static  <pkg_dir> <out.json> <example_dir> [--no-codoc] [--wordlist <file>]
#       checkRd on every Rd file, topic links, codoc (needs the installed EDI), spelling, and the
#       \examples of every Rd file written out with tools::Rd2ex: <stem>.R without the \donttest
#       code (what CRAN times) and, when the page has \donttest, <stem>.full.R with it; a page with
#       \dontrun also gets <stem>.dontrun.R with every part uncommented.
#   Rscript rd_check.R example <example.R> <out.json> [--seed <k>]
#       Loads the installed EDI, runs one example file (after set.seed(k) when --seed is given),
#       records the time, warnings and error. The caller enforces the wall-clock limit (it kills
#       the process).
#   Rscript rd_check.R extract <file.Rd> <example_dir>
#       Only the Rd2ex step of `static`, for one Rd file (the finish stage's check of a proposed
#       @examples block); prints the JSON entry.
#   Rscript rd_check.R checkrd <out.json> <file.Rd>...
#       checkRd only, on the given files (the finish stage's self-check after roxygen).
#
# Never builds or installs EDI: CI installs it before this runs.

args = commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("usage: rd_check.R static|example|checkrd ...")
mode = args[1]
suppressPackageStartupMessages(library(jsonlite))

write_out = function(x, path) {
	writeLines(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", pretty = TRUE, digits = NA), path)
}

check_rd_files = function(files) {
	out = list()
	for (f in files) {
		msgs = tryCatch(
			as.character(tools::checkRd(f, encoding = "UTF-8", def_enc = TRUE)),
			error = function(e) paste("checkRd could not parse the file:", conditionMessage(e))
		)
		if (length(msgs)) out[[basename(f)]] = as.list(msgs)
	}
	out
}

rd_tags = function(x) c(attr(x, "Rd_tag"), if (is.list(x)) unlist(lapply(x, rd_tags), use.names = FALSE))
extract_examples = function(f, ex_dir) {
	stem = sub("\\.Rd$", "", basename(f))
	rd = tryCatch(tools::parse_Rd(f, encoding = "UTF-8"), error = function(e) NULL)
	if (is.null(rd)) return(NULL)
	tags = rd_tags(rd)
	if (!("\\examples" %in% tags)) return(NULL)
	cran = file.path(ex_dir, paste0(stem, ".R"))
	tools::Rd2ex(rd, cran, commentDonttest = TRUE)
	entry = list(rd = basename(f), cran = if (file.exists(cran)) cran else NULL, full = NULL,
		donttest = "\\donttest" %in% tags, dontrun = "\\dontrun" %in% tags)
	if (entry$donttest) {
		full = file.path(ex_dir, paste0(stem, ".full.R"))
		tools::Rd2ex(rd, full, commentDonttest = FALSE)
		if (file.exists(full)) entry$full = full
	}
	if (entry$dontrun) {
		# everything, \dontrun included: run once to see whether the \dontrun code would run
		dr = file.path(ex_dir, paste0(stem, ".dontrun.R"))
		tools::Rd2ex(rd, dr, commentDonttest = FALSE, commentDontrun = FALSE)
		if (file.exists(dr)) entry$dontrun_file = dr
	}
	entry
}

if (mode == "extract") {
	dir.create(args[3], showWarnings = FALSE, recursive = TRUE)
	e = extract_examples(args[2], args[3])
	cat(jsonlite::toJSON(if (is.null(e)) list() else e, auto_unbox = TRUE, null = "null"))
	quit(save = "no", status = 0)
}

if (mode == "checkrd") {
	write_out(list(checkrd = check_rd_files(args[-(1:2)])), args[2])
	quit(save = "no", status = 0)
}

if (mode == "example") {
	ex = args[2]
	out_path = args[3]
	seed = if ("--seed" %in% args) as.integer(args[which(args == "--seed") + 1L]) else NA_integer_
	res = list(file = basename(ex), seed = if (is.na(seed)) NULL else seed, loaded = FALSE, error = NULL, warnings = list(), elapsed = NA,
		cpu = NA, load_elapsed = NA)
	t_load = system.time(loaded <- tryCatch({
		suppressPackageStartupMessages(library(EDI))
		TRUE
	}, error = function(e) conditionMessage(e)))
	res$load_elapsed = unname(t_load[["elapsed"]])
	if (!isTRUE(loaded)) {
		res$error = paste("library(EDI) failed:", loaded)
		write_out(res, out_path)
		quit(save = "no", status = 0)
	}
	res$loaded = TRUE
	write_out(res, out_path)   # a time-out still leaves a record that EDI loaded
	warns = character()
	err = NULL
	env = new.env(parent = globalenv())
	grDevices::pdf(NULL)
	if (!is.na(seed)) set.seed(seed)
	sink(nullfile())
	t_run = system.time(withCallingHandlers(
		tryCatch(source(ex, local = env, echo = FALSE), error = function(e) err <<- conditionMessage(e)),
		warning = function(w) {
			warns <<- c(warns, conditionMessage(w))
			invokeRestart("muffleWarning")
		}
	))
	sink()
	res$elapsed = unname(t_run[["elapsed"]])
	# CPU as CRAN counts it: this process (all its threads) plus any child processes
	res$cpu = unname(sum(t_run[c("user.self", "sys.self", "user.child", "sys.child")], na.rm = TRUE))
	res$error = err
	res$warnings = as.list(utils::head(unique(warns), 10))
	write_out(res, out_path)
	quit(save = "no", status = 0)
}

if (mode != "static") stop("unknown mode: ", mode)

pkg = args[2]
out_path = args[3]
ex_dir = args[4]
no_codoc = "--no-codoc" %in% args
wordlist_file = if ("--wordlist" %in% args) args[which(args == "--wordlist") + 1L] else file.path(pkg, "inst", "WORDLIST")
dir.create(ex_dir, showWarnings = FALSE, recursive = TRUE)
rd_files = sort(list.files(file.path(pkg, "man"), pattern = "\\.Rd$", full.names = TRUE))
res = list(n_rd = length(rd_files), notes = list())

## checkRd
res$checkrd = check_rd_files(rd_files)

## topic links: targets that do not resolve (tools' own check), and links into packages EDI does
## not declare
xref = tryCatch(unclass(tools:::.check_Rd_xrefs(dir = pkg)), error = function(e) {
	res$notes[[length(res$notes) + 1L]] <<- paste("tools:::.check_Rd_xrefs failed:", conditionMessage(e))
	list()
})
xr = list()
for (what in names(xref)) {
	comp = xref[[what]]
	if (!is.list(comp) || !length(comp)) next
	for (f in names(comp)) {
		xr[[length(xr) + 1L]] = list(kind = what, rd = f, targets = as.list(as.character(comp[[f]])))
	}
}
res$xrefs = xr

dcf = read.dcf(file.path(pkg, "DESCRIPTION"))
dep_fields = intersect(c("Depends", "Imports", "Suggests", "Enhances", "LinkingTo"), colnames(dcf))
declared = unlist(lapply(dep_fields, function(f) trimws(sub("\\(.*$", "", strsplit(dcf[1, f], ",")[[1]]))))
base_pkgs = rownames(utils::installed.packages(priority = "base"))
allowed = unique(c(dcf[1, "Package"], declared, base_pkgs, "R"))
link_pkgs = list()
walk_links = function(x, rdname) {
	tag = attr(x, "Rd_tag")
	if (!is.null(tag) && tag %in% c("\\link", "\\linkS4class")) {
		opt = attr(x, "Rd_option")
		if (!is.null(opt)) {
			o = paste(as.character(opt), collapse = "")
			# [=topic] is a topic in this package; [pkg] and [pkg:topic] name a package
			p = if (startsWith(o, "=")) "" else sub(":.*$", "", o)
			if (nzchar(p) && !(p %in% allowed)) {
				link_pkgs[[length(link_pkgs) + 1L]] <<- list(rd = rdname, package = p,
					target = paste(unlist(x), collapse = ""))
			}
		}
	}
	if (is.list(x)) for (y in x) walk_links(y, rdname)
}
for (f in rd_files) {
	rd = tryCatch(tools::parse_Rd(f, encoding = "UTF-8"), error = function(e) NULL)
	if (!is.null(rd)) walk_links(rd, basename(f))
}
res$undeclared_link_packages = link_pkgs

## codoc: arguments and defaults in \usage vs the code (needs the installed EDI)
res$codoc = list()
if (no_codoc) {
	res$notes[[length(res$notes) + 1L]] = "codoc skipped (--no-codoc)"
} else if (!requireNamespace(dcf[1, "Package"], quietly = TRUE)) {
	res$notes[[length(res$notes) + 1L]] = "codoc NOT RUN: EDI is not installed in this job"
} else {
	for (fn in c("codoc", "codocClasses", "codocData")) {
		r = tryCatch(get(fn, envir = asNamespace("tools"))(package = dcf[1, "Package"]),
			error = function(e) structure(conditionMessage(e), class = "codoc_error"))
		if (inherits(r, "codoc_error")) {
			res$notes[[length(res$notes) + 1L]] = paste0(fn, " failed: ", r)
			next
		}
		lines = format(r)
		if (!length(lines)) next
		# split the printout into one piece per Rd file / documentation object
		starts = grep("^(Codoc mismatches|S4 class codoc mismatches|Data codoc mismatches|Data with usage)", lines)
		if (!length(starts)) starts = 1L
		ends = c(starts[-1] - 1L, length(lines))
		for (k in seq_along(starts)) {
			piece = lines[starts[k]:ends[k]]
			m = regmatches(piece[1], regexpr("'[^']+'", piece[1]))
			res$codoc[[length(res$codoc) + 1L]] = list(check = fn,
				rd = if (length(m)) gsub("'", "", m) else "", text = paste(piece, collapse = "\n"))
		}
	}
}

## spelling (spelling::spell_check_files when available, else hunspell on tools::RdTextFilter)
wl = if (file.exists(wordlist_file)) trimws(readLines(wordlist_file, warn = FALSE)) else character()
wl = wl[nzchar(wl)]
lang = if ("Language" %in% colnames(dcf)) dcf[1, "Language"] else "en-US"
res$wordlist_exists = file.exists(wordlist_file)
res$spelling = list()
if (requireNamespace("spelling", quietly = TRUE)) {
	sp = tryCatch(spelling::spell_check_files(rd_files, ignore = wl, lang = lang), error = function(e) {
		res$notes[[length(res$notes) + 1L]] <<- paste("spelling failed:", conditionMessage(e))
		NULL
	})
	if (!is.null(sp) && nrow(sp)) {
		for (i in seq_len(nrow(sp))) {
			res$spelling[[length(res$spelling) + 1L]] = list(word = sp$word[i], found = as.list(sp$found[[i]]))
		}
	}
	res$spelling_engine = "spelling"
} else if (requireNamespace("hunspell", quietly = TRUE)) {
	dict = hunspell::dictionary(sub("-", "_", lang))
	found = list()
	for (f in rd_files) {
		txt = tryCatch(tools::RdTextFilter(f, encoding = "UTF-8"), error = function(e) character())
		if (!length(txt)) next
		bad = hunspell::hunspell(txt, format = "text", dict = dict, ignore = wl)
		for (ln in seq_along(bad)) for (w in unique(bad[[ln]])) {
			found[[w]] = c(found[[w]], sprintf("%s:%d", basename(f), ln))
		}
	}
	for (w in sort(names(found))) res$spelling[[length(res$spelling) + 1L]] = list(word = w, found = as.list(found[[w]]))
	res$spelling_engine = "hunspell"
	res$notes[[length(res$notes) + 1L]] = "spelling package not installed: used hunspell on tools::RdTextFilter (rougher)"
} else {
	res$spelling_engine = "none"
	res$notes[[length(res$notes) + 1L]] = "spelling NOT RUN: neither the spelling nor the hunspell package is installed"
}

## examples, written out for the caller to run one by one
res$examples = lapply(rd_files, extract_examples, ex_dir = ex_dir)
res$examples = Filter(Negate(is.null), res$examples)
write_out(res, out_path)
