# Pure decision helpers shared by comprehensive_tests.R and its key-manifest
# tooling. Inputs are the already-computed per-instance eligibility/skip
# decisions; this file must not construct designs/inference objects or invoke
# estimator methods.
comprehensive_should_run_test_family <- function(test_family, filter = NA_character_) {
	!(!is.na(filter) && !identical(filter, test_family))
}

comprehensive_rand_ci_attempted_functions <- function(
	response_type,
	supports_randomization_ci,
	supports_randomization_bootstrap,
	test_family_filter = NA_character_,
	skip_slow = FALSE,
	skip_rand = FALSE,
	skip_rand_slow = FALSE,
	skip_ci_rand = FALSE,
	skip_rand_ci_slow = FALSE,
	skip_brt_ci = FALSE,
	skip_brt_ci_smoothed_slow = FALSE,
	skip_brt_ci_typed_slow = FALSE,
	test_compute_confidence_interval_rand = TRUE
) {
	ci_response = response_type %in% c("continuous", "proportion", "count", "survival")
	functions = character()
	if (isTRUE(supports_randomization_ci) &&
		comprehensive_should_run_test_family("rand", test_family_filter) &&
		!isTRUE(skip_slow) && !isTRUE(skip_rand) && !isTRUE(skip_rand_slow) &&
		!isTRUE(skip_ci_rand) &&
		!isTRUE(skip_rand_ci_slow) && isTRUE(test_compute_confidence_interval_rand) &&
		ci_response) {
		functions = c(functions, "compute_rand_confidence_interval")
	}
	if (isTRUE(supports_randomization_bootstrap) &&
		comprehensive_should_run_test_family("rand_bootstrap", test_family_filter) &&
		!isTRUE(skip_slow) && !isTRUE(skip_brt_ci) && !isTRUE(skip_rand) &&
		!isTRUE(skip_ci_rand) && isTRUE(test_compute_confidence_interval_rand) &&
		ci_response) {
		functions = c(functions, "compute_rand_bootstrap_confidence_interval")
		if (!isTRUE(skip_brt_ci_typed_slow)) {
			functions = c(
				functions,
				"compute_rand_bootstrap_confidence_interval_studentized",
				"compute_rand_bootstrap_confidence_interval_symmetric-percentile-t"
			)
		}
		if (!isTRUE(skip_brt_ci_smoothed_slow)) {
			functions = c(functions, "compute_rand_bootstrap_confidence_interval_smoothed")
		}
	}
	functions
}

comprehensive_rand_ci_attempt_manifest <- function(cases) {
	if (!is.data.frame(cases)) stop("cases must be a data.frame", call. = FALSE)
	key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	eligibility_columns = c(
		"supports_randomization_ci", "supports_randomization_bootstrap",
		"test_family_filter", "skip_slow", "skip_rand", "skip_rand_slow",
		"skip_ci_rand", "skip_rand_ci_slow", "skip_brt_ci",
		"skip_brt_ci_smoothed_slow", "skip_brt_ci_typed_slow",
		"test_compute_confidence_interval_rand"
	)
	missing = setdiff(c(key_columns, eligibility_columns), names(cases))
	if (length(missing)) {
		stop("missing case-manifest field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	}
	rows = list()
	for (i in seq_len(nrow(cases))) {
		context = as.list(cases[i, eligibility_columns, drop = FALSE])
		functions = do.call(comprehensive_rand_ci_attempted_functions, c(
			list(response_type = as.character(cases$response_type[i])), context
		))
		if (!length(functions)) next
		base = cases[rep(i, length(functions)), key_columns, drop = FALSE]
		base$function_run = functions
		rows[[length(rows) + 1L]] = base
	}
	if (!length(rows)) {
		return(data.frame(
			rep = integer(), beta_T = numeric(), dataset = character(),
			response_type = character(), design = character(), inference_class = character(),
			function_run = character(), stringsAsFactors = FALSE
		))
	}
	manifest = do.call(rbind, rows)
	rownames(manifest) = NULL
	if (anyDuplicated(manifest[c(key_columns, "function_run")])) {
		stop("duplicate attempted result key in case manifest", call. = FALSE)
	}
	manifest
}

# Read only the manual dispatch portion of run_tests_for_response().  This
# deliberately parses the harness instead of instantiating its R6 inference
# classes: their constructors can fit models.  Only the two dispatch guards
# that determine the manual roster (response_type and is_kk_design) are
# interpreted; other guards are traversed on both sides, so this helper is
# conservative when a future dispatch adds another class-dependent branch.
comprehensive_rand_ci_dispatch_roster <- function(script_path, response_type, is_kk_design) {
	if (length(script_path) != 1L || is.na(script_path) || !file.exists(script_path)) {
		stop("script_path must name an existing comprehensive_tests.R", call. = FALSE)
	}
	if (length(response_type) != 1L || is.na(response_type) || !nzchar(response_type)) {
		stop("response_type must be one nonempty value", call. = FALSE)
	}
	if (length(is_kk_design) != 1L || is.na(is_kk_design)) {
		stop("is_kk_design must be TRUE or FALSE", call. = FALSE)
	}
	parsed <- parse(script_path, keep.source = FALSE)

	find_function <- function(expr, name) {
		if (!is.call(expr)) return(NULL)
		if (identical(as.character(expr[[1L]]), "function")) return(NULL)
		if (identical(expr[[1L]], as.name("=")) && identical(expr[[2L]], as.name(name))) {
			return(expr[[3L]])
		}
		if (identical(expr[[1L]], as.name("<-")) && identical(expr[[2L]], as.name(name))) {
			return(expr[[3L]])
		}
		children <- as.list(expr)[-1L]
		for (child_index in seq_along(children)) {
			if (identical(children[child_index], list(quote(expr = )))) next
			child <- children[[child_index]]
			found <- find_function(child, name)
			if (!is.null(found)) return(found)
		}
		NULL
	}

	function_expr <- NULL
	for (expr in as.list(parsed)) {
		function_expr <- find_function(expr, "run_tests_for_response")
		if (!is.null(function_expr)) break
	}
	if (is.null(function_expr) || !is.call(function_expr) || !identical(function_expr[[1L]], as.name("function"))) {
		stop("could not find run_tests_for_response() in parsed source", call. = FALSE)
	}
	body <- function_expr[[3L]]
	sanitize_missing_args <- function(node) {
		if (!is.call(node)) return(node)
		parts <- as.list(node)
		for (part_index in seq_along(parts)) {
			if (identical(parts[part_index], list(quote(expr = )))) {
				parts[part_index] <- list(NULL)
			} else {
				parts[part_index] <- list(sanitize_missing_args(parts[[part_index]]))
			}
		}
		as.call(parts)
	}
	body <- sanitize_missing_args(body)

	selected_branch <- function(condition) {
		if (identical(condition, as.name("is_kk_design"))) return(isTRUE(is_kk_design))
		if (!is.call(condition)) return(NA)
		operator <- as.character(condition[[1L]])
		if (operator %in% c("==", "identical") && length(condition) >= 3L) {
			left <- condition[[2L]]
			right <- condition[[3L]]
			if (identical(left, as.name("response_type")) && is.character(right) && length(right) == 1L) {
				return(identical(response_type, right))
			}
			if (identical(left, as.name("is_kk_design")) && identical(right, TRUE)) return(isTRUE(is_kk_design))
		}
		if (operator == "!" && length(condition) == 2L && identical(condition[[2L]], as.name("is_kk_design"))) {
			return(!isTRUE(is_kk_design))
		}
		NA
	}

	class_from_new_call <- function(expr) {
		if (!is.call(expr)) return(NULL)
		head <- expr[[1L]]
		if (!is.call(head) || !identical(head[[1L]], as.name("$")) || !identical(head[[3L]], as.name("new"))) return(NULL)
		as.character(head[[2L]])
	}

	extract_selector_classes <- function(selector_name) {
		selector <- NULL
		for (expr in as.list(parsed)) {
			selector <- find_function(expr, selector_name)
			if (!is.null(selector)) break
		}
		if (is.null(selector)) return(character())
		classes <- character()
		collect <- function(expr) {
			if (!is.call(expr)) return(invisible(NULL))
			if (identical(expr[[1L]], as.name("list"))) {
				for (item in as.list(expr)[-1L]) {
					if (is.symbol(item)) classes <<- c(classes, as.character(item))
				}
			}
			children <- as.list(expr)[-1L]
			for (child_index in seq_along(children)) {
				if (identical(children[child_index], list(quote(expr = )))) next
				child <- children[[child_index]]
				collect(child)
			}
			invisible(NULL)
		}
		collect(selector[[3L]])
		unique(classes)
	}

	roster <- character()
	walk_safe <- function(node) {
		if (missing(node)) return(invisible(NULL))
		walk(node)
	}
	walk <- function(expr) {
		if (!is.call(expr)) return(invisible(NULL))
		if (identical(expr[[1L]], as.name("if"))) {
			branch <- selected_branch(expr[[2L]])
			if_parts <- as.list(expr)
			yes_branch <- if_parts[3L]
			no_branch <- if (length(if_parts) >= 4L) if_parts[4L] else list(quote(expr = ))
			if (!is.na(branch)) {
				if (isTRUE(branch) && !identical(yes_branch, list(quote(expr = )))) walk_safe(yes_branch[[1L]])
				if (!isTRUE(branch) && !identical(no_branch, list(quote(expr = )))) walk_safe(no_branch[[1L]])
				return(invisible(NULL))
			}
			if (!identical(yes_branch, list(quote(expr = )))) walk_safe(yes_branch[[1L]])
			if (!identical(no_branch, list(quote(expr = )))) walk_safe(no_branch[[1L]])
			return(invisible(NULL))
		}
		call_name <- as.character(expr[[1L]])
		if (identical(call_name, "run_inference_checks_both_paths") && length(expr) >= 3L && is.character(expr[[3L]]) && length(expr[[3L]]) == 1L) {
			roster <<- c(roster, expr[[3L]])
		}
		if (identical(call_name, "run_inference_checks") && length(expr) >= 2L) {
			class_name <- class_from_new_call(expr[[2L]])
			if (!is.null(class_name)) roster <<- c(roster, class_name)
		}
		if (identical(call_name, "for") && length(expr) >= 4L && is.call(expr[[3L]])) {
			selector_name <- as.character(expr[[3L]][[1L]])
			if (selector_name %in% c("select_kk_incidence_glmm_ivwc_generator", "select_kk_survival_class_generators")) {
				roster <<- c(roster, extract_selector_classes(selector_name))
			}
		}
		children <- as.list(expr)[-1L]
		for (child_index in seq_along(children)) {
			if (identical(children[child_index], list(quote(expr = )))) next
			child <- children[[child_index]]
			walk_safe(child)
		}
		invisible(NULL)
	}
	walk(body)
	unique(roster)
}

# Apply the same static capability and slow-path data consumed by
# run_inference_checks_impl() to a source-rostered class. The proxy carries the
# registered design ancestry because design exclusions are attached to parent
# classes (e.g. DesignSeqOneByOne), not just the concrete class name. No design
# or inference constructor is called.
comprehensive_rand_ci_class_attempts <- function(
	class_name, response_type, design_class, model_formula,
	test_family_filter = NA_character_, slow_path_rules,
	additional_slow_paths, force_run_slow_paths = FALSE, narrow_mode = FALSE
) {
	if (!requireNamespace("EDI", quietly = TRUE)) stop("EDI must be loaded", call. = FALSE)
	if (length(class_name) != 1L || is.na(class_name) || !nzchar(class_name)) stop("class_name is required", call. = FALSE)
	if (length(response_type) != 1L || is.na(response_type) || !nzchar(response_type)) stop("response_type is required", call. = FALSE)
	if (length(design_class) != 1L || is.na(design_class) || !nzchar(design_class)) stop("design_class is required", call. = FALSE)
	if (length(model_formula) != 1L || is.na(model_formula) || !nzchar(model_formula)) stop("model_formula is required", call. = FALSE)
	class_formula_match <- function(entries, require_formula = TRUE) {
		if (!length(entries)) return(FALSE)
		any(vapply(entries, function(entry) {
			parts <- strsplit(as.character(entry), "||", fixed = TRUE)[[1L]]
			identical(parts[[1L]], class_name) &&
				(!require_formula || length(parts) == 1L || identical(parts[[2L]], model_formula))
		}, logical(1)))
	}
	class_match <- function(entries) class_name %in% as.character(entries)
	design_class_chain <- function(name) {
		classes <- character()
		current <- name
		repeat {
			if (current %in% classes) {
				stop("cyclic design-class parent metadata for ", name, call. = FALSE)
			}
			classes <- c(classes, current)
			metadata <- tryCatch(
				EDI:::get_design_class_metadata(current),
				error = function(e) NULL
			)
			parent <- metadata$parent
			if (is.null(parent)) break
			current <- parent
		}
		classes
	}
	proxy_design <- structure(list(), class = design_class_chain(design_class))
	capabilities <- tryCatch(
		EDI:::get_effective_capabilities(class_name, des_obj = proxy_design),
		error = function(e) character()
	)
	`%or_empty%` <- function(x, empty) if (is.null(x)) empty else x
	get_rule <- function(name) as.character(slow_path_rules[[name]] %or_empty% character())
	get_local <- function(name) as.character(additional_slow_paths[[name]] %or_empty% character())
	forced <- isTRUE(force_run_slow_paths)
	structural_bootstrap_skip <- !("nonparametric_bootstrap" %in% capabilities) ||
		(!forced && class_formula_match(get_local("bootstrap")))
	skip_rand <- !forced && class_formula_match(get_local("rand"))
	skip_rand_slow <- !forced && class_match(get_rule("rand"))
	skip_rand_ci_slow <- !forced && class_match(get_rule("rand_ci"))
	skip_ci_rand <- (!forced && class_match(get_local("rand_ci"))) ||
		(!forced && identical(response_type, "count") && !class_formula_match(get_local("rand_ci_count_allowed"))) ||
		(!identical(response_type, "continuous") && identical(class_name, "InferenceAllSimpleAverageDiff"))
	skip_bootstrap_slow <- !forced && class_match(get_rule("bootstrap"))
	skip_brt_ci_all_slow <- (!forced && class_match(get_rule("brt_ci_all"))) ||
		(!forced && class_formula_match(get_local("brt_ci_all")))
	skip_brt_ci_smoothed_slow <- isTRUE(narrow_mode) ||
		(!forced && class_match(get_rule("brt_ci_smoothed"))) ||
		(!forced && class_formula_match(get_local("brt_ci_smoothed")))
	skip_brt_ci_typed_slow <- isTRUE(narrow_mode) ||
		(!forced && class_match(get_rule("brt_ci_typed"))) ||
		(!forced && class_formula_match(get_local("brt_ci_typed")))
	comprehensive_rand_ci_attempted_functions(
		response_type = response_type,
		supports_randomization_ci = "randomization_ci" %in% capabilities,
		supports_randomization_bootstrap = "randomization_bootstrap" %in% capabilities,
		test_family_filter = test_family_filter,
		skip_slow = FALSE,
		skip_rand = skip_rand,
		skip_rand_slow = skip_rand_slow,
		skip_ci_rand = skip_ci_rand,
		skip_rand_ci_slow = skip_rand_ci_slow,
		skip_brt_ci = structural_bootstrap_skip || skip_bootstrap_slow || skip_rand_slow || skip_rand || skip_brt_ci_all_slow,
		skip_brt_ci_smoothed_slow = skip_brt_ci_smoothed_slow,
		skip_brt_ci_typed_slow = skip_brt_ci_typed_slow,
		test_compute_confidence_interval_rand = TRUE
	)
}
