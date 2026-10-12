#!/usr/bin/env Rscript
# Merges the per-shard coverage artifacts into one covr "coverage" object and
# uploads it to codecov.
#
# History / root cause (2026-10-12). This job had NEVER completed since the
# coverage tier was sharded (ed2bf4ef, 2026-09-16): every real attempt --
# 2026-09-25 run 36139904290 onward, 20+ runs -- died a few minutes into the
# merge with "the runner has received a shutdown signal" and no R output. (The
# 2026-09-25 "successes" were runs where the shards and merge jobs were
# SKIPPED, not runs where the merge worked.) That message is what a GitHub-
# hosted runner prints when the VM is memory-exhausted and the runner agent
# itself gets killed, and the numbers match exactly: one shard's coverage.rds
# is ~55 MB compressed but ~1.6 GB of R heap once deserialized (56k srcref-
# bearing elements) and takes ~17 s to read, so the old
# `reports = lapply(files, readRDS)` over 100 shards needed ~160 GB on a 16 GB
# runner and was OOM-killed after ~8-10 reads. The 2026-10-07 switch to
# parallel reads "cut the time-to-kill from ~6 minutes to ~70-110 s" -- a
# corrupted/hung gzip stream (the hypothesis the previous per-file-timeout
# machinery was built on) would not die FASTER with 4 readers, but a memory
# blowup fills RAM 4x faster and does. Measured locally on a real artifact
# (run 38226791838, shard 47): readRDS 17.4 s, 1.59 GB heap. Independently,
# covr::merge_coverage() takes ~112 s to merge just TWO of these objects and
# mis-sums the ~9.6k gcov entries whose element names are duplicated (a header
# line is reported once per translation unit; its `x[[name]]` lookup only ever
# hits the first), so it could not have worked at this scale even with
# unlimited memory.
#
# Design now: each shard also writes a compact `coverage_values.rds` sidecar
# (run_shard.R: occurrence-unique keys + counts, ~7 MB, milliseconds to read).
# This script reads ONE full coverage.rds as the skeleton (~1.6 GB, once),
# sums every shard's counts by key, and writes the totals back into the
# skeleton's elements. Peak memory ~2 GB; wall time well under a minute. Line
# totals are exact: downstream consumers (covr::tally_coverage, codecov,
# check_coverage_floor.R, coverage_gap_registry.R) aggregate by filename+line,
# which depends only on each duplicated key group's sum.
log_stage = function(msg) {
	cat(sprintf("[merge_coverage %s] %s\n", format(Sys.time(), "%H:%M:%S"), msg))
	flush(stdout())
}
elapsed_since = function(t0) sprintf("%.1fs", proc.time()[["elapsed"]] - t0)

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: merge_coverage.R ARTIFACT_DIR MATRIX_JSON")
artifact_dir = args[[1]]

log_stage("start")
values_files = list.files(artifact_dir, pattern = "^coverage_values\\.rds$", recursive = TRUE, full.names = TRUE)
full_files = list.files(artifact_dir, pattern = "^coverage\\.rds$", recursive = TRUE, full.names = TRUE)
if (!length(values_files)) {
	stop(sprintf(paste0(
		"found %d coverage.rds files but no coverage_values.rds sidecars: these shard artifacts ",
		"predate run_shard.R's compact sidecar (needed because 100 full coverage objects are ~160 GB ",
		"of R heap, see this script's header). Re-run the workflow so the shards regenerate."),
		length(full_files)))
}
log_stage(sprintf("found %d coverage_values.rds sidecars (+ %d full coverage.rds), reading sidecars ...",
	length(values_files), length(full_files)))
t0 = proc.time()[["elapsed"]]
shards = lapply(values_files, readRDS)
log_stage(sprintf("read sidecars (%s)", elapsed_since(t0)))

# Provenance / completeness checks.
expected = jsonlite::fromJSON(args[[2]])$shard
ids = vapply(shards, function(x) as.integer(x$shard), integer(1))
if (anyDuplicated(ids) || !setequal(ids, expected)) {
	stop(sprintf("Missing or duplicate coverage shards: have %s, expected %s",
		paste(sort(ids), collapse = ","), paste(sort(expected), collapse = ",")))
}
commit = Sys.getenv("GITHUB_SHA")
covr_version = as.character(packageVersion("covr"))
bad = vapply(shards, function(x) !identical(x$commit, commit) || !identical(x$covr_version, covr_version), logical(1))
if (any(bad)) stop("Coverage provenance mismatch in: ", paste(values_files[bad], collapse = ", "))
if (any(vapply(shards, function(x) length(x$keys) != length(x$values) || anyDuplicated(x$keys) > 0, logical(1)))) {
	stop("Malformed coverage_values.rds sidecar (keys/values length mismatch or non-unique keys)")
}

# Sum counts over the union of keys. Shards can legitimately differ in key set:
# gcov only emits a source file's lines when some test in that shard executed
# its translation unit, so a C++ file never touched by a shard is absent there.
log_stage("summing shard counts ...")
t0 = proc.time()[["elapsed"]]
union_keys = unique(unlist(lapply(shards, `[[`, "keys"), use.names = FALSE))
totals = numeric(length(union_keys))
names(totals) = union_keys
for (x in shards) {
	idx = match(x$keys, union_keys)
	totals[idx] = totals[idx] + x$values
}
log_stage(sprintf("summed %d shards over %d keys (%s)", length(shards), length(union_keys), elapsed_since(t0)))

# Skeleton: one full coverage object, from the shard with the most keys so the
# fewest other full objects (if any) have to be opened for keys it lacks.
skeleton_shard = which.max(vapply(shards, function(x) length(x$keys), integer(1)))
skeleton_file = file.path(dirname(values_files[[skeleton_shard]]), "coverage.rds")
if (!file.exists(skeleton_file)) stop("Missing full coverage.rds next to ", values_files[[skeleton_shard]])
element_keys = function(coverage) make.unique(names(coverage), sep = "#dup")
load_coverage_elements = function(file) {
	coverage = readRDS(file)$coverage
	if (!inherits(coverage, "coverage")) stop("Not a covr coverage object: ", file)
	if ("tests" %in% names(coverage)) {
		# `[` on a list keeps only `names`; covr's class/package/root attributes
		# must be carried over by hand or the result is a plain list that
		# tally_coverage()/codecov()/percent_coverage() no longer dispatch on.
		attrs = attributes(coverage)
		keep = names(coverage) != "tests"
		coverage = coverage[keep]
		attrs$names = attrs$names[keep]
		attributes(coverage) = attrs
	}
	coverage
}
log_stage(sprintf("reading skeleton %s (shard %d) ...", skeleton_file, ids[[skeleton_shard]]))
t0 = proc.time()[["elapsed"]]
coverage = load_coverage_elements(skeleton_file)
log_stage(sprintf("read skeleton: %d elements (%s)", length(coverage), elapsed_since(t0)))
skeleton_keys = element_keys(coverage)
if (!identical(skeleton_keys, shards[[skeleton_shard]]$keys)) {
	stop("Sidecar keys do not match the full coverage object they were written from: ", skeleton_file)
}

# Any key the skeleton lacks is pulled, with its srcref, from a shard that has
# it -- one full object open at a time, released before the next.
missing = setdiff(union_keys, skeleton_keys)
while (length(missing) > 0L) {
	holder = which(vapply(shards, function(x) any(missing %in% x$keys), logical(1)))[[1L]]
	holder_file = file.path(dirname(values_files[[holder]]), "coverage.rds")
	log_stage(sprintf("skeleton lacks %d keys; pulling their elements from shard %d (%s) ...",
		length(missing), ids[[holder]], holder_file))
	t0 = proc.time()[["elapsed"]]
	extra = load_coverage_elements(holder_file)
	extra_keys = element_keys(extra)
	if (!identical(extra_keys, shards[[holder]]$keys)) stop("Sidecar keys do not match ", holder_file)
	take = which(extra_keys %in% missing)
	for (i in take) coverage[[length(coverage) + 1L]] = extra[[i]]
	names(coverage)[length(coverage) - length(take) + seq_along(take)] = names(extra)[take]
	skeleton_keys = c(skeleton_keys, extra_keys[take])
	missing = setdiff(missing, extra_keys[take])
	rm(extra); invisible(gc())
	log_stage(sprintf("pulled %d elements (%s)", length(take), elapsed_since(t0)))
}
if (anyDuplicated(skeleton_keys) > 0 || !setequal(skeleton_keys, union_keys)) stop("Internal error assembling skeleton keys")

log_stage("writing summed counts into the skeleton ...")
t0 = proc.time()[["elapsed"]]
summed = unname(totals[skeleton_keys])
for (i in seq_along(coverage)) coverage[[i]]$value = summed[[i]]
if (!inherits(coverage, "coverage") || is.null(attr(coverage, "package"))) {
	stop("Internal error: merged object lost covr's coverage class/attributes")
}
log_stage(sprintf("merge finished: %d elements (%s)", length(coverage), elapsed_since(t0)))

saveRDS(list(coverage = coverage, commit = commit,
	measured_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
	covr_version = covr_version, shards = ids),
	file.path(artifact_dir, "merged-coverage.rds"))
log_stage("wrote merged-coverage.rds")

if (nzchar(Sys.getenv("EDI_SKIP_CODECOV_UPLOAD"))) {
	log_stage("EDI_SKIP_CODECOV_UPLOAD set: skipping codecov upload (local verification run)")
	quit(status = 0)
}
log_stage("starting codecov upload ...")

# covr::codecov() has no built-in timeout: a slow/unresponsive codecov.io endpoint
# hangs this call indefinitely. callr::r(..., timeout = ) runs it in a real child
# OS process that callr forcibly kills (SIGKILL) when the timeout elapses
# regardless of what that process is blocked on -- confirmed locally to actually
# interrupt a genuinely hung child (unlike setTimeLimit()).
upload_attempt = function() {
	callr::r(
		function(coverage, token) {
			covr::codecov(coverage = coverage, flags = "r", token = token, quiet = FALSE)
		},
		args = list(coverage = coverage, token = Sys.getenv("CODECOV_TOKEN")),
		timeout = 300,
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
