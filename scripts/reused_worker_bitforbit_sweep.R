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

# TODO-12's accepted paired sweep is the source-derived 240-key roster; fail
# closed if strict enumeration silently drops every candidate or a later edit
# changes the cohort without updating the plan and this contract.
RESAMPLING_NONDEGENERATE_EXPECTED_KEY_COUNT = 240L

repo_root = function(){
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
	if (is.na(script) || !nzchar(script)) return(getwd())
	normalizePath(file.path(dirname(script), ".."), mustWork = FALSE)
}

sweep_build_design = function(arm, response_type){
	design = tryCatch(arm$build(response_type), error = function(e) {
		stop(sprintf("design constructor failed for %s/%s: %s", arm$name, response_type, conditionMessage(e)), call. = FALSE)
	})
	if (is.null(design)) stop(sprintf("design constructor returned NULL for %s/%s", arm$name, response_type), call. = FALSE)
	design
}

sweep_new_inference = function(generator, des_obj, key){
	tryCatch(generator$new(des_obj, verbose = FALSE), error = function(e) {
		stop(sprintf("inference constructor failed for %s: %s", key, conditionMessage(e)), call. = FALSE)
	})
}

sweep_distribution = function(obj, key, r){
	values = tryCatch(
		suppressWarnings(as.numeric(obj$approximate_randomization_distribution_beta_hat_T(
			r = r, show_progress = FALSE
		))),
		error = function(e) stop(sprintf("distribution failed for %s: %s", key, conditionMessage(e)), call. = FALSE)
	)
	if (!is.numeric(values)) stop(sprintf("distribution for %s is not numeric", key), call. = FALSE)
	if (length(values) != r) stop(sprintf("distribution for %s has length %d; expected %d", key, length(values), r), call. = FALSE)
	if (any(!is.na(values) & !is.finite(values))) stop(sprintf("distribution for %s contains non-finite, non-NA values", key), call. = FALSE)
	values
}

# Keep enough provenance with each snapshot to establish that a comparison
# used the same package release and native ABI. The R-source manifest is
# retained separately because --source intentionally changes that layer.
sweep_capture_provenance = function(use_source_tree){
	ns = asNamespace("EDI")
	package_path = normalizePath(getNamespaceInfo(ns, "path"), winslash = "/", mustWork = TRUE)
	package_description = read.dcf(file.path(package_path, "DESCRIPTION"))
	package_version = unname(package_description[1L, "Version"])
	if (!length(package_version) || is.na(package_version) || !nzchar(package_version)) {
		stop("could not identify the loaded EDI package version", call. = FALSE)
	}
	dll = getLoadedDLLs()[["EDI"]]
	if (is.null(dll) || is.null(dll[["path"]]) || !nzchar(dll[["path"]])) {
		stop("could not identify the loaded EDI native library", call. = FALSE)
	}
	dll_path = normalizePath(dll[["path"]], winslash = "/", mustWork = TRUE)
	r_path = file.path(package_path, "R")
	if (!dir.exists(r_path)) stop("could not identify the loaded EDI R source directory", call. = FALSE)
	r_files = sort(list.files(r_path, recursive = TRUE, full.names = TRUE))
	r_files = r_files[!dir.exists(r_files)]
	if (!length(r_files)) stop("loaded EDI R layer directory contains no files", call. = FALSE)
	r_md5 = unname(tools::md5sum(r_files))
	names(r_md5) = substring(r_files, nchar(r_path) + 2L)
	list(
		package_version = package_version,
		package_path = package_path,
		source_tree = isTRUE(use_source_tree),
		native_dll_path = dll_path,
		native_dll_md5 = unname(tools::md5sum(dll_path)),
		r_layer_kind = if (any(grepl("\\.[Rr]$", r_files))) "source-files" else "installed-lazyload",
		r_layer_file_md5 = r_md5
	)
}

validate_sweep_provenance = function(provenance, context = "snapshot"){
	if (!is.list(provenance) ||
	    length(provenance$package_version) != 1L || is.na(provenance$package_version) || !nzchar(provenance$package_version) ||
	    length(provenance$package_path) != 1L || is.na(provenance$package_path) || !nzchar(provenance$package_path) ||
	    !is.logical(provenance$source_tree) || length(provenance$source_tree) != 1L || is.na(provenance$source_tree) ||
	    length(provenance$native_dll_path) != 1L || is.na(provenance$native_dll_path) || !nzchar(provenance$native_dll_path) ||
	    length(provenance$native_dll_md5) != 1L || is.na(provenance$native_dll_md5) ||
	    !grepl("^[[:xdigit:]]{32}$", provenance$native_dll_md5) ||
	    !is.character(provenance$r_layer_kind) || length(provenance$r_layer_kind) != 1L || is.na(provenance$r_layer_kind) ||
	    !(provenance$r_layer_kind %in% c("source-files", "installed-lazyload")) ||
	    !is.character(provenance$r_layer_file_md5) || !length(provenance$r_layer_file_md5) ||
	    is.null(names(provenance$r_layer_file_md5)) || anyNA(names(provenance$r_layer_file_md5)) ||
	    any(!nzchar(names(provenance$r_layer_file_md5))) || anyNA(provenance$r_layer_file_md5) ||
	    any(!grepl("^[[:xdigit:]]{32}$", provenance$r_layer_file_md5))) {
		stop(context, " is missing valid EDI package/native/R-source provenance", call. = FALSE)
	}
	invisible(provenance)
}

validate_sweep_snapshot = function(snapshot, expected_keys, r, context = "snapshot",
	                                expected_key_count = RESAMPLING_NONDEGENERATE_EXPECTED_KEY_COUNT){
	if (!is.list(snapshot) || is.null(names(snapshot))) stop(context, " is not a named distribution list", call. = FALSE)
	if (anyDuplicated(names(snapshot))) stop(context, " has duplicate keys", call. = FALSE)
	if (!is.character(expected_keys) || !length(expected_keys) || anyNA(expected_keys) || any(!nzchar(expected_keys))) {
		stop(context, " expected manifest must contain non-empty character keys", call. = FALSE)
	}
	if (anyDuplicated(expected_keys)) stop(context, " expected manifest has duplicate keys", call. = FALSE)
	if (length(expected_keys) != expected_key_count) {
		stop(sprintf("%s expected manifest must contain exactly %d source-derived keys", context,
		             expected_key_count), call. = FALSE)
	}
	if (!is.numeric(r) || length(r) != 1L || is.na(r) || !is.finite(r) || r < 1 || r != floor(r)) {
		stop("r must be one positive integer", call. = FALSE)
	}
	missing = setdiff(expected_keys, names(snapshot))
	extra = setdiff(names(snapshot), expected_keys)
	if (length(missing) || length(extra)) {
		stop(sprintf("%s key mismatch: missing={%s}; extra={%s}", context,
		             paste(missing, collapse = ", "), paste(extra, collapse = ", ")), call. = FALSE)
	}
	for (key in expected_keys) {
		values = snapshot[[key]]
		if (!is.numeric(values) || length(values) != r) {
			stop(sprintf("%s distribution for %s must be numeric length %d", context, key, r), call. = FALSE)
		}
		if (any(!is.na(values) & !is.finite(values))) {
			stop(sprintf("%s distribution for %s contains non-finite, non-NA values", context, key), call. = FALSE)
		}
	}
	invisible(snapshot)
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
	provenance = sweep_capture_provenance(use_source_tree)
	load_sweep_enumeration(root)

	snapshot = list()
	expected_keys = character()
	for (arm in resampling_nondegenerate_arms()) {
		for (response_type in RESAMPLING_NONDEGENERATE_RESPONSE_TYPES) {
			if (length(resampling_nondegenerate_cases(arm, response_type, NULL, strict = TRUE)) == 0L) next
			des_obj = sweep_build_design(arm, response_type)
			for (case in resampling_nondegenerate_cases(arm, response_type, des_obj, strict = TRUE)) {
				for (forced in c(FALSE, TRUE)) {
					key = paste(case$classname, arm$name, response_type,
					            if (forced) "forced" else "production", sep = "|")
					if (key %in% expected_keys) stop("duplicate expected sweep key: ", key, call. = FALSE)
					expected_keys = c(expected_keys, key)
					generator = if (forced) {
						resampling_nondegenerate_probe(case$generator, case$classname, reusable = TRUE)
					} else {
						case$generator
					}
					obj = sweep_new_inference(generator, des_obj, key)
					obj$num_cores = 1L
					set.seed(RESAMPLING_NONDEGENERATE_SEED)
					values = sweep_distribution(obj, key, RESAMPLING_NONDEGENERATE_R)
					snapshot[[key]] = values
				}
			}
			cat("swept", arm$name, response_type, "--", length(snapshot), "entries so far\n")
		}
	}
	validate_sweep_snapshot(snapshot, expected_keys, RESAMPLING_NONDEGENERATE_R, "recorded sweep")
	attr(snapshot, "expected_keys") = expected_keys
	attr(snapshot, "provenance") = provenance
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
#   * "fixed"  -- was a finite point mass, now varies. What a fix should do.
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
	# A baseline with no finite draws is not evidence of a collapsed
	# distribution. Keep that transition visible as MOVED instead of claiming
	# the cache fix restored variation.
	if (b_uniq == 1L && a_uniq > 1L) return("fixed")
	if (max_abs_difference(b, a) <= noise_tolerance) return("noise")
	"MOVED"
}

compare = function(before_path, after_path, noise_tolerance = 1e-8){
	before = readRDS(before_path)
	after = readRDS(after_path)
	before_provenance = attr(before, "provenance", exact = TRUE)
	after_provenance = attr(after, "provenance", exact = TRUE)
	validate_sweep_provenance(before_provenance, "before snapshot")
	validate_sweep_provenance(after_provenance, "after snapshot")
	if (!identical(before_provenance$package_version, after_provenance$package_version)) {
		stop("before/after package versions differ", call. = FALSE)
	}
	if (!identical(before_provenance$native_dll_md5, after_provenance$native_dll_md5)) {
		stop("before/after native EDI DLLs differ", call. = FALSE)
	}
	before_keys = attr(before, "expected_keys", exact = TRUE)
	after_keys = attr(after, "expected_keys", exact = TRUE)
	if (is.null(before_keys) || is.null(after_keys)) stop("both snapshots must carry their source-derived expected_keys manifest", call. = FALSE)
	validate_sweep_snapshot(before, before_keys, RESAMPLING_NONDEGENERATE_R, "before snapshot")
	validate_sweep_snapshot(after, after_keys, RESAMPLING_NONDEGENERATE_R, "after snapshot")
	if (!identical(sort(before_keys), sort(after_keys))) stop("before/after expected key manifests differ", call. = FALSE)
	if (!identical(sort(names(before)), sort(names(after)))) stop("before/after observed key sets differ", call. = FALSE)
	shared = intersect(names(before), names(after))
	for (k in shared) {
		if (length(before[[k]]) != length(after[[k]])) stop("distribution length mismatch for ", k, call. = FALSE)
		if (!identical(is.na(before[[k]]), is.na(after[[k]]))) stop("NA-pattern mismatch for ", k, call. = FALSE)
	}
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
