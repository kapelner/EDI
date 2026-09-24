#!/usr/bin/env Rscript
# Bit-for-bit sweep of every reused-worker randomization distribution in the
# package, for verifying the standing "a class that was already correct must not
# move" constraint when the reused-worker resampling machinery is changed
# (stale_worker_cache_resampling.md, TODO-5).
#
# It records one randomization distribution per (class, response type, design
# family, path), where "path" is both the production path and the path with the
# vectorized `compute_fast_randomization_distr()` kernel forced to NULL so the
# reused-worker loader is exercised even for classes that normally bypass it.
# Run it once against the unchanged package and once against the changed one,
# then diff the two snapshots: every entry should be `identical()` except the
# ones the change is supposed to fix.
#
# The class/fixture enumeration is NOT duplicated here. It is taken from
# `R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R` by
# evaluating that file's top-level helper definitions (everything except its
# `test_that()` blocks), so the permanent regression test and this verification
# script can never drift apart in which classes they cover.
#
# Usage, from the repository root:
#
#   # 1. snapshot the CURRENT (unchanged) package -- uses the installed EDI
#   Rscript scripts/reused_worker_bitforbit_sweep.R record before.rds
#
#   # 2. apply the change, then snapshot the working tree. Loading the modified
#   #    R layer needs a shared object; EDI must never be rebuilt just for this
#   #    (see the top-level CLAUDE.md), so borrow the installed one:
#   cp -p "$(Rscript -e 'cat(system.file("libs", "EDI.so", package = "EDI"))')" R/EDI/src/EDI.so
#   Rscript scripts/reused_worker_bitforbit_sweep.R record after.rds --source
#   rm R/EDI/src/EDI.so
#
#   # 3. compare
#   Rscript scripts/reused_worker_bitforbit_sweep.R compare before.rds after.rds
#
# Establish the noise floor first. A handful of KK compound kernels are not
# bit-reproducible run to run on this platform: recording the SAME unchanged
# package twice and comparing the two snapshots yields a small set of entries
# that differ at ~1e-16 (as of 2026-09-22: `InferenceAllKKMeanDiffIVWC` on three
# response types and the two `InferenceBaiAdjustedTKK*` classes, all on the
# forced path). Those entries land in the `noise` bucket and are not evidence of
# anything. So run
#
#   Rscript scripts/reused_worker_bitforbit_sweep.R record before2.rds
#   Rscript scripts/reused_worker_bitforbit_sweep.R compare before.rds before2.rds
#
# once to see which entries move on their own, and only treat `MOVED` entries --
# and `noise` entries outside that set -- as attributable to the change.
#
# `record` takes a few minutes; the .rds snapshots are one-off artifacts and are
# not meant to be committed.

args = commandArgs(trailingOnly = TRUE)
mode = if (length(args) >= 1L) args[1] else "help"

repo_root = function(){
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
	if (is.na(script) || !nzchar(script)) return(getwd())
	normalizePath(file.path(dirname(script), ".."), mustWork = FALSE)
}

# Evaluates the regression test file's helper definitions -- its fixture
# builders, its arm definitions and its registry-driven case enumeration --
# without running its `test_that()` blocks.
load_sweep_enumeration = function(root){
	test_file = file.path(root, "R", "EDI", "tests", "testthat",
	                      "test-reused-worker-resampling-nondegenerate.R")
	if (!file.exists(test_file)) {
		stop("Cannot find the regression test that defines the sweep enumeration: ", test_file, call. = FALSE)
	}
	for (expr in parse(test_file)) {
		if (is.call(expr) && length(expr) > 0L) {
			head_name = tryCatch(as.character(expr[[1L]])[1L], error = function(e) "")
			if (head_name %in% c("test_that", "library", "require")) next
		}
		eval(expr, envir = globalenv())
	}
	invisible(NULL)
}

record = function(out_path, use_source_tree){
	root = repo_root()
	if (isTRUE(use_source_tree)) {
		if (!file.exists(file.path(root, "R", "EDI", "src", "EDI.so"))) {
			stop("--source needs R/EDI/src/EDI.so; copy the installed one in first (see the usage notes above). ",
			     "Never rebuild EDI for this.", call. = FALSE)
		}
		suppressMessages(pkgload::load_all(file.path(root, "R", "EDI"), compile = FALSE, quiet = TRUE, export_all = FALSE))
	} else {
		suppressMessages(library(EDI))
	}
	load_sweep_enumeration(root)

	snapshot = list()
	for (arm in resampling_nondegenerate_arms()) {
		for (response_type in RESAMPLING_NONDEGENERATE_RESPONSE_TYPES) {
			if (length(resampling_nondegenerate_cases(arm, response_type, NULL)) == 0L) next
			des_obj = tryCatch(arm$build(response_type), error = function(e) NULL)
			if (is.null(des_obj)) next
			for (case in resampling_nondegenerate_cases(arm, response_type, des_obj)) {
				for (forced in c(FALSE, TRUE)) {
					generator = if (forced) {
						resampling_nondegenerate_probe(case$generator, case$classname, reusable = TRUE)
					} else {
						case$generator
					}
					obj = tryCatch(generator$new(des_obj, verbose = FALSE), error = function(e) NULL)
					if (is.null(obj)) next
					obj$num_cores = 1L
					set.seed(RESAMPLING_NONDEGENERATE_SEED)
					values = tryCatch(
						suppressWarnings(as.numeric(obj$approximate_randomization_distribution_beta_hat_T(
							r = RESAMPLING_NONDEGENERATE_R,
							show_progress = FALSE
						))),
						error = function(e) NA_real_
					)
					key = paste(case$classname, arm$name, response_type,
					            if (forced) "forced" else "production", sep = "|")
					snapshot[[key]] = values
				}
			}
			cat("swept", arm$name, response_type, "--", length(snapshot), "entries so far\n")
		}
	}
	saveRDS(snapshot, out_path)
	cat("wrote", length(snapshot), "distributions to", out_path, "\n")
}

max_abs_difference = function(b, a){
	if (length(b) != length(a)) return(Inf)
	both_finite = is.finite(b) & is.finite(a)
	if (!identical(is.finite(b), is.finite(a))) return(Inf)
	if (!any(both_finite)) return(0)
	max(abs(b[both_finite] - a[both_finite]))
}

# Classifies each changed entry so a reviewer is not left to eyeball raw
# `identical()` output:
#   * "fixed"  -- was a point mass / all-NA, now varies. What a fix should do.
#   * "noise"  -- still the same shape, differing only at the last bits. Some KK
#                 compound kernels are not bit-reproducible run to run on this
#                 platform at all (see the noise-floor recipe in the header), so
#                 this bucket is not automatically attributable to the change.
#   * "MOVED"  -- a substantive change to an already-varying distribution. This
#                 is the standing-constraint violation to investigate.
# `noise_tolerance` is deliberately loose for the same reason
# `test-bootstrap-reused-worker-families.R` loosened its own: different numeric
# routes to the same optimum differ well above machine epsilon.
classify_change = function(b, a, noise_tolerance){
	b_uniq = length(unique(b[is.finite(b)]))
	a_uniq = length(unique(a[is.finite(a)]))
	if (b_uniq <= 1L && a_uniq > 1L) return("fixed")
	if (max_abs_difference(b, a) <= noise_tolerance) return("noise")
	"MOVED"
}

compare = function(before_path, after_path, noise_tolerance = 1e-8){
	before = readRDS(before_path)
	after = readRDS(after_path)
	only_before = setdiff(names(before), names(after))
	only_after = setdiff(names(after), names(before))
	if (length(only_before)) cat("ONLY IN BEFORE:", paste(only_before, collapse = ", "), "\n")
	if (length(only_after)) cat("ONLY IN AFTER:", paste(only_after, collapse = ", "), "\n")
	shared = intersect(names(before), names(after))
	same = vapply(shared, function(k) identical(before[[k]], after[[k]]), logical(1L))
	changed = shared[!same]
	verdicts = vapply(changed, function(k) classify_change(before[[k]], after[[k]], noise_tolerance), character(1L))
	cat(sprintf("entries: %d  bit-identical: %d  changed: %d (fixed: %d, noise: %d, MOVED: %d)\n",
	            length(shared), sum(same), length(changed),
	            sum(verdicts == "fixed"), sum(verdicts == "noise"), sum(verdicts == "MOVED")))
	if (length(changed)) {
		cat("\nCHANGED entries:\n")
		for (k in changed[order(match(verdicts, c("MOVED", "fixed", "noise")))]) {
			b = before[[k]]
			a = after[[k]]
			cat(sprintf("  [%-5s] %-64s before: n_finite=%2d n_uniq=%2d | after: n_finite=%2d n_uniq=%2d | max|diff|=%s\n",
			            verdicts[[k]], k,
			            sum(is.finite(b)), length(unique(b[is.finite(b)])),
			            sum(is.finite(a)), length(unique(a[is.finite(a)])),
			            format(max_abs_difference(b, a), digits = 3)))
		}
	}
	if (any(verdicts == "MOVED")) {
		cat("\nAt least one already-varying distribution MOVED -- that is the standing\n")
		cat("constraint (`an already-correct class must not move`) being violated.\n")
	}
	invisible(sum(verdicts == "MOVED"))
}

if (identical(mode, "record")) {
	if (length(args) < 2L) stop("Usage: reused_worker_bitforbit_sweep.R record <out.rds> [--source]", call. = FALSE)
	record(args[2L], use_source_tree = "--source" %in% args)
} else if (identical(mode, "compare")) {
	if (length(args) < 3L) stop("Usage: reused_worker_bitforbit_sweep.R compare <before.rds> <after.rds>", call. = FALSE)
	compare(args[2L], args[3L])
} else {
	cat("Usage:\n")
	cat("  Rscript scripts/reused_worker_bitforbit_sweep.R record <out.rds> [--source]\n")
	cat("  Rscript scripts/reused_worker_bitforbit_sweep.R compare <before.rds> <after.rds>\n")
	cat("\nSee the comment block at the top of this file for the full recipe.\n")
}
