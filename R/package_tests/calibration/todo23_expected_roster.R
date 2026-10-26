#!/usr/bin/env Rscript
# TODO-23 expected-key roster generator (release_v1_0_5.md TODO-23; G4-C calibration
# runbook R4 Part B). Promoted 2026-10-22 from the scratch file
# /tmp/edi-todo23-full-key-manifest.R (6,835 bytes, dated 2026-10-20), adapted:
#   * paths come from the repository instead of hard-coded /tmp files;
#   * the 14 current-source CI operations are built in (TODO-23 entry,
#     "Operation-label reconciliation detail, 2026-10-21"; owner decision G6 #36:
#     all 14 operations) instead of /tmp/edi-todo23-source-attempt-operation-manifest.csv,
#     which can still be supplied with --operations;
#   * output goes to a fresh --out-dir outside the checkout.
# The parsing logic (datasets with a survival response, TESTED_DESIGNS, Nrep and
# beta_T defaults, formula list, direct RMST runner call) is unchanged.
#
# It is source-only: it parses comprehensive_tests.R and _dataset_load.R, does
# not load EDI, and lists CANDIDATE keys (rep x beta_T x dataset x design x
# formula x 14 operations). Setup skips or class-ineligible designs in a real run
# surface as missing keys in the reconciliation and must be explained there.
#
# Usage:
#   Rscript R/package_tests/calibration/todo23_expected_roster.R --out-dir DIR [--operations ops.csv] [--nrep N]
# Writes DIR/todo23_expected_roster.csv and DIR/todo23_expected_roster_summary.txt.

TODO23_OPERATIONS <- c(
	"compute_wald_confidence_interval",
	"compute_asymp_confidence_interval",
	"compute_subsampling_confidence_interval",
	"compute_bayesian_bootstrap_confidence_interval_bca",
	"compute_bayesian_bootstrap_confidence_interval_wald",
	"compute_bayesian_bootstrap_confidence_interval",
	"compute_bayesian_bootstrap_confidence_interval_basic",
	"compute_bootstrap_confidence_interval",
	"compute_bootstrap_confidence_interval_bca",
	"compute_bootstrap_confidence_interval_basic",
	"compute_m_out_of_n_bootstrap_confidence_interval",
	"compute_bootstrap_confidence_interval_studentized",
	"compute_jackknife_wald_confidence_interval",
	"compute_bayesian_bootstrap_confidence_interval_studentized"
	# The four compute_rand_bootstrap_confidence_interval* operations were dropped
	# 2026-10-25 (G4-C R4A): RMST now refuses them (log-time-ratio scale, not the
	# RMST difference), so they are no longer CI operations of this class.
)

TODO23_KEY_COLUMNS <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")

todo23_expected_roster <- function(repo, operations = TODO23_OPERATIONS, nrep = NULL) {
	repo <- normalizePath(repo, mustWork = TRUE)
	runner_path <- file.path(repo, "R/package_tests/comprehensive_tests.R")
	dataset_path <- file.path(repo, "R/package_tests/_dataset_load.R")

	top_rhs <- function(path, name) {
		exprs <- parse(path)
		hits <- Filter(function(x) is.call(x) && length(x) >= 3L &&
			(identical(x[[1L]], as.name("=")) || identical(x[[1L]], as.name("<-"))) &&
			identical(x[[2L]], as.name(name)), as.list(exprs))
		if (length(hits) != 1L) stop("expected exactly one top-level assignment: ", name)
		hits[[1L]][[3L]]
	}
	named_call_args <- function(expr, call_name) {
		if (!is.call(expr) || !identical(expr[[1L]], as.name(call_name))) return(NULL)
		as.list(expr)[-1L]
	}
	find_named_list <- function(expr, expected) {
		if (!is.call(expr)) return(FALSE)
		if (identical(expr[[1L]], as.name("list")) && expected %in% names(as.list(expr)[-1L])) return(TRUE)
		children <- as.list(expr)[-1L]
		any(vapply(seq_along(children), function(i) {
			if (identical(children[i], list(quote(expr = )))) return(FALSE)
			find_named_list(children[[i]], expected)
		}, logical(1)))
	}

	dataset_rhs <- top_rhs(dataset_path, "datasets_and_response_models")
	dataset_entries <- named_call_args(dataset_rhs, "list")
	if (is.null(dataset_entries) || is.null(names(dataset_entries))) stop("dataset roster is no longer a named list")
	finagle_rhs <- top_rhs(dataset_path, "finagle_different_responses_from_continuous")
	if (!find_named_list(finagle_rhs[[3L]], "survival")) stop("continuous response transformer no longer declares survival")
	survival_datasets <- names(dataset_entries)[vapply(dataset_entries, function(entry) {
		fields <- named_call_args(entry, "list")
		if (is.null(fields) || !"y_original" %in% names(fields)) return(FALSE)
		y <- fields[["y_original"]]
		if (is.call(y) && identical(y[[1L]], as.name("finagle_different_responses_from_continuous"))) return(TRUE)
		y_fields <- named_call_args(y, "list")
		!is.null(y_fields) && "survival" %in% names(y_fields)
	}, logical(1))]

	designs <- eval(top_rhs(runner_path, "TESTED_DESIGNS"), envir = baseenv())
	nrep_expr <- top_rhs(runner_path, "Nrep")
	if (!is.call(nrep_expr) || !identical(nrep_expr[[1L]], as.name("if"))) stop("Nrep default shape changed")
	nrep_default <- as.integer(eval(nrep_expr[[4L]], envir = baseenv()))
	nrep_used <- if (is.null(nrep)) nrep_default else as.integer(nrep)
	beta_expr <- top_rhs(runner_path, "beta_T_values")
	if (!is.call(beta_expr) || !identical(beta_expr[[1L]], as.name("resolve_comprehensive_beta_values"))) stop("beta default shape changed")
	betas <- as.numeric(eval(beta_expr[[2L]], envir = baseenv()))
	runner_text <- paste(readLines(runner_path, warn = FALSE), collapse = "\n")
	if (!grepl("formulas_to_test\\s*=\\s*list\\(~\\s*1,\\s*~\\s*\\.\\)", runner_text)) stop("formula list source changed")
	formula_labels <- c("~1", "~.")
	# Further constructor arguments (the fixed tau, 2026-10-26) do not change the keys.
	if (!grepl("run_inference_checks\\(InferenceSurvivalRestrictedMeanDiff\\$new\\(des_obj, model_formula = model_formula[,)]", runner_text)) {
		stop("expected direct RMST runner call not found")
	}
	functions <- unique(as.character(operations))
	if (length(functions) != 14L || anyDuplicated(operations)) stop("operation roster must contain 14 unique candidate function_run values")

	cases <- expand.grid(
		rep = seq_len(nrep_used), beta_T = betas, dataset = survival_datasets,
		response_type = "survival", design = designs,
		design_formula = formula_labels, stringsAsFactors = FALSE,
		KEEP.OUT.ATTRS = FALSE
	)
	cases$inference_class <- paste0("InferenceSurvivalRestrictedMeanDiff [design_formula=", cases$design_formula, "]")
	manifest <- merge(cases, data.frame(function_run = functions, stringsAsFactors = FALSE), all = TRUE)
	key_cols <- c("rep", "beta_T", "dataset", "response_type", "design", "design_formula", "inference_class", "function_run")
	manifest <- manifest[key_cols]
	if (anyNA(manifest[key_cols]) || anyDuplicated(manifest[key_cols])) stop("generated full-key manifest has missing/duplicate keys")
	attr(manifest, "roster_info") <- list(
		runner_path = runner_path, dataset_path = dataset_path, survival_datasets = survival_datasets,
		beta_T_values = betas, nrep_default = nrep_default, nrep_used = nrep_used, designs = designs,
		design_formulas = formula_labels, operations = functions, case_count = nrow(cases)
	)
	manifest
}

# Structural gaps of the candidate roster, owner-approved 2026-10-25 as skips
# (same idea as todo14_r5_rescope_approved_skips()): the runner never attempts
# these keys, so they are not missing attempts.
#   (a) FixedBinaryMatch x design_formula=~1: the matching design needs
#       covariates, so the runner skips the whole setup (setup_skipped event).
#   (b) The 6 nonparametric bootstrap / subsampling CIs on KK21stepwise and
#       SPBR: the class's capabilities omit nonparametric_bootstrap for these
#       sequential designs (skip_bootstrap in comprehensive_tests.R).
#   (c) Owner-approved 2026-10-26: on cars, the m-out-of-n and subsampling CIs
#       for design_formula=~. on the two matched-pair designs. The pair count
#       is too small for a subsample (default_small_resampling_size() returns
#       NA: "too few exchangeable units"), so the runner never calls them.
# A result row for one of these keys is reported by the reconciliation as
# result_extra.
TODO23_NONPARAMETRIC_BOOTSTRAP_OPERATIONS <- c(
	"compute_subsampling_confidence_interval",
	"compute_bootstrap_confidence_interval",
	"compute_bootstrap_confidence_interval_bca",
	"compute_bootstrap_confidence_interval_basic",
	"compute_m_out_of_n_bootstrap_confidence_interval",
	"compute_bootstrap_confidence_interval_studentized"
)
TODO23_NO_NONPARAMETRIC_BOOTSTRAP_DESIGNS <- c("KK21stepwise", "SPBR")
TODO23_SMALL_SUBSAMPLE_OPERATIONS <- c(
	"compute_m_out_of_n_bootstrap_confidence_interval",
	"compute_subsampling_confidence_interval"
)
TODO23_TOO_FEW_PAIRS_DATASETS <- "cars"
TODO23_MATCHED_PAIR_DESIGNS <- c("FixedBinaryMatch", "FixedMatchingGreedy")

todo23_structural_skips <- function(manifest) {
	fbm_no_covariates <- manifest$design == "FixedBinaryMatch" & manifest$design_formula == "~1"
	no_boot <- manifest$design %in% TODO23_NO_NONPARAMETRIC_BOOTSTRAP_DESIGNS &
		manifest$function_run %in% TODO23_NONPARAMETRIC_BOOTSTRAP_OPERATIONS
	too_few_pairs <- manifest$dataset %in% TODO23_TOO_FEW_PAIRS_DATASETS &
		manifest$design %in% TODO23_MATCHED_PAIR_DESIGNS & manifest$design_formula == "~." &
		manifest$function_run %in% TODO23_SMALL_SUBSAMPLE_OPERATIONS
	keep <- fbm_no_covariates | no_boot | too_few_pairs
	out <- manifest[keep, , drop = FALSE]
	out$skip_reason <- ifelse(fbm_no_covariates[keep], "fbm_design_formula_1_setup_skipped",
		ifelse(no_boot[keep], "design_lacks_nonparametric_bootstrap", "too_few_exchangeable_units"))
	rownames(out) <- NULL
	out
}

todo23_roster_summary_lines <- function(manifest, out_path = NA_character_) {
	info <- attr(manifest, "roster_info")
	c(
		"TODO-23 current-source full-key attempt manifest (source-only; candidate keys, not a historical artifact roster)",
		paste0("runner_path=", info$runner_path),
		paste0("dataset_path=", info$dataset_path),
		paste0("survival_datasets=", paste(info$survival_datasets, collapse = ",")),
		paste0("beta_T_values=", paste(info$beta_T_values, collapse = ",")),
		paste0("Nrep_default=", info$nrep_default, "; Nrep_used=", info$nrep_used),
		paste0("designs=", paste(info$designs, collapse = ",")),
		paste0("design_formulas=", paste(info$design_formulas, collapse = ",")),
		"inference_class=InferenceSurvivalRestrictedMeanDiff [design_formula=<formula>]",
		paste0("operations (", length(info$operations), ")=", paste(info$operations, collapse = ",")),
		paste0("source_case_dimensions=", info$case_count),
		paste0("generated_candidate_full_keys=", nrow(manifest)),
		paste0("manifest=", out_path)
	)
}

if (sys.nframe() == 0L) {
	local({
		args <- commandArgs(trailingOnly = TRUE)
		f <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
		here <- dirname(normalizePath(sub("^--file=", "", f[[1L]])))
		source(file.path(here, "calibration_common.R"), local = TRUE)
		opt <- calib_parse_args(args, defaults = list(out_dir = "", operations = "", nrep = "", repo = ""),
			usage = "Usage: Rscript R/package_tests/calibration/todo23_expected_roster.R --out-dir DIR [--operations ops.csv] [--nrep N] [--repo ROOT]")
		repo <- if (nzchar(opt$repo)) normalizePath(opt$repo) else calib_find_repo_root(here)
		out_dir <- calib_prepare_output_dir(opt$out_dir, repo)
		ops <- if (nzchar(opt$operations)) {
			o <- utils::read.csv(opt$operations, stringsAsFactors = FALSE)
			unique(o$function_run[(!"response_type" %in% names(o) | o$response_type == "survival") &
				(!"inference_class" %in% names(o) | o$inference_class == "InferenceSurvivalRestrictedMeanDiff")])
		} else TODO23_OPERATIONS
		manifest <- todo23_expected_roster(repo, ops, nrep = if (nzchar(opt$nrep)) as.integer(opt$nrep) else NULL)
		out_path <- file.path(out_dir, "todo23_expected_roster.csv")
		utils::write.csv(manifest, out_path, row.names = FALSE, na = "")
		lines <- c(todo23_roster_summary_lines(manifest, out_path),
			paste0("runner_sha256=", calib_sha256(attr(manifest, "roster_info")$runner_path)),
			paste0("dataset_loader_sha256=", calib_sha256(attr(manifest, "roster_info")$dataset_path)),
			paste0("generator_sha256=", calib_sha256(normalizePath(sub("^--file=", "", f[[1L]])))))
		writeLines(lines, file.path(out_dir, "todo23_expected_roster_summary.txt"))
		cat(paste(lines, collapse = "\n"), "\n")
	})
}
