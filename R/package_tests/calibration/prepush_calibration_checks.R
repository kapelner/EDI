#!/usr/bin/env Rscript
# Pre-push calibration check (design: R/package_metadata/new_feature_plans/
# calibration_gates.md). Run by scripts/pre-push when R/EDI source changes.
#
# Size and coverage are NOT checked here -- that needs hundreds of replicates
# and lives in the scheduled CI fast tier. This script asserts only what one
# replicate can already prove wrong, for the inference classes the push
# touched, on synthetic data (n = 200, p = 2, cheapest compatible design,
# fast analytic procedures at ~ 1 and ~ .; see calibration_fast_tier_common.R):
#
#   agreement  every null replicate (3 of them): "CI excludes the null value"
#              must equal "p < alpha" (ignored when p is within 0.002 of alpha);
#   endpoint   the class's own test re-run at each CI endpoint must give a
#              p-value in [0.7, 1.4] * alpha -- catches an interval built at the
#              wrong level (the alpha/2 bug) or not inverted from its own test;
#              only for p-value methods that accept `delta`;
#   sign       one replicate with a large positive treatment effect: the
#              estimate must sit on the expected side of the null and the CI
#              must exclude it (or p < alpha when there is no CI).
#
# Every replicate uses a fixed seed, so a verdict is deterministic for fixed
# code. Failures listed in prepush_calibration_known_failures.csv are reported
# but do not block; a listed failure that no longer reproduces DOES block, so
# the list cannot go stale (delete the row). NA results are skipped, not failed.
#
# "Touched" classes, from the changed-file list (--changed-files, one repo path
# per line, as scripts/pre-push collects it):
#   * classes defined in a changed R/EDI/R file;
#   * classes composing an inference component whose source file changed
#     (component registry `file`, followed through component dependencies);
#   * classes whose defining file or component files mention a top-level name
#     (>= 5 chars) assigned in a changed R file, or an [[Rcpp::export]] kernel
#     name defined in a changed .cpp;
#   * every descendant of a touched class (registry `parent` chain).
#   A changed .h/.hpp, or EDI_PREPUSH_CALIBRATION=all, selects every class.
#   EDI_PREPUSH_CALIBRATION=skip skips the check (prints a notice).
#
# Uses the INSTALLED EDI, like the other pre-push R scripts: install the code
# you are pushing first.
#
# Usage: Rscript R/package_tests/calibration/prepush_calibration_checks.R \
#          --changed-files FILE [--all] [--write-known-failures PATH]
# --write-known-failures writes every current failure as a known-failures CSV
# (used once to seed the list; review every row before committing it).

suppressPackageStartupMessages(library(EDI))

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
repo_root <- normalizePath(file.path(script_dir, "..", "..", ".."))
source(file.path(script_dir, "calibration_fast_tier_common.R"))

PREPUSH_N <- 200L
PREPUSH_NULL_REPS <- 1:3
PREPUSH_ENDPOINT_BAND <- c(0.7, 1.4) * CAL_ALPHA
PREPUSH_AGREEMENT_SLACK <- 0.002
# Too slow for a push (~190 s per replicate at n = 200); the CI tier covers it.
PREPUSH_EXCLUDED_CLASSES <- c("InferenceCountKKGLMM")
# Endpoint check skipped (agreement and sign still run): on heavily tied data the
# rank-sum p-value is a step function of delta, and the CI endpoints sit on its
# jumps, so the p-value at an endpoint is legitimately far from alpha.
PREPUSH_ENDPOINT_EXEMPT <- data.frame(
	response_type = c("count", "ordinal"),
	inference_class = "InferenceAllSimpleWilcox")
KNOWN_FAILURES_PATH <- file.path(script_dir, "prepush_calibration_known_failures.csv")

args <- commandArgs(TRUE)
arg_value <- function(flag) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) NULL else args[[i + 1L]]
}
changed_path <- arg_value("--changed-files")
write_known <- arg_value("--write-known-failures")
mode <- Sys.getenv("EDI_PREPUSH_CALIBRATION", unset = "")
if (identical(mode, "skip")) {
	cat("prepush_calibration: EDI_PREPUSH_CALIBRATION=skip -- calibration check skipped.\n")
	quit(status = 0L)
}
run_all <- "--all" %in% args || identical(mode, "all")
changed <- if (!is.null(changed_path) && file.exists(changed_path)) trimws(readLines(changed_path, warn = FALSE)) else character()
changed <- changed[nzchar(changed)]

# ---------------------------------------------------------------------------
# Touched classes.
# ---------------------------------------------------------------------------
r_dir <- file.path(repo_root, "R", "EDI", "R")
read_text <- function(path) if (file.exists(path)) paste(readLines(path, warn = FALSE), collapse = "\n") else ""

class_file_index <- function() {
	out <- character()
	for (f in list.files(r_dir, pattern = "\\.R$")) {
		hits <- regmatches(read_text(file.path(r_dir, f)),
			gregexpr("(?m)^\\s*([A-Za-z][A-Za-z0-9_.]*)\\s*(=|<-)\\s*(define_inference_class|R6::R6Class|R6Class)\\(", read_text(file.path(r_dir, f)), perl = TRUE))[[1L]]
		for (h in hits) out[[sub("^\\s*([A-Za-z][A-Za-z0-9_.]*).*$", "\\1", h)]] <- f
	}
	out
}

component_files <- function(components) {
	reg <- EDI:::EDI_INFERENCE_COMPONENTS
	seen <- character()
	queue <- components
	files <- character()
	while (length(queue)) {
		nm <- queue[[1L]]
		queue <- queue[-1L]
		if (nm %in% seen || !exists(nm, envir = reg, inherits = FALSE)) next
		seen <- c(seen, nm)
		comp <- get(nm, envir = reg)
		if (!is.null(comp$file)) files <- c(files, comp$file)
		queue <- c(queue, comp$dependencies %||% character())
	}
	unique(files)
}

touched_classes <- function(candidates) {
	if (run_all) return(candidates)
	src <- changed[grepl("^R/EDI/(R/.*\\.R|src/.*\\.(cpp|h|hpp))$", changed)]
	if (!length(src)) return(character())
	if (any(grepl("\\.(h|hpp)$", src))) {
		cat("prepush_calibration: a C/C++ header changed -- checking every class.\n")
		return(candidates)
	}
	changed_r <- basename(src[grepl("\\.R$", src)])
	names_defined <- character()
	for (f in changed_r) {
		txt <- read_text(file.path(r_dir, f))
		nm <- regmatches(txt, gregexpr("(?m)^([A-Za-z.][A-Za-z0-9_.]*)\\s*(=|<-)", txt, perl = TRUE))[[1L]]
		names_defined <- c(names_defined, sub("\\s*(=|<-)$", "", nm))
	}
	for (f in src[grepl("\\.cpp$", src)]) {
		lines <- readLines(file.path(repo_root, f), warn = FALSE)
		at <- grep("\\[\\[Rcpp::export", lines)
		for (i in at) {
			sig <- paste(lines[(i + 1L):min(length(lines), i + 3L)], collapse = " ")
			m <- regmatches(sig, regexpr("[A-Za-z_][A-Za-z0-9_]*\\s*\\(", sig))
			if (length(m)) names_defined <- c(names_defined, sub("\\s*\\($", "", m))
		}
	}
	names_defined <- unique(names_defined[nchar(names_defined) >= 5L])
	idx <- class_file_index()
	all_classes <- unique(c(candidates, names(idx)))
	direct <- character()
	for (cls in all_classes) {
		meta <- tryCatch(EDI:::get_inference_class_metadata(cls), error = function(e) NULL)
		files <- unique(c(idx[cls][!is.na(idx[cls])], component_files(meta$direct_components %||% character())))
		if (any(files %in% changed_r)) {
			direct <- c(direct, cls)
			next
		}
		if (length(names_defined)) {
			txt <- paste(vapply(file.path(r_dir, files), read_text, ""), collapse = "\n")
			if (any(vapply(names_defined, function(nm) grepl(paste0("\\b", gsub(".", "\\.", nm, fixed = TRUE), "\\b"), txt, perl = TRUE), logical(1L)))) {
				direct <- c(direct, cls)
			}
		}
	}
	# Descendants: walk each candidate's parent chain.
	ancestors <- function(cls) {
		out <- character()
		cur <- cls
		for (k in 1:50) {
			p <- tryCatch(EDI:::get_inference_class_metadata(cur)$parent, error = function(e) NULL)
			if (is.null(p) || is.na(p) || !nzchar(p) || p %in% out) break
			out <- c(out, p)
			cur <- p
		}
		out
	}
	candidates[vapply(candidates, function(cls) cls %in% direct || any(ancestors(cls) %in% direct), logical(1L))]
}

# ---------------------------------------------------------------------------
# Run and judge.
# ---------------------------------------------------------------------------
judge <- function(rows) {
	fails <- list()
	add <- function(r, check, detail) {
		fails[[length(fails) + 1L]] <<- data.frame(response_type = r$response_type, design = r$design,
			inference_class = r$inference_class, method = r$method, formula = r$formula, check = check,
			detail = detail, stringsAsFactors = FALSE)
	}
	for (i in seq_len(nrow(rows))) {
		r <- rows[i, ]
		if (r$status != "ok") next
		has_ci <- is.finite(r$ci_a) && is.finite(r$ci_b)
		excludes <- has_ci && !(r$ci_a <= r$null_value && r$null_value <= r$ci_b)
		if (r$effect == 0 && has_ci && is.finite(r$pval) && abs(r$pval - CAL_ALPHA) > PREPUSH_AGREEMENT_SLACK &&
				excludes != (r$pval < CAL_ALPHA)) {
			add(r, "agreement", sprintf("rep %d: p = %.4g but CI [%.4g, %.4g] %s null %g", r$rep, r$pval, r$ci_a, r$ci_b,
				if (excludes) "excludes" else "contains", r$null_value))
		}
		endpoint_exempt <- any(PREPUSH_ENDPOINT_EXEMPT$response_type == r$response_type &
			PREPUSH_ENDPOINT_EXEMPT$inference_class == r$inference_class)
		for (side in if (endpoint_exempt) character() else c("ci_a", "ci_b")) {
			p_end <- r[[paste0("p_at_", side)]]
			if (is.finite(p_end) && (p_end < PREPUSH_ENDPOINT_BAND[[1L]] || p_end > PREPUSH_ENDPOINT_BAND[[2L]])) {
				add(r, "endpoint", sprintf("%s rep %d: p at %s = %.4g is %.4g, expected ~%g",
					if (r$effect == 0) "null" else "effect", r$rep, side, r[[side]], p_end, CAL_ALPHA))
			}
		}
		if (r$effect != 0) {
			dir <- cal_expected_direction(r$inference_class)
			if (is.finite(r$estimate) && sign(r$estimate - r$null_value) != dir) {
				add(r, "sign", sprintf("estimate %.4g is on the wrong side of null %g (expected %s)", r$estimate, r$null_value,
					if (dir > 0) "above" else "below"))
			} else if (has_ci && !excludes) {
				add(r, "sign", sprintf("large-effect CI [%.4g, %.4g] still contains null %g", r$ci_a, r$ci_b, r$null_value))
			} else if (!has_ci && is.finite(r$pval) && r$pval >= CAL_ALPHA) {
				add(r, "sign", sprintf("large-effect p = %.4g does not reject", r$pval))
			}
		}
	}
	if (!length(fails)) return(NULL)
	# One line per (cell, check): keep the first detail.
	f <- do.call(rbind, fails)
	f[!duplicated(f[, c("response_type", "design", "inference_class", "method", "formula", "check")]), ]
}

t_start <- proc.time()[["elapsed"]]
all_rows <- list()
n_classes <- 0L
for (rt in CAL_RESPONSE_TYPES) {
	plan <- cal_class_plan(rt, PREPUSH_N)
	plan <- lapply(plan, function(cls) setdiff(cls, PREPUSH_EXCLUDED_CLASSES))
	keep <- touched_classes(unlist(plan, use.names = FALSE))
	if (!length(keep)) next
	if ("--list-only" %in% args) {
		cat(sprintf("%s: %s\n", rt, paste(keep, collapse = " ")))
		next
	}
	n_classes <- n_classes + length(keep)
	cat(sprintf("prepush_calibration: %-10s %d class(es): %s\n", rt, length(keep), paste(sub("^Inference", "", keep), collapse = ", ")))
	for (rep in PREPUSH_NULL_REPS) {
		all_rows[[length(all_rows) + 1L]] <- cal_run_rep(rt, PREPUSH_N, rep, plan, keep = keep, effect = 0, endpoints = TRUE)
	}
	all_rows[[length(all_rows) + 1L]] <- cal_run_rep(rt, PREPUSH_N, 1L, plan, keep = keep,
		effect = CAL_SIGN_EFFECT[[rt]], endpoints = TRUE)
}
if ("--list-only" %in% args) quit(status = 0L)
if (!n_classes) {
	cat("prepush_calibration: no inference class touched -- nothing to check.\n")
	quit(status = 0L)
}
rows <- do.call(rbind, Filter(Negate(is.null), all_rows))
fails <- judge(rows)
cat(sprintf("prepush_calibration: %d class(es), %d task rows, %.0f s\n", n_classes, nrow(rows), proc.time()[["elapsed"]] - t_start))

if (!is.null(write_known)) {
	out <- if (is.null(fails)) data.frame(response_type = character(), inference_class = character(), method = character(), formula = character(),
		check = character(), reason = character()) else
		data.frame(fails[, c("response_type", "inference_class", "method", "formula", "check")], reason = fails$detail)
	utils::write.csv(unique(out), write_known, row.names = FALSE)
	cat(sprintf("prepush_calibration: wrote %d known-failure row(s) to %s -- review each before committing.\n", nrow(out), write_known))
	quit(status = 0L)
}

key <- function(df) paste(df$response_type, df$inference_class, df$method, df$formula, df$check, sep = " | ")
known <- if (file.exists(KNOWN_FAILURES_PATH)) utils::read.csv(KNOWN_FAILURES_PATH, stringsAsFactors = FALSE, colClasses = "character") else NULL
known_keys <- if (is.null(known)) character() else key(known)
fail_keys <- if (is.null(fails)) character() else key(fails)
new_fail <- if (is.null(fails)) NULL else fails[!fail_keys %in% known_keys, ]
# A known failure is stale only if its class was actually checked this push.
checked_keys <- unique(paste(rows$response_type, rows$inference_class, rows$method, rows$formula, sep = " | "))
stale <- if (is.null(known)) character() else
	known_keys[paste(known$response_type, known$inference_class, known$method, known$formula, sep = " | ") %in% checked_keys & !known_keys %in% fail_keys]

if (length(fail_keys) && any(fail_keys %in% known_keys)) {
	cat(sprintf("prepush_calibration: %d known failure(s) still present (listed in %s, not blocking).\n",
		sum(fail_keys %in% known_keys), basename(KNOWN_FAILURES_PATH)))
}
status <- 0L
if (!is.null(new_fail) && nrow(new_fail)) {
	cat("\nprepush_calibration: FAILED -- new calibration failure(s):\n", file = stderr())
	for (i in seq_len(nrow(new_fail))) {
		f <- new_fail[i, ]
		cat(sprintf("  [%s] %s %s %s (%s, %s): %s\n", f$check, f$inference_class, f$method, f$formula,
			f$response_type, sub("^DesignFixed", "", f$design), f$detail), file = stderr())
	}
	status <- 1L
}
if (length(stale)) {
	cat("\nprepush_calibration: FAILED -- known failure(s) no longer reproduce; delete these rows from ",
		basename(KNOWN_FAILURES_PATH), ":\n", sep = "", file = stderr())
	cat(paste0("  ", stale, "\n"), sep = "", file = stderr())
	status <- 1L
}
if (status == 0L) cat("prepush_calibration: OK\n")
quit(status = status)
