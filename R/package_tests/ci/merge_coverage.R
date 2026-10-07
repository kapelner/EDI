#!/usr/bin/env Rscript
# Progress tracing: four silent multi-minute hangs-then-externally-killed failures
# so far (2026-09-26 runs 36257223738/36257223636, 2026-10-01 run 36853610057,
# 2026-10-04 run 37184273859, 2026-10-06 run 37540750560), all killed by "the
# runner has received a shutdown signal" a few minutes in. The 2026-10-06 run is
# the first with per-stage logging in place (added after 2026-10-04's failure,
# which still predated it), and it finally pinned the hang down: "found 99
# coverage.rds files, reading ..." printed, then NOTHING for the remaining 6m24s
# until the kill -- i.e. plain `reports = lapply(files, readRDS)` on 99 real
# shard artifacts (totaling ~3.8 GB of covr coverage objects, each carrying full
# per-expression srcrefs for the whole package) is itself the slow part, not
# covr::merge_coverage() or the codecov upload (both already confirmed innocent
# by the earlier instrumentation). RDS deserialization cost scales with object
# *graph complexity* (number of nested list/environment nodes), not just raw
# bytes, which is consistent with covr's deeply nested per-expression structure
# being slow to unserialize at this shard count even though the raw byte volume
# alone wouldn't justify minutes. Parallelized across the runner's cores (plain
# `lapply` was using exactly one) to actually cut the wall-clock time, not just
# time out faster on it; every stage still logs its own start/elapsed time with
# an explicit flush so a new bottleneck surfaces immediately instead of as
# another silent black box.
log_stage = function(msg) {
	cat(sprintf("[merge_coverage %s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
	flush(stdout())
}

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage.R ARTIFACT_DIR MATRIX_JSON")

log_stage("start")
files = list.files(args[[1]], pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
log_stage(sprintf("found %d coverage.rds files, reading (parallelized across %d cores) ...",
	length(files), parallel::detectCores()))
read_t0 = proc.time()[["elapsed"]]
reports = if (.Platform$OS.type == "unix" && length(files) > 1L) {
	parallel::mclapply(files, readRDS, mc.cores = min(parallel::detectCores(), length(files)))
} else {
	lapply(files, readRDS)
}
failed = vapply(reports, inherits, logical(1), what = "error")
if (any(failed)) stop(sprintf("readRDS failed for: %s", paste(files[failed], collapse = ", ")))
log_stage(sprintf("finished readRDS of all shards (%.1fs)", proc.time()[["elapsed"]] - read_t0))

expected = jsonlite::fromJSON(args[[2]])$shard
ids = vapply(reports, function(x) as.integer(x$shard), integer(1))
if (!length(reports) || anyDuplicated(ids) || !setequal(ids, expected)) stop("Missing or duplicate coverage shards")
if (any(vapply(reports, function(x) x$commit != Sys.getenv("GITHUB_SHA") ||
	x$covr_version != as.character(packageVersion("covr")), logical(1)))) stop("Coverage provenance mismatch")

log_stage("provenance checks passed, merging shard coverage objects ...")
# covr's own merge retains source references and adds counters for matching paths.
# This itself runs inside callr::r() with a timeout, not just the upload below --
# merging 99 shards' coverage objects is untested at this scale for hangs/blowup,
# and the three prior silent-hang failures are at least as consistent with a stuck
# merge as with a stuck network call.
merge_result = tryCatch(
	callr::r(
		function(shard_coverages) getFromNamespace("merge_coverage", "covr")(shard_coverages),
		args = list(shard_coverages = lapply(reports, `[[`, "coverage")),
		timeout = 180,
		libpath = .libPaths(),
		show = TRUE
	),
	error = function(e) e
)
if (inherits(merge_result, "error")) stop("covr::merge_coverage() failed or timed out: ", conditionMessage(merge_result))
coverage = merge_result
log_stage("merge finished")

saveRDS(list(coverage = coverage, commit = Sys.getenv("GITHUB_SHA"),
	measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
	covr_version = as.character(packageVersion("covr")), shards = ids),
	file.path(args[[1]], "merged-coverage.rds"))
log_stage("wrote merged-coverage.rds, starting codecov upload ...")

# covr::codecov() has no built-in timeout: a slow/unresponsive codecov.io endpoint
# hangs this call indefinitely. callr::r(..., timeout = ) runs it in a real child
# OS process that callr forcibly kills (SIGKILL) when the timeout elapses
# regardless of what that process is blocked on -- confirmed locally to actually
# interrupt a genuinely hung child (unlike setTimeLimit(), see header comment).
upload_attempt = function() {
	callr::r(
		function(coverage, token) {
			covr::codecov(coverage = coverage, flags = "r", token = token, quiet = FALSE)
		},
		args = list(coverage = coverage, token = Sys.getenv("CODECOV_TOKEN")),
		timeout = 120,
		libpath = .libPaths(),
		show = TRUE
	)
}
uploaded = FALSE
last_error = NULL
for (attempt in 1:3) {
	log_stage(sprintf("codecov upload attempt %d/3 ...", attempt))
	result = tryCatch({ upload_attempt(); TRUE }, error = function(e) { last_error <<- e; FALSE })
	if (isTRUE(result)) { uploaded = TRUE; break }
	message(sprintf("codecov upload attempt %d/3 failed: %s", attempt, conditionMessage(last_error)))
	flush(stderr())
	if (attempt < 3L) Sys.sleep(10)
}
if (!uploaded) stop("codecov upload failed after 3 attempts: ", conditionMessage(last_error))
log_stage("codecov upload succeeded")
