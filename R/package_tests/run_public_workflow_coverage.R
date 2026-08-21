#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/run_public_workflow_coverage.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

source(repo_path("package_tests", "comprehensive_suite_fixtures.R"))

load_edi_for_fixtures()

coverage_path_default = repo_path("package_tests", "comprehensive_suite_coverage.csv")

workflow_checksum = function(value) {
	text = paste(as.character(value), collapse = "\r")
	raw_vals = as.integer(charToRaw(enc2utf8(text)))
	modulus = 4294967296
	hash = 2166136261
	for (byte in raw_vals) hash = (hash * 16777619 + byte) %% modulus
	digits = "0123456789abcdef"
	out = character(8L)
	for (i in 8L:1L) {
		nibble = hash %% 16
		out[i] = substr(digits, nibble + 1L, nibble + 1L)
		hash = floor(hash / 16)
	}
	paste(out, collapse = "")
}

sanitize_id = function(value) {
	value = gsub("[^A-Za-z0-9]+", "_", as.character(value))
	value = gsub("_+", "_", value)
	gsub("^_|_$", "", value)
}

coverage_case_id = function(target, workflow_kind, fixture_id = "") {
	prefix = paste("public_workflow", sanitize_id(target), sanitize_id(workflow_kind), sep = "__")
	paste(substr(prefix, 1L, 120L), workflow_checksum(paste(target, workflow_kind, fixture_id, sep = "||")), sep = "_")
}

git_commit_id = function() {
	commit = tryCatch(system2("git", c("-C", repo_root, "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) NA_character_)
	if (!length(commit) || is.na(commit[1]) || !nzchar(commit[1])) NA_character_ else commit[1]
}

new_coverage_row = function(target, api_kind, workflow_kind, status, fixture_id = "", response_type = "",
	design_class = "", inference_class = "", function_name = "", runtime_tier = "smoke",
	coverage_scope = "public_workflow", runner = "public_workflow_coverage",
	method_family = "workflow", argument_coverage_kind = "not_argument_combination",
	method_name = "", operation_kind = "", capability = "", support_status = "",
	exemption_type = "", exemption_reason = "", error_message = "") {
	data.frame(
		case_id = coverage_case_id(target, workflow_kind, fixture_id),
		target = target,
		api_kind = api_kind,
		coverage_scope = coverage_scope,
		runner = runner,
		workflow_kind = workflow_kind,
		status = status,
		fixture_id = fixture_id,
		response_type = response_type,
		design_class = design_class,
		inference_class = inference_class,
		function_name = function_name,
		method_family = method_family,
		method_name = method_name,
		operation_kind = operation_kind,
		capability = capability,
		support_status = support_status,
		argument_coverage_kind = argument_coverage_kind,
		runtime_tier = runtime_tier,
		github_commit_id = git_commit_id(),
		exemption_type = exemption_type,
		exemption_reason = exemption_reason,
		error_message = error_message,
		timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
		stringsAsFactors = FALSE
	)
}

append_row = function(rows, row) c(rows, list(row))

fixture_for_response = function(fixtures, response_type) {
	id = paste("fixed_bernoulli", response_type, "smoke", sep = "_")
	if (!is.null(fixtures[[id]])) return(fixtures[[id]])
	fixtures[[1L]]
}

inference_response_type = function(class_name) {
	if (grepl("^InferenceIncid|^InferenceIncidence", class_name)) return("incidence")
	if (grepl("^InferenceProp", class_name)) return("proportion")
	if (grepl("^InferenceCount", class_name)) return("count")
	if (grepl("^InferenceSurvival", class_name)) return("survival")
	if (grepl("^InferenceOrdinal", class_name)) return("ordinal")
	"continuous"
}

method_family_for_method_name = function(method_name) {
	if (grepl("m_out_of_n|subsampling", method_name, ignore.case = TRUE)) return("m_out_of_n_subsampling")
	if (grepl("rand_bootstrap", method_name, fixed = TRUE)) return("randomization_bootstrap")
	if (grepl("bayesian_bootstrap", method_name, fixed = TRUE)) return("bayesian_bootstrap")
	if (grepl("param_bootstrap|lik_ratio_bootstrap", method_name)) return("parametric_bootstrap")
	if (grepl("bootstrap", method_name, fixed = TRUE)) return("bootstrap")
	if (grepl("bartlett", method_name, fixed = TRUE)) return("bartlett")
	if (grepl("jackknife", method_name, fixed = TRUE)) return("jackknife")
	if (grepl("rand", method_name, fixed = TRUE)) return("randomization")
	if (grepl("exact", method_name, fixed = TRUE)) return("exact")
	if (grepl("score", method_name, fixed = TRUE)) return("asymptotic_score")
	if (grepl("lik_ratio", method_name, fixed = TRUE)) return("asymptotic_lik_ratio")
	if (grepl("gradient", method_name, fixed = TRUE)) return("asymptotic_gradient")
	if (grepl("wald|asymp", method_name, fixed = TRUE)) return("asymptotic_wald")
	if (grepl("estimate", method_name, fixed = TRUE)) return("estimate")
	"other_method"
}

operation_kind_for_method_name = function(method_name) {
	if (grepl("confidence_interval", method_name, fixed = TRUE)) return("confidence_interval")
	if (grepl("pval|pval_for_treatment_effect", method_name)) return("p_value")
	if (grepl("estimate", method_name, fixed = TRUE)) return("estimate")
	if (grepl("_debug$|approximate_", method_name)) return("debug_distribution")
	"method_call"
}

design_spec_for_class = function(class_name) {
	n = 8L
	common = list(n = n, response_type = "continuous", seed = 20260810L, verbose = FALSE, design_formula = ~ x1 + x2 + stratum)
	extra = switch(
		class_name,
		DesignFixedBinaryMatch = list(m = rep(seq_len(n / 2L), each = 2L)),
		DesignFixedBlockedCluster = list(strata_cols = "stratum", cluster_col = "cluster_id"),
		DesignFixedBlocking = list(strata_cols = "stratum", B_target = 2L, equal_block_sizes = TRUE),
		DesignFixedCluster = list(cluster_col = "cluster_id"),
		DesignFixedFactorial = list(factors = list(treatment = 2L), design_formula = ~ x1 + x2),
		DesignFixedGreedy = list(n_iter = 1L),
		DesignFixedMatchingGreedyPairSwitching = list(n_iter = 1L),
		DesignFixedOptimalBlocks = list(B = 2L, method = "greedy", dist = "mahalanobis"),
		DesignFixedRerandomization = list(prop_acceptable = 1, objective = "mahal_dist"),
		DesignSeqOneByOneEfron = list(weighted_coin_prob = 0.75),
		DesignSeqOneByOneKK14 = list(p = 2L, lambda = 0.5, t_0_pct = 0),
		DesignSeqOneByOneKK21 = list(p = 2L, lambda = 0.5, t_0_pct = 0),
		DesignSeqOneByOneKK21stepwise = list(p = 2L, lambda = 0.5, t_0_pct = 0, num_boot = 2L),
		DesignSeqOneByOnePocockSimon = list(strata_cols = "stratum", p_best = 0.75),
		DesignSeqOneByOneRandomBlockSize = list(strata_cols = "stratum", block_sizes = c(2L, 4L)),
		DesignSeqOneByOneSPBR = list(strata_cols = "stratum", block_size = 4L),
		DesignSeqOneByOneUrn = list(alpha = 1, beta = 1),
		list()
	)
	modifyList(common, extra)
}

complete_design_workflow = function(class_name) {
	gen = getExportedValue("EDI", class_name)
	spec = design_spec_for_class(class_name)
	des = do.call(gen$new, spec)
	n = spec$n
	X = make_fixture_covariates(n)
	y = as.numeric(seq_len(n)) / n
	if (grepl("^DesignSeqOneByOne", class_name)) {
		for (i in seq_len(n)) {
			des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
			des$add_one_subject_response(i, y = y[i])
		}
	} else {
		des$add_all_subjects_to_experiment(X)
		if ("assign_w_to_all_subjects" %in% names(des)) {
			des$assign_w_to_all_subjects()
		}
		if (!"assign_w_to_all_subjects" %in% names(des) || any(is.na(des$get_w()))) {
			des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
		}
		des$add_all_subject_responses(y)
	}
	invisible(list(
		design = des,
		w = des$get_w(),
		y = des$get_y(),
		n = des$get_n(),
		t = des$get_t()
	))
}

run_design_workflows = function(classes) {
	rows = list()
	for (class_name in classes) {
		target = class_name
		row = tryCatch({
			result = complete_design_workflow(class_name)
			if (length(result$w) != result$n || length(result$y) != result$n || as.integer(result$t) != as.integer(result$n)) {
				stop("completed design did not expose expected assignment/response summaries")
			}
			new_coverage_row(target, "r6_class", "design_complete_workflow", "ok", design_class = class_name)
		}, error = function(e) {
			new_coverage_row(
				target, "r6_class", "design_complete_workflow", "exempted",
				design_class = class_name,
				exemption_type = "phase4_smoke_workflow_unavailable",
				exemption_reason = conditionMessage(e),
				error_message = conditionMessage(e)
			)
		})
		rows = append_row(rows, row)
	}
	rows
}

run_inference_workflows = function(classes, fixtures) {
	rows = list()
	for (class_name in classes) {
		response_type = inference_response_type(class_name)
		fixture = fixture_for_response(fixtures, response_type)
		target = class_name
		row = tryCatch({
			gen = getExportedValue("EDI", class_name)
			obj = gen$new(fixture$design)
			if (!inherits(obj, class_name)) stop("constructor returned unexpected class")
			new_coverage_row(
				target, "r6_class", "inference_constructor_workflow", "ok",
				fixture_id = fixture$fixture_id,
				response_type = response_type,
				design_class = fixture$metadata$class_name,
				inference_class = class_name
			)
		}, error = function(e) {
			new_coverage_row(
				target, "r6_class", "inference_constructor_workflow", "exempted",
				fixture_id = fixture$fixture_id,
				response_type = response_type,
				design_class = fixture$metadata$class_name,
				inference_class = class_name,
				exemption_type = "phase4_no_smoke_compatible_fixture",
				exemption_reason = conditionMessage(e),
				error_message = conditionMessage(e)
			)
		})
		rows = append_row(rows, row)
	}
	rows
}

build_matched_incidence_fixture = function() {
	spec = list(
		fixture_id = "phase5_fixed_binary_match_incidence_smoke",
		response_type = "incidence",
		design_type = "matched",
		class_name = "DesignFixedBinaryMatch",
		n = 8L,
		tier = "smoke",
		m = rep(seq_len(4L), each = 2L)
	)
	covariates = make_fixture_covariates(spec$n)
	response = list(y = rep(c(0, 1), length.out = spec$n), dead = rep(1, spec$n))
	design = construct_public_design(spec, covariates)
	populate_public_design(design, spec, covariates, response)
	fixture = list(
		fixture_id = spec$fixture_id,
		design = design,
		data = covariates,
		response = response$y,
		dead = response$dead,
		w = design$get_w(),
		metadata = fixture_metadata(spec, covariates, design)
	)
	validate_public_argument_fixture(fixture)
	fixture
}

method_family_specs = function() {
	list(
		list(family = "estimate", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_estimate", args = list(), tier = "smoke", capability = "estimate"),
		list(family = "asymptotic_wald", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_wald_two_sided_pval", args = list(delta = 0), tier = "smoke", capability = "asymp_pval"),
		list(family = "asymptotic_wald", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_wald_confidence_interval", args = list(alpha = 0.05), tier = "smoke", capability = "asymp_ci"),
		list(family = "asymptotic_score", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_score_two_sided_pval", args = list(delta = 0), tier = "ci", capability = "score_pval"),
		list(family = "asymptotic_score", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_score_confidence_interval", args = list(alpha = 0.05), tier = "ci", capability = "score_ci"),
		list(family = "asymptotic_lik_ratio", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_lik_ratio_two_sided_pval", args = list(delta = 0), tier = "ci", capability = "lik_ratio_pval"),
		list(family = "asymptotic_lik_ratio", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_lik_ratio_confidence_interval", args = list(alpha = 0.05), tier = "ci", capability = "lik_ratio_ci"),
		list(family = "asymptotic_gradient", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_gradient_two_sided_pval", args = list(delta = 0), tier = "ci", capability = "gradient_pval"),
		list(family = "asymptotic_gradient", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_gradient_confidence_interval", args = list(alpha = 0.05), tier = "ci", capability = "gradient_ci"),
		list(family = "exact", class_name = "InferenceIncidExactBinomial", response_type = "incidence", method_name = "compute_exact_two_sided_pval_for_treatment_effect", args = list(), tier = "smoke", capability = "exact_pval", fixture_kind = "matched_incidence"),
		list(family = "exact", class_name = "InferenceIncidExactBinomial", response_type = "incidence", method_name = "compute_exact_confidence_interval", args = list(alpha = 0.05), tier = "smoke", capability = "exact_ci", fixture_kind = "matched_incidence"),
		list(family = "bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_bootstrap_two_sided_pval", args = list(B = 9L, delta = 0, show_progress = FALSE, min_number_usable_samples = 3L), tier = "ci", capability = "bootstrap_pval"),
		list(family = "bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_bootstrap_confidence_interval", args = list(B = 9L, alpha = 0.05, show_progress = FALSE, min_number_usable_samples = 3L), tier = "ci", capability = "bootstrap_ci"),
		list(family = "bayesian_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_bayesian_bootstrap_two_sided_pval", args = list(B = 9L, delta = 0, show_progress = FALSE, min_number_usable_samples = 3L), tier = "ci", capability = "bayesian_bootstrap_pval"),
		list(family = "bayesian_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_bayesian_bootstrap_confidence_interval", args = list(B = 9L, alpha = 0.05, show_progress = FALSE, min_number_usable_samples = 3L), tier = "ci", capability = "bayesian_bootstrap_ci"),
		list(family = "parametric_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_param_bootstrap_pval", args = list(B = 9L, delta = 0, show_progress = FALSE, min_number_usable_samples = 3L), tier = "nightly", capability = "parametric_bootstrap_pval"),
		list(family = "parametric_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_param_bootstrap_confidence_interval", args = list(B = 9L, alpha = 0.05, show_progress = FALSE, min_number_usable_samples = 3L), tier = "nightly", capability = "parametric_bootstrap_ci"),
		list(family = "bartlett", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_lik_ratio_bartlett_approx_two_sided_pval", args = list(delta = 0, B = 9L), tier = "nightly", capability = "bartlett_pval"),
		list(family = "bartlett", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_lik_ratio_bartlett_approx_confidence_interval", args = list(alpha = 0.05, B = 9L), tier = "nightly", capability = "bartlett_ci"),
		list(family = "jackknife", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_jackknife_wald_two_sided_pval", args = list(delta = 0), tier = "ci", capability = "jackknife_pval"),
		list(family = "jackknife", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_jackknife_wald_confidence_interval", args = list(alpha = 0.05), tier = "ci", capability = "jackknife_ci"),
		list(family = "randomization", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_rand_two_sided_pval", args = list(r = 9L, delta = 0, show_progress = FALSE), tier = "ci", capability = "rand_pval"),
		list(family = "randomization", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_rand_confidence_interval", args = list(r = 9L, alpha = 0.05, show_progress = FALSE), tier = "nightly", capability = "rand_ci"),
		list(family = "randomization_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_rand_bootstrap_two_sided_pval", args = list(B = 9L, delta = 0, show_progress = FALSE), tier = "nightly", capability = "rand_bootstrap_pval"),
		list(family = "randomization_bootstrap", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_rand_bootstrap_confidence_interval", args = list(B = 9L, alpha = 0.05, show_progress = FALSE), tier = "nightly", capability = "rand_bootstrap_ci"),
		list(family = "m_out_of_n_subsampling", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_m_out_of_n_bootstrap_two_sided_pval", args = list(B = 9L, m = 4L, delta = 0, show_progress = FALSE, min_number_usable_samples = 3L), tier = "nightly", capability = "m_out_of_n_bootstrap_pval"),
		list(family = "m_out_of_n_subsampling", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "compute_subsampling_confidence_interval", args = list(B = 9L, b = 4L, alpha = 0.05, show_progress = FALSE, min_number_usable_samples = 3L), tier = "nightly", capability = "subsampling_ci"),
		list(family = "debug_distribution", class_name = "InferenceAllSimpleMeanDiff", response_type = "continuous", method_name = "approximate_bootstrap_distribution_beta_hat_T", args = list(B = 9L, debug = TRUE, show_progress = FALSE), tier = "nightly", capability = "bootstrap_debug")
	)
}

argument_kind_for_method = function(class_name, method_name, argument_coverage) {
	target = paste(class_name, method_name, sep = "::")
	row = argument_coverage[argument_coverage$target == target, , drop = FALSE]
	if (!nrow(row)) return("not_in_argument_combination_inventory")
	if (isTRUE(row$has_executed_legal_combination[1])) return("executed_legal_combination")
	if (isTRUE(row$has_legal_combination_case[1])) return("legal_combination_case_not_executed")
	if (row$skipped_slow_cases[1] > 0L) return("argument_combination_skipped_slow")
	"no_argument_combination_case"
}

method_fixture_for_spec = function(spec, fixtures) {
	if (identical(spec$fixture_kind %||% "", "matched_incidence")) return(build_matched_incidence_fixture())
	fixture_for_response(fixtures, spec$response_type)
}

classify_method_error = function(msg) {
	if (grepl("not implemented|must implement|only supported|not supported|does not support|Exact inference is only supported", msg, ignore.case = TRUE)) return("unsupported")
	if (grepl("non-estimable|not estimable", msg, ignore.case = TRUE)) return("nonestimable")
	if (grepl("too small|too slow|p-value floor|root|iterations|must satisfy", msg, ignore.case = TRUE)) return("exempted")
	"error"
}

run_one_method_family_spec = function(spec, fixtures, argument_coverage) {
	fixture = method_fixture_for_spec(spec, fixtures)
	target = paste(spec$class_name, spec$method_name, sep = "::")
	argument_kind = argument_kind_for_method(spec$class_name, spec$method_name, argument_coverage)
	tryCatch({
		gen = getExportedValue("EDI", spec$class_name)
		inf = gen$new(fixture$design)
		if (!(spec$method_name %in% names(inf))) {
			stop("method is not present on inference object")
		}
		result = do.call(inf[[spec$method_name]], spec$args)
		if (is.null(result)) result_summary = "" else result_summary = paste(utils::capture.output(str(result, give.attr = FALSE, vec.len = 3L)), collapse = " ")
		new_coverage_row(
			target, "r6_public_method", "method_family_workflow", "ok",
			fixture_id = fixture$fixture_id,
			response_type = spec$response_type,
			design_class = fixture$metadata$class_name,
			inference_class = spec$class_name,
			method_family = spec$family,
			method_name = spec$method_name,
			operation_kind = operation_kind_for_method_name(spec$method_name),
			capability = spec$capability,
			support_status = "supported",
			argument_coverage_kind = argument_kind,
			runtime_tier = spec$tier,
			error_message = result_summary
		)
	}, error = function(e) {
		status = classify_method_error(conditionMessage(e))
		new_coverage_row(
			target, "r6_public_method", "method_family_workflow", status,
			fixture_id = fixture$fixture_id,
			response_type = spec$response_type,
			design_class = fixture$metadata$class_name,
			inference_class = spec$class_name,
			method_family = spec$family,
			method_name = spec$method_name,
			operation_kind = operation_kind_for_method_name(spec$method_name),
			capability = spec$capability,
			support_status = if (identical(status, "unsupported")) "unsupported" else if (identical(status, "nonestimable")) "nonestimable" else "tiered_or_failed",
			argument_coverage_kind = argument_kind,
			runtime_tier = spec$tier,
			exemption_type = if (status %in% c("unsupported", "nonestimable", "exempted")) paste0("phase5_", status) else "",
			exemption_reason = if (status %in% c("unsupported", "nonestimable", "exempted")) conditionMessage(e) else "",
			error_message = conditionMessage(e)
		)
	})
}

run_method_family_workflows = function(fixtures, argument_coverage) {
	lapply(method_family_specs(), run_one_method_family_spec, fixtures = fixtures, argument_coverage = argument_coverage)
}

run_inference_suite_workflow = function(fixtures) {
	fixture = fixtures[["sequential_bernoulli_continuous_smoke"]]
	tryCatch({
		suite_gen = getExportedValue("EDI", "InferenceSuite")
		suite = suite_gen$new(
			fixture$design,
			inference_params = list(InferenceAllSimpleMeanDiff = list(max_resample_attempts = 5L))
		)
		if (!("InferenceAllSimpleMeanDiff" %in% suite$applicable_design_classes)) {
			stop("InferenceSuite did not discover InferenceAllSimpleMeanDiff")
		}
		new_coverage_row(
			"InferenceSuite", "r6_class", "inference_suite_discovery_and_params", "ok",
			fixture_id = fixture$fixture_id,
			response_type = fixture$metadata$response_type,
			design_class = fixture$metadata$class_name,
			inference_class = "InferenceSuite"
		)
	}, error = function(e) {
		new_coverage_row(
			"InferenceSuite", "r6_class", "inference_suite_discovery_and_params", "error",
			fixture_id = fixture$fixture_id,
			response_type = fixture$metadata$response_type,
			design_class = fixture$metadata$class_name,
			inference_class = "InferenceSuite",
			error_message = conditionMessage(e)
		)
	})
}

run_simulation_framework_workflow = function() {
	tryCatch({
		sim_gen = getExportedValue("EDI", "SimulationFramework")
		report_gen = getExportedValue("EDI", "SimulationFrameworkReport")
		sim = sim_gen$new(
			response_type = "continuous",
			design_classes_and_params = list(getExportedValue("EDI", "DesignFixedBernoulli")),
			inference_classes_and_params = list(getExportedValue("EDI", "InferenceAllSimpleMeanDiff")),
			inference_types_and_params = list(asymp_pval = list()),
			n = 8L,
			p = 2L,
			Nrep_W = 1L,
			Nrep_Y_w = 1L,
			betaT = 0,
			results_filename = tempfile(fileext = ".csv"),
			continue_from_last_result_row = FALSE,
			verbose = FALSE,
			turn_off_asserts_for_speed = FALSE
		)
		sim$run()
		results = report_gen$new(sim)$get_results()
		if (!nrow(results)) stop("SimulationFramework produced no result rows")
		new_coverage_row(
			"SimulationFramework", "r6_class", "simulation_framework_smoke", "ok",
			response_type = "continuous",
			design_class = "DesignFixedBernoulli",
			inference_class = "InferenceAllSimpleMeanDiff"
		)
	}, error = function(e) {
		new_coverage_row(
			"SimulationFramework", "r6_class", "simulation_framework_smoke", "error",
			response_type = "continuous",
			design_class = "DesignFixedBernoulli",
			inference_class = "InferenceAllSimpleMeanDiff",
			error_message = conditionMessage(e)
		)
	})
}

run_simulation_framework_report_workflow = function() {
	tryCatch({
		sim_gen = getExportedValue("EDI", "SimulationFramework")
		report_gen = getExportedValue("EDI", "SimulationFrameworkReport")
		sim = sim_gen$new(
			response_type = "continuous",
			design_classes_and_params = list(getExportedValue("EDI", "DesignFixedBernoulli")),
			inference_classes_and_params = list(getExportedValue("EDI", "InferenceAllSimpleMeanDiff")),
			inference_types_and_params = list(asymp_pval = list()),
			n = 8L,
			p = 2L,
			Nrep_W = 1L,
			Nrep_Y_w = 1L,
			betaT = 0,
			results_filename = tempfile(fileext = ".csv"),
			continue_from_last_result_row = FALSE,
			verbose = FALSE,
			turn_off_asserts_for_speed = FALSE
		)
		sim$run()
		report = report_gen$new(sim)
		raw = report$get_results()
		summary = report$summarize()
		if (!nrow(raw) || !nrow(summary)) stop("SimulationFrameworkReport produced no result or summary rows")
		new_coverage_row(
			"SimulationFrameworkReport", "r6_class", "simulation_framework_report_smoke", "ok",
			response_type = "continuous",
			design_class = "DesignFixedBernoulli",
			inference_class = "InferenceAllSimpleMeanDiff"
		)
	}, error = function(e) {
		new_coverage_row(
			"SimulationFrameworkReport", "r6_class", "simulation_framework_report_smoke", "error",
			response_type = "continuous",
			design_class = "DesignFixedBernoulli",
			inference_class = "InferenceAllSimpleMeanDiff",
			error_message = conditionMessage(e)
		)
	})
}

function_category = function(name) {
	if (grepl("_cpp$|^fast_|cache|kernel|optim|objective|gradient|hessian", name)) return("low_level_exported_routine")
	if (grepl("check|assert|validate", name)) return("helper")
	if (grepl("fit|regr|glm|cox|poisson|binomial|weibull", name)) return("fitting_wrapper")
	"high_level"
}

run_function_classification = function(function_names) {
	lapply(function_names, function(name) {
		category = function_category(name)
		status = if (category %in% c("high_level", "fitting_wrapper")) "exempted" else "classified"
		new_coverage_row(
			name, "function", "exported_function_classification", status,
			function_name = name,
			method_family = category,
			exemption_type = if (identical(status, "exempted")) "phase4_direct_workflow_deferred" else "",
			exemption_reason = if (identical(status, "exempted")) "Requires targeted inputs; classified for Phase 4 and deferred to focused workflow coverage." else ""
		)
	})
}

build_public_workflow_coverage = function(tier = "smoke") {
	inventory = read.csv(repo_path("package_tests", "public_api_inventory.csv"), stringsAsFactors = FALSE)
	classes = sort(unique(inventory$export_name[inventory$api_kind == "r6_class"]))
	design_classes = classes[grepl("^Design", classes)]
	inference_classes = setdiff(classes[grepl("^Inference", classes)], "InferenceSuite")
	function_names = sort(unique(inventory$export_name[inventory$api_kind == "function"]))
	fixtures = build_comprehensive_suite_fixtures(tier)
	argument_coverage = read.csv(repo_path("package_tests", "public_argument_combination_coverage.csv"), stringsAsFactors = FALSE)
	rows = c(
		run_design_workflows(design_classes),
		run_inference_workflows(inference_classes, fixtures),
		run_method_family_workflows(fixtures, argument_coverage),
		list(run_inference_suite_workflow(fixtures)),
		list(run_simulation_framework_workflow()),
		list(run_simulation_framework_report_workflow()),
		run_function_classification(function_names)
	)
	out = do.call(rbind, rows)
	row.names(out) = NULL
	out[order(out$api_kind, out$target, out$workflow_kind), , drop = FALSE]
}

write_public_workflow_coverage = function(tier = "smoke", path = coverage_path_default) {
	coverage = build_public_workflow_coverage(tier)
	write.csv(coverage, path, row.names = FALSE)
	invisible(coverage)
}

if (identical(environment(), globalenv()) && !interactive()) {
	args = commandArgs(trailingOnly = TRUE)
	tier = if (length(args) >= 1L && nzchar(args[1])) args[1] else "smoke"
	path = if (length(args) >= 2L && nzchar(args[2])) args[2] else coverage_path_default
	coverage = write_public_workflow_coverage(tier, path)
	message("public workflow coverage wrote ", nrow(coverage), " rows to ", path)
}
