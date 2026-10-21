# Static expected-attempt inventory for the comprehensive suite's plain
# proportion randomization p-value family. Inputs are case metadata and
# precomputed source/registry eligibility only; this helper never constructs
# a design or inference object and never calls an inference method.

comprehensive_rand_pvalue_attempted_functions <- function(
	response_type,
	supports_randomization_test,
	test_family_filter = NA_character_,
	skip_slow = FALSE,
	skip_rand = FALSE,
	skip_rand_pval = FALSE,
	skip_rand_slow = FALSE,
	skip_rand_delta_pval_slow = FALSE
) {
	assert_scalar_bool <- function(value, name) {
		if (!is.logical(value) || length(value) != 1L || is.na(value)) {
			stop(name, " must be one non-missing logical value", call. = FALSE)
		}
	}
	if (!is.character(response_type) || length(response_type) != 1L ||
		is.na(response_type) || !nzchar(response_type)) {
		stop("response_type must be one nonempty value", call. = FALSE)
	}
	if (!identical(response_type, "proportion")) {
		stop("this manifest enumerates proportion rand p-value rows only", call. = FALSE)
	}
	if (!is.character(test_family_filter) || length(test_family_filter) != 1L) {
		stop("test_family_filter must be one character value or NA", call. = FALSE)
	}
	assert_scalar_bool(supports_randomization_test, "supports_randomization_test")
	assert_scalar_bool(skip_slow, "skip_slow")
	assert_scalar_bool(skip_rand, "skip_rand")
	assert_scalar_bool(skip_rand_pval, "skip_rand_pval")
	assert_scalar_bool(skip_rand_slow, "skip_rand_slow")
	assert_scalar_bool(skip_rand_delta_pval_slow, "skip_rand_delta_pval_slow")

	# Mirrors the enclosing runner guard at comprehensive_tests.R:3060, followed
	# by its two safe_call labels at lines 3067 and 3076. For proportion,
	# supports_incidence_rand_pval is unconditionally TRUE in that runner.
	run_plain_rand_pval <- isTRUE(supports_randomization_test) &&
		(is.na(test_family_filter) || identical(test_family_filter, "rand")) &&
		!isTRUE(skip_slow) && !isTRUE(skip_rand) && !isTRUE(skip_rand_pval) &&
		!isTRUE(skip_rand_slow)
	if (!run_plain_rand_pval) return(character())

	functions <- "compute_rand_two_sided_pval"
	if (!isTRUE(skip_rand_delta_pval_slow)) {
		functions <- c(functions, "compute_rand_two_sided_pval(delta=0.5)")
	}
	functions
}

comprehensive_rand_pvalue_source_guard <- function(script_path) {
	if (!is.character(script_path) || length(script_path) != 1L || is.na(script_path) || !file.exists(script_path)) {
		stop("script_path must name an existing comprehensive_tests.R", call. = FALSE)
	}
	parsed <- parse(script_path, keep.source = FALSE)
	find_assignment <- function(node, name) {
		if (!is.call(node)) return(NULL)
		if (identical(node[[1L]], as.name("function"))) return(NULL)
		if ((identical(node[[1L]], as.name("<-")) || identical(node[[1L]], as.name("="))) &&
			length(node) >= 3L && identical(node[[2L]], as.name(name))) return(node[[3L]])
		children <- as.list(node)[-1L]
		for (child_index in seq_along(children)) {
			if (identical(children[child_index], list(quote(expr = )))) next
			found <- find_assignment(children[[child_index]], name)
			if (!is.null(found)) return(found)
		}
		NULL
	}
	impl <- NULL
	for (expr in as.list(parsed)) {
		impl <- find_assignment(expr, "run_inference_checks_impl")
		if (!is.null(impl)) break
	}
	if (is.null(impl) || !is.call(impl) || !identical(impl[[1L]], as.name("function"))) {
		stop("could not find run_inference_checks_impl() in parsed source", call. = FALSE)
	}
	condition_atoms <- function(expr) {
		if (is.call(expr) && identical(expr[[1L]], as.name("&&"))) {
			return(c(condition_atoms(expr[[2L]]), condition_atoms(expr[[3L]])))
		}
		paste(deparse(expr, width.cutoff = 500L), collapse = " ")
	}
	walk <- function(node, fn) {
		if (!is.call(node)) return(invisible(NULL))
		fn(node)
		for (child in as.list(node)[-1L]) walk(child, fn)
		invisible(NULL)
	}
	count_safe_call <- function(node, label) {
		count <- 0L
		walk(node, function(expr) {
			if (identical(expr[[1L]], as.name("safe_call")) && length(expr) >= 2L &&
				is.character(expr[[2L]]) && identical(expr[[2L]], label)) count <<- count + 1L
		})
		count
	}
	condition <- c(
		"supports_randomization_test",
		"should_run_test_family(\"rand\")",
		"!skip_slow",
		"!skip_rand",
		"!skip_regular_rand_pval",
		"!skip_rand_slow",
		"response_type %in% c(\"continuous\", \"survival\", \"proportion\", \"incidence\", \"count\", \"ordinal\")"
	)
	branches <- list()
	walk(impl[[3L]], function(expr) {
		if (!identical(expr[[1L]], as.name("if")) || length(expr) < 3L) return(invisible(NULL))
		if (!setequal(condition_atoms(expr[[2L]]), condition) || length(condition_atoms(expr[[2L]])) != length(condition)) return(invisible(NULL))
		if (count_safe_call(expr[[3L]], "compute_rand_two_sided_pval") != 1L ||
			count_safe_call(expr[[3L]], "compute_rand_two_sided_pval(delta=0.5)") != 1L) return(invisible(NULL))
		delta_guards <- list()
		walk(expr[[3L]], function(inner) {
			if (identical(inner[[1L]], as.name("if")) && length(inner) >= 3L &&
				identical(paste(deparse(inner[[2L]], width.cutoff = 500L), collapse = " "), "!skip_rand_delta_pval_slow") &&
				count_safe_call(inner[[3L]], "compute_rand_two_sided_pval(delta=0.5)") == 1L) {
				delta_guards[[length(delta_guards) + 1L]] <<- inner
			}
		})
		if (length(delta_guards) == 1L) branches[[length(branches) + 1L]] <<- expr
	})
	if (length(branches) != 1L) {
		stop("unrecognized plain-rand p-value source guards or labels; refusing expected-key manifest", call. = FALSE)
	}
	invisible(TRUE)
}

comprehensive_rand_pvalue_attempt_manifest <- function(cases, script_path) {
	comprehensive_rand_pvalue_source_guard(script_path)
	if (!is.data.frame(cases)) stop("cases must be a data.frame", call. = FALSE)
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	eligibility_columns <- c(
		"supports_randomization_test", "test_family_filter", "skip_slow", "skip_rand",
		"skip_rand_pval", "skip_rand_slow", "skip_rand_delta_pval_slow"
	)
	missing <- setdiff(c(key_columns, eligibility_columns), names(cases))
	if (length(missing)) {
		stop("missing case-manifest field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	}
	if (!is.numeric(cases$rep) || is.complex(cases$rep) ||
			!is.numeric(cases$beta_T) || is.complex(cases$beta_T)) {
		stop("rep and beta_T must be numeric key columns", call. = FALSE)
	}
	if (nrow(cases) && (anyNA(cases[key_columns]) || any(!is.finite(cases$rep)) ||
			any(cases$rep < 1) || any(cases$rep != floor(cases$rep)) ||
			any(!is.finite(cases$beta_T)))) {
		stop("case-manifest keys require non-missing values, positive finite integer reps, and finite beta_T", call. = FALSE)
	}
	for (column in c("dataset", "response_type", "design", "inference_class")) {
		if (!is.character(cases[[column]])) {
			stop(column, " must be a character key column", call. = FALSE)
		}
	}
	if (nrow(cases) && any(cases$response_type != "proportion" | is.na(cases$response_type))) {
		stop("all cases must have response_type = 'proportion'", call. = FALSE)
	}
	if (anyDuplicated(cases[key_columns])) {
		stop("duplicate source case key in case manifest", call. = FALSE)
	}
	if (!is.character(cases$test_family_filter) || length(cases$test_family_filter) != nrow(cases)) {
		stop("test_family_filter must be a character column", call. = FALSE)
	}
	allowed_filters <- c(
		"estimate", "exact", "asymp", "wald", "score", "lik_ratio", "gradient",
		"bootstrap", "bayesian_bootstrap", "parametric_bootstrap", "bartlett",
		"jackknife", "rand", "rand_custom", "rand_bootstrap"
	)
	for (i in seq_len(nrow(cases))) {
		filter <- cases$test_family_filter[i]
		if (length(filter) != 1L || (!is.na(filter) && !filter %in% allowed_filters)) {
			stop("test_family_filter must be one supported family or NA", call. = FALSE)
		}
		for (flag in eligibility_columns[!eligibility_columns %in% c("test_family_filter")]) {
			value <- cases[[flag]][i]
			if (!is.logical(value) || length(value) != 1L || is.na(value)) {
				stop(flag, " must be one non-missing logical value", call. = FALSE)
			}
		}
	}
	rows <- list()
	for (i in seq_len(nrow(cases))) {
		context <- as.list(cases[i, eligibility_columns, drop = FALSE])
		functions <- do.call(comprehensive_rand_pvalue_attempted_functions, c(
			list(response_type = as.character(cases$response_type[i])), context
		))
		if (!length(functions)) next
		base <- cases[rep(i, length(functions)), key_columns, drop = FALSE]
		base$function_run <- functions
		rows[[length(rows) + 1L]] <- base
	}
	if (!length(rows)) {
		return(data.frame(
			rep = integer(), beta_T = numeric(), dataset = character(),
			response_type = character(), design = character(), inference_class = character(),
			function_run = character(), stringsAsFactors = FALSE
		))
	}
	manifest <- do.call(rbind, rows)
	rownames(manifest) <- NULL
	if (anyDuplicated(manifest[c(key_columns, "function_run")])) {
		stop("duplicate attempted result key in case manifest", call. = FALSE)
	}
	manifest
}

# Source-only candidate-key generator for the comprehensive proportion G-comp
# rand p-value + ordinary rand-CI slice. It parses the runner's literal grid
# and dispatch, then projects through the pure eligibility helpers above and
# comprehensive_rand_ci_attempted_functions(). It never sources the runner,
# constructs designs/inference objects, or fits models. Rows are conditional
# candidates: a runner setup failure can prevent any call in that case from
# being reached.
comprehensive_proportion_rand_candidate_manifest <- function(
	Nrep = 40L,
	runner_path,
	dataset_source_path,
	force_run_slow_paths = FALSE,
	test_family_filter = "rand"
) {
	if (!is.numeric(Nrep) || length(Nrep) != 1L || is.na(Nrep) || !is.finite(Nrep) ||
		Nrep < 1 || Nrep != floor(Nrep)) stop("Nrep must be one positive integer", call. = FALSE)
	if (!is.logical(force_run_slow_paths) || length(force_run_slow_paths) != 1L || is.na(force_run_slow_paths)) {
		stop("force_run_slow_paths must be one non-missing logical value", call. = FALSE)
	}
	if (!is.character(test_family_filter) || length(test_family_filter) != 1L ||
		(!is.na(test_family_filter) && !test_family_filter %in% c("rand", "NA"))) {
		stop("test_family_filter must be 'rand', 'NA', or NA_character_", call. = FALSE)
	}
	if (!file.exists(runner_path) || !file.exists(dataset_source_path)) {
		stop("runner_path and dataset_source_path must exist", call. = FALSE)
	}
	parsed <- parse(runner_path, keep.source = FALSE)
	find_assignment <- function(node, name) {
		if (!is.call(node) || identical(node[[1L]], as.name("function"))) return(NULL)
		if ((identical(node[[1L]], as.name("<-")) || identical(node[[1L]], as.name("="))) &&
			length(node) >= 3L && identical(node[[2L]], as.name(name))) return(node[[3L]])
		children <- as.list(node)[-1L]
		for (child_index in seq_along(children)) {
			if (identical(children[child_index], list(quote(expr = )))) next
			found <- find_assignment(children[[child_index]], name)
			if (!is.null(found)) return(found)
		}
		NULL
	}
	assignment <- function(name) {
		found <- lapply(as.list(parsed), find_assignment, name = name)
		found <- Filter(Negate(is.null), found)
		if (length(found) != 1L) stop("expected one runner assignment for ", name, call. = FALSE)
		found[[1L]]
	}
	source_assignment <- function(path, name) {
		exprs <- parse(path, keep.source = FALSE)
		matches <- Filter(function(expr) is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("<-")) || identical(expr[[1L]], as.name("="))) &&
			identical(expr[[2L]], as.name(name)), as.list(exprs))
		if (length(matches) != 1L) stop("expected one source assignment for ", name, call. = FALSE)
		matches[[1L]][[3L]]
	}
	contains_named_field <- function(expr, field) {
		if (!is.call(expr)) return(FALSE)
		args <- as.list(expr)[-1L]
		arg_names <- names(args)
		if (identical(expr[[1L]], as.name("list")) && !is.null(arg_names) && field %in% arg_names) return(TRUE)
		any(vapply(args, contains_named_field, logical(1), field = field))
	}
	named_call_argument <- function(expr, name) {
		if (!is.call(expr)) return(NULL)
		args <- as.list(expr)[-1L]
		arg_names <- names(args)
		if (is.null(arg_names) || !name %in% arg_names) return(NULL)
		args[[match(name, arg_names)]]
	}
	proportion_dataset_roster <- function(path) {
		dataset_expr <- source_assignment(path, "datasets_and_response_models")
		transform_expr <- source_assignment(path, "finagle_different_responses_from_continuous")
		if (!contains_named_field(transform_expr, "proportion")) {
			stop("source response transformer no longer declares proportion", call. = FALSE)
		}
		if (!is.call(dataset_expr) || !identical(dataset_expr[[1L]], as.name("list"))) {
			stop("datasets_and_response_models must remain a literal list", call. = FALSE)
		}
		entries <- as.list(dataset_expr)[-1L]
		y_exprs <- lapply(entries, named_call_argument, name = "y_original")
		has_proportion <- vapply(y_exprs, function(y_expr) {
			if (!is.call(y_expr)) return(FALSE)
			if (identical(y_expr[[1L]], as.name("finagle_different_responses_from_continuous"))) return(TRUE)
			identical(y_expr[[1L]], as.name("list")) && "proportion" %in% names(as.list(y_expr)[-1L])
		}, logical(1))
		datasets <- names(entries)[has_proportion]
		if (is.null(datasets) || anyNA(datasets) || any(!nzchar(datasets))) {
			stop("proportion dataset entries must be named", call. = FALSE)
		}
		datasets
	}
	runner_design_class_map <- function(path) {
		runner_exprs <- parse(path, keep.source = FALSE)
		function_expr <- NULL
		for (expr in as.list(runner_exprs)) {
			function_expr <- find_assignment(expr, "run_tests_for_response")
			if (!is.null(function_expr)) break
		}
		if (is.null(function_expr) || !is.call(function_expr) || !identical(function_expr[[1L]], as.name("function"))) {
			stop("missing run_tests_for_response()", call. = FALSE)
		}
		find_switch <- function(expr) {
			if (!is.call(expr) || identical(expr[[1L]], as.name("function"))) return(NULL)
			if (identical(expr[[1L]], as.name("switch")) && length(expr) >= 2L && identical(expr[[2L]], as.name("design_type"))) return(expr)
			children <- as.list(expr)[-1L]
			for (i in seq_along(children)) {
				if (identical(children[i], list(quote(expr = )))) next
				found <- find_switch(children[[i]])
				if (!is.null(found)) return(found)
			}
			NULL
		}
		design_switch <- find_switch(function_expr[[3L]])
		if (is.null(design_switch)) stop("missing design_type switch", call. = FALSE)
		switch_args <- as.list(design_switch)[-c(1L, 2L)]
		classes <- vapply(switch_args, function(expr) {
			head <- if (is.call(expr)) expr[[1L]] else NULL
			if (is.call(head) && identical(head[[1L]], as.name("$")) && identical(head[[3L]], as.name("new"))) {
				return(as.character(head[[2L]]))
			}
			NA_character_
		}, character(1))
		stats::setNames(classes, names(switch_args))
	}
	literal_character_vector <- function(expr, name) {
		if (!is.call(expr) || !identical(expr[[1L]], as.name("c"))) stop(name, " must remain a literal c() vector", call. = FALSE)
		values <- as.list(expr)[-1L]
		if (!length(values) || any(!vapply(values, is.character, logical(1)))) {
			stop(name, " must contain only literal strings", call. = FALSE)
		}
		unname(vapply(values, `[[`, character(1), 1L))
	}
	literal_numeric_vector <- function(expr, name) {
		if (!is.call(expr) || !identical(expr[[1L]], as.name("c"))) stop(name, " must remain a literal c() vector", call. = FALSE)
		values <- as.list(expr)[-1L]
		if (!length(values) || any(!vapply(values, is.numeric, logical(1)))) {
			stop(name, " must contain only literal numbers", call. = FALSE)
		}
		unname(vapply(values, as.numeric, numeric(1)))
	}
	designs <- literal_character_vector(assignment("TESTED_DESIGNS"), "TESTED_DESIGNS")
	beta_expr <- assignment("beta_T_values")
	if (!is.call(beta_expr) || !identical(beta_expr[[1L]], as.name("resolve_comprehensive_beta_values")) ||
		length(beta_expr) < 2L) stop("beta_T_values no longer uses the guarded default resolver", call. = FALSE)
	betas <- literal_numeric_vector(beta_expr[[2L]], "beta_T_values default")
	formula_expr <- assignment("formulas_to_test")
	if (!is.call(formula_expr) || !identical(formula_expr[[1L]], as.name("list"))) {
		stop("formulas_to_test must remain a literal formula list", call. = FALSE)
	}
	formula_nodes <- as.list(formula_expr)[-1L]
	if (!length(formula_nodes) || any(!vapply(formula_nodes, function(x) is.call(x) && identical(x[[1L]], as.name("~")), logical(1)))) {
		stop("formulas_to_test must contain only literal formulas", call. = FALSE)
	}
	formulas <- vapply(formula_nodes, function(x) paste(deparse(x), collapse = " "), character(1))
	if (!identical(formulas, c("~1", "~."))) stop("unexpected design-formula roster", call. = FALSE)
	if (!"InferencePropGCompMeanDiff" %in% comprehensive_rand_ci_dispatch_roster(runner_path, "proportion", FALSE) ||
		"InferencePropGCompMeanDiff" %in% comprehensive_rand_ci_dispatch_roster(runner_path, "proportion", TRUE)) {
		stop("proportion G-comp dispatch changed; refusing candidate-key generation", call. = FALSE)
	}
	# The target is present only on non-KK designs. Keep the source TESTED_DESIGNS
	# roster intact, then use its source dispatch branch to exclude KK designs.
	design_classes <- runner_design_class_map(runner_path)
	if (!all(designs %in% names(design_classes))) stop("TESTED_DESIGNS and dispatch labels differ", call. = FALSE)
	run_tests <- assignment("run_tests_for_response")
	kk_expr <- find_assignment(run_tests[[3L]], "is_kk_design")
	if (!is.call(kk_expr) || !identical(kk_expr[[1L]], as.name("%in%")) ||
		!identical(kk_expr[[2L]], as.name("design_type")) ||
		!identical(literal_character_vector(kk_expr[[3L]], "is_kk_design classes"),
			c("KK21", "KK21stepwise", "KK14", "FixedBinaryMatch"))) {
		stop("is_kk_design source rule changed; refusing design filtering", call. = FALSE)
	}
	slow_paths_expr <- assignment("ADDITIONAL_TEST_SLOW_PATHS")
	if (!is.call(slow_paths_expr) || !identical(slow_paths_expr[[1L]], as.name("list"))) {
		stop("ADDITIONAL_TEST_SLOW_PATHS must remain a literal list", call. = FALSE)
	}
	slow_path_args <- as.list(slow_paths_expr)[-1L]
	slow_path_names <- names(slow_path_args)
	class_in_slow_path <- function(category) {
		if (is.null(slow_path_names) || !category %in% slow_path_names) return(FALSE)
		literal_character_vector(slow_path_args[[match(category, slow_path_names)]],
			paste0("ADDITIONAL_TEST_SLOW_PATHS$", category))
	}
	if (!all(vapply(c("rand", "rand_pval", "rand_ci"), function(category) {
		"InferencePropGCompMeanDiff" %in% class_in_slow_path(category)
	}, logical(1)))) {
		stop("default proportion G-comp rand skip gates changed", call. = FALSE)
	}
	designs <- designs[!designs %in% c("KK21", "KK21stepwise", "KK14", "FixedBinaryMatch")]
	if (!length(designs) || !all(vapply(designs, function(x) !is.na(design_classes[[x]]), logical(1)))) {
		stop("no source-rostered non-KK design remains", call. = FALSE)
	}
	datasets <- proportion_dataset_roster(dataset_source_path)
	if (!length(datasets)) stop("source has no proportion datasets", call. = FALSE)

	# The inference helper is source-guarded separately from the outer formula
	# loop. This is the exact pair of labels it emits for each outer design
	# formula; both are retained in the result key.
	both_paths <- assignment("run_inference_checks_both_paths")
	both_paths_text <- paste(deparse(both_paths), collapse = " ")
	model_formulas <- c("~1", "~.")
	if (!grepl("class_name, \" (model_formula=~1)\"", both_paths_text, fixed = TRUE) ||
		!grepl("class_name, \" (model_formula=~.)\"", both_paths_text, fixed = TRUE)) {
		stop("run_inference_checks_both_paths labels changed", call. = FALSE)
	}
	if (identical(test_family_filter, "NA")) test_family_filter <- NA_character_
	grid <- expand.grid(
		rep = seq_len(as.integer(Nrep)), beta_T = betas, dataset = datasets,
		response_type = "proportion", design = designs,
		design_formula = formulas, model_formula = model_formulas,
		KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
	)
	grid$inference_class <- paste0(
		"InferencePropGCompMeanDiff (model_formula=", grid$model_formula,
		") [design_formula=", grid$design_formula, "]"
	)
	# In the ordinary runner mode, all three plain-rand operations are excluded
	# by the harness slow-path registries for this class. Explicit force mode
	# removes those skips; the manifest is still conditional on setup success.
	if (!force_run_slow_paths) {
		out <- data.frame(
			rep = integer(), beta_T = numeric(), dataset = character(), response_type = character(),
			design = character(), inference_class = character(), function_run = character(), id = character(),
			eligibility_scope = character(), stringsAsFactors = FALSE
		)
		attr(out, "candidate_context_count") <- nrow(grid)
		attr(out, "excluded_by_default_slow_path") <- TRUE
		return(out)
	}

	case_grid <- grid[c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")]
	case_grid$supports_randomization_test <- TRUE
	case_grid$test_family_filter <- test_family_filter
	case_grid$skip_slow <- FALSE
	case_grid$skip_rand <- FALSE
	case_grid$skip_rand_pval <- FALSE
	case_grid$skip_rand_slow <- FALSE
	case_grid$skip_rand_delta_pval_slow <- FALSE
	pvalue <- comprehensive_rand_pvalue_attempt_manifest(case_grid, runner_path)
	ci_cases <- case_grid
	ci_cases$supports_randomization_ci <- TRUE
	ci_cases$supports_randomization_bootstrap <- FALSE
	ci_cases$skip_ci_rand <- FALSE
	ci_cases$skip_rand_ci_slow <- FALSE
	ci_cases$skip_brt_ci <- FALSE
	ci_cases$skip_brt_ci_smoothed_slow <- FALSE
	ci_cases$skip_brt_ci_typed_slow <- FALSE
	ci_cases$test_compute_confidence_interval_rand <- TRUE
	ci <- comprehensive_rand_ci_attempt_manifest(ci_cases)
	columns <- c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	manifest <- rbind(pvalue[columns], ci[columns])
	rownames(manifest) <- NULL
	if (anyDuplicated(manifest[columns])) stop("duplicate candidate attempt key", call. = FALSE)
	# Evaluate only the runner's two pure key functions in a base-only sandbox;
	# never source or execute the comprehensive runner itself.
	key_env <- new.env(parent = baseenv())
	for (name in c("serialize_beta_T", "build_result_key")) {
		expr <- assignment(name)
		if (!is.call(expr) || !identical(expr[[1L]], as.name("function"))) {
			stop("runner key helper is no longer a function: ", name, call. = FALSE)
		}
		assign(name, eval(expr, envir = key_env), envir = key_env)
	}
	manifest$id <- mapply(
		key_env$build_result_key, manifest$rep, manifest$beta_T, manifest$dataset,
		manifest$response_type, manifest$design, manifest$inference_class,
		manifest$function_run, USE.NAMES = FALSE
	)
	manifest$eligibility_scope <- "candidate_if_setup_and_source_capability_succeed"
	manifest <- manifest[c(columns, "id", "eligibility_scope")]
	if (anyDuplicated(manifest$id)) stop("duplicate serialized candidate result ID", call. = FALSE)
	attr(manifest, "candidate_context_count") <- nrow(grid)
	attr(manifest, "excluded_by_default_slow_path") <- FALSE
	manifest
}
