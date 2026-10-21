# Build a bounded expected-attempt roster for an explicitly selected ordinal
# coverage-truth class. This is reconciliation preparation only: it parses
# runner/registry source and never constructs a design or inference object.
ordinal_attempt_source_assignment <- function(path, name) {
	exprs <- parse(path)
	matches <- Filter(function(expr) {
		is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) &&
			identical(expr[[2L]], as.name(name))
	}, as.list(exprs))
	if (length(matches) != 1L) {
		stop("expected one top-level source assignment for ", name, call. = FALSE)
	}
	matches[[1L]][[3L]]
}

ordinal_attempt_walk <- function(expr, visit) {
	visit(expr)
	if (!is.call(expr)) return(invisible(NULL))
	children <- as.list(expr)
	if (length(children) > 0L) {
		for (i in seq_along(children)) {
			if (identical(children[[i]], quote(expr = ))) next
			ordinal_attempt_walk(children[[i]], visit)
		}
	}
	invisible(NULL)
}

ordinal_attempt_symbols <- function(expr) {
	found <- character()
	ordinal_attempt_walk(expr, function(node) {
		if (is.name(node)) found <<- c(found, as.character(node))
	})
	unique(found)
}

ordinal_attempt_is_ordinal_if <- function(expr) {
	if (!is.call(expr) || !identical(expr[[1L]], as.name("if")) || length(expr) < 3L) return(FALSE)
	condition <- expr[[2L]]
	is.call(condition) && identical(condition[[1L]], as.name("==")) &&
		length(condition) == 3L &&
		((identical(condition[[2L]], as.name("response_type")) && identical(condition[[3L]], "ordinal")) ||
			(identical(condition[[3L]], as.name("response_type")) && identical(condition[[2L]], "ordinal")))
}

ordinal_attempt_find_ordinal_branch <- function(expr) {
	if (!is.call(expr)) return(NULL)
	if (ordinal_attempt_is_ordinal_if(expr)) return(expr[[3L]])
	children <- as.list(expr)
	if (length(children) > 0L) {
		for (i in seq_along(children)) {
			if (identical(children[[i]], quote(expr = ))) next
			found <- ordinal_attempt_find_ordinal_branch(children[[i]])
			if (!is.null(found)) return(found)
		}
	}
	NULL
}

ordinal_attempt_runner_routes <- function(runner_path) {
	runner_exprs <- parse(runner_path)
	run_assignment <- Filter(function(expr) {
		is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) &&
			identical(expr[[2L]], as.name("run_tests_for_response"))
	}, as.list(runner_exprs))
	if (length(run_assignment) != 1L) stop("missing unique run_tests_for_response()", call. = FALSE)
	ordinal_branch <- ordinal_attempt_find_ordinal_branch(run_assignment[[1L]][[3L]][[3L]])
	if (is.null(ordinal_branch)) stop("missing response_type == 'ordinal' runner branch", call. = FALSE)

	routes <- list()
	ordinal_attempt_walk(ordinal_branch, function(node) {
		if (!is.call(node) || !length(node) ||
				!(identical(node[[1L]], as.name("run_inference_checks")) ||
					identical(node[[1L]], as.name("run_inference_checks_both_paths")))) return(invisible(NULL))
		if (length(node) < 2L) return(invisible(NULL))
		class_names <- ordinal_attempt_symbols(node[[2L]])
		class_names <- class_names[grepl("^InferenceOrdinal", class_names)]
		route <- if (identical(node[[1L]], as.name("run_inference_checks_both_paths"))) "both_paths" else "direct"
		for (class_name in class_names) {
			routes[[class_name]] <<- unique(c(routes[[class_name]], route))
		}
	})
	if (!length(routes)) stop("no ordinal class calls found in runner branch", call. = FALSE)
	routes
}

ordinal_attempt_formula_values <- function(runner_path) {
	exprs <- parse(runner_path)
	matches <- list()
	ordinal_attempt_walk(as.call(c(as.name("{"), as.list(exprs))), function(node) {
		if (is.call(node) && length(node) >= 3L &&
				(identical(node[[1L]], as.name("=")) || identical(node[[1L]], as.name("<-"))) &&
				identical(node[[2L]], as.name("formulas_to_test"))) {
			matches[[length(matches) + 1L]] <<- node[[3L]]
		}
	})
	if (length(matches) != 1L || !is.call(matches[[1L]]) || !identical(matches[[1L]][[1L]], as.name("list"))) {
		stop("expected one runner formulas_to_test list", call. = FALSE)
	}
	vapply(as.list(matches[[1L]])[-1L], function(formula) paste(deparse(formula), collapse = " "), character(1))
}

ordinal_attempt_family_labels <- function(runner_path, family) {
	run_impl <- ordinal_attempt_source_assignment(runner_path, "run_inference_checks_impl")
	labels <- character()
	ordinal_attempt_walk(run_impl[[3L]], function(node) {
		if (is.call(node) && identical(node[[1L]], as.name("safe_call_family")) && length(node) >= 3L &&
				identical(node[[2L]], family) && is.character(node[[3L]]) && length(node[[3L]]) == 1L) {
			labels <<- c(labels, node[[3L]])
		}
	})
	unique(labels)
}

ordinal_attempt_direct_testing_labels <- function(runner_path, testing_type) {
	run_impl <- ordinal_attempt_source_assignment(runner_path, "run_inference_checks_impl")
	labels <- character()
	ordinal_attempt_walk(run_impl[[3L]], function(node) {
		if (is.call(node) && identical(node[[1L]], as.name("call_direct_asymp")) &&
				length(node) >= 3L && is.character(node[[2L]]) && length(node[[2L]]) == 1L &&
				identical(node[[3L]], testing_type)) {
			labels <<- c(labels, node[[2L]])
		}
	})
	unique(labels)
}

comprehensive_ordinal_coverage_attempt_manifest <- function(case_grid, runner_path,
		class_filter = NULL, attempt_flags) {
	if (!is.data.frame(case_grid)) stop("case_grid must be a data.frame", call. = FALSE)
	key_columns <- c("rep", "beta_T", "dataset", "response_type", "design")
	missing <- setdiff(key_columns, names(case_grid))
	if (length(missing)) stop("missing case-grid field(s): ", paste(missing, collapse = ", "), call. = FALSE)
	if (nrow(case_grid) && (anyNA(case_grid[key_columns]) || any(case_grid$response_type != "ordinal"))) {
		stop("case grid must have non-missing keys and response_type = 'ordinal'", call. = FALSE)
	}
	if (nrow(case_grid) && any(case_grid$design != "Bernoulli")) {
		stop("bounded ordinal MC roster supports the Bernoulli fixture only", call. = FALSE)
	}
	if (anyDuplicated(case_grid[key_columns])) stop("duplicate ordinal source case key", call. = FALSE)
	if (!is.null(class_filter) &&
			(!is.character(class_filter) || !length(class_filter) || anyNA(class_filter) || any(!nzchar(class_filter)))) {
		stop("class_filter must be NULL or a non-empty character vector", call. = FALSE)
	}
	flag_names <- c("test_family_filters", "has_compute_estimate", "skip_asymp",
		"has_wald_two_sided_pval", "has_wald_confidence_interval",
		"supports_wald_testing_type", "skip_slow")
	if (!is.list(attempt_flags) || !all(flag_names %in% names(attempt_flags)) ||
			!is.character(attempt_flags$test_family_filters) || !length(attempt_flags$test_family_filters) ||
			anyNA(attempt_flags$test_family_filters) ||
			any(!attempt_flags$test_family_filters %in% c("estimate", "wald")) ||
			anyDuplicated(attempt_flags$test_family_filters)) {
		stop("bounded roster requires explicit estimate/wald family and capability flags", call. = FALSE)
	}
	logical_flags <- flag_names[-1L]
	if (any(!vapply(attempt_flags[logical_flags], function(x) is.logical(x) && length(x) == 1L && !is.na(x), logical(1)))) {
		stop("all ordinal attempt capability and branch flags must be explicit scalar logicals", call. = FALSE)
	}
	# These flags model one reduced runner configuration. They are deliberately
	# supplied by the fixture, not inferred from live class objects: in
	# particular exact-inference capability, method existence, and direct Wald
	# support remain runtime-dependent and are outside this source-only roster.
	# `test_family_filters` is the union of separate family-filtered runner
	# invocations, not a claim that TEST_FAMILY_FILTER accepts a vector. The
	# explicit skip_slow value is fixture context; it does not gate estimate or
	# the selected direct Wald calls in the runner.

	registry_expr <- ordinal_attempt_source_assignment(runner_path, "COVERAGE_MC_SPEC")
	registry <- eval(registry_expr, envir = new.env(parent = baseenv()))
	ordinal_mc_classes <- names(registry)[vapply(registry, function(spec) identical(spec$rt, "ordinal"), logical(1))]
	routes <- ordinal_attempt_runner_routes(runner_path)
	ordinal_mc_direct_classes <- ordinal_mc_classes[vapply(ordinal_mc_classes, function(class_name) {
		class_name %in% names(routes) && identical(routes[[class_name]], "direct")
	}, logical(1))]
	if (is.null(class_filter)) class_filter <- ordinal_mc_direct_classes
	if (any(!class_filter %in% ordinal_mc_direct_classes)) {
		stop("selected classes must be ordinal MC-truth classes on direct runner routes", call. = FALSE)
	}
	formulas <- ordinal_attempt_formula_values(runner_path)
	if (!length(formulas)) stop("runner formula list is empty", call. = FALSE)
	if (!grepl("design_formula=", paste(deparse(ordinal_attempt_source_assignment(runner_path, "run_inference_checks_impl")), collapse = " "), fixed = TRUE)) {
		stop("runner no longer appends design_formula labels", call. = FALSE)
	}
	estimate_labels <- ordinal_attempt_family_labels(runner_path, "estimate")
	if (!identical(estimate_labels, "compute_estimate")) {
		stop("expected one compute_estimate attempt in estimate-only runner path", call. = FALSE)
	}
	wald_labels <- ordinal_attempt_direct_testing_labels(runner_path, "wald")
	if (!identical(wald_labels, c("compute_wald_two_sided_pval", "compute_wald_confidence_interval"))) {
		stop("unexpected direct Wald attempt labels in runner", call. = FALSE)
	}
	function_runs <- character()
	if ("estimate" %in% attempt_flags$test_family_filters && isTRUE(attempt_flags$has_compute_estimate)) {
		function_runs <- c(function_runs, estimate_labels)
	}
	if ("wald" %in% attempt_flags$test_family_filters && !attempt_flags$skip_asymp &&
			attempt_flags$has_wald_two_sided_pval && attempt_flags$has_wald_confidence_interval &&
			attempt_flags$supports_wald_testing_type) {
		function_runs <- c(function_runs, wald_labels)
	}
	if (anyDuplicated(function_runs)) stop("duplicate ordinal function_run labels", call. = FALSE)

	if (!nrow(case_grid) || !length(function_runs)) {
		out <- case_grid[FALSE, key_columns, drop = FALSE]
		out$inference_class <- character()
		out$function_run <- character()
		return(out[c(key_columns, "inference_class", "function_run")])
	}
	rows <- vector("list", nrow(case_grid) * length(class_filter) * length(formulas) * length(function_runs))
	index <- 0L
	for (i in seq_len(nrow(case_grid))) {
		for (class_name in class_filter) {
			for (formula in formulas) {
				for (function_run in function_runs) {
					index <- index + 1L
					row <- case_grid[i, key_columns, drop = FALSE]
					row$inference_class <- paste0(class_name, " [design_formula=", formula, "]")
					row$function_run <- function_run
					rows[[index]] <- row
				}
			}
		}
	}
	manifest <- do.call(rbind, rows)
	rownames(manifest) <- NULL
	full_key <- c(key_columns, "inference_class", "function_run")
	if (anyDuplicated(manifest[full_key])) stop("duplicate ordinal attempted result key", call. = FALSE)
	manifest[full_key]
}
