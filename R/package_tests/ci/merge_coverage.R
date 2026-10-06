#!/usr/bin/env Rscript
# Progress tracing: three silent ~5-6 minute hangs-then-externally-killed failures
# so far (2026-09-26 runs 36257223738/36257223636, 2026-10-01 run 36853610057,
# 2026-10-04 run 37184273859), all with ZERO R-level output before the runner
# killed the job. The 2026-09-27 fix assumed the hang was in covr::codecov()'s
# network upload and wrapped only that in a timeout (first setTimeLimit(), which
# doesn't preempt a blocked C-level socket call and never fired; then callr::r(),
# which does forcibly kill a hung child) -- but 2026-10-04's failure still showed
# zero output and killed at ~5 minutes, well inside the callr-wrapped retry
# loop's own timeline, meaning that loop was likely never reached at all: the
# hang is plausibly in merge_coverage()'s large-object merge over 99 shards
# instead, upstream of where any timeout existed. Since this is still unconfirmed,
# every stage below now logs its own start/elapsed time with an explicit flush,
# so whichever stage is actually hanging will be visible as the LAST line printed
# before the next failure, instead of another silent black box.
log_stage = function(msg) {
	cat(sprintf("[merge_coverage %s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
	flush(stdout())
}

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage.R ARTIFACT_DIR MATRIX_JSON")

log_stage("start")
files = list.files(args[[1]], pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
log_stage(sprintf("found %d coverage.rds files, reading ...", length(files)))
reports = lapply(files, readRDS)
log_stage("finished readRDS of all shards")

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
