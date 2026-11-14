#!/usr/bin/env Rscript
# Merges one wave of the cloud comprehensive study into its campaign directory
# (.github/workflows/comprehensive-study.yml `analyze`; release_v1_1_0.md TODO-194).
#
# Reads every <wave-dir>/**/<call_id>/ a shard uploaded. A call counts only if it has a DONE file
# (the runner exited 0); its pieces (classes x reps of its plan row, or "__other__" x rep 1 for a
# catch-all) are appended to <campaign-dir>/ledger.csv. Its result rows go to
# <campaign-dir>/rows/<response>/wave-<NNN>.csv.xz, its log into <campaign-dir>/logs/wave-<NNN>.tar.xz
# (all calls, done or not). Classes a catch-all call ran (not in the cost table) are appended to
# <campaign-dir>/discovered.csv with their measured seconds per rep, so the planner schedules
# their other reps. Re-running a merge for the same wave replaces that wave's ledger rows.
#
# Usage: merge_comprehensive_study_wave.R --wave-dir <dir> --plan plan.csv --campaign-dir <dir> --wave <N>

suppressPackageStartupMessages(library(data.table))
args = commandArgs(trailingOnly = TRUE)
opt = list()
for (i in seq(1L, length(args), by = 2L)) opt[[gsub("-", "_", sub("^--", "", args[[i]]))]] = args[[i + 1L]]
stopifnot(!is.null(opt$wave_dir), !is.null(opt$plan), !is.null(opt$campaign_dir), !is.null(opt$wave))
wave = as.integer(opt$wave); tag = sprintf("wave-%03d", wave)
plan = fread(opt$plan, colClasses = c(reps = "character", class_regex = "character", exclude_regex = "character"))
cdir = opt$campaign_dir; dir.create(cdir, recursive = TRUE, showWarnings = FALSE)

call_dirs = unique(dirname(list.files(opt$wave_dir, pattern = "^log\\.txt$", recursive = TRUE, full.names = TRUE)))
call_ids = basename(call_dirs)
done = file.exists(file.path(call_dirs, "DONE"))
cat(sprintf("%s: %d calls reported, %d done, %d planned\n", tag, length(call_dirs), sum(done), nrow(plan)))

# Ledger: one row per finished piece.
pieces = rbindlist(lapply(which(done), function(i) {
	pr = plan[call_id == call_ids[i]]
	if (!nrow(pr)) return(NULL)
	secs = as.numeric(sub("^seconds=", "", grep("^seconds=", readLines(file.path(call_dirs[i], "DONE")), value = TRUE)))
	cls = strsplit(pr$classes, ";", fixed = TRUE)[[1L]]
	reps = as.integer(strsplit(pr$reps, ",", fixed = TRUE)[[1L]])
	CJ(class = cls, rep = reps)[, `:=`(response_type = pr$response_type, dataset = pr$dataset, design = pr$design,
		beta_T = pr$beta_T, call_id = pr$call_id, call_seconds = secs, wave = wave)]
}), fill = TRUE)
ledger_path = file.path(cdir, "ledger.csv")
ledger = if (file.exists(ledger_path)) fread(ledger_path) else NULL
if (!is.null(ledger) && nrow(ledger)) ledger = ledger[wave != (..wave)]
ledger = rbind(ledger, pieces, fill = TRUE)
if (!is.null(ledger) && nrow(ledger)) fwrite(ledger, ledger_path)

# Rows, per response type, xz-compressed.
read_call_rows = function(d) {
	f = list.files(d, pattern = "^comprehensive_tests_results_nc_1_.*\\.csv$", full.names = TRUE)
	if (!length(f)) return(NULL)
	rbindlist(lapply(f, fread, colClasses = "character"), fill = TRUE)
}
rows = rbindlist(lapply(call_dirs[done], read_call_rows), fill = TRUE)
if (nrow(rows)) {
	for (rt in unique(rows$response_type)) {
		odir = file.path(cdir, "rows", rt); dir.create(odir, recursive = TRUE, showWarnings = FALSE)
		f = file.path(odir, paste0(tag, ".csv"))
		fwrite(rows[response_type == rt], f, na = "NA")
		unlink(paste0(f, ".xz"))
		if (system2("xz", c("-T0", "-6", shQuote(f))) != 0L) stop("xz failed on ", f)
	}
}

# Classes found by catch-all calls.
other = which(done & grepl("-other$", call_ids))
disc = rbindlist(lapply(other, function(i) {
	r = read_call_rows(call_dirs[i])
	if (is.null(r) || !nrow(r)) return(NULL)
	r[, .(sec_per_rep = round(sum(as.numeric(duration_time_sec), na.rm = TRUE), 1), reps_seen = 1L),
		by = .(response_type, dataset, design = sub("@prob_T=.*$", "", design), class = sub(" .*$", "", inference_class), beta_T = as.numeric(beta_T))]
}), fill = TRUE)
if (nrow(disc)) {
	disc_path = file.path(cdir, "discovered.csv")
	old = if (file.exists(disc_path)) fread(disc_path) else NULL
	disc = unique(rbind(old, disc, fill = TRUE), by = c("response_type", "dataset", "design", "class", "beta_T"))
	fwrite(disc, disc_path)
	cat(sprintf("::notice title=Comprehensive study::%d class piece(s) not in the cost table were found by catch-all calls and will be scheduled\n", nrow(disc)))
}

# Logs of every call (done or not), one archive per wave.
ldir = file.path(cdir, "logs"); dir.create(ldir, showWarnings = FALSE)
logs = file.path(call_dirs, "log.txt")
tmp = tempfile("logs"); dir.create(tmp)
for (i in seq_along(logs)) file.copy(logs[i], file.path(tmp, paste0(call_ids[i], if (done[i]) "" else ".NOT-DONE", ".log")))
tarf = normalizePath(file.path(ldir, paste0(tag, ".tar.xz")), mustWork = FALSE)
if (system2("tar", c("-C", shQuote(tmp), "-cJf", shQuote(tarf), ".")) != 0L) stop("tar failed")
cat(sprintf("%s merged: %d pieces, %d rows, logs in %s\n", tag, nrow(pieces), nrow(rows), basename(tarf)))
