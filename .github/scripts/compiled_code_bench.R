#!/usr/bin/env Rscript
# One timing measurement for the compiled-code audit's benchmark check (stage 4).
# Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 5).
#
# Usage: compiled_code_bench.R LIB BENCH_CODE OUT_JSON [RESULT_RDS]
#   LIB         library holding the EDI build to time (base or patched)
#   BENCH_CODE  R file from the proposal: defines bench_setup() (fixed-seed data) and
#               bench_run(d) (one call into the changed C++ function; returns its result)
#   OUT_JSON    writes {"per_call": seconds (median), "reps": n, "load": seconds}
#   RESULT_RDS  if given, saves bench_run(d)'s value for the numerical-equivalence check
# compiled_code_verify.py calls this once per measurement, alternating builds (ABBA), so each
# measurement is a fresh process with only one EDI build loaded.
args = commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) stop("Usage: compiled_code_bench.R LIB BENCH_CODE OUT_JSON [RESULT_RDS]")
lib = args[[1]]
code = args[[2]]
out = args[[3]]
rds = if (length(args) >= 4L) args[[4]] else NA_character_

t0 = proc.time()[["elapsed"]]
suppressPackageStartupMessages(library(EDI, lib.loc = lib))
load_s = proc.time()[["elapsed"]] - t0
env = new.env(parent = globalenv())
sys.source(code, envir = env)
if (!is.function(env$bench_setup) || !is.function(env$bench_run))
	stop("the bench code must define bench_setup() and bench_run(d)")
d = env$bench_setup()

# Clock: Sys.time() has microsecond resolution on Linux; proc.time() counts whole milliseconds,
# which for a 4.6 ms call timed in 20 ms blocks quantized every measurement to 0.2 ms (4%), so
# all 20 ABBA blocks of the first PR (#38) gave the same ratio and a zero-width interval.
now = function() as.numeric(Sys.time())

# Warm up (page faults, lazy loading, first-call caches), then time blocks of calls: each block
# at least BLOCK_SECONDS (so the clock's resolution is under 1e-5 of it), MIN_SECONDS in all.
MIN_SECONDS = 1.5
BLOCK_SECONDS = 0.25
MAX_BLOCKS = 500L
res = env$bench_run(d)
for (i in 1:2) env$bench_run(d)
s = now(); invisible(env$bench_run(d)); one = max(now() - s, 1e-6)
block = max(1L, as.integer(ceiling(BLOCK_SECONDS / one)))
nb = min(MAX_BLOCKS, max(5L, as.integer(ceiling(MIN_SECONDS / (block * one)))))
times = numeric(nb)
for (i in seq_len(nb)) {
	s = now()
	for (j in seq_len(block)) env$bench_run(d)
	times[i] = (now() - s) / block
}
reps = nb * block
if (!is.na(rds)) saveRDS(res, rds)
writeLines(sprintf('{"per_call": %.9g, "reps": %d, "load": %.4g}', stats::median(times), reps, load_s), out)
