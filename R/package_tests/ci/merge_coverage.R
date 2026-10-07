#!/usr/bin/env Rscript
# Progress tracing: five silent hangs-then-externally-killed failures so far
# (2026-09-26 runs 36257223738/36257223636, 2026-10-01 run 36853610057,
# 2026-10-04 run 37184273859, 2026-10-06 run 37540750560, 2026-10-07 runs
# 37604972047/37618617132), all killed by "the runner has received a shutdown
# signal". Per-stage logging (added 2026-10-06) pinned the hang down to plain
# `reports = lapply(files, readRDS)` on the 99 real shard artifacts. Switching
# to `parallel::mclapply()` (2026-10-07) cut the time-to-kill from ~6 minutes
# to ~70-110 seconds -- real speedup -- but two more runs the SAME day still
# hung and got killed mid-read, including one in complete isolation (verified
# no other GitHub Actions run existed anywhere on the account at the time, so
# this is not account-level concurrency eviction). A plain CPU-bound
# deserialization slowdown should get uniformly faster with parallelism, not
# still hang indefinitely with zero output after parallelizing -- that pattern
# instead matches ONE corrupted/truncated coverage.rds (an artifact upload/
# download hiccup, plausible at ~40 MB x 99 artifacts) that readRDS()'s
# underlying gzip stream can block on forever rather than erroring, and
# because mclapply() waits for every forked child to return before giving back
# ANY result, a single stuck child blocks the whole batch -- explaining why
# even the parallel version still goes fully silent rather than finishing 98
# reads and erroring on the 99th.
#
# Replaced with a manual mcparallel()/mccollect() loop so each file read has
# its own bounded timeout and a hung one is named and killed individually,
# instead of silently blocking everything else. Every stage still logs its
# own start/elapsed time with an explicit flush so a new bottleneck surfaces
# immediately instead of as another silent black box.
log_stage = function(msg) {
	cat(sprintf("[merge_coverage %s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
	flush(stdout())
}

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage.R ARTIFACT_DIR MATRIX_JSON")

log_stage("start")
files = list.files(args[[1]], pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
log_stage(sprintf("found %d coverage.rds files, reading (parallelized across %d cores, per-file timeout) ...",
	length(files), parallel::detectCores()))
read_t0 = proc.time()[["elapsed"]]

PER_FILE_TIMEOUT_SECS = 60
read_files_with_timeout = function(files, timeout_secs) {
	results = vector("list", length(files))
	names(results) = files
	pending = seq_along(files)
	n_cores = min(parallel::detectCores(), length(files))
	jobs = list() # pid (as character) -> file index
	deadlines = list() # pid (as character) -> deadline
	launch = function(idx) {
		job = parallel::mcparallel(readRDS(files[[idx]]), silent = TRUE)
		pid_chr = as.character(job$pid)
		jobs[[pid_chr]] <<- idx
		deadlines[[pid_chr]] <<- proc.time()[["elapsed"]] + timeout_secs
		job
	}
	running = list()
	next_idx = 1L
	while (next_idx <= length(files) && length(running) < n_cores) {
		running[[length(running) + 1L]] = launch(next_idx)
		next_idx = next_idx + 1L
	}
	while (length(running) > 0L) {
		done = parallel::mccollect(running, wait = FALSE, timeout = 1L)
		for (pid_chr in names(done)) {
			idx = jobs[[pid_chr]]
			val = done[[pid_chr]]
			results[[idx]] = if (inherits(val, "try-error")) {
				structure(list(message = paste("readRDS failed:", conditionMessage(attr(val, "condition")))), class = c("error", "condition"))
			} else val
			running = running[vapply(running, function(j) as.character(j$pid) != pid_chr, logical(1))]
		}
		now = proc.time()[["elapsed"]]
		still_running_pids = vapply(running, function(j) as.character(j$pid), character(1))
		for (pid_chr in still_running_pids) {
			if (now > deadlines[[pid_chr]]) {
				idx = jobs[[pid_chr]]
				log_stage(sprintf("TIMEOUT after %ds reading %s (pid %s) -- killing", timeout_secs, files[[idx]], pid_chr))
				tryCatch(tools::pskill(as.integer(pid_chr), tools::SIGTERM), error = function(e) invisible(NULL))
				results[[idx]] = structure(list(message = sprintf("readRDS timed out after %ds", timeout_secs)), class = c("error", "condition"))
				running = running[vapply(running, function(j) as.character(j$pid) != pid_chr, logical(1))]
			}
		}
		while (next_idx <= length(files) && length(running) < n_cores) {
			running[[length(running) + 1L]] = launch(next_idx)
			next_idx = next_idx + 1L
		}
	}
	results
}
reports = read_files_with_timeout(files, PER_FILE_TIMEOUT_SECS)
failed = vapply(reports, inherits, logical(1), what = "error")
if (any(failed)) stop(sprintf("readRDS failed or timed out for: %s", paste(files[failed], collapse = ", ")))
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
