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

cleanup = function() for (w in workers) {
	if (!is.null(w$process) && w$process$is_alive()) w$process$kill()
	if (!is.null(w$root) && dir.exists(w$root)) remove_shard_root(w$root)
}
on.exit(cleanup(), add = TRUE)

# covr compiles in place, which would litter the working tree with .o/.gcda/.gcno files
# and let configure rewrite tracked Makevars, so each shard builds in a private copy of the
# package under build_base. Everything else in the checkout is symlinked so tests still
# resolve repo-relative paths exactly as they do in CI.
build_base = normalizePath(Sys.getenv("EDI_COVERAGE_BUILD_DIR", "/tmp/edi-coverage-builds"), mustWork = FALSE)
dir.create(build_base, recursive = TRUE, showWarnings = FALSE)
build_base = normalizePath(build_base, mustWork = TRUE)
head_sha = tryCatch(system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE), error = function(e) "")

prepare_shard_root = function(shard_id) {
	shard_root = file.path(build_base, sprintf("shard-%d", shard_id))
	if (dir.exists(shard_root)) remove_shard_root(shard_root)
	dir.create(file.path(shard_root, "R", "EDI"), recursive = TRUE)
	copy_status = system(sprintf("tar -C %s --exclude='*.o' --exclude='*.so' --exclude='*.gcda' --exclude='*.gcno' --exclude='*.gcov' -cf - . | tar -C %s -xf -",
		shQuote(file.path(root, "R", "EDI")), shQuote(file.path(shard_root, "R", "EDI"))))
	if (copy_status != 0L) stop("Could not copy the package for shard ", shard_id)
	for (entry in setdiff(list.files(root, all.files = TRUE, no.. = TRUE), c("R", ".git")))
		file.symlink(file.path(root, entry), file.path(shard_root, entry))
	for (entry in setdiff(list.files(file.path(root, "R"), all.files = TRUE, no.. = TRUE), "EDI"))
		file.symlink(file.path(root, "R", entry), file.path(shard_root, "R", entry))
	shard_root
}

remove_shard_root = function(shard_root) {
	# Only ever delete inside build_base, and drop symlinks first so nothing in the real checkout is touched.
	stopifnot(startsWith(shard_root, paste0(build_base, "/")))
	for (path in list.files(shard_root, all.files = TRUE, no.. = TRUE, full.names = TRUE))
		if (nzchar(Sys.readlink(path))) file.remove(path)
	for (path in list.files(file.path(shard_root, "R"), all.files = TRUE, no.. = TRUE, full.names = TRUE))
		if (nzchar(Sys.readlink(path))) file.remove(path)
	unlink(shard_root, recursive = TRUE)
}

launch = function(shard_id) {
	shard_dir = file.path(artifact_dir, sprintf("shard-%d", shard_id))
	dir.create(shard_dir, recursive = TRUE, showWarnings = FALSE)
	shard_root = prepare_shard_root(shard_id)
	proc = processx::process$new("Rscript",
		c(file.path(shard_root, "R/package_tests/ci/run_shard.R"), shard_root,
			file.path(plan_dir, sprintf("shard-%d.json", shard_id)), tier, shard_dir),
		# Each shard's own compile must stay single-threaded (-j 1): num_cores concurrent
		# multi-threaded builds would oversubscribe the machine's cores far beyond num_cores.
		# EDI's native kernels (fast_coxph_regression.cpp, fast_kk_wilcox_parallel.cpp, etc.)
		# call omp_set_num_threads() at runtime once a test crosses their parallel-dispatch
		# threshold -- exactly what these coverage tests are written to do -- so without
		# capping these, a single shard can fan out across every core on its own, independent
		# of MAKEFLAGS and num_cores. Mirrors test-coverage-R.yaml's job-level env exactly.
		# ~/.R/Makevars may set MAKEFLAGS (-j10 here), and that overrides the MAKEFLAGS
		# environment variable, so R_MAKEVARS_USER must point at a serial Makevars instead.
		# EDI_PORTABLE=1 is required for native coverage: without it configure emits
		# `override CXXFLAGS += -O3 -g0`, which discards covr's --coverage, so no C++ is
		# instrumented and covr silently reports R files only. NOT_CRAN/CI/R_KEEP_PKG_SOURCE
		# mirror test-coverage-R.yaml so local numbers are comparable with CI's.
		env = c("current", MAKEFLAGS = "-j 1", OMP_NUM_THREADS = "1",
			EDI_PORTABLE = "1", NOT_CRAN = "true", CI = "true", R_KEEP_PKG_SOURCE = "yes",
			R_MAKEVARS_USER = file.path(shard_root, "R/package_tests/ci/makevars_serial"), GITHUB_SHA = head_sha, MKL_NUM_THREADS = "1",
			OPENBLAS_NUM_THREADS = "1", GOTO_NUM_THREADS = "1", VECLIB_MAXIMUM_THREADS = "1",
			NUMEXPR_NUM_THREADS = "1"),
		stdout = file.path(shard_dir, "run.log"), stderr = "2>&1", wd = shard_root)
	list(process = proc, start = Sys.time(), id = shard_id, root = shard_root)
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
			remove_shard_root(w$root)
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
	# covr's own merge_coverage() is unusable here: shards built in /tmp copies record some files under
	# absolute per-shard paths, so it never merges them (and took ~3 hours). Merge at line level with
	# normalized repo-relative names instead; the CSV feeds coverage_gap_registry.R directly.
	log_line("merging %d coverage shards at line level...", length(shard_ids))
	merged_csv = file.path(artifact_dir, "merged-lines.csv")
	merge_status = system2("Rscript", c(file.path(root, "R/package_tests/ci/merge_coverage_lines.R"), artifact_dir, merged_csv))
	if (merge_status != 0L) stop("Line-level merge failed.")
	log_line("merged line coverage written to %s (commit %s)", merged_csv, head_sha)
}
