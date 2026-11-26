#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_public_argument_combination_fixtures.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "public_argument_combination_fixtures.R"))
source(file.path(repo_root, "package_tests", "public_argument_combination_constraints.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

fixtures = build_public_argument_fixtures("smoke")
fixtures_again = build_public_argument_fixtures("smoke")
inventory = fixture_inventory(fixtures)
inventory_again = fixture_inventory(fixtures_again)

expect_true(length(fixtures) >= 12L, "Expected smoke fixtures across response and design dimensions.")
expect_true(all(vapply(fixtures, validate_public_argument_fixture, logical(1))), "Fixture validation failed.")
expect_true(identical(inventory, inventory_again), "Fixture inventory is not deterministic.")
expect_true(identical(fixtures[["sequential_bernoulli_continuous_smoke"]]$w, fixtures_again[["sequential_bernoulli_continuous_smoke"]]$w), "Sequential fixture assignment is not deterministic.")

missing_response_types = setdiff(response_fixture_families, unique(inventory$response_type))
expect_true(!length(missing_response_types), paste("Missing response fixtures:", paste(missing_response_types, collapse = ", ")))

required_design_types = c("fixed", "sequential", "stratified", "clustered", "blocked_cluster", "matched", "search")
missing_design_types = setdiff(required_design_types, unique(inventory$design_type))
expect_true(!length(missing_design_types), paste("Missing design fixtures:", paste(missing_design_types, collapse = ", ")))

method_coverage = unique(unlist(lapply(fixtures, function(fixture) fixture$metadata$compatible_method_families), use.names = FALSE))
missing_methods = setdiff(high_priority_fixture_methods, method_coverage)
expect_true(!length(missing_methods), paste("Missing high-priority method fixture metadata:", paste(missing_methods, collapse = ", ")))

censored_survival = fixtures[["fixed_bernoulli_survival_censored_smoke"]]
expect_true(censored_survival$metadata$has_censoring, "Censored survival fixture metadata is false.")
expect_true(censored_survival$design$any_censoring(), "Censored survival fixture has no public censoring signal.")

formula_case = constraint_context_result(
	args = list(model_formula = "~ x1 + stratum"),
	fixture = fixtures[["fixed_bernoulli_continuous_smoke"]]$metadata,
	tier = "ci",
	registry_entry = list()
)
expect_true(identical(formula_case$status, "valid"), paste("Fixture metadata failed formula constraint:", formula_case$reason))

cluster_case = constraint_context_result(
	args = list(strata_cols = "stratum", cluster_col = "cluster_id"),
	fixture = fixtures[["fixed_blocked_cluster_continuous_smoke"]]$metadata,
	tier = "ci",
	registry_entry = list()
)
expect_true(identical(cluster_case$status, "valid"), paste("Blocked-cluster metadata failed constraints:", cluster_case$reason))

# Data-shape fixtures (v1.0.7-TODO-41) are built from their ids, on demand.
shape_cell = list(design = "fixed_blocking", response_type = "survival", sample_size = "fixed", group_sizes = "unequal",
	censoring = "interval", missing_covariate = "yes", effect = "strong")
shape_id = data_shape_fixture_id(shape_cell)
shape = build_public_argument_fixtures("nightly", fixture_ids = shape_id)[[shape_id]]
expect_true(is.null(shape$build_error), paste("Data-shape fixture failed to build:", shape$build_error))
expect_true(shape$design$any_censoring(), "Interval-censored data-shape fixture has no censoring.")
expect_true(anyNA(shape$data$x1), "Missing-covariate data-shape fixture has no missing covariate.")
expect_true(length(unique(table(shape$data$stratum))) > 1L, "Unequal-group data-shape fixture has equal strata.")
expect_true(identical(shape$w, build_public_argument_fixtures("nightly", fixture_ids = shape_id)[[shape_id]]$w), "Data-shape fixture is not deterministic.")
mid_id = data_shape_fixture_id(utils::modifyList(shape_cell, list(design = "seq_bernoulli", response_type = "continuous", sample_size = "null_mid",
	group_sizes = "equal", censoring = "none", missing_covariate = "no")))
mid = build_public_argument_fixtures("nightly", fixture_ids = mid_id)[[mid_id]]
expect_true(is.null(mid$build_error), paste("Mid-stream data-shape fixture failed to build:", mid$build_error))
expect_true(mid$metadata$n_responded < mid$metadata$n_enrolled && is.na(mid$metadata$n) && !isTRUE(mid$design$.__enclos_env__$private$fixed_sample), "Mid-stream fixture is not an n = NULL interim look.")
broken = build_public_argument_fixtures("nightly", fixture_ids = "data_shape__no_such")
expect_true(!is.null(broken[[1L]]$build_error), "A malformed data-shape id did not become a build error.")

message("public_argument_combination_fixtures smoke test passed with ", nrow(inventory), " fixtures")
