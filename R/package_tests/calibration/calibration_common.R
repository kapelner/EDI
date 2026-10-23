# Shared helpers for the G4-C calibration scripts (release_v1_0_5.md,
# "G4-C. Calibration runbook", R1-R7). Pure R; sourced by the scripts in this
# directory and by R/benchmark/benchmark_todo67_kk21_matching_quality.R.
#
# Contract shared by every calibration script:
#   * it loads the INSTALLED EDI with library(EDI) (never load_all, never the
#     checkout) and refuses to run if the loaded namespace lives in the checkout;
#   * it writes only into a fresh output directory OUTSIDE the git checkout
#     (so never under R/package_metadata, R/package_tests or any canonical
#     results directory);
#   * it records provenance with capture_comprehensive_run_provenance() from
#     R/package_tests/comprehensive_run_provenance.R, saved as provenance.rds;
#   * it appends one row per (outer replicate, method) to a row CSV as soon as
#     the row is known, then writes summaries computed only from those rows.

calib_script_path <- function() {
	file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
	if (!length(file_arg)) return(NA_character_)
	normalizePath(sub("^--file=", "", file_arg[[1L]]), winslash = "/", mustWork = TRUE)
}

calib_find_repo_root <- function(start) {
	dir <- normalizePath(start, winslash = "/", mustWork = TRUE)
	if (!dir.exists(dir)) dir <- dirname(dir)
	repeat {
		if (file.exists(file.path(dir, "R", "package_tests", "comprehensive_run_provenance.R")) &&
				dir.exists(file.path(dir, "R", "EDI"))) {
			return(dir)
		}
		parent <- dirname(dir)
		if (identical(parent, dir)) stop("could not locate the EDI repository root above ", start, call. = FALSE)
		dir <- parent
	}
}

# ---------------------------------------------------------------------------
# Command line: --name value pairs plus boolean flags.
# ---------------------------------------------------------------------------
calib_parse_args <- function(args, defaults, flags = character(), usage = NULL) {
	out <- defaults
	for (f in flags) out[[f]] <- FALSE
	i <- 1L
	while (i <= length(args)) {
		a <- args[[i]]
		if (a %in% c("-h", "--help")) {
			if (!is.null(usage)) cat(usage, "\n")
			quit(save = "no", status = 0L)
		}
		if (!startsWith(a, "--")) stop("unexpected argument: ", a, call. = FALSE)
		name <- gsub("-", "_", substring(a, 3L), fixed = TRUE)
		if (grepl("=", name, fixed = TRUE)) {
			value <- sub("^[^=]*=", "", substring(a, 3L))
			name <- sub("=.*$", "", name)
			i <- i + 1L
		} else if (name %in% flags) {
			out[[name]] <- TRUE
			i <- i + 1L
			next
		} else {
			if (i == length(args)) stop("missing value after ", a, call. = FALSE)
			value <- args[[i + 1L]]
			i <- i + 2L
		}
		if (name %in% flags) {
			out[[name]] <- value %in% c("1", "true", "TRUE", "yes")
		} else if (!name %in% names(defaults)) {
			stop("unknown option --", gsub("_", "-", name, fixed = TRUE), call. = FALSE)
		} else {
			out[[name]] <- value
		}
	}
	out
}

# "1001:1400", "1,2,5", "1001:1010,2000" -> integer vector (order kept, no duplicates allowed)
calib_parse_int_set <- function(x, what = "seeds") {
	if (is.numeric(x)) return(as.integer(x))
	parts <- trimws(strsplit(as.character(x), ",", fixed = TRUE)[[1L]])
	parts <- parts[nzchar(parts)]
	vals <- unlist(lapply(parts, function(p) {
		if (grepl("^-?[0-9]+:-?[0-9]+$", p)) {
			ends <- as.integer(strsplit(p, ":", fixed = TRUE)[[1L]])
			seq.int(ends[[1L]], ends[[2L]])
		} else if (grepl("^-?[0-9]+$", p)) {
			as.integer(p)
		} else {
			stop("could not parse ", what, " entry: ", p, call. = FALSE)
		}
	}), use.names = FALSE)
	if (!length(vals)) stop("empty ", what, call. = FALSE)
	if (anyDuplicated(vals)) stop("duplicate values in ", what, call. = FALSE)
	vals
}

calib_parse_num_set <- function(x) {
	vals <- as.numeric(trimws(strsplit(as.character(x), ",", fixed = TRUE)[[1L]]))
	if (!length(vals) || anyNA(vals)) stop("could not parse numeric list: ", x, call. = FALSE)
	vals
}

calib_parse_chr_set <- function(x) {
	vals <- trimws(strsplit(as.character(x), ",", fixed = TRUE)[[1L]])
	vals[nzchar(vals)]
}

# ---------------------------------------------------------------------------
# Output-directory guard.
# ---------------------------------------------------------------------------
calib_path_is_within <- function(path, root) {
	root <- normalizePath(root, winslash = "/", mustWork = TRUE)
	root_prefix <- if (endsWith(root, "/")) root else paste0(root, "/")
	identical(path, root) || startsWith(paste0(path, "/"), root_prefix)
}

# Resolve a path whose tail may not exist yet (normalizes the deepest existing
# ancestor so symlinks into the checkout are caught).
calib_resolve_path <- function(path) {
	path <- path.expand(path)
	if (!grepl("^(/|[A-Za-z]:)", path)) path <- file.path(getwd(), path)
	tail <- character()
	cur <- path
	while (!file.exists(cur)) {
		tail <- c(basename(cur), tail)
		parent <- dirname(cur)
		if (identical(parent, cur)) break
		cur <- parent
	}
	base <- normalizePath(cur, winslash = "/", mustWork = TRUE)
	if (length(tail)) do.call(file.path, as.list(c(base, tail))) else base
}

calib_prepare_output_dir <- function(out_dir, repo_root) {
	if (length(out_dir) != 1L || is.na(out_dir) || !nzchar(out_dir)) {
		stop("--out-dir is required (use a fresh directory outside the checkout, e.g. ",
			"/tmp/edi_calib_todo<N>_$(date -u +%Y%m%dT%H%M%SZ))", call. = FALSE)
	}
	resolved <- calib_resolve_path(out_dir)
	protected <- c(
		file.path(repo_root, "R", "package_metadata"),
		file.path(repo_root, "R", "package_tests"),
		file.path(repo_root, "R", "benchmark"),
		file.path(repo_root, "R", "EDI"),
		repo_root
	)
	for (p in protected[dir.exists(protected)]) {
		if (calib_path_is_within(resolved, p)) {
			stop("refusing to write calibration output inside the checkout (", p, "): ", resolved,
				". Use a fresh directory outside the repository, e.g. under /tmp.", call. = FALSE)
		}
	}
	results_override <- Sys.getenv("EDI_COMPREHENSIVE_RESULTS_DIR", unset = "")
	if (dir.exists(resolved)) {
		existing <- list.files(resolved, all.files = TRUE, no.. = TRUE)
		if (length(existing)) {
			stop("output directory is not empty (use one fresh directory per run): ", resolved, call. = FALSE)
		}
	} else {
		if (!dir.create(resolved, recursive = TRUE)) stop("could not create output directory ", resolved, call. = FALSE)
	}
	if (nzchar(results_override) && dir.exists(results_override) &&
			identical(normalizePath(results_override, winslash = "/"), normalizePath(resolved, winslash = "/"))) {
		message("NOTE: --out-dir equals EDI_COMPREHENSIVE_RESULTS_DIR; keep calibration rows and comprehensive CSVs apart if possible.")
	}
	normalizePath(resolved, winslash = "/", mustWork = TRUE)
}

# ---------------------------------------------------------------------------
# Installed-package load and provenance.
# ---------------------------------------------------------------------------
calib_load_installed_edi <- function(repo_root) {
	if (!"EDI" %in% loadedNamespaces()) {
		suppressPackageStartupMessages(library(EDI))
	}
	ns_path <- normalizePath(getNamespaceInfo(asNamespace("EDI"), "path"), winslash = "/", mustWork = TRUE)
	if (calib_path_is_within(ns_path, file.path(repo_root, "R", "EDI"))) {
		stop("EDI is loaded from the checkout (", ns_path, "); these scripts must run against the INSTALLED package.",
			call. = FALSE)
	}
	invisible(ns_path)
}

calib_sha256 <- function(path) {
	if (length(path) != 1L || is.na(path) || !file.exists(path) || dir.exists(path)) return(NA_character_)
	for (cmd in list(c("sha256sum"), c("shasum", "-a", "256"), c("openssl", "dgst", "-sha256"))) {
		exe <- Sys.which(cmd[[1L]])
		if (!nzchar(exe)) next
		out <- tryCatch(suppressWarnings(system2(exe, c(cmd[-1L], shQuote(path)), stdout = TRUE, stderr = FALSE)),
			error = function(e) character())
		h <- regmatches(out, regexpr("[[:xdigit:]]{64}", out))
		if (length(h)) return(tolower(h[[1L]]))
	}
	NA_character_
}

calib_capture_provenance <- function(repo_root, script_path, out_dir, args, seeds, extra = list()) {
	helper <- file.path(repo_root, "R", "package_tests", "comprehensive_run_provenance.R")
	source(helper, local = environment())
	# capture_comprehensive_run_provenance() derives the package root and the
	# beta-filter helper from dirname(runner_path), which must be
	# R/package_tests; anchor it on the provenance helper itself and record the
	# calibration script separately below.
	base <- capture_comprehensive_run_provenance(repo_root, helper)
	common <- file.path(repo_root, "R", "package_tests", "calibration", "calibration_common.R")
	prov <- c(base, list(
		calibration_schema_version = 1L,
		calibration_script_path = script_path,
		calibration_script_sha256 = if (!is.na(script_path)) comprehensive_sha256_file(script_path) else NA_character_,
		calibration_common_path = common,
		calibration_common_sha256 = comprehensive_sha256_file(common),
		runner_path_note = paste(
			"runner_path/runner_sha256 name the provenance helper (the anchor capture_comprehensive_run_provenance()",
			"needs); the calibration script is calibration_script_path/_sha256."),
		checkout_dirty = length(base$checkout_status_porcelain) > 0L,
		edi_library_path = dirname(base$edi_package_path),
		lib_paths = .libPaths(),
		command_args = args,
		seeds = seeds,
		output_dir = out_dir,
		r_platform = R.version$platform,
		blas = tryCatch(unname(extSoftVersion()["BLAS"]), error = function(e) NA_character_),
		thread_env = as.list(Sys.getenv(c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "NOT_CRAN"),
			unset = "<unset>")),
		edi_num_cores = tryCatch(EDI:::get_num_cores(), error = function(e) NA_integer_),
		attached_package_versions = vapply(
			c("EDI", "survival", "nbpMatching", "data.table", "dplyr", "Rcpp", "RcppEigen"),
			function(p) tryCatch(as.character(utils::packageVersion(p)), error = function(e) "<not installed>"),
			character(1L))
	), extra)
	saveRDS(prov, file.path(out_dir, "provenance.rds"))
	lines <- c(
		sprintf("captured_at_utc: %s", prov$captured_at_utc),
		sprintf("edi_package_version: %s", prov$edi_package_version),
		sprintf("edi_package_path: %s", prov$edi_package_path),
		sprintf("edi_library_path: %s", prov$edi_library_path),
		sprintf("edi_dll_path: %s", prov$edi_dll_path),
		sprintf("edi_dll_sha256: %s", prov$edi_dll_sha256),
		sprintf("checkout_head: %s", prov$checkout_head),
		sprintf("checkout_dirty: %s (%d porcelain lines)", prov$checkout_dirty, length(prov$checkout_status_porcelain)),
		sprintf("checkout_diff_sha256: %s", prov$checkout_diff_sha256),
		sprintf("r_version: %s", prov$r_version),
		sprintf("rng_kind: %s", paste(prov$rng_kind, collapse = " / ")),
		sprintf("calibration_script: %s (sha256 %s)", prov$calibration_script_path, prov$calibration_script_sha256),
		sprintf("command_args: %s", paste(args, collapse = " ")),
		sprintf("seeds: %s", calib_describe_ints(seeds))
	)
	writeLines(lines, file.path(out_dir, "provenance.txt"))
	invisible(prov)
}

calib_describe_ints <- function(x) {
	x <- as.integer(x)
	if (!length(x)) return("<none>")
	if (length(x) > 2L && identical(x, seq.int(x[[1L]], x[[length(x)]]))) {
		return(sprintf("%d:%d (%d values)", x[[1L]], x[[length(x)]], length(x)))
	}
	if (length(x) > 20L) return(sprintf("%s ... (%d values)", paste(head(x, 10L), collapse = ","), length(x)))
	paste(x, collapse = ",")
}

calib_finish_provenance <- function(out_dir, extra = list()) {
	path <- file.path(out_dir, "provenance.rds")
	prov <- readRDS(path)
	prov$finished_at_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC")
	for (nm in names(extra)) prov[[nm]] <- extra[[nm]]
	saveRDS(prov, path)
	cat(sprintf("finished_at_utc: %s\n", prov$finished_at_utc), file = file.path(out_dir, "provenance.txt"), append = TRUE)
	invisible(prov)
}

# ---------------------------------------------------------------------------
# Row writer: fixed column order, appended as rows become known.
# ---------------------------------------------------------------------------
calib_row_writer <- function(path, columns) {
	if (file.exists(path)) stop("refusing to overwrite ", path, call. = FALSE)
	header <- as.data.frame(setNames(replicate(length(columns), character(), simplify = FALSE), columns),
		stringsAsFactors = FALSE)
	utils::write.table(header, path, sep = ",", row.names = FALSE, col.names = TRUE, qmethod = "double")
	function(row) {
		row <- as.list(row)
		extra <- setdiff(names(row), columns)
		if (length(extra)) stop("row has unknown column(s): ", paste(extra, collapse = ", "), call. = FALSE)
		vals <- lapply(columns, function(cn) {
			v <- row[[cn]]
			if (is.null(v) || !length(v)) NA else v[[1L]]
		})
		df <- as.data.frame(setNames(vals, columns), stringsAsFactors = FALSE)
		utils::write.table(df, path, sep = ",", row.names = FALSE, col.names = FALSE, append = TRUE,
			qmethod = "double", na = "NA")
		invisible(df)
	}
}

calib_read_rows <- function(path) {
	utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE, na.strings = c("NA", ""))
}

# ---------------------------------------------------------------------------
# Evaluation with status classification and an optional elapsed-time cap.
# ---------------------------------------------------------------------------
# Returns list(value, status, error_message, elapsed_sec). status is "ok" when
# the value is accepted by `is_ok`, "nonestimable" when the call returned
# without error but the value is not usable, "timeout" when the elapsed cap
# fired, otherwise "error". A cap is enforced with setTimeLimit(), which only
# interrupts at R-level interrupt checks (long native loops may overrun it).
calib_eval <- function(expr_fn, is_ok = function(v) length(v) >= 1L && all(is.finite(as.numeric(v))),
		timeout_sec = 0) {
	t0 <- proc.time()[["elapsed"]]
	warnings_seen <- character()
	res <- tryCatch({
		if (is.finite(timeout_sec) && timeout_sec > 0) {
			setTimeLimit(elapsed = timeout_sec, transient = TRUE)
		}
		v <- withCallingHandlers(expr_fn(), warning = function(w) {
			warnings_seen <<- c(warnings_seen, conditionMessage(w))
			invokeRestart("muffleWarning")
		})
		list(value = v, status = if (isTRUE(tryCatch(is_ok(v), error = function(e) FALSE))) "ok" else "nonestimable",
			error_message = NA_character_)
	}, error = function(e) {
		msg <- conditionMessage(e)
		timeout <- grepl("reached (elapsed|CPU) time limit|time limit", msg, ignore.case = TRUE)
		list(value = NULL, status = if (timeout) "timeout" else "error", error_message = msg)
	})
	setTimeLimit(elapsed = Inf)
	res$elapsed_sec <- round(proc.time()[["elapsed"]] - t0, 4L)
	res$warnings <- paste(unique(warnings_seen), collapse = " | ")
	if (!nzchar(res$warnings)) res$warnings <- NA_character_
	res
}

calib_num <- function(v, i = 1L) {
	v <- suppressWarnings(as.numeric(v))
	if (length(v) < i) NA_real_ else v[[i]]
}

calib_clean_msg <- function(x) {
	if (is.null(x) || !length(x) || is.na(x)) return(NA_character_)
	x <- gsub("[\r\n\t]+", " ", x)
	substr(x, 1L, 500L)
}

# Exact Clopper-Pearson interval (binom.test's conf.int); NA when n == 0.
calib_cp_interval <- function(k, n, conf_level = 0.95) {
	if (!is.finite(n) || n <= 0) return(c(NA_real_, NA_real_))
	as.numeric(stats::binom.test(as.integer(k), as.integer(n), conf.level = conf_level)$conf.int)
}

# ---------------------------------------------------------------------------
# Harness reuse: evaluate named top-level assignments of comprehensive_tests.R
# (or another script) without running it.
# ---------------------------------------------------------------------------
calib_top_level_assignment <- function(path, name) {
	exprs <- parse(path, keep.source = FALSE)
	hits <- Filter(function(x) is.call(x) && length(x) >= 3L &&
		(identical(x[[1L]], as.name("=")) || identical(x[[1L]], as.name("<-"))) &&
		identical(x[[2L]], as.name(name)), as.list(exprs))
	if (length(hits) != 1L) stop("expected exactly one top-level assignment of ", name, " in ", path, call. = FALSE)
	hits[[1L]]
}

calib_eval_harness_objects <- function(path, names, envir) {
	for (nm in names) eval(calib_top_level_assignment(path, nm), envir = envir)
	invisible(envir)
}

# Loads the comprehensive harness's datasets exactly as comprehensive_tests.R
# does at startup (set.seed(1); required packages; max_n_dataset = 148;
# source(_dataset_load.R)). Whether the harness consumes RNG between its
# set.seed(1) and that source() is not verified, so the realized
# slice_sample() rows may differ from a harness run; the caller records a
# hash of the rows it actually used.
calib_load_harness_datasets <- function(repo_root, max_n_dataset = 148L) {
	pkgs <- c("PTE", "datasets", "mlbench", "AppliedPredictiveModeling", "dplyr", "ggplot2", "data.table")
	for (p in pkgs) {
		if (!suppressPackageStartupMessages(require(p, character.only = TRUE, quietly = TRUE))) {
			stop("harness dataset loader needs package ", p, call. = FALSE)
		}
	}
	had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
	if (had_seed) old_seed <- get(".Random.seed", envir = globalenv())
	on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
	set.seed(1)
	assign("max_n_dataset", as.integer(max_n_dataset), envir = globalenv())
	suppressWarnings(source(file.path(repo_root, "R", "package_tests", "_dataset_load.R"), local = globalenv()))
	get("datasets_and_response_models", envir = globalenv())
}

calib_object_sha256 <- function(x) {
	tf <- tempfile()
	on.exit(unlink(tf), add = TRUE)
	saveRDS(x, tf, version = 2L, compress = FALSE)
	calib_sha256(tf)
}

calib_write_markdown_table <- function(df, digits = 4L) {
	if (!nrow(df)) return("(no rows)")
	fmt <- lapply(df, function(col) {
		if (is.numeric(col)) {
			whole <- is.finite(col) & abs(col - round(col)) < 1e-12 & abs(col) < 1e15
			out <- ifelse(whole, format(round(col), scientific = FALSE, trim = TRUE),
				format(signif(col, digits), trim = TRUE, scientific = FALSE, drop0trailing = TRUE))
			out[is.na(col)] <- "NA"
			out
		} else {
			ifelse(is.na(col), "NA", as.character(col))
		}
	})
	header <- paste0("| ", paste(names(df), collapse = " | "), " |")
	sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
	body <- vapply(seq_len(nrow(df)), function(i) paste0("| ", paste(vapply(fmt, `[`, "", i), collapse = " | "), " |"), "")
	c(header, sep, body)
}
