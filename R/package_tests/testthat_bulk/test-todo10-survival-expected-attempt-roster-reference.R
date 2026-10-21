library(testthat)
library(EDI)

# Derive a small expected attempt roster from the runner's declarative spec
# and dispatch source. This test does not source the runner (which launches
# the comprehensive suite), instantiate an inference object, or write rows.
todo10_runner_exprs <- parse(testthat::test_path("..", "comprehensive_tests.R"))
todo10_is_assignment <- function(expr, name) {
	is.call(expr) && length(expr) >= 3L &&
		(identical(expr[[1L]], as.name("<-")) || identical(expr[[1L]], as.name("="))) &&
		identical(expr[[2L]], as.name(name))
}
todo10_top_rhs <- function(name) {
	for (expr in as.list(todo10_runner_exprs)) {
		if (todo10_is_assignment(expr, name)) return(expr[[3L]])
	}
	for (expr in as.list(todo10_runner_exprs)) {
		rhs <- todo10_find_assignment_rhs(expr, name)
		if (!is.null(rhs)) return(rhs)
	}
	stop("Missing top-level comprehensive runner assignment: ", name, call. = FALSE)
}
todo10_find_assignment_rhs <- function(expr, name) {
	if (!is.call(expr)) return(NULL)
	if (identical(expr[[1L]], as.name("function"))) return(todo10_find_assignment_rhs(expr[[3L]], name))
	if (length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("<-")) || identical(expr[[1L]], as.name("="))) &&
			identical(expr[[2L]], as.name(name))) {
		return(expr[[3L]])
	}
	children <- as.list(expr)[-1L]
	for (child_index in seq_along(children)) {
		if (identical(unname(children[child_index]), list(quote(expr = )))) next
		child <- children[[child_index]]
		found <- todo10_find_assignment_rhs(child, name)
		if (!is.null(found)) return(found)
	}
	NULL
}
todo10_find_function_rhs <- function(name) {
	rhs <- todo10_top_rhs(name)
	if (!is.call(rhs) || !identical(rhs[[1L]], as.name("function"))) {
		stop("Expected a function assignment for ", name, call. = FALSE)
	}
	rhs
}
todo10_named_argument <- function(expr, name) {
	if (!is.call(expr) || !identical(expr[[1L]], as.name("list"))) {
		stop("Expected a literal named list while deriving source roster", call. = FALSE)
	}
	args <- as.list(expr)[-1L]
	arg_names <- names(args)
	if (is.null(arg_names) || sum(arg_names == name, na.rm = TRUE) != 1L) {
		stop("Expected exactly one source field named ", name, call. = FALSE)
	}
	args[[which(arg_names == name)]]
}
todo10_literal_vector <- function(expr, mode) {
	if (!is.call(expr) || !identical(expr[[1L]], as.name("c"))) {
		stop("Expected a literal c(...) source axis", call. = FALSE)
	}
	values <- as.list(expr)[-1L]
	valid <- if (mode == "character") vapply(values, is.character, logical(1)) else
		vapply(values, function(x) is.numeric(x) && length(x) == 1L && is.finite(x), logical(1))
	if (!length(values) || !all(valid)) stop("Non-literal source axis", call. = FALSE)
	unlist(values, use.names = FALSE)
}
todo10_source_response_roster <- function(dataset_path) {
	dataset_exprs <- parse(dataset_path)
	dataset_assignment <- Filter(function(x) todo10_is_assignment(x, "datasets_and_response_models"),
		as.list(dataset_exprs))
	if (length(dataset_assignment) != 1L) stop("Missing unique source dataset roster", call. = FALSE)
	dataset_list <- dataset_assignment[[1L]][[3L]]
	if (!is.call(dataset_list) || !identical(dataset_list[[1L]], as.name("list"))) {
		stop("Source dataset roster is no longer a literal list", call. = FALSE)
	}
	entries <- as.list(dataset_list)[-1L]
	dataset_names <- names(entries)
	if (is.null(dataset_names) || anyNA(dataset_names) || any(!nzchar(dataset_names))) {
		stop("Source datasets must all have literal names", call. = FALSE)
	}
	transform_rhs <- NULL
	for (expr in as.list(dataset_exprs)) {
		transform_rhs <- todo10_find_assignment_rhs(expr, "finagle_different_responses_from_continuous")
		if (!is.null(transform_rhs)) break
	}
	if (is.null(transform_rhs) || !is.call(transform_rhs) || !identical(transform_rhs[[1L]], as.name("function"))) {
		stop("Could not locate the literal response transformer", call. = FALSE)
	}
	transform_lists <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("list")),
		todo10_calls_named(transform_rhs[[3L]], "list"))
	response_keys <- if (length(transform_lists) == 1L) names(as.list(transform_lists[[1L]])[-1L]) else character()
	if (!all(c("survival", "ordinal") %in% response_keys)) {
		stop("Response transformer no longer declares survival and ordinal", call. = FALSE)
	}
	pairs <- lapply(seq_along(entries), function(i) {
		y_expr <- todo10_named_argument(entries[[i]], "y_original")
		if (is.call(y_expr) && identical(y_expr[[1L]], as.name("finagle_different_responses_from_continuous"))) {
			responses <- response_keys
		} else if (is.call(y_expr) && identical(y_expr[[1L]], as.name("list"))) {
			responses <- names(as.list(y_expr)[-1L])
			if (is.null(responses)) stop("Direct response list must be named", call. = FALSE)
		} else {
			stop("Unsupported y_original source expression for ", dataset_names[[i]], call. = FALSE)
		}
		responses <- intersect(responses, c("survival", "ordinal"))
		if (!length(responses)) return(data.frame(dataset = character(), response_type = character()))
		data.frame(dataset = rep(dataset_names[[i]], length(responses)), response_type = responses,
			stringsAsFactors = FALSE)
	})
	roster <- do.call(rbind, pairs)
	if (is.null(roster) || !nrow(roster)) stop("No source-declared survival/ordinal datasets", call. = FALSE)
	row.names(roster) <- NULL
	if (anyDuplicated(roster)) stop("Duplicate source dataset/response pair", call. = FALSE)
	roster
}
todo10_candidate_case_lattice <- function(Nrep, runner_path, dataset_path) {
	if (!is.numeric(Nrep) || length(Nrep) != 1L || is.na(Nrep) || !is.finite(Nrep) ||
			Nrep < 1L || Nrep != floor(Nrep)) stop("Nrep must be a positive integer", call. = FALSE)
	runner_exprs <- parse(runner_path)
	get_rhs <- function(name) {
		for (expr in as.list(runner_exprs)) {
			if (todo10_is_assignment(expr, name)) return(expr[[3L]])
		}
		for (expr in as.list(runner_exprs)) {
			rhs <- todo10_find_assignment_rhs(expr, name)
			if (!is.null(rhs)) return(rhs)
		}
		stop("Missing runner source axis: ", name, call. = FALSE)
	}
	designs <- todo10_literal_vector(get_rhs("TESTED_DESIGNS"), "character")
	formulas <- get_rhs("formulas_to_test")
	if (!is.call(formulas) || !identical(formulas[[1L]], as.name("list"))) stop("Runner formulas must be a literal list", call. = FALSE)
	formula_labels <- vapply(as.list(formulas)[-1L], function(x) paste(deparse(x), collapse = " "), character(1))
	if (!setequal(gsub(" ", "", formula_labels), c("~1", "~."))) stop("Unexpected runner formula axis", call. = FALSE)
	beta_rhs <- get_rhs("beta_T_values")
	if (!is.call(beta_rhs) || !identical(beta_rhs[[1L]], as.name("resolve_comprehensive_beta_values")) || length(beta_rhs) < 2L) {
		stop("Runner beta axis is not the expected literal resolver call", call. = FALSE)
	}
	betas <- as.numeric(todo10_literal_vector(beta_rhs[[2L]], "numeric"))
	if (!setequal(betas, c(0, 0.5))) stop("Unexpected runner beta axis", call. = FALSE)
	pairs <- todo10_source_response_roster(dataset_path)
	cases <- expand.grid(
		rep = seq_len(as.integer(Nrep)), beta_T = betas,
		dataset = unique(pairs$dataset), response_type = c("survival", "ordinal"),
		design = designs, design_formula = formula_labels,
		stringsAsFactors = FALSE
	)
	cases <- merge(cases, pairs, by = c("dataset", "response_type"), all = FALSE, sort = FALSE)
	cases$candidate_status <- "candidate only; requires successful dataset/design/inference setup and runtime support"
	# This describes the source design_formula axis only. Some runner classes add
	# a separate model_formula label, so this is not a per-result cache-key mode.
	cases$design_formula_covariate_mode <- ifelse(gsub(" ", "", cases$design_formula) == "~1", "legacy_no_covariates", "real_covariates")
	unavailable <- eval(todo10_top_rhs("COVERAGE_TRUTH_UNAVAILABLE"), envir = baseenv())
	key_cols <- c("rep", "beta_T", "dataset", "response_type", "design", "design_formula")
	if (anyDuplicated(cases[key_cols])) stop("Duplicate source candidate case key", call. = FALSE)
	cases <- cases[order(cases$response_type, cases$dataset, cases$beta_T, cases$rep, cases$design, cases$design_formula), , drop = FALSE]
	row.names(cases) <- NULL
	attr(cases, "excluded_truth_classes") <- unavailable
	cases
}
todo10_calls_named <- function(expr, name) {
	if (!is.call(expr)) return(list())
	if (identical(expr[[1L]], as.name("function"))) return(todo10_calls_named(expr[[3L]], name))
	out <- if (identical(expr[[1L]], as.name(name))) list(expr) else list()
	children <- as.list(expr)[-1L]
	for (child_index in seq_along(children)) {
		if (identical(unname(children[child_index]), list(quote(expr = )))) next
		out <- c(out, todo10_calls_named(children[[child_index]], name))
	}
	out
}
todo10_all_calls <- function(expr) {
	if (!is.call(expr)) return(list())
	out <- list(expr)
	if (identical(expr[[1L]], as.name("function"))) return(c(out, todo10_all_calls(expr[[3L]])))
	children <- as.list(expr)[-1L]
	for (child_index in seq_along(children)) {
		if (identical(unname(children[child_index]), list(quote(expr = )))) next
		out <- c(out, todo10_all_calls(children[[child_index]]))
	}
	out
}
todo10_source_classes <- function(call_expr, argument_index) {
	args <- Filter(is.call, call_expr)
	if (length(args)) {
		return(vapply(Filter(function(x) length(x) >= argument_index && is.name(x[[argument_index]]), args),
			function(x) as.character(x[[argument_index]]), character(1)))
	}
	vapply(Filter(is.name, call_expr), as.character, character(1))
}
todo10_public_method_names <- function(path, class_name) {
	parsed <- parse(path)
	for (expr in as.list(parsed)) {
		for (call_expr in todo10_calls_named(expr, "define_inference_class")) {
			args <- as.list(call_expr)[-1L]
			arg_names <- names(args)
			if (is.null(arg_names) || !"classname" %in% arg_names || !"public" %in% arg_names) next
			if (!identical(args[["classname"]], class_name)) next
			public <- args[["public"]]
			if (!is.call(public) || !identical(public[[1L]], as.name("list"))) return(character())
			return(names(as.list(public)[-1L]))
		}
	}
	character()
}
todo10_expr_values <- function(expr, mode) {
	if (mode == "character" && is.character(expr)) return(as.character(expr))
	if (mode == "symbol" && is.name(expr)) return(as.character(expr))
	if (!is.call(expr)) return(character())
	unlist(lapply(as.list(expr), todo10_expr_values, mode = mode), use.names = FALSE)
}
todo10_class_source_specs <- function(source_dir) {
	specs <- list()
	for (path in list.files(source_dir, pattern = "\\.R$", full.names = TRUE)) {
		for (expr in as.list(parse(path))) {
			for (definition in todo10_calls_named(expr, "define_inference_class")) {
				args <- as.list(definition)[-1L]
				arg_names <- names(args)
				if (is.null(arg_names) || !all(c("classname", "inherit", "components") %in% arg_names)) next
				class_name <- args[["classname"]]
				if (!is.character(class_name) || length(class_name) != 1L) next
				specs[[class_name]] <- list(
					parents = todo10_expr_values(args[["inherit"]], "symbol"),
					components = todo10_expr_values(args[["components"]], "character"),
					metadata = if ("metadata" %in% arg_names) todo10_expr_values(args[["metadata"]], "character") else character()
				)
			}
		}
	}
	specs
}
todo10_source_exact_eligible <- function(class_name, specs, seen = character()) {
	if (grepl("Exact", class_name, fixed = TRUE)) return(TRUE)
	if (class_name %in% seen) stop("cyclic inference-class source inheritance", call. = FALSE)
	spec <- specs[[class_name]]
	if (is.null(spec)) stop("Missing source definition for survival MC class: ", class_name, call. = FALSE)
	if ("exact_test" %in% spec$metadata || any(grepl("Exact", spec$components, fixed = TRUE)) ||
			"InferenceExact" %in% spec$parents) return(TRUE)
	parents <- intersect(spec$parents, names(specs))
	any(vapply(parents, todo10_source_exact_eligible, logical(1), specs = specs, seen = c(seen, class_name)))
}

todo10_survival_roster <- function(cases, source_spec, unavailable, kk_classes, kk_design_types, both_paths, estimate_labels, model_formulas, extra_function_runs = data.frame()) {
	key_cols <- c("rep", "beta_T", "dataset", "design", "design_formula")
	if (!is.data.frame(cases) || !all(key_cols %in% names(cases))) {
		stop("cases must contain the runner's rep/beta/dataset/design/formula dimensions", call. = FALSE)
	}
	if (anyNA(cases[key_cols]) || anyDuplicated(cases[key_cols])) {
		stop("runner case dimensions must be complete and unique", call. = FALSE)
	}
	survival_classes <- names(source_spec)[vapply(source_spec, function(x) identical(x$rt, "survival"), logical(1))]
	eligible_classes <- setdiff(survival_classes, unavailable)
	kk_classes <- intersect(eligible_classes, kk_classes)
	non_kk_classes <- setdiff(eligible_classes, kk_classes)
	if (!length(eligible_classes) || !length(estimate_labels)) {
		stop("survival roster source or estimate-family dispatch is empty", call. = FALSE)
	}
	rows <- list()
	for (i in seq_len(nrow(cases))) {
		case <- cases[i, , drop = FALSE]
		case_is_kk <- case$design[[1L]] %in% kk_design_types
		classes <- if (case_is_kk) kk_classes else non_kk_classes
		for (class_name in classes) {
			class_model_formulas <- if (class_name %in% both_paths) model_formulas else NA_character_
			labels <- if (length(class_model_formulas) == 1L && is.na(class_model_formulas)) {
				paste0(class_name, " [design_formula=", case$design_formula[[1L]], "]")
			} else {
				paste0(class_name, " (model_formula=", class_model_formulas, ") [design_formula=", case$design_formula[[1L]], "]")
			}
			for (label in labels) {
				class_function_runs <- unique(c(estimate_labels, extra_function_runs$function_run[extra_function_runs$class_name == class_name]))
				for (function_run in class_function_runs) {
					rows[[length(rows) + 1L]] <- data.frame(
						rep = as.integer(case$rep[[1L]]),
						beta_T = as.numeric(case$beta_T[[1L]]),
						dataset = as.character(case$dataset[[1L]]),
						response_type = "survival",
						design = as.character(case$design[[1L]]),
						inference_class = label,
						function_run = function_run,
						stringsAsFactors = FALSE
					)
				}
			}
		}
	}
	roster <- do.call(rbind, rows)
	row.names(roster) <- NULL
	full_key <- c("function_run", "rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	if (anyDuplicated(roster[full_key])) stop("duplicate full survival attempt key", call. = FALSE)
	roster[order(roster$design, roster$rep, roster$beta_T, roster$dataset, roster$inference_class, roster$function_run), full_key, drop = FALSE]
}

test_that("survival expected attempts use runner/spec keys and retain only available MC-truth classes", {
	source_spec <- eval(todo10_top_rhs("COVERAGE_MC_SPEC"), envir = baseenv())
	unavailable <- eval(todo10_top_rhs("COVERAGE_TRUTH_UNAVAILABLE"), envir = baseenv())
	tested_designs <- eval(todo10_top_rhs("TESTED_DESIGNS"), envir = baseenv())
	response_runner <- todo10_find_function_rhs("run_tests_for_response")
	response_body <- response_runner[[3L]]
	survival_branches <- Filter(function(x) {
		is.call(x) && identical(x[[1L]], as.name("if")) &&
			length(x) >= 3L &&
			grepl("response_type", paste(deparse(x[[2L]]), collapse = " "), fixed = TRUE) &&
			grepl("survival", paste(deparse(x[[2L]]), collapse = " "), fixed = TRUE) &&
			grepl("InferenceSurvivalLogRank", paste(deparse(x), collapse = " "), fixed = TRUE)
	}, as.list(response_body)[-1L])[[1L]]
	kk_selector <- todo10_find_function_rhs("select_kk_survival_class_generators")
	kk_list <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name("list")), todo10_calls_named(kk_selector, "list"))[[1L]]
	kk_classes <- todo10_source_classes(as.list(kk_list)[-1L], 1L)
	both_path_calls <- todo10_calls_named(survival_branches, "run_inference_checks_both_paths")
	both_paths <- vapply(both_path_calls, function(x) as.character(x[[3L]]), character(1))
	new_calls <- Filter(function(x) length(x) >= 2L && is.call(x[[1L]]) &&
		identical(x[[1L]][[1L]], as.name("$")) && identical(x[[1L]][[3L]], as.name("new")),
		todo10_all_calls(survival_branches))
	direct_classes <- vapply(Filter(function(x) is.name(x[[1L]][[2L]]), new_calls),
		function(x) as.character(x[[1L]][[2L]]), character(1))
	kk_design_rhs <- todo10_find_assignment_rhs(response_runner, "is_kk_design")
	kk_design_types <- eval(kk_design_rhs[[3L]], envir = baseenv())
	checks <- todo10_find_function_rhs("run_inference_checks_impl")
	family_calls <- todo10_calls_named(checks, "safe_call_family")
	family_labels <- function(family) unique(vapply(Filter(function(x) {
		length(x) >= 3L && identical(x[[2L]], family) && is.character(x[[3L]])
	}, family_calls), function(x) as.character(x[[3L]]), character(1)))
	# This reduced fixture covers the unconditional estimate family across the
	# selected eligible classes, plus every asymptotic family call source-declared
	# on the selected LogRank class. It does not cover exact, call_direct_asymp,
	# bootstrap, or other safe_call paths, so it is not the runner's full method inventory.
	estimate_labels <- family_labels("estimate")
	exact_labels <- family_labels("exact")
	asymp_labels <- family_labels("asymp")
	formulas <- eval(todo10_top_rhs("formulas_to_test"), envir = baseenv())
	formula_labels <- vapply(formulas, function(x) paste(deparse(x), collapse = " "), character(1))
	both_paths_fn <- todo10_find_function_rhs("run_inference_checks_both_paths")
	model_formula_labels <- unlist(lapply(c("univ_label", "multi_label"), function(name) {
		rhs <- todo10_find_assignment_rhs(both_paths_fn, name)
		literals <- Filter(is.character, as.list(rhs)[-1L])
		paste0(unlist(literals, use.names = FALSE), collapse = "")
	}), use.names = FALSE)
	model_formulas <- unique(sub(".*model_formula=([^)]*).*", "\\1", model_formula_labels[grepl("model_formula=", model_formula_labels, fixed = TRUE)]))

	expect_true(is.call(survival_branches) && identical(survival_branches[[1L]], as.name("if")))
	expect_setequal(formula_labels, c("~1", "~."))
	expect_setequal(model_formulas, c("~1", "~."))
	expect_setequal(estimate_labels, "compute_estimate")
	expect_setequal(exact_labels, c("compute_exact_two_sided_pval_for_treatment_effect", "compute_exact_confidence_interval"))
	expect_setequal(both_paths, c(
		"InferenceSurvivalWeibullRegr", "InferenceSurvivalDepCensTransformRegr",
		"InferenceSurvivalCoxPHRegr", "InferenceSurvivalStratCoxPHRegr"
	))
	expect_true(all(c("Bernoulli", "KK21stepwise") %in% tested_designs))
	expect_setequal(kk_design_types, c("KK21", "KK21stepwise", "KK14", "FixedBinaryMatch"))
	available_spec_classes <- setdiff(names(source_spec)[vapply(source_spec, function(x) identical(x$rt, "survival"), logical(1))], unavailable)
	survival_spec_classes <- names(source_spec)[vapply(source_spec, function(x) identical(x$rt, "survival"), logical(1))]
	expect_setequal(intersect(survival_spec_classes, unavailable), c(
		"InferenceSurvivalKKLWACoxPHOneLik", "InferenceSurvivalKKStratCoxPHOneLik"
	))
	expect_setequal(intersect(available_spec_classes, c(direct_classes, both_paths, kk_classes)), available_spec_classes)
	expect_true("InferenceSurvivalLogRank" %in% direct_classes)
	logrank_methods <- todo10_public_method_names(testthat::test_path("..", "..", "EDI", "R", "inference_survival_log_rank.R"), "InferenceSurvivalLogRank")
	logrank_asymp_labels <- intersect(asymp_labels, logrank_methods)
	expect_setequal(logrank_asymp_labels, c(
		"compute_asymp_log_rank_two_sided_pval_for_treatment_effect",
		"compute_asymp_two_sided_pval", "compute_asymp_confidence_interval"
	))
	extra_function_runs <- data.frame(
		class_name = rep("InferenceSurvivalLogRank", length(logrank_asymp_labels)),
		function_run = logrank_asymp_labels,
		stringsAsFactors = FALSE
	)

	cases <- expand.grid(
		rep = 1:2,
		beta_T = c(0, 0.5),
		dataset = c("toy-a", "toy-b"),
		design = c("Bernoulli", "KK21stepwise"),
		design_formula = formula_labels,
		stringsAsFactors = FALSE
	)
	roster <- todo10_survival_roster(cases, source_spec, unavailable, kk_classes, kk_design_types, both_paths, estimate_labels, model_formulas, extra_function_runs)
	full_key <- c("function_run", "rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	allowed_classes <- available_spec_classes

	expect_equal(length(allowed_classes), 10L)
	expect_equal(nrow(roster), 272L)
	expect_named(roster, full_key)
	expect_equal(anyDuplicated(roster[full_key]), 0L)
	expect_true(all(roster$response_type == "survival"))
	expect_setequal(roster$function_run, c("compute_estimate", logrank_asymp_labels))
	expect_equal(sum(roster$function_run != "compute_estimate"), 48L)
	expect_true(all(!vapply(unavailable, function(x) any(startsWith(roster$inference_class, x)), logical(1))))
	expect_true("InferenceSurvivalLogRank [design_formula=~1]" %in% roster$inference_class)
	expect_true("InferenceSurvivalWeibullRegr (model_formula=~.) [design_formula=~.]" %in% roster$inference_class)
	expect_true("InferenceSurvivalGLMMWeibullFrailtyNormalOneLik [design_formula=~.]" %in% roster$inference_class)
	expect_true(any(
		roster$rep == 2L & roster$beta_T == 0.5 & roster$dataset == "toy-b" &
			roster$design == "Bernoulli" &
			roster$inference_class == "InferenceSurvivalWeibullRegr (model_formula=~.) [design_formula=~.]" &
			roster$function_run == "compute_estimate"
	))
})

test_that("survival exact-family attempt keys are empty under the runner's incidence-only guard", {
	checks <- todo10_find_function_rhs("run_inference_checks_impl")
	family_calls <- todo10_calls_named(checks, "safe_call_family")
	exact_calls <- Filter(function(x) length(x) >= 3L && identical(x[[2L]], "exact") && is.character(x[[3L]]), family_calls)
	exact_labels <- unique(vapply(exact_calls, function(x) as.character(x[[3L]]), character(1)))
	guard_branches <- Filter(function(x) {
		if (!is.call(x) || !identical(x[[1L]], as.name("if")) || length(x) < 3L) return(FALSE)
		condition <- paste(deparse(x[[2L]], width.cutoff = 500L), collapse = " ")
		branch_exact_calls <- Filter(function(call_expr) length(call_expr) >= 3L &&
			identical(call_expr[[2L]], "exact") && is.character(call_expr[[3L]]),
			todo10_calls_named(x[[3L]], "safe_call_family"))
		grepl("response_type", condition, fixed = TRUE) && grepl("incidence", condition, fixed = TRUE) &&
			setequal(vapply(branch_exact_calls, function(call_expr) as.character(call_expr[[3L]]), character(1)), exact_labels)
	}, todo10_calls_named(checks, "if"))
	full_key <- c("function_run", "rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	expected_survival_exact_keys <- data.frame(
		function_run = character(), rep = integer(), beta_T = numeric(), dataset = character(),
		response_type = character(), design = character(), inference_class = character(),
		stringsAsFactors = FALSE
	)

	expect_setequal(exact_labels, c("compute_exact_two_sided_pval_for_treatment_effect", "compute_exact_confidence_interval"))
	expect_length(guard_branches, 1L)
	expect_named(expected_survival_exact_keys, full_key)
	expect_equal(nrow(expected_survival_exact_keys), 0L)
	expect_equal(anyDuplicated(expected_survival_exact_keys[full_key]), 0L)
})

test_that("TODO-10 production case lattice is source-derived and remains setup-conditional", {
	lattice <- todo10_candidate_case_lattice(
		Nrep = 40L,
		runner_path = testthat::test_path("..", "comprehensive_tests.R"),
		dataset_path = testthat::test_path("..", "_dataset_load.R")
	)
	key_cols <- c("rep", "beta_T", "dataset", "response_type", "design", "design_formula")
	expect_equal(nrow(lattice), 20160L)
	expect_equal(anyDuplicated(lattice[key_cols]), 0L)
	expect_setequal(unique(lattice$dataset), c(
		"diamonds", "pte_example", "ionosphere", "abalone", "iris", "boston", "fuel", "cars", "airquality"
	))
	expect_setequal(unique(lattice$response_type), c("survival", "ordinal"))
	expect_equal(sum(lattice$response_type == "survival"), 10080L)
	expect_equal(sum(lattice$response_type == "ordinal"), 10080L)
	expect_equal(sum(lattice$design_formula_covariate_mode == "real_covariates"), 10080L)
	expect_equal(sum(lattice$design_formula_covariate_mode == "legacy_no_covariates"), 10080L)
	expect_setequal(unique(lattice$design), eval(todo10_top_rhs("TESTED_DESIGNS"), envir = baseenv()))
	expect_true(all(lattice$candidate_status ==
		"candidate only; requires successful dataset/design/inference setup and runtime support"))
	expect_setequal(attr(lattice, "excluded_truth_classes"), c(
		"InferenceSurvivalKKLWACoxPHOneLik", "InferenceSurvivalKKStratCoxPHOneLik"
	))
	source_spec <- eval(todo10_top_rhs("COVERAGE_MC_SPEC"), envir = baseenv())
	expect_true(all(c("InferenceSurvivalKKLWACoxPHOneLik", "InferenceSurvivalKKStratCoxPHOneLik") %in%
		names(source_spec)[vapply(source_spec, function(spec) identical(spec$rt, "survival"), logical(1))]))
	# Candidate case axes are not emitted attempts: setup, dispatch support,
	# skips, event keys, statuses, and production provenance remain empirical.
})

test_that("TODO-10 runner event keys separate started attempts from candidates and skips", {
	scratch = tempfile("edi-todo10-attempt-events-", tmpdir = tempdir())
	dir.create(scratch)
	on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

	runner_path = testthat::test_path("..", "comprehensive_tests.R")
	key_env = new.env(parent = environment())
	key_env$serialize_beta_T = eval(todo10_find_function_rhs("serialize_beta_T"), envir = key_env)
	key_env$build_result_key = eval(todo10_find_function_rhs("build_result_key"), envir = key_env)
	source(testthat::test_path("..", "comprehensive_results_path.R"), local = key_env)
	key_env$attempt_manifest_writer = key_env$new_comprehensive_attempt_manifest_writer(
		file.path(scratch, "attempt-events.csv"),
		results_file = file.path(scratch, "results.csv"),
		checkout_root = testthat::test_path("..", "..", "..")
	)
	record_event = eval(todo10_find_function_rhs("record_comprehensive_attempt_event"), envir = key_env)

	# This is one exact row from the reduced source-derived roster above. The
	# recorder is the runner's production event path; `started` is emitted only
	# after safe_call's completed/slow/confirmed-timeout skip checks.
	operation = list(
		rep_value = 2L,
		beta_value = 0.5,
		dataset_value = "toy-b",
		response_value = "survival",
		design_value = "KK21stepwise",
		inference_value = "InferenceSurvivalWeibullRegr (model_formula=~.) [design_formula=~.]"
	)
	function_run = "compute_estimate"
	do.call(record_event, c(list(event_type = "started", function_run = function_run), operation))
	do.call(record_event, c(list(event_type = "terminal", function_run = function_run, status = "ok"), operation))
	do.call(record_event, c(list(event_type = "skipped_slow", function_run = "compute_exact_confidence_interval", skip_reason = "slow_path"), operation))
	record_event(
		"setup_skipped", skip_reason = "design_setup_failed",
		rep_value = 2L, beta_value = 0.5, dataset_value = "toy-b",
		response_value = "survival", design_value = "KK21stepwise", inference_value = NA_character_
	)

	events = utils::read.csv(file.path(scratch, "attempt-events.csv"), stringsAsFactors = FALSE, na.strings = "")
	full_key = c("function_run", "rep", "beta_T", "dataset", "response_type", "design", "inference_class")
	expected_started = data.frame(
		function_run = function_run, rep = 2L, beta_T = 0.5, dataset = "toy-b",
		response_type = "survival", design = "KK21stepwise",
		inference_class = "InferenceSurvivalWeibullRegr (model_formula=~.) [design_formula=~.]",
		stringsAsFactors = FALSE
	)

	expect_identical(events$event_type, c("started", "terminal", "skipped_slow", "setup_skipped"))
	expect_equal(events[events$event_type == "started", full_key, drop = FALSE], expected_started)
	expect_identical(events$status[events$event_type == "terminal"], "ok")
	expect_identical(events$skip_reason[events$event_type == "skipped_slow"], "slow_path")
	expect_true(is.na(events$id[events$event_type == "setup_skipped"]))
	expect_identical(
		events$id[events$event_type == "started"],
		"2||5e-01||toy-b||survival||KK21stepwise||InferenceSurvivalWeibullRegr (model_formula=~.) [design_formula=~.]||compute_estimate"
	)

	# Statically pin the eligibility seam without executing safe_call (which can
	# fork and run a model): every explicit skip event precedes the started event.
	safe_call_body = todo10_find_function_rhs("safe_call")[[3L]]
	safe_call_source = paste(deparse(safe_call_body, width.cutoff = 500L), collapse = "\n")
	event_offsets = vapply(c("skipped_completed", "skipped_slow", "skipped_confirmed_timeout", "started"), function(event) {
		regexpr(paste0('record_comprehensive_attempt_event("', event, '"'), safe_call_source, fixed = TRUE)[[1L]]
	}, integer(1))
	expect_true(all(event_offsets > 0L))
	expect_true(all(diff(event_offsets) > 0L))
})
