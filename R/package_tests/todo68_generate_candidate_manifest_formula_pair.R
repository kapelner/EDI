repo <- "/home/kapelner/workspace/EDI"
pkgload::load_all(file.path(repo, "R/EDI"), compile = FALSE, quiet = TRUE)
source(file.path(repo, "R/package_tests/comprehensive_rand_ci_eligibility.R"))

script <- file.path(repo, "R/package_tests/comprehensive_tests.R")
source_ast <- parse(script, keep.source = FALSE)

assignment_rhs <- function(name) {
	for (expr in as.list(source_ast)) {
		if (is.call(expr) && length(expr) >= 3L && (identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) && identical(expr[[2L]], as.name(name))) {
			return(expr[[3L]])
		}
	}
	stop("missing source assignment: ", name)
}

tested_designs <- eval(assignment_rhs("TESTED_DESIGNS"), envir = baseenv())
runner_args <- character()
nrep <- eval(assignment_rhs("Nrep"), envir = list2env(list(args = runner_args), parent = baseenv()))
beta_env <- new.env(parent = baseenv())
source(file.path(repo, "R/package_tests/comprehensive_beta_filter.R"), local = beta_env)
beta_env$BETA_T_FILTER <- NA_real_
beta_expr <- assignment_rhs("beta_T_values")
beta_values <- eval(beta_expr, envir = beta_env)
additional_expr <- assignment_rhs("ADDITIONAL_TEST_SLOW_PATHS")
validate_literal <- function(node) {
	if (!is.call(node)) return(invisible(NULL))
	name <- as.character(node[[1L]])
	if (!(name %in% c("list", "c"))) stop("non-literal call in ADDITIONAL_TEST_SLOW_PATHS: ", name)
	parts <- as.list(node)
	for (i in seq_along(parts)[-1L]) {
		if (!identical(parts[i], list(quote(expr = )))) validate_literal(parts[[i]])
	}
	invisible(NULL)
}
validate_literal(additional_expr)
additional_slow_paths <- eval(additional_expr, envir = baseenv())
slow_path_rules <- EDI::EDI_COMPREHENSIVE_SLOW_PATHS

# Derive dataset/response presence from the source list declaration; do not
# source _dataset_load.R, which samples real rows even though only names are
# needed for this conditional roster.
dataset_source_ast <- parse(file.path(repo, "R/package_tests/_dataset_load.R"), keep.source = FALSE)
dataset_expr <- NULL
for (expr in as.list(dataset_source_ast)) {
	if (is.call(expr) && length(expr) >= 3L && (identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) && identical(expr[[2L]], as.name("datasets_and_response_models"))) {
		dataset_expr <- expr[[3L]]
		break
	}
}
if (is.null(dataset_expr) || !identical(dataset_expr[[1L]], as.name("list"))) stop("cannot locate source dataset roster")
dataset_parts <- as.list(dataset_expr)
dataset_arg_names <- names(dataset_parts)
finagle_fn <- NULL
for (expr in as.list(dataset_source_ast)) {
	if (is.call(expr) && length(expr) >= 3L && (identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) && identical(expr[[2L]], as.name("finagle_different_responses_from_continuous"))) {
		finagle_fn <- expr[[3L]]
		break
	}
}
find_named_arg <- function(call, name) {
	if (!is.call(call)) return(NULL)
	parts <- as.list(call)
	idx <- which(names(parts) == name)
	if (length(idx) != 1L) return(NULL)
	parts[[idx]]
}
finagle_result <- NULL
walk_calls <- function(node) {
	if (!is.call(node)) return(NULL)
	if (identical(node[[1L]], as.name("list")) && "continuous" %in% names(as.list(node))) return(node)
	parts <- as.list(node)
	for (i in seq_along(parts)[-1L]) {
		if (identical(parts[i], list(quote(expr = )))) next
		found <- walk_calls(parts[[i]])
		if (!is.null(found)) return(found)
	}
	NULL
}
finagle_result <- walk_calls(finagle_fn[[3L]])
finagle_responses <- names(as.list(finagle_result))[-1L]
dataset_response_pairs <- list()
for (i in seq_along(dataset_parts)[-1L]) {
	dataset_name <- dataset_arg_names[[i]]
	dataset_spec <- dataset_parts[[i]]
	y_expr <- find_named_arg(dataset_spec, "y_original")
	if (is.call(y_expr) && identical(y_expr[[1L]], as.name("list"))) {
		responses <- names(as.list(y_expr))[-1L]
	} else if (is.call(y_expr) && identical(y_expr[[1L]], as.name("finagle_different_responses_from_continuous"))) {
		responses <- finagle_responses
	} else {
		stop("unrecognized y_original source for dataset ", dataset_name)
	}
	dataset_response_pairs[[dataset_name]] <- responses
}

find_function <- function(expr, name) {
	if (!is.call(expr)) return(NULL)
	if ((identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) && identical(expr[[2L]], as.name(name))) return(expr[[3L]])
	parts <- as.list(expr)
	for (i in seq_along(parts)[-1L]) {
		if (identical(parts[i], list(quote(expr = )))) next
		found <- find_function(parts[[i]], name)
		if (!is.null(found)) return(found)
	}
	NULL
}
run_tests_fn <- NULL
for (expr in as.list(source_ast)) {
	run_tests_fn <- find_function(expr, "run_tests_for_response")
	if (!is.null(run_tests_fn)) break
}
find_assignment <- function(node, name) {
	if (!is.call(node)) return(NULL)
	if ((identical(node[[1L]], as.name("=")) || identical(node[[1L]], as.name("<-"))) && identical(node[[2L]], as.name(name))) return(node[[3L]])
	parts <- as.list(node)
	for (i in seq_along(parts)[-1L]) {
		if (identical(parts[i], list(quote(expr = )))) next
		found <- find_assignment(parts[[i]], name)
		if (!is.null(found)) return(found)
	}
	NULL
}
# 2026-10-23 (TODO-68 shape fix): classes the runner calls through
# run_inference_checks_both_paths() emit two inference labels per design
# formula, "<class> (model_formula=~1|~.) [design_formula=<F>]"; every other
# rostered class emits "<class> [design_formula=<F>]" with the design formula
# as its inference formula (run_inference_checks_impl()).
both_paths_classes <- character()
collect_both_paths <- function(node) {
	if (!is.call(node)) return(invisible(NULL))
	if (identical(node[[1L]], as.name("run_inference_checks_both_paths")) && length(node) >= 3L && is.character(node[[3L]])) {
		both_paths_classes <<- c(both_paths_classes, node[[3L]])
	}
	parts <- as.list(node)
	for (i in seq_along(parts)[-1L]) {
		if (identical(parts[i], list(quote(expr = )))) next
		collect_both_paths(parts[[i]])
	}
	invisible(NULL)
}
collect_both_paths(run_tests_fn[[3L]])
both_paths_classes <- unique(both_paths_classes)
is_kk_expr <- find_assignment(run_tests_fn[[3L]], "is_kk_design")
is_kk_design_for <- function(design_type) isTRUE(eval(is_kk_expr, envir = list2env(list(design_type = design_type), parent = baseenv())))
formulas_expr <- NULL
for (expr in as.list(source_ast)) {
	formulas_expr <- find_assignment(expr, "formulas_to_test")
	if (!is.null(formulas_expr)) break
}
formula_text <- vapply(eval(formulas_expr, envir = baseenv()), function(f) paste(deparse(f), collapse = " "), character(1))
design_switch <- NULL
find_switch <- function(node) {
	if (!is.call(node)) return(NULL)
	if (identical(node[[1L]], as.name("switch")) && identical(node[[2L]], as.name("design_type"))) return(node)
	parts <- as.list(node)
	for (i in seq_along(parts)[-1L]) {
		if (identical(parts[i], list(quote(expr = )))) next
		found <- find_switch(parts[[i]])
		if (!is.null(found)) return(found)
	}
	NULL
}
design_switch <- find_switch(run_tests_fn[[3L]])
switch_parts <- as.list(design_switch)
switch_names <- names(switch_parts)
design_class <- stats::setNames(character(length(tested_designs)), tested_designs)
for (design in tested_designs) {
	i <- match(design, switch_names)
	if (is.na(i)) stop("design missing from source switch: ", design)
	constructor <- switch_parts[[i]]
	head <- if (is.call(constructor)) constructor[[1L]] else NULL
	if (!is.call(head) || !identical(head[[1L]], as.name("$")) || !identical(head[[3L]], as.name("new"))) stop("unexpected source design constructor for ", design)
	design_class[[design]] <- as.character(head[[2L]])
}

rows <- list()
row_n <- 0L
for (dataset in names(dataset_response_pairs)) {
	for (response in dataset_response_pairs[[dataset]]) {
		for (design in tested_designs) {
			classes <- comprehensive_rand_ci_dispatch_roster(script, response, is_kk_design_for(design))
			for (formula in formula_text) {
				for (class_name in classes) {
					inference_formulas <- if (class_name %in% both_paths_classes) formula_text else formula
					for (inference_formula in inference_formulas) {
					functions <- comprehensive_rand_ci_class_attempts(
						class_name = class_name,
						response_type = response,
						design_class = design_class[[design]],
						model_formula = inference_formula,
						test_family_filter = NA_character_,
						slow_path_rules = slow_path_rules,
						additional_slow_paths = additional_slow_paths
					)
					if (!length(functions)) next
					row_n <- row_n + 1L
					keys <- expand.grid(rep = seq_len(nrep), beta_T = beta_values, function_run = functions, KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
					keys$dataset <- dataset
					keys$response_type <- response
					keys$design <- design
					keys$design_formula <- gsub("[[:space:]]", "", formula)
					keys$model_formula <- gsub("[[:space:]]", "", inference_formula)
					keys$inference_class_base <- class_name
					keys$inference_class <- paste0(class_name,
						if (class_name %in% both_paths_classes) paste0(" (model_formula=", keys$model_formula, ")") else "",
						" [design_formula=", formula, "]")
					keys$conditional_on_setup_success <- TRUE
					rows[[row_n]] <- keys[c("rep", "beta_T", "dataset", "response_type", "design", "design_formula", "model_formula", "inference_class_base", "inference_class", "function_run", "conditional_on_setup_success")]
					}
				}
			}
		}
	}
}
manifest <- if (length(rows)) do.call(rbind, rows) else data.frame()
rownames(manifest) <- NULL
key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
if (anyDuplicated(manifest[key_columns])) stop("duplicate conditional candidate key")
manifest$manifest_classification <- "candidate_attempts_conditional_on_case_setup_success"
# Output path: first command-line argument, else a dated file in tempdir().
# Never write into the checkout (release_v1_0_5.md TODO-68).
cli_args <- commandArgs(trailingOnly = TRUE)
out <- if (length(cli_args) >= 1L) cli_args[[1L]] else
	file.path(tempdir(), sprintf("edi_todo68_rand_ci_candidate_attempt_roster_formula_pair_%s.csv", format(Sys.Date(), "%Y%m%d")))
utils::write.csv(manifest, out, row.names = FALSE, na = "")
cat("manifest=", out, "\n", sep = "")
cat("rows=", nrow(manifest), "\n", sep = "")
cat("unique_keys=", nrow(unique(manifest[key_columns])), "\n", sep = "")
cat("datasets=", length(dataset_response_pairs), "\n", sep = "")
cat("dataset_response_pairs=", sum(lengths(dataset_response_pairs)), "\n", sep = "")
cat("designs=", paste(tested_designs, collapse = ","), "\n", sep = "")
cat("both_paths_classes=", length(both_paths_classes), "\n", sep = "")
print(table(manifest$function_run))
print(table(paste(manifest$design_formula, manifest$model_formula, sep = "/")))
