#!/usr/bin/env Rscript

`%||%` = function(x, y) if (is.null(x)) y else x

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% "package_tests/generate_public_argument_combinations.R")
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "public_argument_combination_constraints.R"))
source(file.path(repo_root, "package_tests", "public_argument_combination_fixtures.R"))

generator_tier_rank = c(smoke = 1L, ci = 2L, nightly = 3L, release = 4L)

registry_path = file.path(repo_root, "package_tests", "public_argument_contract_registry.rds")
cases_path = file.path(repo_root, "package_tests", "public_argument_combination_cases.csv")
rejected_path = file.path(repo_root, "package_tests", "public_argument_combination_rejected_candidates.csv")
coverage_path = file.path(repo_root, "package_tests", "public_argument_combination_coverage.csv")

default_smoke_target_filter = paste(
	"^InferenceAllSimpleAverageDiff::compute_bootstrap_confidence_interval$",
	"^DesignFixedBernoulli::add_all_subject_responses$",
	sep = "|"
)

default_smoke_fixture_ids = c(
	"fixed_bernoulli_continuous_smoke",
	"fixed_bernoulli_survival_censored_smoke"
)

read_registry = function(path = registry_path) {
	if (!file.exists(path)) {
		stop("Missing package_tests/public_argument_contract_registry.rds. Run Phase 2 first.", call. = FALSE)
	}
	readRDS(path)
}

tier_allows = function(value_tier, requested_tier) {
	value_rank = generator_tier_rank[[value_tier]]
	request_rank = generator_tier_rank[[requested_tier]]
	!is.null(value_rank) && !is.null(request_rank) && !is.na(value_rank) && !is.na(request_rank) && value_rank <= request_rank
}

target_response_family = function(entry) {
	txt = paste(entry$target %||% "", entry$class_name %||% "", entry$api_name %||% "", sep = " ")
	if (grepl("Survival|surv", txt, ignore.case = TRUE)) return("survival")
	if (grepl("Ordinal|ordinal", txt, ignore.case = TRUE)) return("ordinal")
	if (grepl("Count|count|Poisson|NegBin|Hurdle", txt, ignore.case = TRUE)) return("count")
	if (grepl("Prop|proportion|Beta", txt, ignore.case = TRUE)) return("proportion")
	if (grepl("Incid|incidence|Logit|Probit|Binomial|Risk", txt, ignore.case = TRUE)) return("incidence")
	if (grepl("Contin|continuous|Robust|Quantile|Mean", txt, ignore.case = TRUE)) return("continuous")
	NA_character_
}

target_design_type = function(entry) {
	txt = paste(entry$target %||% "", entry$class_name %||% "", entry$api_name %||% "", sep = " ")
	if (grepl("BlockedCluster|blocked_cluster", txt, ignore.case = TRUE)) return("blocked_cluster")
	if (grepl("Cluster", txt, ignore.case = TRUE)) return("clustered")
	if (grepl("Blocking|Blocks|CMH|Robins", txt, ignore.case = TRUE)) return("stratified")
	if (grepl("BinaryMatch|Matching", txt, ignore.case = TRUE)) return("matched")
	if (grepl("Greedy|Optimal|AOptimal", txt, ignore.case = TRUE)) return("search")
	if (grepl("SeqOneByOne|KK14|KK21|Efron|Atkinson", txt, ignore.case = TRUE)) return("sequential")
	if (grepl("Factorial", txt, ignore.case = TRUE)) return("factorial")
	if (grepl("Fixed", txt, ignore.case = TRUE)) return("fixed")
	NA_character_
}

is_high_priority_target = function(entry) {
	method = entry$method_name %||% ""
	method %in% high_priority_fixture_methods ||
		grepl("bootstrap|bayesian_bootstrap|rand|asymp", method, ignore.case = TRUE)
}

has_extra_constraints = function(entry) {
	constraints = entry$constraints %||% character()
	any(nzchar(constraints) & constraints != "no_extra_combination_constraints")
}

compatible_fixtures = function(entry, fixtures) {
	family = target_response_family(entry)
	design_type = target_design_type(entry)
	hits = fixtures
	if (!is.na(family)) {
		hits = hits[vapply(hits, function(fixture) identical(fixture$metadata$response_type, family), logical(1))]
	}
	if (!is.na(design_type)) {
		design_hits = hits[vapply(hits, function(fixture) identical(fixture$metadata$design_type, design_type), logical(1))]
		if (length(design_hits)) hits = design_hits
	}
	if (!length(hits)) {
		fallback = fixtures[vapply(fixtures, function(fixture) identical(fixture$metadata$fixture_id, "fixed_bernoulli_continuous_smoke"), logical(1))]
		if (length(fallback)) return(fallback)
		return(fixtures[seq_len(min(1L, length(fixtures)))])
	}
	hits[seq_len(min(2L, length(hits)))]
}

domain_values = function(domain, tier, include_any_if_empty = TRUE) {
	if (!nrow(domain)) return(domain)
	allowed = domain[vapply(domain$tier, tier_allows, logical(1), requested_tier = tier), , drop = FALSE]
	if (!nrow(allowed) && isTRUE(include_any_if_empty)) {
		allowed = domain[1L, , drop = FALSE]
	}
	row.names(allowed) = NULL
	allowed
}

default_domain_row = function(domain, tier) {
	if (!nrow(domain)) return(domain)
	default = domain[domain$label == "default", , drop = FALSE]
	if (nrow(default)) return(default[1L, , drop = FALSE])
	allowed = domain_values(domain, tier)
	allowed[1L, , drop = FALSE]
}

non_default_domain_rows = function(domain, tier, max_values = 3L) {
	rows = domain_values(domain, tier, include_any_if_empty = FALSE)
	rows = rows[rows$label != "default", , drop = FALSE]
	if (!nrow(rows)) return(rows)
	rows[seq_len(min(max_values, nrow(rows))), , drop = FALSE]
}

fixture_arg_expr = function(arg, value_expr) {
	if (arg %in% c("X_all", "X", "data", "newdata")) return("<fixture:data.frame>")
	if (arg %in% c("ys", "y")) return("<fixture:response>")
	if (arg %in% c("deads", "dead")) return("<fixture:dead>")
	if (arg == "y_Ls") return("<fixture:response_y_L>")
	if (arg == "y_Rs") return("<fixture:response_y_R>")
	if (arg %in% c("w", "w_precomputed")) return("<fixture:w>")
	if (arg %in% c("m", "m_vec")) return("<fixture:m>")
	# DesignFixedFactorial's factor-level list, not the covariates (<fixture:list>): the class accepts only
	# levels whose product is 2.
	if (arg == "factors") return("<fixture:factors>")
	value_expr
}

eval_value_expr = function(value_expr, fixture) {
	value_expr = trimws(as.character(value_expr))
	if (!nzchar(value_expr)) return(NULL)
	if (value_expr == "NULL") return(NULL)
	if (grepl("^<fixture:", value_expr)) {
		kind = sub("^<fixture:([^>]+)>$", "\\1", value_expr)
		if (kind == "data.frame") return(fixture$data)
		if (kind == "matrix") return(as.matrix(fixture$data))
		if (kind == "list") return(as.list(fixture$data))
		if (kind == "factors") return(list(treatment = 2))
		if (kind == "string") return(fixture$fixture_id)
		if (kind == "response") return(ifelse(fixture$dead == 1, fixture$response, NA_real_))
		if (kind == "response_y_L") return(ifelse(fixture$dead == 1, NA_real_, fixture$response))
		if (kind == "response_y_R") return(ifelse(fixture$dead == 1, NA_real_, Inf))
		if (kind == "dead") return(fixture$dead)
		if (kind == "w") return(fixture$w)
		if (kind == "m") return(rep(seq_len(ceiling(fixture$metadata$n / 2L)), each = 2L)[seq_len(fixture$metadata$n)])
		if (kind == "no_censoring") return(!fixture$metadata$has_censoring)
		if (startsWith(kind, "custom_stat_")) return(custom_statistic_value(sub("^custom_stat_", "", kind)))
		return(fixture)
	}
	if (grepl("^~", value_expr)) return(stats::as.formula(value_expr))
	tryCatch(eval(parse(text = value_expr), envir = baseenv()), error = function(e) value_expr)
}

signature_from_exprs = function(exprs) {
	if (!length(exprs)) return("<default>")
	paste(paste(names(exprs), exprs, sep = "="), collapse = ";")
}

stable_checksum = function(x) {
	ints = utf8ToInt(enc2utf8(x))
	if (!length(ints)) return("00000000")
	acc = 0
	for (i in seq_along(ints)) {
		acc = (acc * 33 + ints[i]) %% 4294967291
	}
	sprintf("%08x", as.integer(acc %% 2147483647))
}

case_id_for = function(entry, fixture_id, coverage_kind, signature) {
	prefix = gsub("[^A-Za-z0-9]+", "_", paste(entry$target, fixture_id, coverage_kind, sep = "__"))
	prefix = gsub("_+", "_", prefix)
	prefix = substr(prefix, 1L, 120L)
	paste(prefix, stable_checksum(signature), sep = "_")
}

case_candidate = function(entry, fixture, tier, coverage_kind, value_rows_by_arg) {
	exprs = vapply(value_rows_by_arg, function(row) row$value_expr[1L], character(1))
	exprs = mapply(fixture_arg_expr, names(exprs), exprs, USE.NAMES = TRUE)
	labels = vapply(value_rows_by_arg, function(row) row$label[1L], character(1))
	args = lapply(exprs, eval_value_expr, fixture = fixture)
	names(args) = names(exprs)
	signature = signature_from_exprs(exprs)
	constraint = constraint_context_result(args = args, fixture = fixture$metadata, tier = tier, registry_entry = entry)
	data.frame(
		case_id = case_id_for(entry, fixture$fixture_id, coverage_kind, signature),
		api_kind = entry$api_kind %||% "",
		class_name = entry$class_name %||% "",
		function_name = if (nzchar(entry$method_name %||% "")) "" else entry$api_name %||% "",
		method_name = entry$method_name %||% "",
		fixture_id = fixture$fixture_id,
		tier = tier,
		argument_signature = signature,
		argument_labels = signature_from_exprs(labels),
		argument_coverage_kind = coverage_kind,
		source_contracts = paste(entry$source_contract_lines %||% character(), collapse = ";"),
		constraint_status = constraint$status,
		constraint_reason = constraint$reason,
		constraint_sources = paste(unique(constraint$results$source[constraint$results$status != "valid"]), collapse = ";"),
		target = entry$target %||% "",
		invariants = paste(entry$invariants %||% character(), collapse = ";"),
		stringsAsFactors = FALSE
	)
}

default_case_values = function(entry, tier) {
	rows = lapply(entry$domains, default_domain_row, tier = tier)
	names(rows) = names(entry$domains)
	rows
}

one_nondefault_candidates = function(entry, tier) {
	defaults = default_case_values(entry, tier)
	out = list()
	for (arg in names(entry$domains)) {
		rows = non_default_domain_rows(entry$domains[[arg]], tier, max_values = 1L)
		if (!nrow(rows)) next
		vals = defaults
		vals[[arg]] = rows[1L, , drop = FALSE]
		out[[length(out) + 1L]] = vals
	}
	out
}

pairwise_candidates = function(entry, tier, max_values_per_arg = 3L, max_candidates = 24L) {
	if (length(entry$domains) < 2L) return(list())
	defaults = default_case_values(entry, tier)
	values = lapply(entry$domains, non_default_domain_rows, tier = tier, max_values = max_values_per_arg)
	values = values[vapply(values, nrow, integer(1)) > 0L]
	if (length(values) < 2L) return(list())
	out = list()
	arg_pairs = utils::combn(names(values), 2L, simplify = FALSE)
	for (pair in arg_pairs) {
		left = values[[pair[1L]]]
		right = values[[pair[2L]]]
		grid = expand.grid(i = seq_len(nrow(left)), j = seq_len(nrow(right)))
		for (k in seq_len(nrow(grid))) {
			vals = defaults
			vals[[pair[1L]]] = left[grid$i[k], , drop = FALSE]
			vals[[pair[2L]]] = right[grid$j[k], , drop = FALSE]
			out[[length(out) + 1L]] = vals
			if (length(out) >= max_candidates) return(out)
		}
	}
	out
}

targeted_three_way_candidates = function(entry, tier) {
	high_risk_sets = list(
		c("type", "B", "min_number_usable_samples"),
		c("type", "B", "show_progress"),
		c("model_formula", "transform_responses", "type"),
		c("strata_cols", "cluster_col", "B")
	)
	defaults = default_case_values(entry, tier)
	out = list()
	for (arg_set in high_risk_sets) {
		if (!all(arg_set %in% names(entry$domains))) next
		vals = defaults
		for (arg in arg_set) {
			rows = non_default_domain_rows(entry$domains[[arg]], tier, max_values = 1L)
			if (nrow(rows)) vals[[arg]] = rows[1L, , drop = FALSE]
		}
		out[[length(out) + 1L]] = vals
	}
	out
}

tiny_exhaustive_candidates = function(entry, tier, max_cases = 16L) {
	if (length(entry$domains) == 0L || length(entry$domains) > 3L) return(list())
	values = lapply(entry$domains, domain_values, tier = tier, include_any_if_empty = FALSE)
	if (any(vapply(values, nrow, integer(1)) == 0L)) return(list())
	total = prod(vapply(values, nrow, integer(1)))
	if (total > max_cases) return(list())
	grid = expand.grid(lapply(values, function(x) seq_len(nrow(x))))
	out = vector("list", nrow(grid))
	for (i in seq_len(nrow(grid))) {
		vals = Map(function(domain, idx) domain[idx, , drop = FALSE], values, grid[i, ])
		names(vals) = names(values)
		out[[i]] = vals
	}
	out
}

dedupe_cases = function(cases) {
	if (!nrow(cases)) return(cases)
	keys = paste(cases$case_id, cases$argument_coverage_kind, sep = "\r")
	cases[!duplicated(keys), , drop = FALSE]
}

generate_cases_for_entry = function(entry, fixtures, tier) {
	fixtures = compatible_fixtures(entry, fixtures)
	rows = list()
	expand_combinations = has_extra_constraints(entry) || is_high_priority_target(entry)
	for (fixture in fixtures) {
		rows[[length(rows) + 1L]] = case_candidate(entry, fixture, tier, "default", default_case_values(entry, tier))
		for (vals in one_nondefault_candidates(entry, tier)) {
			rows[[length(rows) + 1L]] = case_candidate(entry, fixture, tier, "one_non_default", vals)
		}
		if (expand_combinations) {
			for (vals in pairwise_candidates(entry, tier)) {
				rows[[length(rows) + 1L]] = case_candidate(entry, fixture, tier, "pairwise", vals)
			}
			for (vals in targeted_three_way_candidates(entry, tier)) {
				rows[[length(rows) + 1L]] = case_candidate(entry, fixture, tier, "targeted_3way", vals)
			}
			for (vals in tiny_exhaustive_candidates(entry, tier)) {
				rows[[length(rows) + 1L]] = case_candidate(entry, fixture, tier, "tiny_exhaustive", vals)
			}
		}
	}
	dedupe_cases(do.call(rbind, rows))
}

generate_public_argument_combinations = function(tier = "smoke", target_filter = NULL, fixture_ids = NULL) {
	registry = read_registry()
	if (!is.null(target_filter)) {
		keep = grepl(target_filter, names(registry)) |
			vapply(registry, function(entry) grepl(target_filter, entry$target %||% ""), logical(1))
		registry = registry[keep]
	}
	if (!length(registry)) stop("No registry entries selected.", call. = FALSE)
	fixtures = build_public_argument_fixtures(tier = tier, fixture_ids = fixture_ids)
	rows = lapply(registry, generate_cases_for_entry, fixtures = fixtures, tier = tier)
	cases = dedupe_cases(do.call(rbind, rows))
	cases = cases[order(cases$target, cases$fixture_id, cases$argument_coverage_kind, cases$argument_signature), , drop = FALSE]
	row.names(cases) = NULL
	cases
}

coverage_from_cases = function(cases) {
	valid = cases[cases$constraint_status == "valid", , drop = FALSE]
	pairwise = valid[valid$argument_coverage_kind %in% c("pairwise", "targeted_3way", "tiny_exhaustive"), , drop = FALSE]
	data.frame(
		target = sort(unique(cases$target)),
		total_cases = as.integer(tabulate(match(cases$target, sort(unique(cases$target))))),
		valid_cases = as.integer(tabulate(match(valid$target, sort(unique(cases$target))), nbins = length(sort(unique(cases$target))))),
		valid_pairwise_or_higher_cases = as.integer(tabulate(match(pairwise$target, sort(unique(cases$target))), nbins = length(sort(unique(cases$target))))),
		stringsAsFactors = FALSE
	)
}

write_generation_outputs = function(cases, cases_file = cases_path, rejected_file = rejected_path, coverage_file = coverage_path) {
	write.csv(cases, cases_file, row.names = FALSE)
	rejected = cases[cases$constraint_status != "valid", , drop = FALSE]
	write.csv(rejected, rejected_file, row.names = FALSE)
	write.csv(coverage_from_cases(cases), coverage_file, row.names = FALSE)
	invisible(list(cases = cases_file, rejected = rejected_file, coverage = coverage_file))
}

# ---------------------------------------------------------------------------------------------
# Data-shape cases (v1.0.7-TODO-41). The cases above vary argument values on the canonical
# fixtures; these vary the data (public_argument_combination_fixtures.R, "Data-shape axes") and run
# a fixed set of inference methods at their defaults on each cell. Cells cover every legal pair of
# axis values (a greedy covering array over the full factorial, filtered by
# data_shape_cell_violations()), not the full factorial: ~2,000 legal cells shrink to the number
# needed to cover the largest pair product (inference class x design). Results go through
# run_case() like every other case, with an output_outcome column that separates a silent NA from
# a documented one, so the NA gate (v1.0.6-TODO-54) can fail on it.
# ---------------------------------------------------------------------------------------------

data_shape_inference_classes = list(
	continuous = c("InferenceAllSimpleAverageDiff", "InferenceAllSimpleWilcox", "InferenceContinOLS", "InferenceContinLin",
		"InferenceContinRobustRegr", "InferenceContinKKOLSOneLik"),
	incidence = c("InferenceAllSimpleAverageDiff", "InferenceIncidLogRegr", "InferenceIncidRiskDiff", "InferenceIncidExactFisher",
		"InferenceIncidKKCondLogitOneLik"),
	proportion = c("InferenceAllSimpleAverageDiff", "InferencePropBetaRegr", "InferencePropFractionalLogit", "InferencePropKKGEE"),
	count = c("InferenceAllSimpleAverageDiff", "InferenceCountPoisson", "InferenceCountNegBin", "InferenceCountKKCondPoissonOneLik"),
	ordinal = c("InferenceAllSimpleAverageDiff", "InferenceOrdinalPropOddsRegr", "InferenceOrdinalRidit", "InferenceOrdinalKKGEE"),
	survival = c("InferenceSurvivalKMDiff", "InferenceSurvivalRestrictedMeanDiff", "InferenceSurvivalLogRank",
		"InferenceSurvivalCoxPHRegr", "InferenceSurvivalWeibullRegr", "InferenceSurvivalKKStratCoxPHOneLik")
)

data_shape_kk_classes = c("InferenceContinKKOLSOneLik", "InferenceIncidKKCondLogitOneLik", "InferencePropKKGEE",
	"InferenceCountKKCondPoissonOneLik", "InferenceOrdinalKKGEE", "InferenceSurvivalKKStratCoxPHOneLik")

# Method -> (argument signature, invariants). Every method runs at its defaults except the
# resampling size. B = 501 is the smallest B the BCa boundary warning accepts; below it the
# bootstrap interval is NA by design, which would hide every other failure. r = 101 is enough for a
# finite randomization p-value (the matrix checks finiteness and errors, not calibration).
data_shape_methods = list(
	compute_estimate = list(args = "", invariants = "numeric_finite_or_documented_missing;estimate_shape_valid"),
	compute_asymp_confidence_interval = list(args = "", invariants = "ci_length_2;ci_ordered;numeric_finite_or_documented_missing"),
	compute_asymp_two_sided_pval = list(args = "", invariants = "pval_in_0_1;strong_effect_detected"),
	compute_bootstrap_confidence_interval = list(args = "B=501L;show_progress=FALSE", invariants = "ci_length_2;ci_ordered;numeric_finite_or_documented_missing"),
	compute_bootstrap_two_sided_pval = list(args = "B=501L;show_progress=FALSE", invariants = "pval_in_0_1;strong_effect_detected"),
	compute_rand_two_sided_pval = list(args = "r=101L;show_progress=FALSE", invariants = "pval_in_0_1;strong_effect_detected"),
	# unit = "auto": the jackknife is where clustered designs silently gave NA (v1.0.7-TODO-37).
	compute_jackknife_wald_confidence_interval = list(args = "", invariants = "ci_length_2;ci_ordered;numeric_finite_or_documented_missing")
)

# Methods only some drawn classes have. A drawn class that lacks one of data_shape_methods records
# "unsupported" for it (run_case()); these are the procedures it has instead.
data_shape_extra_methods = list(
	InferenceIncidExactFisher = list(
		compute_exact_two_sided_pval_for_treatment_effect = list(args = "", invariants = "pval_in_0_1;strong_effect_detected"),
		compute_exact_confidence_interval = list(args = "", invariants = "ci_length_2;ci_ordered;numeric_finite_or_documented_missing")
	)
)

data_shape_cell_axes = function() {
	c(data_shape_fixture_axes(), list(inference_class = unique(unlist(data_shape_inference_classes, use.names = FALSE))))
}

legal_data_shape_cells = function() {
	axes = data_shape_cell_axes()
	cells = expand.grid(axes, stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
	why = data_shape_cell_violations(
		cells,
		inference_classes_by_response = data_shape_inference_classes,
		kk_classes = data_shape_kk_classes,
		sequential_designs = names(Filter(function(d) isTRUE(d$sequential), data_shape_designs)),
		grouped_designs = names(Filter(function(d) isTRUE(d$grouped), data_shape_designs))
	)
	cells = cells[!nzchar(why), , drop = FALSE]
	row.names(cells) = NULL
	cells
}

# Greedy covering array (AETG-style): repeatedly take the legal cell that covers the most
# still-uncovered value pairs, until every pair some legal cell has is covered. Deterministic:
# ties go to the first cell in expand.grid order.
#
# Two passes. n = NULL breaks the whole design for some classes today (KK21 cannot even assign,
# v1.0.6-TODO-38; no n = NULL design can be analyzed, v1.0.6-TODO-39), so a single pass would cover
# many (inference class, censoring)-style pairs only on n = NULL cells that never reach the
# inference call. Pass 1 covers every pair among fixed-n cells; pass 2 adds cells only for the
# pairs that involve n = NULL.
greedy_pair_cover = function(cells, covered_keys = character()) {
	if (!nrow(cells)) return(list(cells = cells, keys = covered_keys))
	axes = names(cells)
	pairs = utils::combn(axes, 2L, simplify = FALSE)
	keys = vapply(pairs, function(p) paste(p[1L], cells[[p[1L]]], p[2L], cells[[p[2L]]], sep = "\r"), character(nrow(cells)))
	if (!is.matrix(keys)) keys = matrix(keys, nrow = nrow(cells))
	universe = unique(as.vector(keys))
	ids = matrix(match(keys, universe), nrow = nrow(cells))
	uncovered = !universe %in% covered_keys
	chosen = integer()
	while (any(uncovered)) {
		gain = rowSums(matrix(uncovered[ids], nrow = nrow(ids)))
		best = which.max(gain)
		if (gain[best] == 0L) break
		chosen = c(chosen, best)
		uncovered[ids[best, ]] = FALSE
	}
	list(cells = cells[chosen, , drop = FALSE], keys = union(covered_keys, universe[!uncovered]))
}

pairwise_data_shape_cells = function(cells = legal_data_shape_cells()) {
	fixed_n = cells$sample_size == "fixed"
	first = greedy_pair_cover(cells[fixed_n, , drop = FALSE])
	second = greedy_pair_cover(cells, covered_keys = first$keys)
	out = rbind(first$cells, second$cells)
	row.names(out) = NULL
	out
}

data_shape_case_row = function(fixture_id, class_name, method_name, args, invariants, tier, receiver_args = "", cell_label = "") {
	target = paste(class_name, method_name, sep = "::")
	signature = if (nzchar(args)) args else "<default>"
	data.frame(
		case_id = case_id_for(list(target = target), fixture_id, "data_shape", paste(signature, receiver_args, sep = "|")),
		api_kind = "r6_public_method",
		class_name = class_name,
		function_name = "",
		method_name = method_name,
		fixture_id = fixture_id,
		tier = tier,
		argument_signature = signature,
		argument_labels = cell_label,
		argument_coverage_kind = "data_shape",
		source_contracts = "",
		constraint_status = "valid",
		constraint_reason = "data-shape cell is legal",
		constraint_sources = "",
		target = target,
		invariants = invariants,
		receiver_args = receiver_args,
		stringsAsFactors = FALSE
	)
}

# The InferenceRandCustom block: R and C++ statistics returning one value, several values, NA, and
# (R only) NA on some permutations. The documented contract is one finite scalar
# (?InferenceRandCustom), so a several-value statistic must be refused (v1.0.6-TODO-44) and a nonzero
# delta on an incidence response must be refused however the statistic is given (v1.0.6-TODO-42).
custom_statistic_kinds = c("r_scalar", "r_vector", "r_na", "r_sometimes_na", "cpp_scalar", "cpp_vector", "cpp_na")

custom_statistic_value = function(kind) {
	mean_diff = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0])
	switch(kind,
		r_scalar = mean_diff,
		r_vector = function(y, w, dead) c(mean(y[w == 1]) - mean(y[w == 0]), stats::median(y[w == 1]) - stats::median(y[w == 0])),
		r_na = function(y, w, dead) NA_real_,
		r_sometimes_na = function(y, w, dead) if (w[1L] == 1) NA_real_ else mean(y[w == 1]) - mean(y[w == 0]),
		cpp_scalar = paste(
			"double ds_mean_diff(Rcpp::NumericVector y, Rcpp::IntegerVector w) {",
			"  double s1 = 0, s0 = 0; int n1 = 0, n0 = 0;",
			"  for (int i = 0; i < y.size(); i++) { if (w[i] == 1) { s1 += y[i]; n1++; } else { s0 += y[i]; n0++; } }",
			"  return s1 / n1 - s0 / n0;",
			"}", sep = "\n"),
		cpp_vector = paste(
			"Rcpp::NumericVector ds_mean_diff_vec(Rcpp::NumericVector y, Rcpp::IntegerVector w) {",
			"  double s1 = 0, s0 = 0; int n1 = 0, n0 = 0;",
			"  for (int i = 0; i < y.size(); i++) { if (w[i] == 1) { s1 += y[i]; n1++; } else { s0 += y[i]; n0++; } }",
			"  return Rcpp::NumericVector::create(s1 / n1 - s0 / n0, s1 / n1 + s0 / n0);",
			"}", sep = "\n"),
		cpp_na = paste(
			"double ds_always_na(Rcpp::NumericVector y, Rcpp::IntegerVector w) {",
			"  return NA_REAL;",
			"}", sep = "\n"),
		stop("Unknown custom statistic kind: ", kind, call. = FALSE)
	)
}

custom_statistic_fixture_ids = function() {
	base = list(design = "fixed_bernoulli", sample_size = "fixed", group_sizes = "equal", censoring = "none", missing_covariate = "no")
	c(
		data_shape_fixture_id(utils::modifyList(base, list(response_type = "continuous", effect = "null"))),
		data_shape_fixture_id(utils::modifyList(base, list(response_type = "continuous", effect = "strong"))),
		data_shape_fixture_id(utils::modifyList(base, list(response_type = "incidence", effect = "null"))),
		data_shape_fixture_id(utils::modifyList(base, list(response_type = "survival", censoring = "right", effect = "null")))
	)
}

custom_statistic_cases = function(tier = "nightly") {
	rows = list()
	for (fixture_id in custom_statistic_fixture_ids()) {
		cell = parse_data_shape_fixture_id(fixture_id)
		for (kind in custom_statistic_kinds) {
			arg = if (startsWith(kind, "cpp_")) "custom_randomization_statistic_cpp" else "custom_randomization_statistic_function"
			receiver_args = paste0(arg, "=<fixture:custom_stat_", kind, ">")
			refused = if (kind %in% c("r_vector", "cpp_vector")) "documented_refusal" else ""
			add = function(method, args, invariants) {
				invariants = paste(c(invariants, refused)[nzchar(c(invariants, refused))], collapse = ";")
				rows[[length(rows) + 1L]] <<- data_shape_case_row(fixture_id, "InferenceRandCustom", method, args, invariants, tier,
					receiver_args = receiver_args, cell_label = paste0("custom_stat=", kind))
			}
			add("compute_estimate", "", "numeric_finite_or_documented_missing")
			add("compute_rand_two_sided_pval", "r=101L;show_progress=FALSE", "pval_in_0_1;strong_effect_detected")
			add("compute_rand_two_sided_pval", "r=101L;na.rm=FALSE;show_progress=FALSE", "pval_in_0_1")
			if (identical(cell$response_type, "incidence")) {
				# The roxygen bans a nonzero delta on incidence responses (v1.0.6-TODO-42).
				add("compute_rand_two_sided_pval", "r=101L;delta=0.1;show_progress=FALSE", "documented_refusal")
			}
			if (identical(cell$response_type, "continuous") && kind %in% c("r_scalar", "cpp_scalar")) {
				add("compute_rand_confidence_interval", "r=101L;show_progress=FALSE", "ci_length_2;ci_ordered;numeric_finite_or_documented_missing")
			}
		}
	}
	do.call(rbind, rows)
}

# cell_filter: optional regular expression on the fixture id or inference class (e.g. "survival",
# "seq_kk21", "InferenceSurvivalKMDiff"). max_cells: keep the first max_cells covering-array cells.
generate_public_argument_data_shape_cases = function(tier = "nightly", cell_filter = NULL, max_cells = NULL, include_custom_statistics = TRUE) {
	cells = pairwise_data_shape_cells()
	fixture_ids = vapply(seq_len(nrow(cells)), function(i) data_shape_fixture_id(as.list(cells[i, , drop = FALSE])), character(1))
	keep = rep(TRUE, nrow(cells))
	if (!is.null(cell_filter)) keep = grepl(cell_filter, fixture_ids) | grepl(cell_filter, cells$inference_class)
	cells = cells[keep, , drop = FALSE]
	fixture_ids = fixture_ids[keep]
	if (!is.null(max_cells)) {
		take = seq_len(min(max_cells, nrow(cells)))
		cells = cells[take, , drop = FALSE]
		fixture_ids = fixture_ids[take]
	}
	rows = list()
	for (i in seq_len(nrow(cells))) {
		label = paste(paste(names(cells), unlist(cells[i, , drop = TRUE]), sep = "="), collapse = ";")
		methods = c(data_shape_methods, data_shape_extra_methods[[cells$inference_class[i]]])
		for (method in names(methods)) {
			spec = methods[[method]]
			rows[[length(rows) + 1L]] = data_shape_case_row(fixture_ids[i], cells$inference_class[i], method, spec$args, spec$invariants, tier, cell_label = label)
		}
	}
	if (isTRUE(include_custom_statistics)) {
		custom = custom_statistic_cases(tier)
		if (!is.null(cell_filter)) custom = custom[grepl(cell_filter, custom$fixture_id) | grepl(cell_filter, custom$class_name), , drop = FALSE]
		rows[[length(rows) + 1L]] = custom
	}
	cases = dedupe_cases(do.call(rbind, rows))
	row.names(cases) = NULL
	cases
}

main = function() {
	args = commandArgs(trailingOnly = TRUE)
	tier = if (length(args) >= 1L && !is.na(args[1L]) && nzchar(args[1L])) args[1L] else "smoke"
	target_filter = if (length(args) >= 2L && !is.na(args[2L]) && nzchar(args[2L])) args[2L] else default_smoke_target_filter
	fixture_ids = if (length(args) >= 3L) strsplit(args[3L], ",", fixed = TRUE)[[1L]] else default_smoke_fixture_ids
	cases = generate_public_argument_combinations(tier = tier, target_filter = target_filter, fixture_ids = fixture_ids)
	write_generation_outputs(cases)
	message("Wrote ", nrow(cases), " public argument combination candidates.")
	message("Valid candidates: ", sum(cases$constraint_status == "valid"))
	message("Rejected candidates: ", sum(cases$constraint_status != "valid"))
}

called_as_generate_script = function() {
	file_arg = grep("^--file=", commandArgs(FALSE), value = TRUE)[1] %||% ""
	identical(basename(sub("^--file=", "", file_arg)), "generate_public_argument_combinations.R")
}

if (called_as_generate_script()) {
	main()
}
