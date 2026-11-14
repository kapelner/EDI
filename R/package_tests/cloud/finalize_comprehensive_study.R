#!/usr/bin/env Rscript
# Finishes a cloud comprehensive-study campaign (.github/workflows/comprehensive-study.yml, last
# wave; release_v1_1_0.md TODO-194). For each response type it joins every wave's rows
# (<campaign-dir>/rows/<response>/wave-*.csv.xz), keeps the newest row per `id` (a re-planned
# call can repeat a piece; later waves win), and writes
#   <results-dir>/comprehensive_tests_results_nc_1_<response>.csv   for the audits, and
#   <campaign-dir>/rows/<response>.csv.xz                           the published raw rows,
# then removes the per-wave files. It also rebuilds the cost table from the campaign's own rows
# (<campaign-dir>/costs.csv), which the next campaign plans with.
#
# Usage: finalize_comprehensive_study.R --campaign-dir <dir> --results-dir <R/package_tests>

suppressPackageStartupMessages(library(data.table))
args = commandArgs(trailingOnly = TRUE)
opt = list()
for (i in seq(1L, length(args), by = 2L)) opt[[gsub("-", "_", sub("^--", "", args[[i]]))]] = args[[i + 1L]]
stopifnot(!is.null(opt$campaign_dir), !is.null(opt$results_dir))
rows_dir = file.path(opt$campaign_dir, "rows")
summary = list(); variation = list()

# Estimates must vary across reps. Before the 2026-11-12 per-case seeding, a single-rep run drew the
# first rep's data whatever rep it asked for, so "different" reps were byte-identical copies and
# every rate rested on a few draws. A cell (class x dataset x design x beta_T) with finite
# compute_estimate results on at least 10 reps FAILS when fewer than half of them are distinct
# (10 significant digits). On the local 2026-11 results no cell comes close.
rep_variation_check = function(d) {
	e = d[function_run == "compute_estimate" & status == "ok"]
	if (!nrow(e)) return(NULL)
	e[, v := suppressWarnings(as.numeric(result_1))]
	e[is.finite(v), .(reps = uniqueN(rep), distinct = uniqueN(signif(v, 10))),
		by = .(response_type, inference_class, dataset, design, beta_T)][reps >= 10L & distinct < reps / 2]
}
for (rt in list.dirs(rows_dir, full.names = FALSE, recursive = FALSE)) {
	waves = sort(list.files(file.path(rows_dir, rt), pattern = "^wave-[0-9]+\\.csv\\.xz$", full.names = TRUE))
	if (!length(waves)) next
	d = rbindlist(lapply(waves, function(f) fread(cmd = paste("xz -dc", shQuote(f)), colClasses = "character")), fill = TRUE)
	n_all = nrow(d)
	d = d[!duplicated(id, fromLast = TRUE)]
	out = file.path(opt$results_dir, sprintf("comprehensive_tests_results_nc_1_%s.csv", rt))
	fwrite(d, out, na = "NA")
	pub = file.path(rows_dir, paste0(rt, ".csv"))
	file.copy(out, pub, overwrite = TRUE)
	unlink(paste0(pub, ".xz"))
	if (system2("xz", c("-T0", "-6", shQuote(pub))) != 0L) stop("xz failed on ", pub)
	unlink(file.path(rows_dir, rt), recursive = TRUE)
	variation[[rt]] = rep_variation_check(d)
	summary[[rt]] = data.table(response_type = rt, rows = nrow(d), duplicates_dropped = n_all - nrow(d),
		ok = sum(d$status == "ok", na.rm = TRUE), errors = sum(d$status == "error", na.rm = TRUE),
		timeouts = sum(grepl("timeout", d$skip_reason), na.rm = TRUE))
}
summary = rbindlist(summary)
fwrite(summary, file.path(opt$campaign_dir, "rows_summary.csv"))
print(summary)
variation = rbindlist(variation)
adir = file.path(opt$campaign_dir, "audit"); dir.create(adir, recursive = TRUE, showWarnings = FALSE)
fwrite(variation, file.path(adir, "rep_variation_failures.csv"))
writeLines(as.character(nrow(variation)), file.path(adir, "rep_variation.count"))
if (nrow(variation)) {
	cat(sprintf("::warning title=Comprehensive study::%d cell(s) whose estimates barely vary across reps (see audit/rep_variation_failures.csv)\n", nrow(variation)))
	print(head(variation, 20L))
} else cat("rep variation: every cell's estimates vary across reps\n")
here = dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L]))
st = system2("Rscript", c(shQuote(file.path(here, "build_comprehensive_study_costs.R")), shQuote(opt$results_dir),
	shQuote(file.path(opt$campaign_dir, "costs.csv"))))
if (st != 0L) stop("rebuilding the cost table failed")
