#!/usr/bin/env Rscript
args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage.R ARTIFACT_DIR MATRIX_JSON")
files = list.files(args[[1]], pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
reports = lapply(files, readRDS)
expected = jsonlite::fromJSON(args[[2]])$shard
ids = vapply(reports, function(x) as.integer(x$shard), integer(1))
if (!length(reports) || anyDuplicated(ids) || !setequal(ids, expected)) stop("Missing or duplicate coverage shards")
if (any(vapply(reports, function(x) x$commit != Sys.getenv("GITHUB_SHA") ||
	x$covr_version != as.character(packageVersion("covr")), logical(1)))) stop("Coverage provenance mismatch")
# covr's own merge retains source references and adds counters for matching paths.
coverage = getFromNamespace("merge_coverage", "covr")(lapply(reports, `[[`, "coverage"))
saveRDS(list(coverage = coverage, commit = Sys.getenv("GITHUB_SHA"),
	measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
	covr_version = as.character(packageVersion("covr")), shards = ids),
	file.path(args[[1]], "merged-coverage.rds"))

# covr::codecov() has no built-in timeout: a slow/unresponsive codecov.io endpoint
# hangs this call indefinitely with zero output, and the only symptom visible in CI
# is the whole job eventually dying with "the runner has received a shutdown signal"
# minutes later (observed three times now: 2026-09-26 runs 36257223738/36257223636,
# 2026-10-01 run 36853610057) -- an opaque failure with no diagnosable R-level error.
#
# 2026-09-27's first fix wrapped this in setTimeLimit(elapsed = 120) -- that did
# NOT work (run 36853610057 hung the full ~6 minutes with zero output again, no
# "codecov upload attempt" message ever printed): setTimeLimit() only interrupts
# at R-level bytecode-safe points (GC, certain instruction boundaries) and cannot
# preempt a C-level call blocked in a kernel socket read/write, which is exactly
# what a hung HTTP upload is. Using callr::r(..., timeout = ) instead runs the
# upload in a real child OS process that callr forcibly kills (SIGKILL) when the
# timeout elapses regardless of what that process is blocked on -- this actually
# works for a hung network call. callr is already a transitive dependency here
# (covr/testthat pull it in), confirmed installed in CI.
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
	result = tryCatch({ upload_attempt(); TRUE }, error = function(e) { last_error <<- e; FALSE })
	if (isTRUE(result)) { uploaded = TRUE; break }
	message(sprintf("codecov upload attempt %d/3 failed: %s", attempt, conditionMessage(last_error)))
	if (attempt < 3L) Sys.sleep(10)
}
if (!uploaded) stop("codecov upload failed after 3 attempts: ", conditionMessage(last_error))
