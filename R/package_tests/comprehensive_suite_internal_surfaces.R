#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/comprehensive_suite_internal_surfaces.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

paths = list(
	audit = repo_path("package_tests", "comprehensive_suite_baseline_audit.csv"),
	registry = repo_path("package_tests", "comprehensive_suite_registry.csv"),
	inventory = repo_path("package_tests", "public_api_inventory.csv"),
	default_output = repo_path("package_tests", "comprehensive_suite_internal_surfaces.csv")
)

surface_columns = c(
	"internal_symbol", "normalized_symbol", "surface_category", "coverage_scope",
	"source_runner", "required_coverage", "runtime_tier", "priority_score",
	"test_fan_in", "occurrence_count", "source_reference_count",
	"numerical_risk_score", "argument_complexity_score", "historical_failure_score",
	"direct_testthat_files", "registry_targets", "source_files", "public_entrypoints",
	"public_link_status", "classification_reason", "rationale"
)

read_required_csv = function(path, label) {
	if (!file.exists(path)) stop("Missing ", label, ": ", path, call. = FALSE)
	read.csv(path, stringsAsFactors = FALSE, na.strings = character())
}

clean_chr = function(x) {
	x = as.character(x %||% "")
	x[is.na(x)] = ""
	x
}

split_semicolon = function(x) {
	parts = unlist(strsplit(clean_chr(x), ";", fixed = TRUE), use.names = FALSE)
	parts = trimws(parts)
	parts[nzchar(parts)]
}

collapse_unique = function(x) {
	x = sort(unique(clean_chr(x)[nzchar(clean_chr(x))]))
	paste(x, collapse = ";")
}

normalize_internal_symbol = function(symbol) {
	symbol = trimws(clean_chr(symbol))
	symbol = sub("^EDI:::", "", symbol)
	symbol = sub("^getFromNamespace\\([\"']([^\"']+)[\"'].*,.*$", "\\1", symbol)
	symbol
}

surface_category_for = function(symbol) {
	s = tolower(symbol)
	if (grepl("check|assert|valid|validate|normalize|canonical|sanitize|clamp|coerce|ensure", s)) return("validator_or_canonicalizer")
	if (grepl("bootstrap|resample|sample|permutation|rand|jackknife|subsampling|m_out_of_n", s)) return("shared_resampling_helper")
	if (grepl("model_matrix|design_matrix|gcomp|qr|drop_linearly|matrix_rank|cache|data|covariate|workspace", s)) return("model_matrix_or_data_shaping")
	if (grepl("(_cpp$|^fast_|score|hessian|gradient|neg_loglik|loglik|likelihood|optim|fit|regression|fisher|variance|var_|se$)", s)) return("numerical_kernel")
	if (grepl("capability|registry|component|metadata|manifest|hierarchy|method_family", s)) return("registry_or_capability")
	if (grepl("assignment|draw_|redraw|optimal|blocking|match|atkinson|pocock|urn|efron", s)) return("design_assignment_helper")
	"other_internal"
}

numerical_risk_for = function(symbol, category) {
	score = switch(
		category,
		numerical_kernel = 3L,
		shared_resampling_helper = 2L,
		model_matrix_or_data_shaping = 2L,
		design_assignment_helper = 1L,
		validator_or_canonicalizer = 1L,
		registry_or_capability = 1L,
		0L
	)
	if (grepl("cpp|hessian|score|gradient|lik|optim|fast_|var|se", symbol, ignore.case = TRUE)) score = score + 1L
	as.integer(min(score, 4L))
}

historical_failure_for = function(files) {
	text = paste(files, collapse = " ")
	score = 0L
	if (grepl("problem|failure|hardening|regression|bug|fix|blocked|unstable|edge", text, ignore.case = TRUE)) score = score + 2L
	if (grepl("permutation|workspace|determinism|missing|singular|overflow|parallel|cache", text, ignore.case = TRUE)) score = score + 1L
	as.integer(min(score, 3L))
}

formal_count_for = function(symbol) {
	if (!requireNamespace("EDI", quietly = TRUE)) return(0L)
	obj = tryCatch(getFromNamespace(symbol, "EDI"), error = function(e) NULL)
	if (!is.function(obj)) return(0L)
	formals_obj = tryCatch(formals(obj), error = function(e) NULL)
	if (is.null(formals_obj)) return(0L)
	as.integer(length(formals_obj))
}

source_text_index = function(source_dir) {
	files = list.files(source_dir, pattern = "\\.R$", full.names = TRUE)
	files = sort(files)
	text = lapply(files, function(path) paste(readLines(path, warn = FALSE), collapse = "\n"))
	names(text) = files
	text
}

source_files_for = function(symbol, source_index) {
	if (!length(source_index)) return(character())
	hits = vapply(source_index, function(txt) grepl(paste0("\\b", gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", symbol), "\\b"), txt, perl = TRUE), logical(1))
	names(source_index)[hits]
}

inventory_targets_for_source_files = function(files, inventory) {
	if (!nrow(inventory) || !"source_files" %in% names(inventory) || !length(files)) return(character())
	file_basenames = basename(files)
	has_file = vapply(clean_chr(inventory$source_files), function(src) {
		parts = split_semicolon(src)
		any(basename(parts) %in% file_basenames)
	}, logical(1))
	target = ifelse(nzchar(clean_chr(inventory$method_name)), paste(inventory$export_name, inventory$method_name, sep = "::"), inventory$export_name)
	target[has_file & nzchar(target)]
}

expand_internal_audit = function(audit) {
	internal = audit[audit$row_type == "testthat_internal", , drop = FALSE]
	if (!nrow(internal)) return(data.frame())
	rows = list()
	for (i in seq_len(nrow(internal))) {
		symbols = split_semicolon(internal$internal_symbols[i])
		for (symbol in symbols) {
			rows[[length(rows) + 1L]] = data.frame(
				internal_symbol = symbol,
				normalized_symbol = normalize_internal_symbol(symbol),
				testthat_file = clean_chr(internal$testthat_file[i]),
				registry_target = clean_chr(internal$target[i]),
				classification_reason = clean_chr(internal$classification_reason[i]),
				stringsAsFactors = FALSE
			)
		}
	}
	if (!length(rows)) return(data.frame())
	do.call(rbind, rows)
}

rationale_for = function(category, fan_in, source_refs, numerical_risk, historical_failure) {
	parts = c(
		switch(
			category,
			validator_or_canonicalizer = "validator/canonicalizer shared across public behavior",
			shared_resampling_helper = "shared resampling helper whose failures can affect multiple inference methods",
			model_matrix_or_data_shaping = "model-matrix/data-shaping helper where public failures are hard to localize",
			numerical_kernel = "numerical kernel with exported/public wrappers",
			registry_or_capability = "registry/capability helper used to route public workflows",
			design_assignment_helper = "design-assignment helper with workflow-visible consequences",
			"namespace-internal helper with focused direct assertions"
		),
		paste0("test fan-in=", fan_in),
		paste0("source refs=", source_refs)
	)
	if (numerical_risk >= 3L) parts = c(parts, "high numerical risk")
	if (historical_failure > 0L) parts = c(parts, "historical/edge-case signal from focused tests")
	paste(parts, collapse = "; ")
}

build_internal_surfaces = function() {
	audit = read_required_csv(paths$audit, "comprehensive_suite_baseline_audit")
	registry = read_required_csv(paths$registry, "comprehensive_suite_registry")
	inventory = if (file.exists(paths$inventory)) read.csv(paths$inventory, stringsAsFactors = FALSE, na.strings = character()) else data.frame()

	expanded = expand_internal_audit(audit)
	if (!nrow(expanded)) return(data.frame(matrix(character(), nrow = 0L, ncol = length(surface_columns), dimnames = list(NULL, surface_columns))))

	internal_registry = registry[registry$coverage_scope == "internal_safety_net", , drop = FALSE]
	missing_registry = setdiff(unique(expanded$registry_target), unique(internal_registry$target))
	if (length(missing_registry)) {
		stop("Internal audit rows missing registry rows: ", paste(missing_registry, collapse = ", "), call. = FALSE)
	}

	source_index = source_text_index(repo_path("EDI", "R"))
	symbols = sort(unique(expanded$normalized_symbol))
	rows = lapply(symbols, function(symbol) {
		rows_for_symbol = expanded[expanded$normalized_symbol == symbol, , drop = FALSE]
		files = sort(unique(rows_for_symbol$testthat_file))
		registry_targets = sort(unique(rows_for_symbol$registry_target))
		source_files = source_files_for(symbol, source_index)
		category = surface_category_for(symbol)
		fan_in = length(files)
		occurrences = nrow(rows_for_symbol)
		source_refs = length(source_files)
		numerical_risk = numerical_risk_for(symbol, category)
		arg_complexity = min(formal_count_for(symbol), 8L)
		historical_failure = historical_failure_for(files)
		priority = fan_in * 3L + occurrences + source_refs * 2L + numerical_risk * 3L + arg_complexity + historical_failure * 2L
		public_entrypoints = inventory_targets_for_source_files(source_files, inventory)
		data.frame(
			internal_symbol = collapse_unique(rows_for_symbol$internal_symbol),
			normalized_symbol = symbol,
			surface_category = category,
			coverage_scope = "internal_safety_net",
			source_runner = "internal_safety_net",
			required_coverage = "internal_safety_net",
			runtime_tier = "ci",
			priority_score = as.integer(priority),
			test_fan_in = as.integer(fan_in),
			occurrence_count = as.integer(occurrences),
			source_reference_count = as.integer(source_refs),
			numerical_risk_score = as.integer(numerical_risk),
			argument_complexity_score = as.integer(arg_complexity),
			historical_failure_score = as.integer(historical_failure),
			direct_testthat_files = collapse_unique(files),
			registry_targets = collapse_unique(registry_targets),
			source_files = collapse_unique(file.path("EDI", "R", basename(source_files))),
			public_entrypoints = collapse_unique(public_entrypoints),
			public_link_status = if (length(source_files)) "linked_to_source_files" else "not_statically_linked",
			classification_reason = collapse_unique(rows_for_symbol$classification_reason),
			rationale = rationale_for(category, fan_in, source_refs, numerical_risk, historical_failure),
			stringsAsFactors = FALSE
		)
	})
	surfaces = do.call(rbind, rows)
	surfaces = surfaces[order(-surfaces$priority_score, surfaces$surface_category, surfaces$normalized_symbol), surface_columns, drop = FALSE]
	row.names(surfaces) = NULL
	validate_internal_surfaces(surfaces, expanded, internal_registry)
	surfaces
}

validate_internal_surfaces = function(surfaces, expanded, internal_registry) {
	if (!nrow(surfaces)) stop("Internal surface registry has no rows.", call. = FALSE)
	if (any(!nzchar(surfaces$normalized_symbol))) stop("Internal surface rows have blank normalized symbols.", call. = FALSE)
	if (any(surfaces$coverage_scope != "internal_safety_net")) stop("Internal surfaces must use coverage_scope=internal_safety_net.", call. = FALSE)
	if (any(surfaces$source_runner != "internal_safety_net")) stop("Internal surfaces must use source_runner=internal_safety_net.", call. = FALSE)
	if (any(!nzchar(surfaces$rationale))) stop("Internal surface rows have blank rationale.", call. = FALSE)
	if (any(!nzchar(surfaces$classification_reason))) stop("Internal surface rows have blank classification_reason.", call. = FALSE)
	missing_symbols = setdiff(unique(expanded$normalized_symbol), surfaces$normalized_symbol)
	if (length(missing_symbols)) stop("Internal symbols missing surface rows: ", paste(missing_symbols, collapse = ", "), call. = FALSE)
	missing_registry = setdiff(unique(expanded$registry_target), unique(internal_registry$target))
	if (length(missing_registry)) stop("Internal tests missing registry rows: ", paste(missing_registry, collapse = ", "), call. = FALSE)
	covered_registry = unique(unlist(strsplit(surfaces$registry_targets, ";", fixed = TRUE), use.names = FALSE))
	missing_surface_rationale = setdiff(unique(expanded$registry_target), covered_registry)
	if (length(missing_surface_rationale)) stop("Internal tests missing rationale-bearing surface rows: ", paste(missing_surface_rationale, collapse = ", "), call. = FALSE)
	invisible(TRUE)
}

write_internal_surfaces = function(surfaces = build_internal_surfaces(), path = paths$default_output) {
	write.csv(surfaces, path, row.names = FALSE)
	invisible(surfaces)
}

args = commandArgs(trailingOnly = TRUE)
output_path = args[1] %||% paths$default_output
surfaces = write_internal_surfaces(path = output_path)
message("wrote ", nrow(surfaces), " internal safety-net surface rows to ", output_path)
