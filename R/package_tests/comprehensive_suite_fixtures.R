#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/comprehensive_suite_fixtures.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "public_argument_combination_fixtures.R"))

comprehensive_fixture_tier_rank = fixture_tier_rank

comprehensive_response_types = response_fixture_families

comprehensive_design_aliases = c(
	Bernoulli = "sequential_bernoulli_continuous_smoke",
	FixedBernoulli = "fixed_bernoulli_continuous_smoke",
	FixediBCRD = "fixed_bernoulli_continuous_smoke",
	FixedBlocking = "fixed_blocking_continuous_smoke",
	FixedCluster = "fixed_cluster_continuous_smoke",
	FixedBlockedCluster = "fixed_blocked_cluster_continuous_smoke",
	FixedBinaryMatch = "fixed_binary_match_continuous_smoke",
	FixedMatchingGreedy = "fixed_binary_match_continuous_smoke",
	FixedGreedy = "fixed_greedy_continuous_smoke",
	KK21stepwise = "sequential_bernoulli_continuous_smoke",
	SPBR = "fixed_blocking_continuous_smoke"
)

comprehensive_dataset_aliases = c(
	cars = "fixed_bernoulli_continuous_smoke",
	diamonds = "fixed_bernoulli_ordinal_smoke",
	pima = "fixed_bernoulli_incidence_smoke",
	pte_example = "fixed_bernoulli_survival_censored_smoke",
	airquality = "fixed_bernoulli_count_smoke",
	boston = "fixed_bernoulli_proportion_smoke"
)

comprehensive_extended_fixture_specs = function() {
	specs = list(
		survival_no_censoring_nightly = list(
			fixture_id = "survival_no_censoring_nightly",
			response_type = "survival",
			response_variant = "no_censoring",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly",
			has_censoring = FALSE,
			censoring_level = "none"
		),
		survival_light_censoring_nightly = list(
			fixture_id = "survival_light_censoring_nightly",
			response_type = "survival",
			response_variant = "light_censoring",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly",
			has_censoring = TRUE,
			censoring_level = "light"
		),
		survival_moderate_censoring_release = list(
			fixture_id = "survival_moderate_censoring_release",
			response_type = "survival",
			response_variant = "moderate_censoring",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 96L,
			tier = "release",
			has_censoring = TRUE,
			censoring_level = "moderate"
		),
		incidence_rare_event_nightly = list(
			fixture_id = "incidence_rare_event_nightly",
			response_type = "incidence",
			response_variant = "rare_event",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly"
		),
		incidence_balanced_release = list(
			fixture_id = "incidence_balanced_release",
			response_type = "incidence",
			response_variant = "balanced_binary",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 96L,
			tier = "release"
		),
		count_zero_heavy_nightly = list(
			fixture_id = "count_zero_heavy_nightly",
			response_type = "count",
			response_variant = "zero_heavy",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly"
		),
		count_overdispersed_release = list(
			fixture_id = "count_overdispersed_release",
			response_type = "count",
			response_variant = "overdispersed",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 96L,
			tier = "release"
		),
		proportion_boundary_nightly = list(
			fixture_id = "proportion_boundary_nightly",
			response_type = "proportion",
			response_variant = "boundary_values",
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly"
		),
		ordinal_4_level_nightly = list(
			fixture_id = "ordinal_4_level_nightly",
			response_type = "ordinal",
			response_variant = "four_levels",
			ordinal_level_count = 4L,
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 32L,
			tier = "nightly"
		),
		ordinal_5_level_release = list(
			fixture_id = "ordinal_5_level_release",
			response_type = "ordinal",
			response_variant = "five_levels",
			ordinal_level_count = 5L,
			design_type = "fixed",
			class_name = "DesignFixedBernoulli",
			n = 96L,
			tier = "release"
		),
		clustered_blocked_nightly = list(
			fixture_id = "clustered_blocked_nightly",
			response_type = "continuous",
			response_variant = "balanced_continuous",
			design_type = "blocked_cluster",
			class_name = "DesignFixedBlockedCluster",
			n = 32L,
			tier = "nightly",
			strata_cols = "stratum",
			cluster_col = "cluster_id"
		),
		matched_release = list(
			fixture_id = "matched_release",
			response_type = "continuous",
			response_variant = "balanced_continuous",
			design_type = "matched",
			class_name = "DesignFixedBinaryMatch",
			n = 96L,
			tier = "release",
			m = rep(seq_len(48L), each = 2L)
		)
	)
	names(specs) = vapply(specs, function(spec) spec$fixture_id, character(1))
	specs
}

comprehensive_fixture_specs = function() {
	specs = public_argument_fixture_specs()
	extended = comprehensive_extended_fixture_specs()
	specs = c(specs, extended)
	names(specs) = vapply(specs, function(spec) spec$fixture_id, character(1))
	specs
}

make_comprehensive_fixture_response = function(spec) {
	n = spec$n
	variant = spec$response_variant %||% "default"
	if (identical(spec$response_type, "survival")) {
		y = seq_len(n) + 0.5
		dead = switch(
			spec$censoring_level %||% if (isTRUE(spec$has_censoring)) "light" else "none",
			none = rep(1, n),
			light = ifelse(seq_len(n) %% 8L == 0L, 0, 1),
			moderate = ifelse(seq_len(n) %% 3L == 0L, 0, 1),
			rep(1, n)
		)
		return(list(y = y, dead = dead))
	}
	if (identical(spec$response_type, "incidence") && identical(variant, "rare_event")) {
		return(list(y = as.integer(seq_len(n) %% 8L == 0L), dead = rep(1, n)))
	}
	if (identical(spec$response_type, "incidence") && identical(variant, "balanced_binary")) {
		return(list(y = rep(c(0, 1), length.out = n), dead = rep(1, n)))
	}
	if (identical(spec$response_type, "count") && identical(variant, "zero_heavy")) {
		return(list(y = rep(c(0, 0, 0, 1, 2, 4, 0, 3), length.out = n), dead = rep(1, n)))
	}
	if (identical(spec$response_type, "count") && identical(variant, "overdispersed")) {
		return(list(y = rep(c(0, 1, 1, 2, 3, 5, 8, 13), length.out = n), dead = rep(1, n)))
	}
	if (identical(spec$response_type, "proportion") && identical(variant, "boundary_values")) {
		return(list(y = rep(c(0, 0.01, 0.2, 0.5, 0.8, 0.99, 1, 0.5), length.out = n), dead = rep(1, n)))
	}
	if (identical(spec$response_type, "ordinal") && !is.null(spec$ordinal_level_count)) {
		return(list(y = rep(seq_len(spec$ordinal_level_count), length.out = n), dead = rep(1, n)))
	}
	make_fixture_response(spec$response_type, n, censored = isTRUE(spec$has_censoring))
}

annotate_comprehensive_fixture = function(fixture, spec) {
	meta = fixture$metadata
	meta$response_variant = spec$response_variant %||% if (isTRUE(meta$has_censoring)) "censored" else "default"
	meta$runtime_tier = spec$tier
	meta$comprehensive_fixture = TRUE
	meta$comprehensive_dataset_aliases = names(comprehensive_dataset_aliases)[comprehensive_dataset_aliases == fixture$fixture_id]
	meta$comprehensive_design_aliases = names(comprehensive_design_aliases)[comprehensive_design_aliases == fixture$fixture_id]
	meta$censoring_level = spec$censoring_level %||% if (isTRUE(meta$has_censoring)) "light" else "none"
	meta$ordinal_level_count = if (identical(spec$response_type, "ordinal")) length(unique(fixture$response)) else NA_integer_
	meta$edge_case_family = if (meta$response_variant %in% c("rare_event", "zero_heavy", "overdispersed", "boundary_values")) meta$response_variant else ""
	fixture$metadata = meta
	fixture
}

build_comprehensive_suite_fixture = function(spec) {
	load_edi_for_fixtures()
	covariates = make_fixture_covariates(spec$n)
	response = make_comprehensive_fixture_response(spec)
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
	fixture = annotate_comprehensive_fixture(fixture, spec)
	validate_comprehensive_suite_fixture(fixture)
	fixture
}

build_comprehensive_suite_fixtures = function(tier = "smoke", fixture_ids = NULL) {
	specs = comprehensive_fixture_specs()
	if (!is.null(fixture_ids)) {
		missing = setdiff(fixture_ids, names(specs))
		if (length(missing)) stop("Unknown fixture_ids: ", paste(missing, collapse = ", "), call. = FALSE)
		specs = specs[fixture_ids]
	}
	max_rank = comprehensive_fixture_tier_rank[[tier]]
	if (is.null(max_rank) || is.na(max_rank)) stop("Unknown tier: ", tier, call. = FALSE)
	specs = specs[vapply(specs, function(spec) comprehensive_fixture_tier_rank[[spec$tier]] <= max_rank, logical(1))]
	fixtures = lapply(specs, build_comprehensive_suite_fixture)
	names(fixtures) = vapply(fixtures, function(fixture) fixture$fixture_id, character(1))
	fixtures
}

validate_comprehensive_suite_fixture = function(fixture) {
	validate_public_argument_fixture(fixture)
	meta = fixture$metadata
	required_meta = c(
		"runtime_tier", "comprehensive_fixture", "response_variant",
		"comprehensive_dataset_aliases", "comprehensive_design_aliases",
		"censoring_level", "ordinal_level_count", "edge_case_family"
	)
	missing_meta = setdiff(required_meta, names(meta))
	if (length(missing_meta)) stop("Comprehensive fixture metadata missing fields: ", paste(missing_meta, collapse = ", "), call. = FALSE)
	if (!(meta$runtime_tier %in% names(comprehensive_fixture_tier_rank))) stop("Unknown runtime_tier: ", meta$runtime_tier, call. = FALSE)
	if (!isTRUE(meta$comprehensive_fixture)) stop("Comprehensive fixture flag is false.", call. = FALSE)
	if (identical(meta$response_type, "survival")) {
		has_censored_rows = any(fixture$dead == 0)
		if (identical(meta$censoring_level, "none") && has_censored_rows) stop("No-censoring survival fixture contains censored rows.", call. = FALSE)
		if (!identical(meta$censoring_level, "none") && !has_censored_rows) stop("Censored survival fixture contains no censored rows.", call. = FALSE)
	}
	if (identical(meta$response_type, "ordinal") && length(unique(fixture$response)) < 3L) {
		stop("Ordinal fixture must contain at least three levels.", call. = FALSE)
	}
	invisible(TRUE)
}

comprehensive_fixture_inventory = function(fixtures) {
	rows = lapply(fixtures, function(fixture) {
		meta = fixture$metadata
		data.frame(
			fixture_id = meta$fixture_id,
			response_type = meta$response_type,
			design_type = meta$design_type,
			class_name = meta$class_name,
			n = meta$n,
			p = meta$p,
			response_variant = meta$response_variant,
			has_strata = meta$has_strata,
			has_cluster = meta$has_cluster,
			has_matching = meta$has_matching,
			has_censoring = meta$has_censoring,
			censoring_level = meta$censoring_level,
			ordinal_level_count = meta$ordinal_level_count,
			edge_case_family = meta$edge_case_family,
			runtime_tier = meta$runtime_tier,
			comprehensive_dataset_aliases = paste(meta$comprehensive_dataset_aliases, collapse = ";"),
			comprehensive_design_aliases = paste(meta$comprehensive_design_aliases, collapse = ";"),
			available_columns = paste(meta$available_columns, collapse = ";"),
			stringsAsFactors = FALSE
		)
	})
	out = do.call(rbind, rows)
	row.names(out) = NULL
	out
}
