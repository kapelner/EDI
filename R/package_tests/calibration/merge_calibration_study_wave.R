#!/usr/bin/env Rscript
# Adds one wave of the published calibration study (release_v1_2_0.md TODO-36) to
# its campaign: every <wave-dir>/<id>/shard.csv is appended to
# <campaign-dir>/ledger.csv (with its id), and every shard's tests.csv.gz /
# est.csv.gz to <campaign-dir>/stats/{tests,est}.csv.gz. A shard id already in the
# ledger is skipped, so re-running a merge never double-counts. No EDI needed.
#
# Usage: Rscript R/package_tests/calibration/merge_calibration_study_wave.R \
#          --campaign-dir DIR --wave-dir DIR
# <wave-dir> holds one directory per shard, named by shard id (an optional
# "study-shard-" prefix, as actions/download-artifact writes it, is stripped).

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

script_dir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])))
source(file.path(script_dir, "calibration_study_stats.R"))
args <- commandArgs(TRUE)
arg_value <- function(flag, default = NULL) {
	i <- match(flag, args)
	if (is.na(i) || i == length(args)) default else args[[i + 1L]]
}
campaign_dir <- arg_value("--campaign-dir")
wave_dir <- arg_value("--wave-dir")
dir.create(file.path(campaign_dir, "stats"), recursive = TRUE, showWarnings = FALSE)

ledger_path <- file.path(campaign_dir, "ledger.csv")
ledger <- if (file.exists(ledger_path)) read_csv_fast(ledger_path, stringsAsFactors = FALSE,
	colClasses = c(reps_done = "character")) else NULL
seen <- if (is.null(ledger)) character() else ledger$id

dirs <- list.dirs(wave_dir, recursive = FALSE)
new_ledger <- list()
new_tests <- list()
new_est <- list()
for (d in dirs) {
	id <- sub("^study-shard-", "", basename(d))
	f <- file.path(d, "shard.csv")
	if (!file.exists(f) || id %in% seen) next
	x <- read_csv_fast(f, stringsAsFactors = FALSE, colClasses = c(reps_done = "character"))
	x$id <- id
	new_ledger[[length(new_ledger) + 1L]] <- x
	new_tests[[length(new_tests) + 1L]] <- cal_stats_read(file.path(d, "tests.csv.gz"))
	new_est[[length(new_est) + 1L]] <- cal_stats_read(file.path(d, "est.csv.gz"))
}
if (length(new_ledger)) {
	all <- do.call(rbind, c(if (!is.null(ledger)) list(ledger), new_ledger))
	utils::write.csv(all, ledger_path, row.names = FALSE)
	for (kind in c("tests", "est")) {
		path <- file.path(campaign_dir, "stats", paste0(kind, ".csv.gz"))
		merged <- cal_stats_merge(c(list(cal_stats_read(path)), if (kind == "tests") new_tests else new_est), kind)
		if (!is.null(merged)) cal_stats_write(merged, path)
	}
}
cat(sprintf("merged %d new shard(s) into %s\n", length(new_ledger), campaign_dir))
