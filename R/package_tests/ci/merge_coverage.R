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
saveRDS(coverage, file.path(args[[1]], "merged-coverage.rds"))
covr::codecov(coverage = coverage, flags = "r", token = Sys.getenv("CODECOV_TOKEN"), quiet = FALSE)
