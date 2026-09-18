#!/usr/bin/env Rscript
# Drives a full run of plan_shards.py's shards through a local process pool instead of
# CI's one-shard-per-runner matrix, so a complete, provenance-bearing report can be produced
# from a single machine. Each worker still runs run_shard.R unmodified (same instrumented
# covr::package_coverage() build+run for the "coverage" tier), so per-shard cost matches CI
# exactly; only the scheduling (a bounded local pool instead of one runner per shard) differs.
suppressMessages({
	library(processx)
	library(jsonlite)
})

NUM_CORES = 6L  # default worker-pool size; override via the 4th CLI arg or EDI_SHARD_POOL_CORES

args = commandArgs(trailingOnly = TRUE)
if (length(args) < 2L || length(args) > 5L) {
	stop("Usage: run_coverage_shards_parallel.R ROOT ARTIFACT_DIR [tier=coverage] [num_cores] [target_seconds=2400]")
}
root = normalizePath(args[[1]], mustWork = TRUE)
tier = if (length(args) >= 3L && nzchar(args[[3]])) args[[3]] else "coverage"
num_cores = if (length(args) >= 4L && nzchar(args[[4]])) as.integer(args[[4]]) else {
	env_cores = Sys.getenv("EDI_SHARD_POOL_CORES", "")
	if (nzchar(env_cores)) as.integer(env_cores) else NUM_CORES
}
target_seconds = if (length(args) >= 5L) as.numeric(args[[5]]) else 2400

stopifnot(tier %in% c("correctness", "coverage"), is.finite(num_cores), num_cores >= 1L)
available_cores = parallel::detectCores()
if (!is.na(available_cores) && num_cores > available_cores) {
	cat(sprintf("Note: num_cores=%d exceeds detected %d cores; proceeding anyway.\n", num_cores, available_cores))
}

dir.create(args[[2]], recursive = TRUE, showWarnings = FALSE)
artifact_dir = normalizePath(args[[2]], mustWork = TRUE)
plan_dir = file.path(artifact_dir, "plan")

log_line = function(fmt, ...) cat(sprintf(paste0("[%s] ", fmt, "\n"), format(Sys.time(), "%H:%M:%S"), ...))

log_line("planning %s shards (target %.0fs/bucket)...", tier, target_seconds)
plan_status = system2("python3", c(file.path(root, "R/package_tests/ci/plan_shards.py"), tier,
	"--target-seconds", target_seconds, "--output", plan_dir))
if (plan_status != 0L) stop("Shard planning failed; run plan_shards.py directly to see the error.")

shard_ids = jsonlite::fromJSON(file.path(plan_dir, "matrix.json"))$shard
shard_seconds = vapply(shard_ids, function(id) {
	jsonlite::fromJSON(file.path(plan_dir, sprintf("shard-%d.json", id)))$estimated_seconds
}, numeric(1))
names(shard_seconds) = as.character(shard_ids)
queue = as.list(shard_ids[order(-shard_seconds)])

log_line("%d %s shards queued across a %d-worker pool (~%.1fh total estimated test time)",
	length(queue), tier, num_cores, sum(shard_seconds) / 3600)

runner = file.path(root, "R/package_tests/ci/run_shard.R")
workers = list()  # keyed by shard id (as character): list(process=, start=, id=)

cleanup = function() for (w in workers) if (!is.null(w$process) && w$process$is_alive()) w$process$kill()
on.exit(cleanup(), add = TRUE)

launch = function(shard_id) {
	shard_dir = file.path(artifact_dir, sprintf("shard-%d", shard_id))
	dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
	proc = processx::process$new("Rscript",
		c(runner, root, file.path(plan_dir, sprintf("shard-%d.json", shard_id)), tier, shard_dir),
		stdout = file.path(shard_dir, "run.log"), stderr = "2>&1", cwd = root)
	list(process = proc, start = Sys.time(), id = shard_id)
}

poll_interval_seconds = 15
slow_warn_multiplier = 2  # flag a still-running shard once it passes this multiple of its estimate
results = data.frame(shard = integer(), estimated_seconds = numeric(), elapsed_seconds = numeric(),
	exit_status = integer())

repeat {
	while (length(workers) < num_cores && length(queue) > 0L) {
		shard_id = queue[[1]]
		queue = queue[-1]
		key = as.character(shard_id)
		workers[[key]] = launch(shard_id)
		log_line("started shard %d (est %.0fs); %d queued, %d running",
			shard_id, shard_seconds[[key]], length(queue), length(workers))
	}
	if (length(workers) == 0L && length(queue) == 0L) break

	Sys.sleep(poll_interval_seconds)
	finished = character(0)
	for (key in names(workers)) {
		w = workers[[key]]
		elapsed = as.numeric(difftime(Sys.time(), w$start, units = "secs"))
		if (!w$process$is_alive()) {
			status = w$process$get_exit_status()
			results = rbind(results, data.frame(shard = w$id, estimated_seconds = shard_seconds[[key]],
				elapsed_seconds = elapsed, exit_status = status))
			log_line("shard %d finished (exit %d) in %.0fs (est %.0fs)", w$id, status, elapsed, shard_seconds[[key]])
			finished = c(finished, key)
		} else if (elapsed > slow_warn_multiplier * shard_seconds[[key]]) {
			log_line("WARNING: shard %d still running at %.0fs, %.1fx its %.0fs estimate",
				w$id, elapsed, elapsed / shard_seconds[[key]], shard_seconds[[key]])
		}
	}
	for (key in finished) workers[[key]] = NULL
}

timing_csv = file.path(artifact_dir, "shard_pool_timings.csv")
write.csv(results, timing_csv, row.names = FALSE)
log_line("all %s shards complete; timings written to %s", tier, timing_csv)

if (any(results$exit_status != 0L)) {
	cat("Failed shards:\n")
	print(results[results$exit_status != 0L, ])
	quit(status = 1L)
}

if (tier == "coverage") {
	log_line("merging %d coverage shards into one provenance-bearing report...", length(shard_ids))
	reports = lapply(shard_ids, function(id) readRDS(file.path(artifact_dir, sprintf("shard-%d", id), "coverage.rds")))
	versions = vapply(reports, `[[`, character(1), "covr_version")
	if (length(unique(versions)) > 1L) stop("Mixed covr versions across shards; re-run with a consistent covr install.")
	commit = tryCatch(system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE), error = function(e) NA_character_)
	coverage = getFromNamespace("merge_coverage", "covr")(lapply(reports, `[[`, "coverage"))
	merged_path = file.path(artifact_dir, "merged-coverage.rds")
	saveRDS(list(coverage = coverage, commit = commit, covr_version = unique(versions),
		measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), shards = shard_ids), merged_path)
	log_line("merged report written to %s (commit %s)", merged_path, commit)
}
