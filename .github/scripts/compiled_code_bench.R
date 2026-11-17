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

# Warm up (page faults, lazy loading, first-call caches), then size the loop so the timed
# part takes at least MIN_SECONDS.
MIN_SECONDS = 1.5
MAX_REPS = 500L
res = env$bench_run(d)
for (i in 1:2) env$bench_run(d)
one = system.time(env$bench_run(d))[["elapsed"]]
reps = max(5L, min(MAX_REPS, as.integer(ceiling(MIN_SECONDS / max(one, 1e-4)))))
times = numeric(reps)
for (i in seq_len(reps)) {
	s = proc.time()[["elapsed"]]
	env$bench_run(d)
	times[i] = proc.time()[["elapsed"]] - s
}
# proc.time() has millisecond resolution; for very short calls time blocks of calls instead.
if (stats::median(times) < 0.005) {
	block = as.integer(ceiling(0.02 / max(mean(times), 1e-6)))
	nb = max(5L, as.integer(ceiling(reps / block)))
	times = numeric(nb)
	for (i in seq_len(nb)) {
		s = proc.time()[["elapsed"]]
		for (j in seq_len(block)) env$bench_run(d)
		times[i] = (proc.time()[["elapsed"]] - s) / block
	}
	reps = nb * block
}
if (!is.na(rds)) saveRDS(res, rds)
writeLines(sprintf('{"per_call": %.9g, "reps": %d, "load": %.4g}', stats::median(times), reps, load_s), out)
