#!/usr/bin/env Rscript
# Type-I calibration summarizer for the G4-C calibration runbook
# (release_v1_0_5.md, "G4-C. Calibration runbook", rule G6 #20; used by R1-R3).
#
# The #20 rule, per method x stratum (`~1` and `~.` are separate strata):
#   n_att = outer datasets attempted (rows in the cell);
#   n_fin = finite p-values in [0, 1] from rows whose status is ok (the
#           denominator; same finite-p convention as SimulationFrameworkReport,
#           whose contract is pinned by test-simulation-report-finite-calibration-reference.R);
#   k     = #(finite p < alpha)   (strict, as SimulationFrameworkReport);
#   rate  = k / n_fin, with the exact Clopper-Pearson interval
#           binom.test(k, n_fin)$conf.int (95% by default).
#   PASS                  : the interval contains alpha;
#   FAIL_ANTICONSERVATIVE : the interval lies entirely above alpha;
#   CONSERVATIVE          : the interval lies entirely below alpha (reported, not a
#                           failure; agent reading of #20, the owner may tighten it);
#   NO_FINITE             : n_fin == 0.
#   Target 500 outer datasets per stratum (`meets_target`; basis "attempted" by
#   default, "finite" for R3's ">= 500 finite p-values" reading). No
#   multiplicity adjustment: the decision is per cell.
#
# Inputs (one or more CSVs, comma-separated in --rows):
#   (a) calibration row CSVs written by the scripts in this directory: columns
#       method, stratum, pval and (optionally) status, seed;
#   (b) raw comprehensive_tests.R result CSVs (function_run, inference_class,
#       dataset, design, beta_T, rep, result/result_1, status, skip_reason,
#       error_message). Only beta_T == --beta rows are used (default 0).
#       method = <base class>::<function_run> (or the --map label),
#       stratum = <dataset>|<design>|<formula label from inference_class>.
#       Without --map only function_run values containing "pval" are kept.
#   --map: optional CSV with columns function_run, method and optional
#       class_pattern (regex on the base inference class); only mapped rows
#       are kept.
#
# Usage:
#   Rscript R/package_tests/calibration/summarize_type1_calibration.R \
#     --rows $D/rows.csv[,more.csv] --out-dir $D [--map map.csv] [--alpha 0.05] \
#     [--conf-level 0.95] [--target 500] [--target-basis attempted|finite] [--beta 0] [--prefix type1] \
#     [--methods m1,m2]
# Writes <out-dir>/<prefix>_summary.csv and <prefix>_summary.md (refuses to
# overwrite, refuses any directory inside the checkout).

TYPE1_SUMMARY_COLUMNS <- c(
	"method", "stratum", "n_att", "n_fin", "n_not_finite", "n_nonestimable", "n_error", "n_timeout",
	"n_ok_nonfinite", "k", "rate", "cp_lower", "cp_upper", "conf_level", "alpha", "verdict",
	"target", "target_basis", "meets_target", "target_shortfall"
)

type1_verdict <- function(k, n_fin, alpha = 0.05, conf_level = 0.95) {
	if (!is.finite(n_fin) || n_fin <= 0) return("NO_FINITE")
	ci <- as.numeric(stats::binom.test(as.integer(k), as.integer(n_fin), conf.level = conf_level)$conf.int)
	if (ci[[1L]] > alpha) return("FAIL_ANTICONSERVATIVE")
	if (ci[[2L]] < alpha) return("CONSERVATIVE")
	"PASS"
}

type1_normalize_status <- function(status, pval) {
	status <- as.character(status)
	status[is.na(status) | !nzchar(status)] <- NA_character_
	status <- tolower(status)
	status
}

# Rows with columns method, stratum, pval[, status] -> per-cell summary.
summarize_type1_rows <- function(rows, alpha = 0.05, conf_level = 0.95, target = 500L,
		target_basis = c("attempted", "finite")) {
	target_basis <- match.arg(target_basis)
	required <- c("method", "stratum", "pval")
	missing <- setdiff(required, names(rows))
	if (length(missing)) stop("type-I rows are missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
	if (!nrow(rows)) {
		out <- as.data.frame(setNames(replicate(length(TYPE1_SUMMARY_COLUMNS), logical(), simplify = FALSE),
			TYPE1_SUMMARY_COLUMNS))
		return(out)
	}
	if (!"status" %in% names(rows)) rows$status <- NA_character_
	rows$status <- type1_normalize_status(rows$status, rows$pval)
	id_col <- intersect(c("seed", "rep"), names(rows))
	if (length(id_col)) {
		key <- paste(rows$method, rows$stratum, rows[[id_col[[1L]]]], sep = "\r")
		if (anyDuplicated(key)) {
			stop("duplicate (method, stratum, ", id_col[[1L]], ") rows; each outer dataset must appear once per method",
				call. = FALSE)
		}
	}
	p <- suppressWarnings(as.numeric(rows$pval))
	status_ok <- is.na(rows$status) | rows$status == "ok"
	finite <- status_ok & is.finite(p) & p >= 0 & p <= 1
	cells <- unique(rows[c("method", "stratum")])
	cells <- cells[order(cells$method, cells$stratum), , drop = FALSE]
	out <- lapply(seq_len(nrow(cells)), function(i) {
		in_cell <- rows$method == cells$method[[i]] & rows$stratum == cells$stratum[[i]]
		n_att <- sum(in_cell)
		n_fin <- sum(in_cell & finite)
		k <- sum(in_cell & finite & p < alpha)
		ci <- if (n_fin > 0L) as.numeric(stats::binom.test(k, n_fin, conf.level = conf_level)$conf.int) else c(NA_real_, NA_real_)
		basis_n <- if (identical(target_basis, "finite")) n_fin else n_att
		data.frame(
			method = cells$method[[i]],
			stratum = cells$stratum[[i]],
			n_att = n_att,
			n_fin = n_fin,
			n_not_finite = n_att - n_fin,
			n_nonestimable = sum(in_cell & rows$status %in% "nonestimable"),
			n_error = sum(in_cell & rows$status %in% "error"),
			n_timeout = sum(in_cell & rows$status %in% "timeout"),
			n_ok_nonfinite = sum(in_cell & status_ok & !finite),
			k = k,
			rate = if (n_fin > 0L) k / n_fin else NA_real_,
			cp_lower = ci[[1L]],
			cp_upper = ci[[2L]],
			conf_level = conf_level,
			alpha = alpha,
			verdict = type1_verdict(k, n_fin, alpha, conf_level),
			target = as.integer(target),
			target_basis = target_basis,
			meets_target = basis_n >= target,
			target_shortfall = max(0L, as.integer(target) - basis_n),
			stringsAsFactors = FALSE
		)
	})
	out <- do.call(rbind, out)
	rownames(out) <- NULL
	out[TYPE1_SUMMARY_COLUMNS]
}

# Raw comprehensive_tests.R rows -> method/stratum/pval/status rows.
type1_rows_from_comprehensive <- function(df, map = NULL, beta = 0) {
	need <- c("function_run", "inference_class", "dataset", "design", "beta_T", "status")
	missing <- setdiff(need, names(df))
	if (length(missing)) stop("comprehensive CSV is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
	df <- df[is.finite(suppressWarnings(as.numeric(df$beta_T))) & abs(as.numeric(df$beta_T) - beta) < 1e-12, , drop = FALSE]
	base_class <- sub(" [\\(\\[].*$", "", df$inference_class)
	# perl = TRUE: R's default ERE engine does not honour backslash escapes inside [...]
	formula_re <- "^.*[\\(\\[][^=\\)\\]]*=([^\\)\\]]*)[\\)\\]].*$"
	formula_label <- ifelse(grepl(formula_re, df$inference_class, perl = TRUE),
		sub(formula_re, "\\1", df$inference_class, perl = TRUE), "NA")
	if (is.null(map)) {
		keep <- grepl("pval", df$function_run, fixed = TRUE)
		method <- paste0(base_class, "::", df$function_run)
	} else {
		if (!all(c("function_run", "method") %in% names(map))) {
			stop("--map needs columns function_run and method (optional class_pattern)", call. = FALSE)
		}
		method <- rep(NA_character_, nrow(df))
		for (j in seq_len(nrow(map))) {
			hit <- df$function_run == map$function_run[[j]]
			if ("class_pattern" %in% names(map) && !is.na(map$class_pattern[[j]]) && nzchar(map$class_pattern[[j]])) {
				hit <- hit & grepl(map$class_pattern[[j]], base_class)
			}
			method[hit & is.na(method)] <- map$method[[j]]
		}
		keep <- !is.na(method)
	}
	pv_col <- if ("result" %in% names(df)) "result" else "result_1"
	pval <- suppressWarnings(as.numeric(df[[pv_col]]))
	if (pv_col == "result" && "result_1" %in% names(df)) {
		fill <- !is.finite(pval)
		pval[fill] <- suppressWarnings(as.numeric(df$result_1[fill]))
	}
	status <- tolower(as.character(df$status))
	skip <- if ("skip_reason" %in% names(df)) as.character(df$skip_reason) else rep("", nrow(df))
	msg <- if ("error_message" %in% names(df)) as.character(df$error_message) else rep("", nrow(df))
	skip[is.na(skip)] <- ""
	msg[is.na(msg)] <- ""
	timeout <- skip == "timeout" | grepl("^Skipped due to timeout", msg, ignore.case = TRUE)
	status[timeout] <- "timeout"
	status[status == "ok" & !is.finite(pval)] <- "nonestimable"
	out <- data.frame(
		method = method,
		stratum = paste(df$dataset, df$design, formula_label, sep = "|"),
		rep = if ("rep" %in% names(df)) df$rep else NA_integer_,
		pval = pval,
		status = status,
		stringsAsFactors = FALSE
	)
	out[keep, , drop = FALSE]
}

type1_read_input <- function(path, map = NULL, beta = 0) {
	df <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("NA", ""))
	if (all(c("method", "stratum", "pval") %in% names(df))) return(df)
	if ("function_run" %in% names(df)) return(type1_rows_from_comprehensive(df, map = map, beta = beta))
	stop("unrecognized row CSV schema: ", path, call. = FALSE)
}

type1_markdown <- function(summary, title = "Type-I calibration summary (G6 #20 rule)", notes = character()) {
	shown <- summary[c("method", "stratum", "n_att", "n_fin", "n_not_finite", "k", "rate", "cp_lower", "cp_upper",
		"verdict", "meets_target")]
	c(
		paste("#", title), "",
		sprintf("Rule: per method x stratum; finite-p denominator; k = #(p < %s); exact Clopper-Pearson %s%% interval.",
			format(summary$alpha[1L]), format(100 * summary$conf_level[1L])),
		"PASS = interval contains alpha; FAIL_ANTICONSERVATIVE = interval entirely above alpha;",
		"CONSERVATIVE = entirely below alpha (reported, not a failure); no multiplicity adjustment.",
		sprintf("Target: %d outer datasets per cell (basis: %s).", summary$target[1L], summary$target_basis[1L]),
		if (length(notes)) c("", paste0("- ", notes)) else character(),
		"",
		calib_write_markdown_table_local(shown),
		"",
		sprintf("Cells: %d; PASS %d; FAIL_ANTICONSERVATIVE %d; CONSERVATIVE %d; NO_FINITE %d; below target %d.",
			nrow(summary), sum(summary$verdict == "PASS"), sum(summary$verdict == "FAIL_ANTICONSERVATIVE"),
			sum(summary$verdict == "CONSERVATIVE"), sum(summary$verdict == "NO_FINITE"), sum(!summary$meets_target))
	)
}

calib_write_markdown_table_local <- function(df, digits = 4L) {
	if (exists("calib_write_markdown_table", mode = "function")) return(calib_write_markdown_table(df, digits))
	if (!nrow(df)) return("(no rows)")
	fmt <- lapply(df, function(col) if (is.numeric(col)) ifelse(is.na(col), "NA", signif(col, digits)) else
		ifelse(is.na(col), "NA", as.character(col)))
	c(paste0("| ", paste(names(df), collapse = " | "), " |"),
		paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
		vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(vapply(fmt, function(c) as.character(c[[i]]), ""),
			collapse = " | "), " |"), ""))
}

# Writes <prefix>_summary.csv / .md into out_dir; refuses to overwrite.
write_type1_summary <- function(summary, out_dir, prefix = "type1", notes = character(), title = NULL) {
	csv <- file.path(out_dir, paste0(prefix, "_summary.csv"))
	md <- file.path(out_dir, paste0(prefix, "_summary.md"))
	for (f in c(csv, md)) if (file.exists(f)) stop("refusing to overwrite ", f, call. = FALSE)
	utils::write.csv(summary, csv, row.names = FALSE, na = "NA")
	writeLines(type1_markdown(summary, title = if (is.null(title)) "Type-I calibration summary (G6 #20 rule)" else title,
		notes = notes), md)
	invisible(c(csv = csv, md = md))
}

type1_main <- function(args) {
	usage <- paste(
		"Usage: Rscript R/package_tests/calibration/summarize_type1_calibration.R --rows <csv[,csv...]> --out-dir <dir>",
		"  [--map map.csv] [--alpha 0.05] [--conf-level 0.95] [--target 500] [--target-basis attempted|finite]",
		"  [--beta 0] [--prefix type1] [--methods m1,m2 (keep only these method labels)]", sep = "\n")
	opt <- calib_parse_args(args, defaults = list(rows = "", out_dir = "", map = "", alpha = "0.05",
		conf_level = "0.95", target = "500", target_basis = "attempted", beta = "0", prefix = "type1", methods = ""),
		usage = usage)
	if (!nzchar(opt$rows) || !nzchar(opt$out_dir)) {
		cat(usage, "\n")
		quit(save = "no", status = 2L)
	}
	script <- calib_script_path()
	repo_root <- calib_find_repo_root(dirname(script))
	out_dir <- calib_resolve_path(opt$out_dir)
	for (p in c(file.path(repo_root, "R", "package_metadata"), repo_root)) {
		if (calib_path_is_within(out_dir, p)) stop("refusing to write a summary inside the checkout: ", out_dir, call. = FALSE)
	}
	if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
	map <- if (nzchar(opt$map)) utils::read.csv(opt$map, stringsAsFactors = FALSE) else NULL
	paths <- calib_parse_chr_set(opt$rows)
	rows <- do.call(rbind, lapply(paths, function(p) {
		r <- type1_read_input(p, map = map, beta = as.numeric(opt$beta))
		r[intersect(c("method", "stratum", "seed", "rep", "pval", "status"), names(r))]
	}))
	if (nzchar(opt$methods)) rows <- rows[rows$method %in% calib_parse_chr_set(opt$methods), , drop = FALSE]
	summary <- summarize_type1_rows(rows, alpha = as.numeric(opt$alpha), conf_level = as.numeric(opt$conf_level),
		target = as.integer(opt$target), target_basis = opt$target_basis)
	files <- write_type1_summary(summary, out_dir, prefix = opt$prefix,
		notes = c(sprintf("inputs: %s", paste(paths, collapse = ", ")),
			sprintf("input sha256: %s", paste(vapply(paths, calib_sha256, ""), collapse = ", "))))
	print(summary[c("method", "stratum", "n_att", "n_fin", "k", "rate", "cp_lower", "cp_upper", "verdict")], row.names = FALSE)
	cat("wrote", files[["csv"]], "and", files[["md"]], "\n")
	invisible(summary)
}

if (!exists("calib_parse_args", mode = "function")) {
	.type1_here <- local({
		f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
		if (length(f)) dirname(normalizePath(sub("^--file=", "", f[[1L]]))) else NA_character_
	})
	.type1_common <- if (exists(".type1_source_dir")) file.path(.type1_source_dir, "calibration_common.R") else
		file.path(.type1_here, "calibration_common.R")
	if (!is.na(.type1_common) && file.exists(.type1_common)) source(.type1_common)
}

if (sys.nframe() == 0L && identical(basename(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])),
		"summarize_type1_calibration.R")) {
	type1_main(commandArgs(trailingOnly = TRUE))
}
