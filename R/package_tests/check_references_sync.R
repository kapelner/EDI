#!/usr/bin/env Rscript
# Checks that every in-code @references roxygen block and REFERENCES.md's
# "Used by:" class/function lists stay in sync, in both directions:
#
#   (a) every file with an @references block declares at least one
#       class/function name that REFERENCES.md indexes somewhere under some
#       entry's "Used by:" list (so a newly-cited method doesn't silently
#       fall outside the central map), and
#   (b) every class/function name REFERENCES.md lists under "Used by:" still
#       exists in the codebase under that exact name -- in R/EDI/R, R/EDI/src,
#       or python/cpp -- (so a rename/merge, e.g. DesignFixedAOptimal/
#       DesignFixedDOptimal merging into DesignFixedGreedyDOptimal, doesn't
#       leave REFERENCES.md silently citing a class that no longer exists).
#
# This is a coverage/staleness check, not a citation-text diff: it does not
# verify the bibliographic details in each @references block match
# REFERENCES.md word-for-word, only that the two files agree on *which*
# classes/functions are cited at all.
#
# (a) is checked per-*file*, not per-declaration: several inference class
# files define a scratch/component-harvesting R6 class first, then reassign
# the real class via define_inference_class() further down (documented in
# fix_inference_hierarchy.md) -- so "the very next assignment after the doc
# comment" is not a reliable way to name what an @references block
# documents. Instead, every quoted classname/R6 class name/Rcpp::export
# name/pybind11 export name declared *anywhere in that file* is a candidate;
# the check passes if REFERENCES.md indexes at least one of them.
#
# Run manually via:
#   Rscript R/package_tests/check_references_sync.R
# Wired into .githooks/pre-push to run before fast_roxygenize.R, gated on the
# same "roxygen comments changed" signal that hook's own run already uses.

repo_root = normalizePath(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])), "..", ".."))
references_md = file.path(repo_root, "R", "EDI", "REFERENCES.md")
r_dir   = file.path(repo_root, "R", "EDI", "R")
src_dir = file.path(repo_root, "R", "EDI", "src")
py_dir  = file.path(repo_root, "python", "cpp")

if (!file.exists(references_md)) {
	cat("check_references_sync: REFERENCES.md not found at", references_md, "-- skipping.\n")
	quit(status = 0)
}

r_files  = list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
src_files = list.files(src_dir, pattern = "\\.cpp$", full.names = TRUE)
py_files  = if (dir.exists(py_dir)) list.files(py_dir, pattern = "\\.cpp$", full.names = TRUE) else character(0)

match_all = function(pattern, text) {
	m = gregexpr(pattern, text, perl = TRUE)
	regmatches(text, m)[[1]]
}

# ── Per-file candidate name sets (used for both "live" universe and "what
# does this file's @references block document") ──
r_file_names = list()
for (f in r_files) {
	lines = readLines(f, warn = FALSE)
	txt = paste(lines, collapse = "\n")
	lhs = character(0)
	for (ln in lines) {
		m = regmatches(ln, regexpr("^[A-Za-z][A-Za-z0-9_.]*(?=\\s*=)", ln, perl = TRUE))
		if (length(m) > 0 && nzchar(m)) lhs = c(lhs, m)
	}
	quoted = match_all('(?:classname|"[A-Za-z][A-Za-z0-9_.]*"\\s*,\\s*inherit)|R6::R6Class\\(\\s*"([A-Za-z][A-Za-z0-9_.]*)"|classname\\s*=\\s*"([A-Za-z][A-Za-z0-9_.]*)"', txt)
	# Simpler, robust two-pass extraction instead of relying on one combined regex:
	quoted1 = match_all('R6::R6Class\\(\\s*"([A-Za-z][A-Za-z0-9_.]*)"', txt)
	quoted1 = gsub('R6::R6Class\\(\\s*"|"$', "", quoted1)
	quoted2 = match_all('classname\\s*=\\s*"([A-Za-z][A-Za-z0-9_.]*)"', txt)
	quoted2 = gsub('classname\\s*=\\s*"|"$', "", quoted2)
	r_file_names[[f]] = unique(c(lhs, quoted1, quoted2))
}

src_file_names = list()
for (f in src_files) {
	lines = readLines(f, warn = FALSE)
	export_idx = grep("[[Rcpp::export]]", lines, fixed = TRUE)
	nms = character(0)
	for (i in export_idx) {
		for (j in i:min(i + 3L, length(lines))) {
			mm = regmatches(lines[j], regexpr("[A-Za-z_][A-Za-z0-9_]*(?=\\s*\\()", lines[j], perl = TRUE))
			if (length(mm) > 0 && nzchar(mm)) { nms = c(nms, mm[1]); break }
		}
	}
	src_file_names[[f]] = unique(nms)
}

py_file_names = list()
for (f in py_files) {
	lines = readLines(f, warn = FALSE)
	txt = paste(lines, collapse = "\n")
	nms = match_all('m\\.def\\(\\s*"([A-Za-z_][A-Za-z0-9_]*)"', txt)
	nms = gsub('m\\.def\\(\\s*"|"$', "", nms)
	py_file_names[[f]] = unique(nms)
}

live_names = unique(c(unlist(r_file_names), unlist(src_file_names), unlist(py_file_names)))

# ── Which files have an @references block, and their candidate name set ──
# EDI.R's @references is package-level (attached to the package doc itself,
# not any one class/function this map indexes by name) and RcppExports.R is
# fully auto-generated (fast_roxygenize.R regenerates it from the real
# source's own roxygen, so any @references there is a mechanical echo, not a
# citation of its own) -- both are legitimate exceptions, not staleness.
exempt_basenames = c("EDI.R", "RcppExports.R")
files_with_references = function(files, is_cpp, name_lookup) {
	out = list()
	for (f in files) {
		if (basename(f) %in% exempt_basenames) next
		lines = readLines(f, warn = FALSE)
		pat = if (is_cpp) "^//'\\s*@references" else "^#'\\s*@references"
		if (any(grepl(pat, lines, perl = TRUE))) {
			out[[f]] = name_lookup[[f]]
		}
	}
	out
}
ref_r   = files_with_references(r_files, is_cpp = FALSE, r_file_names)
ref_src = files_with_references(src_files, is_cpp = TRUE, src_file_names)
all_ref_files = c(ref_r, ref_src)

# ── Every backtick-quoted "Used by:" name in REFERENCES.md ──
ref_lines = readLines(references_md, warn = FALSE)
# Markdown word-wrapping can split "Used by:" itself across two lines (e.g.
# "... — Used" / "by: `Foo`.") at an unpredictable point, so line-anchored
# matching is unreliable. Instead, split the whole file into per-bullet
# blocks (each starting with "- **[") and join each block's lines with a
# single space before searching -- wrapping then can't hide the phrase.
# A block ends at the next bullet OR the next section heading (## ...),
# whichever comes first -- otherwise the *last* bullet's block would swallow
# every line through end-of-file, including unrelated prose (e.g. a
# "Coverage gaps" section) in any backtick-quoted names it happens to
# mention.
bullet_starts = grep("^-\\s*\\*\\*\\[", ref_lines)
heading_lines = grep("^#", ref_lines)
bullet_ends = vapply(seq_along(bullet_starts), function(b) {
	next_bullet = if (b < length(bullet_starts)) bullet_starts[b + 1L] else length(ref_lines) + 1L
	next_heading = heading_lines[heading_lines > bullet_starts[b]]
	next_heading = if (length(next_heading) > 0) min(next_heading) else length(ref_lines) + 1L
	min(next_bullet, next_heading) - 1L
}, integer(1))
used_by_names = character(0)
for (b in seq_along(bullet_starts)) {
	block_lines = ref_lines[bullet_starts[b]:bullet_ends[b]]
	txt = paste(block_lines, collapse = " ")
	m = regexpr("Used\\s+by:", txt, perl = TRUE)
	if (m == -1) next
	used_by_txt = substr(txt, m + attr(m, "match.length"), nchar(txt))
	names_here = match_all("`([A-Za-z_][A-Za-z0-9_]*)\\(?\\)?`", used_by_txt)
	names_here = gsub("[`()]", "", names_here)
	# Drop filename-shaped tokens (contain a literal "." e.g. "foo.R") and
	# single-character noise -- not real class/function identifiers.
	names_here = names_here[!grepl("\\.", names_here) & nchar(names_here) > 1]
	used_by_names = c(used_by_names, names_here)
}
used_by_names = unique(used_by_names)

# ── Cross-check (a): every @references file has >=1 candidate name indexed ──
missing_files = character(0)
for (f in names(all_ref_files)) {
	candidates = all_ref_files[[f]]
	if (length(candidates) == 0 || !any(candidates %in% used_by_names)) {
		missing_files = c(missing_files, f)
	}
}

# ── Cross-check (b): every "Used by:" name still resolves to something live ──
stale_in_map = setdiff(used_by_names, live_names)

ok = TRUE
if (length(missing_files) > 0) {
	ok = FALSE
	cat("check_references_sync: FAIL -- these files have an @references block but none of their\n")
	cat("declared class/function names are indexed anywhere in REFERENCES.md's \"Used by:\" lists:\n")
	for (f in sort(missing_files)) {
		cat(sprintf("  - %s  (candidates: %s)\n", sub(paste0("^", repo_root, "/"), "", f),
		            paste(all_ref_files[[f]], collapse = ", ")))
	}
}
if (length(stale_in_map) > 0) {
	ok = FALSE
	cat("check_references_sync: FAIL -- REFERENCES.md cites a name that no longer exists (as an R6\n")
	cat("class, Rcpp::export, or pybind11 export) anywhere in R/EDI/R, R/EDI/src, or python/cpp:\n")
	cat(paste0("  - ", sort(stale_in_map)), sep = "\n")
}

if (ok) {
	cat("check_references_sync: OK --", length(all_ref_files), "files with @references,",
	    length(used_by_names), "REFERENCES.md \"Used by:\" names, all in sync.\n")
	quit(status = 0)
} else {
	cat("\ncheck_references_sync: fix REFERENCES.md (R/EDI/REFERENCES.md) so every @references-bearing\n")
	cat("file has at least one of its class/function names indexed under some entry's \"Used by:\"\n")
	cat("list, and every \"Used by:\" name still exists in the codebase under that exact name, then\n")
	cat("re-run.\n")
	quit(status = 1)
}
