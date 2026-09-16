#!/usr/bin/env Rscript
# Machine-readable capability matrix: "which inference class supports which
# design family x response type x method" -- exported straight from EDI's own
# class registries so it cannot disagree with what the package actually does.
#
# Written 2026-09-16 for agent discoverability (improve_discoverability.md):
# an agent asking "what can EDI do for my situation?" reads ONE file instead
# of inferring the answer from 130+ reference pages. Three artifacts, all
# committed and drift-checked by drift_artifacts.sh (same regenerate/check
# discipline as public_api_inventory.csv):
#
#   package_tests/capability_matrix.csv     one row per exported, concrete
#                                            inference class
#   package_tests/design_matrix.csv         one row per exported, concrete
#                                            design class
#   package_tests/capability_matrix.json    both tables + the capability ->
#                                            public-method map, the method
#                                            sentinels InferenceSuite accepts,
#                                            and the design-level exclusions,
#                                            in one object (linked from
#                                            pkgdown/assets/llms.txt)
#
# Everything here is read from the registries (get_inference_class_metadata(),
# get_design_class_metadata(), get_effective_capabilities(),
# public_methods_for_capability, EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES) --
# nothing is hand-maintained. `design_families` is the registry's static
# compatibility declaration; the live per-instance rule (e.g. a sequential
# design losing nonparametric_bootstrap) is reported separately under
# `design_level_exclusions`, matching how the package itself applies it.
#
# Loads the source tree via pkgload (compile = FALSE), like every other
# generator here. Set EDI_CAPABILITY_MATRIX_USE_INSTALLED=1 to read the
# installed package instead (e.g. when src/ has no compiled objects yet).

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/capability_matrix.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

load_edi_namespace = function() {
	if (identical(Sys.getenv("EDI_CAPABILITY_MATRIX_USE_INSTALLED"), "1")) {
		suppressPackageStartupMessages(library(EDI))
		return(asNamespace("EDI"))
	}
	if (!requireNamespace("pkgload", quietly = TRUE)) {
		stop("Package 'pkgload' is required (or set EDI_CAPABILITY_MATRIX_USE_INSTALLED=1).", call. = FALSE)
	}
	pkgload::load_all(file.path(repo_root, "EDI"), quiet = TRUE, export_all = FALSE, compile = FALSE)
	asNamespace("EDI")
}

collapse = function(x) paste(sort(unique(as.character(x %||% character()))), collapse = "|")
flag = function(x) if (isTRUE(x)) "TRUE" else "FALSE"

ns = load_edi_namespace()
ns$populate_inference_class_registry()
ns$populate_design_class_registry()

# ---- inference classes ----------------------------------------------------
inf_registry = ns$inference_class_registry_as_list()
inf_names = sort(names(inf_registry))
method_map = ns$public_methods_for_capability

inf_rows = lapply(inf_names, function(nm) {
	m = ns$get_inference_class_metadata(nm)
	if (isTRUE(m$abstract) || !isTRUE(m$exported)) return(NULL)
	caps = tryCatch(ns$get_effective_capabilities(nm), error = function(e) character())
	methods = unique(unlist(method_map[intersect(names(method_map), caps)], use.names = FALSE))
	data.frame(
		inference_class = nm,
		response_types = collapse(m$response_types),
		design_families = collapse(m$design_families),
		estimand = collapse(m$estimand),
		likelihood_tier = as.character(m$likelihood_tier %||% ""),
		adjusts_for_covariates = flag(m$adjusts_for_covariates),
		requires_kk_matching_design = flag(m$requires_kk_matching_design),
		requires_blocking_design = flag(m$requires_blocking_design),
		supports_general_censoring = flag(m$supports_general_censoring),
		capabilities = collapse(caps),
		public_methods = collapse(methods),
		required_packages = collapse(m$required_packages),
		stringsAsFactors = FALSE
	)
})
inf_df = do.call(rbind, Filter(Negate(is.null), inf_rows))
inf_df = inf_df[order(inf_df$inference_class), , drop = FALSE]

# ---- design classes -------------------------------------------------------
des_registry = ns$design_class_registry_as_list()
des_names = sort(names(des_registry))
des_rows = lapply(des_names, function(nm) {
	m = ns$get_design_class_metadata(nm)
	if (isTRUE(m$abstract) || !isTRUE(m$exported)) return(NULL)
	data.frame(
		design_class = nm,
		timing_family = as.character(m$timing_family %||% ""),
		randomization_family = as.character(m$randomization_family %||% ""),
		seed_reproducible_draw = flag(m$seed_reproducible_draw),
		seed_reproducible_single_thread_only = flag(m$seed_reproducible_draw_requires_single_thread),
		required_packages = collapse(m$required_packages),
		stringsAsFactors = FALSE
	)
})
des_df = do.call(rbind, Filter(Negate(is.null), des_rows))
des_df = des_df[order(des_df$design_class), , drop = FALSE]

# ---- design-level exclusions (applied per instance, by ancestry) ----------
excl = ns$EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES
excl_df = if (length(excl)) data.frame(
	design_ancestor = names(excl),
	excluded_capability = vapply(excl, collapse, character(1)),
	note = "Applies to every design class inheriting from design_ancestor (including external subclasses); the listed capability's public methods stop with 'This method is not supported'.",
	stringsAsFactors = FALSE, row.names = NULL
) else data.frame(design_ancestor = character(), excluded_capability = character(), note = character())

# ---- write -----------------------------------------------------------------
out_dir = file.path(repo_root, "package_tests")
write.csv(inf_df, file.path(out_dir, "capability_matrix.csv"), row.names = FALSE)
write.csv(des_df, file.path(out_dir, "design_matrix.csv"), row.names = FALSE)

json_obj = list(
	`_about` = paste0(
		"EDI capability matrix, generated from the package's class registries by ",
		"R/package_tests/capability_matrix.R (EDI ", as.character(utils::packageVersion("EDI")), "). ",
		"inference_classes[].design_families lists the registry's static design compatibility; ",
		"design_level_exclusions is the per-instance rule applied on top. ",
		"public_methods are the R6 methods each capability exposes. ",
		"Docs: https://kapelner.github.io/EDI/"
	),
	package_version = as.character(utils::packageVersion("EDI")),
	response_types = sort(unique(unlist(strsplit(inf_df$response_types, "|", fixed = TRUE)))),
	design_families = sort(unique(des_df$randomization_family)),
	capability_to_public_methods = lapply(method_map, function(v) sort(unique(as.character(v)))),
	inference_suite_method_sentinels = as.character(ns$EDI_INFERENCE_SUITE_METHOD_SENTINELS),
	design_level_exclusions = excl_df,
	design_classes = des_df,
	inference_classes = inf_df
)
if (!requireNamespace("jsonlite", quietly = TRUE)) {
	stop("Package 'jsonlite' is required to write capability_matrix.json.", call. = FALSE)
}
jsonlite::write_json(json_obj, file.path(out_dir, "capability_matrix.json"),
	pretty = TRUE, auto_unbox = TRUE, dataframe = "rows")

cat(sprintf("capability_matrix: %d inference classes, %d design classes, %d design-level exclusion(s) -> %s/{capability_matrix.csv,design_matrix.csv,capability_matrix.json}\n",
	nrow(inf_df), nrow(des_df), nrow(excl_df), out_dir))
