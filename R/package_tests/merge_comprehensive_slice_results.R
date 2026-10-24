#!/usr/bin/env Rscript
# Merge a class-filtered comprehensive-test slice (a comprehensive_tests.R run
# made with EDI_COMPREHENSIVE_RESULTS_DIR=<slice dir>) into the canonical
# result CSVs R/package_tests/comprehensive_tests_results_nc_<N>_<response_type>.csv.
#
# Key: the row's `id` column, i.e. build_result_key(rep, beta_T, dataset,
# response_type, design, inference_class, function_run) in comprehensive_tests.R
# -- the same key the runner's resume cache (completed_rows_cache) uses. The two
# key helpers are evaluated from the runner's own source (never by sourcing or
# running the runner), and every slice row's `id` is checked against them.
# Existing keys can live in tracked `_filtered_` files too: every
# comprehensive_tests_results_nc_*.csv in the canonical dir (filtered or not,
# skipping files named for another response type) is searched by id. A key in
# more than one file is refused; an existing key is replaced in the file that
# holds it; a new key is appended to the unfiltered nc_<N>_<response_type>.csv.
# The report says where each key lives and how many live only in _filtered_
# files (the path audits and the results audit read unfiltered files only).
# Within a file one key can occur several times (append-only); the
# runner treats the LAST occurrence as current (.SD[.N] in
# get_existing_error_keys_latest()), so a slice row replaces that last
# occurrence in place. Earlier occurrences are reported, never deleted.
#
# Per canonical target file the report lists: rows replaced (same key, changed
# line), rows identical (same key, same line), rows added (new key, appended at
# the end), canonical keys in the slice's scope that the slice did NOT produce
# (missing_in_slice: listed, never deleted), status transitions and value
# changes (status/result/result_1/result_2/coverage_truth/
# beta_T_in_confidence_interval/error_message/skip_reason) of replaced rows.
# Scope = same response_type and the slice's design/class/dataset/beta/rep
# filters (raw values from the provenance sidecar's command_args, else parsed
# from the _filtered_ file name); a family filter is approximated by the
# method_family values the slice itself produced (the runner has no
# family->function_run table, only code paths).
#
# Blocking (exit 1, --apply refused): no completed receipt with exit_status 0,
# or no matching schema-v2 provenance sidecar (both downgraded to warnings by
# --allow-no-receipt, which is refused together with --apply); a sidecar DLL
# SHA-256 differing from the installed EDI.so (both reported); a duplicated
# slice key; a key living in more than one results file; an `id` that does not match the runner's key; slice columns not
# the same set as the canonical header; a missing canonical target; a slice
# row whose response_type differs from its file; --expect-keys differing from
# the slice's key set; a canonical file whose lines cannot be mapped 1:1 to
# rows (embedded newline or CR); the runner's results lock held.
#
# --apply (only with no blocking issue): per touched canonical file, under the
# runner's own `<file>.lock` directory lock, copy it to
# `<file>.pre_slice_merge_<UTC stamp>.bak` (same precedent as
# comprehensive_tests_results_nc_1_ordinal.csv.pre_stereotype_merge.bak), then
# write a temp file in the same directory and rename it over the original.
# Untouched lines are copied byte for byte; column order is the canonical
# header's; slice lines are re-ordered field by field, keeping each field's
# original text. Nothing is written when every slice row is already identical
# (a second --apply is a no-op). The audit stamp becomes stale automatically
# (it keys on size/mtime), so re-run audit_comprehensive_results.R afterwards.
#
# Three steps:
#   1. dry run (default): report only.
#   2. --out-dir DIR (empty dir outside the checkout): write the merged copies of
#      the touched files into DIR, symlink the untouched unfiltered nc_1_<type>.csv
#      files and copy comprehensive_results_audit_baseline.csv there, then
#      EDI_COMPREHENSIVE_RESULTS_DIR=DIR Rscript R/package_tests/audit_comprehensive_results.R --force
#      (the audit reads exactly nc_1_<type>.csv + the baseline; it writes its own stamp there).
#   3. --apply: rewrite the canonical files in place (backup + atomic rename).
# Usage (from any cwd; DRY RUN unless --out-dir or --apply):
#   Rscript R/package_tests/merge_comprehensive_slice_results.R --slice-dir DIR \
#     [--canonical-dir R/package_tests] [--canonical-nc N] [--expect-keys FILE] \
#     [--receipt FILE] [--report-dir DIR] [--installed-dll FILE] [--target-file FILE] \
#     [--out-dir DIR] [--allow-no-receipt] [--apply]
# --expect-keys: one id per line, or a CSV with an `id` column.
# --canonical-nc: send new keys of an nc_<k> slice to the nc_<N> unfiltered file
#   (the id does not contain num_cores; the audits and pruner read nc_1 only).
# --target-file: skip the search and reconcile every slice row against this one
#   results CSV (e.g. to compare with a single reference file).
# --report-dir: where the report goes (default: the slice dir); never the checkout.
# --installed-dll: the native library to compare the sidecar's DLL hash with
#   (default: <find.package("EDI")>/libs/EDI.so; the package is not loaded).
# Exit: 0 clean (dry run without blocking issue, or applied), 1 blocking issue,
# 2 usage/parse error.

suppressPackageStartupMessages(library(data.table))

script_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1]
here = if (is.na(script_arg)) normalizePath("R/package_tests", mustWork = FALSE) else dirname(normalizePath(sub("^--file=", "", script_arg)))
repo_root = normalizePath(file.path(here, "..", ".."), winslash = "/", mustWork = FALSE)
source(file.path(here, "comprehensive_run_provenance.R"), local = TRUE)
source(file.path(here, "comprehensive_beta_filter.R"), local = TRUE)

usage_text = paste(
	"usage: Rscript R/package_tests/merge_comprehensive_slice_results.R --slice-dir DIR",
	"  [--canonical-dir DIR] [--canonical-nc N] [--expect-keys FILE] [--receipt FILE]",
	"  [--report-dir DIR] [--installed-dll FILE] [--target-file FILE] [--out-dir DIR] [--allow-no-receipt] [--apply]",
	sep = "\n"
)
usage_exit = function(msg) {
	cat("merge_comprehensive_slice_results: ", msg, "\n", usage_text, "\n", sep = "", file = stderr())
	quit(save = "no", status = 2L)
}
parse_exit = function(msg) {
	cat("merge_comprehensive_slice_results: parse error: ", msg, "\n", sep = "", file = stderr())
	quit(save = "no", status = 2L)
}

# ---- arguments ---------------------------------------------------------------
args = commandArgs(trailingOnly = TRUE)
opts = list(slice_dir = NA_character_, canonical_dir = here, canonical_nc = NA_character_,
	expect_keys = NA_character_, receipt = NA_character_, report_dir = NA_character_,
	installed_dll = NA_character_, target_file = NA_character_, out_dir = NA_character_)
flags = c(apply = FALSE, allow_no_receipt = FALSE)
value_opts = c("--slice-dir", "--canonical-dir", "--canonical-nc", "--expect-keys", "--receipt", "--report-dir", "--installed-dll", "--target-file", "--out-dir")
seen = character()
i = 1L
while (i <= length(args)) {
	a = args[[i]]
	if (a %in% c("-h", "--help")) { cat(usage_text, "\n"); quit(save = "no", status = 0L) }
	if (a == "--apply") { flags[["apply"]] = TRUE; i = i + 1L; next }
	if (a == "--allow-no-receipt") { flags[["allow_no_receipt"]] = TRUE; i = i + 1L; next }
	if (grepl("^--[a-z-]+=", a)) { # --opt=value form
		args = append(args, c(sub("=.*$", "", a), sub("^[^=]*=", "", a)), after = i)
		args = args[-i]
		next
	}
	if (!a %in% value_opts) usage_exit(paste0("unknown argument: ", a))
	if (a %in% seen) usage_exit(paste0("duplicate option: ", a))
	if (i == length(args)) usage_exit(paste0("missing value after ", a))
	seen = c(seen, a)
	opts[[gsub("-", "_", sub("^--", "", a))]] = args[[i + 1L]]
	i = i + 2L
}
if (is.na(opts$slice_dir)) usage_exit("--slice-dir is required")
if (!dir.exists(opts$slice_dir)) usage_exit(paste0("--slice-dir is not a directory: ", opts$slice_dir))
if (!dir.exists(opts$canonical_dir)) usage_exit(paste0("--canonical-dir is not a directory: ", opts$canonical_dir))
if (flags[["apply"]] && flags[["allow_no_receipt"]]) usage_exit("--allow-no-receipt is for dry runs only; it is refused with --apply")
if (!is.na(opts$canonical_nc) && !grepl("^[0-9]+$", opts$canonical_nc)) usage_exit("--canonical-nc must be a positive integer")
if (!is.na(opts$expect_keys) && !file.exists(opts$expect_keys)) usage_exit(paste0("--expect-keys file not found: ", opts$expect_keys))
if (!is.na(opts$receipt) && !file.exists(opts$receipt)) usage_exit(paste0("--receipt file not found: ", opts$receipt))
if (!is.na(opts$target_file) && !file.exists(opts$target_file)) usage_exit(paste0("--target-file not found: ", opts$target_file))
if (!is.na(opts$target_file) && !is.na(opts$canonical_nc)) usage_exit("--target-file and --canonical-nc are exclusive")
slice_dir = normalizePath(opts$slice_dir, winslash = "/", mustWork = TRUE)
canonical_dir = normalizePath(opts$canonical_dir, winslash = "/", mustWork = TRUE)
report_dir = if (is.na(opts$report_dir)) slice_dir else opts$report_dir
if (!dir.exists(report_dir)) usage_exit(paste0("--report-dir is not a directory: ", report_dir))
report_dir = normalizePath(report_dir, winslash = "/", mustWork = TRUE)
inside = function(path, root) identical(path, root) || startsWith(path, paste0(sub("/$", "", root), "/"))
if (dir.exists(file.path(repo_root, ".git")) && inside(report_dir, repo_root)) {
	usage_exit(paste0("the report directory is inside the checkout (", report_dir, "); pass --report-dir outside it"))
}
out_dir = NA_character_
if (!is.na(opts$out_dir)) {
	if (flags[["apply"]]) usage_exit("--out-dir and --apply are exclusive (--out-dir never touches the canonical files)")
	if (!dir.exists(opts$out_dir)) usage_exit(paste0("--out-dir is not an existing directory: ", opts$out_dir))
	out_dir = normalizePath(opts$out_dir, winslash = "/", mustWork = TRUE)
	if (inside(out_dir, repo_root) || inside(out_dir, canonical_dir)) usage_exit(paste0("--out-dir must be outside the checkout and the canonical dir: ", out_dir))
	if (length(list.files(out_dir, pattern = "^comprehensive_(tests_results_nc_|results_audit_baseline)"))) {
		usage_exit(paste0("--out-dir already holds results/baseline files; use an empty directory: ", out_dir))
	}
}

blockers = character()
warnings_out = character()
block = function(...) blockers <<- c(blockers, paste0(...))
warn = function(...) warnings_out <<- c(warnings_out, paste0(...))
waived = function(...) if (flags[["allow_no_receipt"]]) warn(..., " [waived for this dry run by --allow-no-receipt]") else block(...)

# ---- the runner's own key helpers (evaluated, never sourced) -----------------
runner_path = file.path(here, "comprehensive_tests.R")
if (!file.exists(runner_path)) parse_exit(paste0("runner not found next to this script: ", runner_path))
runner_exprs = tryCatch(parse(runner_path, keep.source = FALSE), error = function(e) parse_exit(paste0("cannot parse the runner: ", conditionMessage(e))))
key_env = new.env(parent = baseenv())
for (name in c("serialize_beta_T", "build_result_key", "canonicalize_test_family_filter", "sanitize_results_filter")) {
	hits = Filter(function(e) is.call(e) && (identical(e[[1L]], as.name("=")) || identical(e[[1L]], as.name("<-"))) &&
		identical(e[[2L]], as.name(name)) && is.call(e[[3L]]) && identical(e[[3L]][[1L]], as.name("function")), as.list(runner_exprs))
	if (length(hits) != 1L) parse_exit(paste0("expected one top-level definition of ", name, "() in ", runner_path))
	assign(name, eval(hits[[1L]][[3L]], envir = key_env), envir = key_env)
}
RESPONSE_ERROR_ID_PREFIX = "run_tests_for_response_error||" # response-level error rows: not build_result_key()
VALUE_COLUMNS = c("status", "result", "result_1", "result_2", "coverage_truth", "beta_T_in_confidence_interval", "error_message", "skip_reason")
SCOPE_COLUMNS = c("id", "rep", "beta_T", "dataset", "response_type", "design", "inference_class", "method_family")

# ---- small helpers ----------------------------------------------------------
read_lines_raw = function(path) {
	con = file(path, open = "rb")
	on.exit(close(con))
	readLines(con, warn = FALSE)
}
# Newline/CR count without materializing the file as lines.
count_bytes = function(path) {
	con = file(path, open = "rb")
	on.exit(close(con))
	n_lf = 0; n_cr = 0; last = as.raw(10L)
	repeat {
		chunk = readBin(con, "raw", n = 64L * 1024L * 1024L)
		if (!length(chunk)) break
		n_lf = n_lf + sum(chunk == as.raw(10L)); n_cr = n_cr + sum(chunk == as.raw(13L))
		last = chunk[length(chunk)]
	}
	list(lf = n_lf, cr = n_cr, ends_with_lf = identical(last, as.raw(10L)))
}
# Split fwrite-style CSV lines into their raw field texts (quotes kept), so a
# slice line can be re-ordered to the canonical header without re-formatting.
split_csv_fields = function(lines) {
	if (any(grepl("\001|\002", lines, useBytes = TRUE))) stop("control byte \\001/\\002 in a CSV line")
	quoted = gregexpr('"(?:[^"]|"")*"', lines, perl = TRUE, useBytes = TRUE)
	protected = regmatches(lines, quoted)
	regmatches(lines, quoted) = lapply(protected, function(x) gsub(",", "\001", x, fixed = TRUE, useBytes = TRUE))
	lapply(strsplit(paste0(lines, ",\002"), ",", fixed = TRUE, useBytes = TRUE), function(f) {
		f = f[-length(f)]
		gsub("\001", ",", f, fixed = TRUE, useBytes = TRUE)
	})
}
values_equal = function(a, b) {
	a = ifelse(is.na(a), "", a); b = ifelse(is.na(b), "", b)
	na = suppressWarnings(as.numeric(a)); nb = suppressWarnings(as.numeric(b))
	(a == b) | (!is.na(na) & !is.na(nb) & na == nb)
}
fmt_val = function(x) ifelse(is.na(x), "NA", x)
parse_slice_filename = function(base) {
	m = regmatches(base, regexec("^comprehensive_tests_results_nc_([0-9]+)(?:_(continuous|incidence|proportion|count|survival|ordinal))?(_filtered_.*)?\\.csv$", base))[[1L]]
	if (!length(m)) return(NULL)
	out = list(nc = m[2L], response_type = if (nzchar(m[3L])) m[3L] else NA_character_,
		design = NA_character_, class = NA_character_, dataset = NA_character_, beta = NA_character_, rep = NA_character_, family = NA_character_)
	rest = sub("^_filtered_", "", m[4L])
	tags = c("design", "class", "dataset", "beta", "rep", "family")
	for (k in seq_along(tags)) {
		later = tags[-seq_len(k)]
		pat = paste0("^", tags[k], "-(.*?)", if (length(later)) paste0("(?=_(?:", paste(later, collapse = "|"), ")-|$)") else "$")
		hit = regmatches(rest, regexpr(pat, rest, perl = TRUE))
		if (length(hit) && nzchar(hit)) {
			out[[tags[k]]] = sub(paste0("^", tags[k], "-"), "", hit)
			rest = sub("^_", "", substring(rest, nchar(hit) + 1L))
		}
	}
	if (nzchar(rest)) out$unparsed = rest
	out
}
sha_or_na = function(path) tryCatch(comprehensive_sha256_file(path), error = function(e) NA_character_)

# ---- installed DLL -------------------------------------------------------------
installed_dll = if (!is.na(opts$installed_dll)) {
	opts$installed_dll
} else {
	pkg = find.package("EDI", quiet = TRUE)
	cand = if (length(pkg)) file.path(pkg, "libs", c("EDI.so", "EDI.dll", "EDI.dylib")) else character()
	cand = cand[file.exists(cand)]
	if (length(cand)) cand[1L] else NA_character_
}
installed_dll_sha = if (!is.na(installed_dll) && file.exists(installed_dll)) sha_or_na(installed_dll) else NA_character_

# ---- receipt ---------------------------------------------------------------------
receipt_summary = "none"
receipt_paths = if (!is.na(opts$receipt)) opts$receipt else list.files(slice_dir, pattern = "^receipt.*\\.(rds|json)$", full.names = TRUE)
running = list.files(slice_dir, pattern = "^receipt.*\\.running$", full.names = TRUE)
if (length(running)) block("receipt still marked running (", paste(basename(running), collapse = ", "), "): the slice run has not completed")
if (!length(receipt_paths)) {
	waived("no external-process receipt (receipt*.rds / receipt*.json written by run_comprehensive_with_receipt.R) in ", slice_dir)
} else if (length(receipt_paths) > 1L) {
	block("more than one receipt in the slice dir (", paste(basename(receipt_paths), collapse = ", "), "); pass --receipt")
} else {
	receipt = tryCatch(readRDS(receipt_paths), error = function(e) NULL)
	if (!is.list(receipt) || !identical(receipt$schema, "edi_external_process_receipt")) {
		block("receipt ", receipt_paths, " is not an edi_external_process_receipt RDS")
	} else {
		receipt_summary = sprintf("%s: state=%s exit_status=%s pid=%s started=%s completed=%s",
			receipt_paths, receipt$state, format(receipt$exit_status), format(receipt$pid), receipt$started_at_utc, format(receipt$completed_at_utc))
		if (!identical(receipt$state, "completed")) block("receipt state is '", receipt$state, "', not 'completed'")
		if (!identical(as.integer(receipt$exit_status), 0L)) block("receipt exit_status is ", format(receipt$exit_status), ", not 0")
		for (stream in c("stdout", "stderr")) {
			ident = receipt[[stream]]
			if (is.list(ident) && !is.null(ident$path) && file.exists(ident$path) &&
				!identical(tolower(sha_or_na(ident$path)), tolower(ident$sha256))) {
				warn("receipt ", stream, " log ", ident$path, " changed since the receipt was written")
			}
		}
	}
}

# ---- slice files -----------------------------------------------------------------
slice_files = list.files(slice_dir, pattern = "^comprehensive_tests_results_nc_[0-9]+.*\\.csv$", recursive = TRUE, full.names = TRUE)
if (!length(slice_files)) {
	cat("merge_comprehensive_slice_results: no comprehensive_tests_results_nc_*.csv under ", slice_dir, "\n", sep = "")
	quit(save = "no", status = 1L)
}

slices = list()
for (sf in slice_files) {
	base = basename(sf)
	meta = parse_slice_filename(base)
	if (is.null(meta)) parse_exit(paste0("unrecognized slice file name: ", base))
	if (!is.null(meta$unparsed)) parse_exit(paste0("could not parse filter part '", meta$unparsed, "' of ", base))
	# Provenance sidecars (schema v2) written next to the CSV by the runner.
	sidecars = list.files(dirname(sf), full.names = TRUE)
	sidecars = sidecars[startsWith(basename(sidecars), paste0(base, ".provenance-")) & endsWith(sidecars, ".rds")]
	raw_args = NULL
	sidecar_lines = character()
	if (!length(sidecars)) {
		waived("no provenance sidecar (", base, ".provenance-*.rds): cannot verify the slice's DLL")
	} else {
		csv_sha = sha_or_na(sf)
		matched = FALSE
		for (sc in sidecars) {
			p = tryCatch(readRDS(sc), error = function(e) NULL)
			if (!is.list(p) || !identical(as.integer(p$schema_version), 2L)) { block("sidecar ", basename(sc), " is not a schema-v2 provenance sidecar"); next }
			dll_after = p$after$edi_dll_sha256; dll_before = p$before$edi_dll_sha256
			sidecar_lines = c(sidecar_lines, sprintf("  %s: dll=%s (%s) head=%s completed=%s", basename(sc), dll_after, p$after$edi_dll_path, p$after$checkout_head, p$completed_at_utc))
			if (!identical(dll_before, dll_after)) block("sidecar ", basename(sc), ": DLL changed during the run (before ", dll_before, ", after ", dll_after, ")")
			if (is.na(installed_dll_sha)) {
				block("cannot hash the installed EDI native library (", installed_dll, ") to compare with sidecar ", basename(sc))
			} else if (!identical(tolower(dll_after), tolower(installed_dll_sha))) {
				block("sidecar ", basename(sc), " DLL sha256 ", dll_after, " (", p$after$edi_dll_path, ") differs from the installed ", installed_dll, " sha256 ", installed_dll_sha)
			}
			if (identical(tolower(p$results_file_after$sha256), tolower(csv_sha))) {
				matched = TRUE
				if (is.character(p$command_args)) raw_args = p$command_args
			}
		}
		if (!matched) block(base, ": no sidecar's results_file_after sha256 matches the CSV (run incomplete, or the CSV changed after the run)")
	}
	# Raw filters from the runner's command line beat the sanitized file name.
	filt = meta[c("design", "class", "dataset", "beta", "rep", "family")]
	filt_source = "file name"
	if (!is.null(raw_args)) {
		pos = c(design = 4L, class = 5L, dataset = 6L, beta = 7L, rep = 8L, family = 9L)
		for (nm in names(pos)) {
			v = if (length(raw_args) >= pos[[nm]]) raw_args[[pos[[nm]]]] else "NA"
			filt[[nm]] = if (identical(v, "NA")) NA_character_ else v
		}
		if (!is.na(filt$family)) filt$family = key_env$canonicalize_test_family_filter(filt$family)
		filt_source = "sidecar command_args"
	}
	lines = read_lines_raw(sf)
	lines = lines[nzchar(lines)]
	header_line = lines[1L]
	dt = tryCatch(fread(sf, colClasses = "character", na.strings = "NA", showProgress = FALSE), error = function(e) parse_exit(paste0("cannot read ", sf, ": ", conditionMessage(e))))
	if (nrow(dt) != length(lines) - 1L) parse_exit(paste0(base, ": ", nrow(dt), " rows but ", length(lines) - 1L, " data lines (embedded newline?)"))
	fields = tryCatch(split_csv_fields(lines), error = function(e) parse_exit(paste0(base, ": ", conditionMessage(e))))
	if (any(lengths(fields) != ncol(dt))) parse_exit(paste0(base, ": could not split every line into ", ncol(dt), " fields"))
	header_fields = gsub('^"|"$', "", fields[[1L]])
	if (!identical(header_fields, names(dt))) parse_exit(paste0(base, ": header split disagrees with fread"))
	need = c(SCOPE_COLUMNS, "function_run", "status")
	if (length(setdiff(need, names(dt)))) parse_exit(paste0(base, ": missing column(s) ", paste(setdiff(need, names(dt)), collapse = ", ")))
	nc = if (is.na(opts$canonical_nc)) meta$nc else opts$canonical_nc
	slices[[length(slices) + 1L]] = list(path = sf, base = base, meta = meta, filt = filt, filt_source = filt_source,
		dt = dt, fields = fields[-1L], header = names(dt), nc = nc, sidecar_lines = sidecar_lines)
}

# ---- key checks across the whole slice --------------------------------------
all_slice = rbindlist(lapply(slices, function(s) data.table(slice_file = s$base, id = s$dt$id, response_type = s$dt$response_type,
	file_rt = s$meta$response_type)))
dup = all_slice[, .N, by = id][N > 1L]
if (nrow(dup)) block(nrow(dup), " slice key(s) appear more than once, e.g. ", paste(head(dup$id, 3L), collapse = " ; "))
if (anyNA(all_slice$id) || any(!nzchar(all_slice$id))) block("slice row(s) with an empty id")
bad_rt = all_slice[!is.na(file_rt) & response_type != file_rt]
if (nrow(bad_rt)) block(nrow(bad_rt), " slice row(s) whose response_type differs from their file's (", bad_rt$slice_file[1L], ")")
for (s in slices) {
	d = s$dt
	is_resp_err = startsWith(d$id, RESPONSE_ERROR_ID_PREFIX)
	rebuilt = key_env$build_result_key(as.integer(d$rep), suppressWarnings(as.numeric(d$beta_T)), d$dataset, d$response_type, d$design, d$inference_class, d$function_run)
	bad = which(!is_resp_err & (is.na(d$id) | d$id != rebuilt))
	if (length(bad)) block(s$base, ": ", length(bad), " row(s) whose id differs from build_result_key(), e.g. '", d$id[bad[1L]], "' vs '", rebuilt[bad[1L]], "'")
}
expect_summary = NULL
if (!is.na(opts$expect_keys)) {
	ek = if (grepl("\\.csv$", opts$expect_keys, ignore.case = TRUE)) {
		e = tryCatch(fread(opts$expect_keys, colClasses = "character", showProgress = FALSE), error = function(e) parse_exit(paste0("cannot read --expect-keys: ", conditionMessage(e))))
		if (!"id" %in% names(e)) parse_exit("--expect-keys CSV has no `id` column")
		e$id
	} else {
		trimws(readLines(opts$expect_keys, warn = FALSE))
	}
	ek = unique(ek[!is.na(ek) & nzchar(ek)])
	miss = setdiff(ek, all_slice$id); extra = setdiff(all_slice$id, ek)
	expect_summary = sprintf("expect-keys %s: %d expected, %d in slice, %d expected but missing, %d unexpected extra",
		opts$expect_keys, length(ek), length(unique(all_slice$id)), length(miss), length(extra))
	if (length(miss) || length(extra)) {
		block("slice key set differs from --expect-keys: ", length(miss), " missing (e.g. ", paste(head(miss, 2L), collapse = " ; "),
			"), ", length(extra), " extra (e.g. ", paste(head(extra, 2L), collapse = " ; "), ")")
	}
}

# ---- reconcile against each canonical target ----------------------------------
report_rows = list()
target_plans = list()
# Where does each slice key already live? Existing keys can sit in tracked
# _filtered_ files as well as in the unfiltered nc_<N>_<type>.csv, so every
# results CSV in the canonical dir whose name does not name another response
# type is searched (by `id`). A key found in more than one file is refused; an
# existing key is replaced in the file that holds it; a new key goes to the
# unfiltered nc_<N>_<response_type>.csv.
slice_rts = unique(all_slice$response_type)
candidates = if (!is.na(opts$target_file)) {
	normalizePath(opts$target_file, winslash = "/", mustWork = TRUE)
} else {
	f = list.files(canonical_dir, pattern = "^comprehensive_tests_results_nc_[0-9]+.*\\.csv$", full.names = TRUE)
	f = f[vapply(basename(f), function(b) { m = parse_slice_filename(b); !is.null(m) && (is.na(m$response_type) || m$response_type %in% slice_rts) }, logical(1L))]
	normalizePath(f, winslash = "/", mustWork = TRUE)
}
locations = rbindlist(lapply(candidates, function(f) {
	ids = tryCatch(fread(f, select = "id", colClasses = "character", showProgress = FALSE)$id, error = function(e) {
		warn("could not read `id` from ", basename(f), ": ", conditionMessage(e)); character()
	})
	hit = unique(intersect(all_slice$id, ids))
	if (length(hit)) data.table(id = hit, file = f) else NULL
}))
if (!nrow(locations)) locations = data.table(id = character(), file = character())
multi = locations[, .(n_files = .N, files = paste(basename(file), collapse = " + ")), by = id][n_files > 1L]
if (nrow(multi)) {
	block(nrow(multi), " slice key(s) live in more than one results file, e.g. ", multi$id[1L], " in ", multi$files[1L])
	locations = locations[!id %in% multi$id]
}
is_filtered_file = function(f) grepl("_filtered_", basename(f), fixed = TRUE)
location_lines = c(sprintf("key locations (searched %d results file(s) in %s):", length(candidates), if (is.na(opts$target_file)) canonical_dir else "--target-file"),
	if (nrow(locations)) locations[, .N, by = file][, sprintf("  %5d existing key(s) only in %s", N, basename(file))] else "  no slice key exists in exactly one file",
	sprintf("  %d new key(s) (go to the unfiltered nc_<N>_<type>.csv)", length(setdiff(unique(all_slice$id), c(locations$id, multi$id)))),
	sprintf("  %d slice key(s) live only in _filtered_ files (invisible to the path audits and audit_comprehensive_results.R)", sum(is_filtered_file(locations$file))),
	if (nrow(multi)) c(sprintf("  %d key(s) in more than one file (blocking; listed as action=multi_location in the report CSV):", nrow(multi)),
		multi[, .N, by = files][, sprintf("    %5d in %s", N, files)]))
routes = list()
for (si in seq_along(slices)) {
	s = slices[[si]]
	loc = locations$file[match(s$dt$id, locations$id)]
	default = if (!is.na(opts$target_file)) candidates[1L] else
		file.path(canonical_dir, sprintf("comprehensive_tests_results_nc_%s_%s.csv", s$nc, s$dt$response_type))
	tgt = ifelse(is.na(loc), default, loc)
	keep = !s$dt$id %in% multi$id
	for (target in unique(tgt[keep])) {
		routes[[target]] = c(routes[[target]], list(list(si = si, rows = which(keep & tgt == target))))
	}
}
target_summaries = character()
for (target in names(routes)) {
	tbase = basename(target)
	if (!file.exists(target)) {
		block("canonical target ", target, " does not exist (refusing to create a canonical file; see --canonical-nc)")
		next
	}
	can_header = names(fread(target, nrows = 0L, showProgress = FALSE))
	schema_ok = TRUE
	for (r in routes[[target]]) {
		s = slices[[r$si]]
		if (!setequal(s$header, can_header)) {
			schema_ok = FALSE
			block("schema mismatch ", s$base, " vs ", tbase, ": only in slice [", paste(setdiff(s$header, can_header), collapse = ", "),
				"], only in canonical [", paste(setdiff(can_header, s$header), collapse = ", "), "]")
		} else if (!identical(s$header, can_header)) {
			warn(s$base, ": same columns as ", tbase, " in a different order; slice lines are re-ordered field by field")
		}
	}
	if (!schema_ok) next
	bytes = count_bytes(target)
	sel = intersect(unique(c(SCOPE_COLUMNS, "function_run", VALUE_COLUMNS)), can_header)
	can = fread(target, select = sel, colClasses = "character", na.strings = "NA", showProgress = FALSE)
	expected_lf = nrow(can) + 1L
	lines_ok = bytes$cr == 0 && bytes$lf == expected_lf && bytes$ends_with_lf
	if (bytes$cr > 0) block(tbase, ": contains CR bytes; lines cannot be preserved byte for byte")
	if (bytes$lf != expected_lf || !bytes$ends_with_lf) {
		block(tbase, ": ", nrow(can), " rows but ", bytes$lf, " line feeds (embedded newline or missing final newline); cannot map rows to lines")
	}
	can[, row_index := .I]
	last_idx = can[, .(last = max(row_index), n_occ = .N), by = id]

	# Slice rows routed here, as canonical-ordered lines.
	pieces = lapply(routes[[target]], function(r) {
		s = slices[[r$si]]
		ord = match(can_header, s$header)
		rows_idx = r$rows # not inside dt[...]: the results schema has a column named `r`
		data.table(slice_file = s$base, slice_row = rows_idx,
			line = vapply(s$fields[rows_idx], function(f) paste(f[ord], collapse = ","), character(1L)),
			s$dt[rows_idx])
	})
	sl = rbindlist(pieces, use.names = TRUE, fill = TRUE)
	sl = merge(sl, last_idx, by = "id", all.x = TRUE, sort = FALSE)
	setorder(sl, slice_file, slice_row)
	sl[, action := ifelse(is.na(last), "add", "replace")]

	# Scope of canonical rows the slice speaks for (to list keys it did not produce).
	in_scope = rep(TRUE, nrow(can))
	scope_desc = character()
	rt_set = unique(sl$response_type)
	in_scope = in_scope & can$response_type %in% rt_set
	scope_desc = c(scope_desc, paste0("response_type in {", paste(rt_set, collapse = ","), "}"))
	srcs = unique(vapply(routes[[target]], function(r) slices[[r$si]]$filt_source, character(1L)))
	for (r in routes[[target]][1L]) {
		f = slices[[r$si]]$filt
		if (length(routes[[target]]) > 1L) warn(tbase, ": ", length(routes[[target]]), " slice files share this target; scope uses the first file's filters")
		if (!is.na(f$design)) { in_scope = in_scope & can$design == f$design; scope_desc = c(scope_desc, paste0("design == ", f$design)) }
		if (!is.na(f$dataset)) { in_scope = in_scope & can$dataset == f$dataset; scope_desc = c(scope_desc, paste0("dataset == ", f$dataset)) }
		if (!is.na(f$beta)) {
			b = tryCatch(parse_comprehensive_beta_filter(f$beta), error = function(e) NA_real_)
			in_scope = in_scope & !is.na(b) & suppressWarnings(as.numeric(can$beta_T)) == b; scope_desc = c(scope_desc, paste0("beta_T == ", f$beta))
		}
		if (!is.na(f$rep)) { in_scope = in_scope & suppressWarnings(as.integer(can$rep)) == as.integer(f$rep); scope_desc = c(scope_desc, paste0("rep == ", f$rep)) }
		if (!is.na(f$class)) {
			raw = identical(slices[[r$si]]$filt_source, "sidecar command_args") || grepl("^[A-Za-z0-9.]+$", f$class)
			if (raw) {
				in_scope = in_scope & grepl(f$class, can$inference_class)
				scope_desc = c(scope_desc, paste0("grepl('", f$class, "', inference_class) [runner's INFERENCE_CLASS_FILTER rule]"))
			} else {
				bare = function(x) trimws(sub("^([^ (\\[]+).*$", "\\1", x))
				cls = unique(bare(sl$inference_class))
				in_scope = in_scope & bare(can$inference_class) %in% cls
				scope_desc = c(scope_desc, paste0("bare class in {", paste(cls, collapse = ","), "} [sanitized class filter '", f$class, "'; approximated by the slice's classes]"))
			}
		}
		if (!is.na(f$family)) {
			fams = unique(sl$method_family)
			in_scope = in_scope & can$method_family %in% fams
			scope_desc = c(scope_desc, paste0("method_family in {", paste(fams, collapse = ","), "} [family filter '", f$family, "'; approximated by the slice's method_family values]"))
		}
	}
	scope_ids = unique(can$id[in_scope])
	missing_ids = setdiff(scope_ids, sl$id)

	# Compare replaced rows with the canonical row they replace (the key's last occurrence).
	can_last = can[last_idx$last]
	cmp = merge(sl[action == "replace", c("id", "slice_file", "slice_row", intersect(VALUE_COLUMNS, names(sl))), with = FALSE],
		can_last[, c("id", intersect(VALUE_COLUMNS, names(can_last))), with = FALSE], by = "id", suffixes = c("_slice", "_canonical"), sort = FALSE)
	vc = intersect(VALUE_COLUMNS, names(can_last))
	if (nrow(cmp)) {
		changed = vapply(seq_len(nrow(cmp)), function(k) {
			parts = character()
			for (col in vc) {
				a = cmp[[paste0(col, "_canonical")]][k]; b = cmp[[paste0(col, "_slice")]][k]
				if (!values_equal(a, b)) parts = c(parts, sprintf("%s: %s -> %s", col, fmt_val(a), fmt_val(b)))
			}
			paste(parts, collapse = " | ")
		}, character(1L))
		cmp[, value_changes := changed]
	} else {
		cmp[, value_changes := character()]
	}
	sl = merge(sl, cmp[, .(id, value_changes, canonical_status = if ("status_canonical" %in% names(cmp)) status_canonical else NA_character_)], by = "id", all.x = TRUE, sort = FALSE)
	setorder(sl, slice_file, slice_row)

	# Byte-level identity needs the canonical lines; read them only for replaced keys.
	sl[, identical_line := FALSE]
	plan = list(target = target, header = can_header, n_rows = nrow(can), bytes = bytes,
		replace_idx = sl[action == "replace", last], replace_lines = sl[action == "replace", line],
		add_lines = sl[action == "add", line], mtime = file.mtime(target), size = file.size(target))
	if (length(plan$replace_idx) && lines_ok) {
		con = file(target, open = "rb")
		current = readLines(con, warn = FALSE)
		close(con)
		old = current[plan$replace_idx + 1L]
		rm(current); invisible(gc(verbose = FALSE))
		same = old == plan$replace_lines
		sl[action == "replace", identical_line := same]
		plan$old_lines = old
	}
	sl[action == "replace" & identical_line, action := "identical"]
	target_plans[[target]] = plan

	n_rep = sum(sl$action == "replace"); n_same = sum(sl$action == "identical"); n_add = sum(sl$action == "add")
	shadowed = sl[action %in% c("replace", "identical") & n_occ > 1L]
	trans = sl[action %in% c("replace", "identical"), .N, by = .(from = fmt_val(canonical_status), to = fmt_val(status))]
	val_changed = sl[action == "replace" & !is.na(value_changes) & nzchar(value_changes)]
	slice_status = sl[, .N, by = .(status = fmt_val(status))]
	target_summaries = c(target_summaries,
		sprintf("target %s (%d canonical rows)", target, nrow(can)),
		sprintf("  slice rows: %d (status %s)", nrow(sl), paste(sprintf("%s=%d", slice_status$status, slice_status$N), collapse = ", ")),
		sprintf("  replaced (same key, line differs): %d", n_rep),
		sprintf("  identical (same key, same line):   %d", n_same),
		sprintf("  added (new key, appended):         %d", n_add),
		sprintf("  canonical keys in scope: %d; not produced by the slice (missing_in_slice, not deleted): %d", length(scope_ids), length(missing_ids)),
		sprintf("  scope: %s (filters from %s)", paste(scope_desc, collapse = "; "), paste(srcs, collapse = "/")),
		sprintf("  keys with earlier canonical occurrences kept as-is (only the last is replaced): %d", nrow(shadowed)),
		sprintf("  status transitions (canonical last -> slice) for matched keys: %s",
			if (nrow(trans)) paste(sprintf("%s->%s=%d", trans$from, trans$to, trans$N), collapse = ", ") else "none"),
		sprintf("  replaced rows with value changes: %d", nrow(val_changed))
	)
	if (nrow(val_changed)) target_summaries = c(target_summaries, paste0("    ", head(paste(val_changed$id, "::", val_changed$value_changes), 10L)),
		if (nrow(val_changed) > 10L) sprintf("    ... %d more in the report CSV", nrow(val_changed) - 10L))
	report_rows[[length(report_rows) + 1L]] = rbindlist(list(
		sl[, .(target_file = tbase, action, id, slice_file, slice_row, canonical_occurrences = ifelse(is.na(n_occ), 0L, n_occ),
			canonical_status = canonical_status, slice_status = status, value_changes = ifelse(is.na(value_changes), "", value_changes))],
		if (length(missing_ids)) data.table(target_file = tbase, action = "missing_in_slice", id = missing_ids, slice_file = NA_character_, slice_row = NA_integer_,
			canonical_occurrences = last_idx[match(missing_ids, id), n_occ],
			canonical_status = can_last[match(missing_ids, id), status], slice_status = NA_character_, value_changes = "")
	), fill = TRUE)
}

# ---- report --------------------------------------------------------------------
stamp = format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
report_csv = file.path(report_dir, sprintf("merge_slice_report_%s.csv", stamp))
report_txt = file.path(report_dir, sprintf("merge_slice_report_%s.txt", stamp))
if (nrow(multi)) report_rows[[length(report_rows) + 1L]] = multi[, .(target_file = files, action = "multi_location", id)]
report_dt = if (length(report_rows)) rbindlist(report_rows, fill = TRUE) else data.table(target_file = character(), action = character(), id = character())
summary_lines = c(
	sprintf("merge_comprehensive_slice_results %s (%s)", if (flags[["apply"]]) "APPLY" else if (!is.na(out_dir)) paste("OUT-DIR", out_dir) else "DRY RUN", stamp),
	sprintf("slice dir: %s", slice_dir),
	sprintf("canonical dir: %s", canonical_dir),
	sprintf("slice files: %s", paste(vapply(slices, function(s) sprintf("%s (%d rows)", s$base, nrow(s$dt)), character(1L)), collapse = "; ")),
	sprintf("receipt: %s", receipt_summary),
	sprintf("installed DLL: %s sha256=%s", installed_dll, installed_dll_sha),
	if (length(unlist(lapply(slices, `[[`, "sidecar_lines")))) c("provenance sidecars:", unlist(lapply(slices, `[[`, "sidecar_lines"))) else "provenance sidecars: none",
	expect_summary,
	location_lines,
	target_summaries,
	if (length(warnings_out)) c("warnings:", paste0("  - ", warnings_out)) else NULL,
	if (length(blockers)) c("BLOCKING issues (nothing applied):", paste0("  - ", blockers)) else "blocking issues: none",
	sprintf("report CSV: %s", report_csv)
)
fwrite(report_dt, report_csv)
writeLines(summary_lines, report_txt)
cat(summary_lines, sep = "\n")
cat(sprintf("summary: %s\n", report_txt))

if (length(blockers)) quit(save = "no", status = 1L)
if (!flags[["apply"]] && is.na(out_dir)) {
	cat("merge_comprehensive_slice_results: dry run clean; next --out-dir DIR (preview + audit), then --apply.\n")
	quit(save = "no", status = 0L)
}

# ---- apply / out-dir -----------------------------------------------------------
# Writes `lines` (the target with the slice applied) to dest via temp file + rename.
write_merged = function(target, plan, changed_idx, dest) {
	con = file(target, open = "rb")
	lines = readLines(con, warn = FALSE)
	close(con)
	if (length(lines) != plan$n_rows + 1L) stop(basename(target), ": line count changed")
	lines[plan$replace_idx[changed_idx] + 1L] = plan$replace_lines[changed_idx]
	lines = c(lines, plan$add_lines)
	tmp = tempfile(paste0(basename(target), ".merge_tmp-"), tmpdir = dirname(dest))
	out = file(tmp, open = "wb")
	writeLines(lines, out, sep = "\n", useBytes = TRUE)
	close(out)
	check = count_bytes(tmp)
	if (check$lf != length(lines)) { unlink(tmp); stop("temp file line count mismatch for ", basename(target)) }
	if (!file.rename(tmp, dest)) { unlink(tmp); stop("could not rename the temp file over ", dest) }
	invisible(dest)
}
fail = function(msg) {
	cat("merge_comprehensive_slice_results: ", msg, "\n", sep = "", file = stderr())
	quit(save = "no", status = 1L)
}

if (!is.na(out_dir)) {
	written = character()
	for (target in names(target_plans)) {
		plan = target_plans[[target]]
		changed_idx = if (is.null(plan$old_lines)) integer() else which(plan$old_lines != plan$replace_lines)
		dest = file.path(out_dir, basename(target))
		tryCatch(write_merged(target, plan, changed_idx, dest), error = function(e) fail(conditionMessage(e)))
		written = c(written, basename(target))
		cat(sprintf("%s: merged copy written to %s (replaced %d, appended %d)\n", basename(target), dest, length(changed_idx), length(plan$add_lines)))
	}
	# The audit reads exactly comprehensive_tests_results_nc_1_<type>.csv plus
	# comprehensive_results_audit_baseline.csv from EDI_COMPREHENSIVE_RESULTS_DIR
	# (it writes its stamp there itself): link the untouched unfiltered files so
	# it sees the whole suite, and copy the baseline.
	for (rt in c("continuous", "incidence", "proportion", "count", "survival", "ordinal")) {
		b = sprintf("comprehensive_tests_results_nc_1_%s.csv", rt)
		if (b %in% written || !file.exists(file.path(canonical_dir, b))) next
		if (!file.symlink(file.path(canonical_dir, b), file.path(out_dir, b))) fail(paste0("could not link ", b, " into ", out_dir))
	}
	baseline = file.path(canonical_dir, "comprehensive_results_audit_baseline.csv")
	if (!file.exists(baseline)) baseline = file.path(here, "comprehensive_results_audit_baseline.csv")
	if (file.exists(baseline)) file.copy(baseline, file.path(out_dir, basename(baseline)), copy.date = TRUE)
	if (any(grepl("_filtered_", written, fixed = TRUE))) {
		cat("note: merged _filtered_ file(s) are not read by audit_comprehensive_results.R or the path audits.\n")
	}
	cat(sprintf("merge_comprehensive_slice_results: preview written to %s (canonical files untouched). Next:\n  EDI_COMPREHENSIVE_RESULTS_DIR=%s Rscript %s --force\n",
		out_dir, out_dir, file.path(here, "audit_comprehensive_results.R")))
	quit(save = "no", status = 0L)
}

for (target in names(target_plans)) {
	plan = target_plans[[target]]
	changed_idx = if (is.null(plan$old_lines)) integer() else which(plan$old_lines != plan$replace_lines)
	if (!length(changed_idx) && !length(plan$add_lines)) {
		cat(sprintf("%s: nothing to change (every slice row already identical)\n", basename(target)))
		next
	}
	lock_dir = paste0(target, ".lock")
	if (!dir.create(lock_dir, showWarnings = FALSE)) {
		fail(sprintf("results lock %s is held (a runner is writing?); nothing applied to %s", lock_dir, basename(target)))
	}
	tryCatch({
		if (!identical(file.size(target), plan$size) || !identical(file.mtime(target), plan$mtime)) {
			stop(basename(target), " changed since it was read; re-run the merge")
		}
		backup = paste0(target, ".pre_slice_merge_", stamp, ".bak")
		if (file.exists(backup) || !file.copy(target, backup, copy.date = TRUE)) stop("could not create backup ", backup)
		write_merged(target, plan, changed_idx, target)
		cat(sprintf("%s: replaced %d row(s), appended %d row(s); backup %s\n", basename(target), length(changed_idx), length(plan$add_lines), backup))
	}, error = function(e) {
		unlink(lock_dir, recursive = TRUE, force = TRUE)
		fail(paste0("apply failed: ", conditionMessage(e)))
	})
	unlink(lock_dir, recursive = TRUE, force = TRUE)
}
cat("merge_comprehensive_slice_results: applied. Re-run audit_comprehensive_results.R (its stamp is now stale) and the path audits.\n")
quit(save = "no", status = 0L)
