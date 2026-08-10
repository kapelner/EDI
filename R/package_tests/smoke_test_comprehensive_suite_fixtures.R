#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_comprehensive_suite_fixtures.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "comprehensive_suite_fixtures.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

smoke_fixtures = build_comprehensive_suite_fixtures("smoke")
smoke_again = build_comprehensive_suite_fixtures("smoke")
smoke_inventory = comprehensive_fixture_inventory(smoke_fixtures)
smoke_inventory_again = comprehensive_fixture_inventory(smoke_again)

expect_true(length(smoke_fixtures) >= 12L, "Expected comprehensive smoke fixtures to wrap public argument fixtures.")
expect_true(all(vapply(smoke_fixtures, validate_comprehensive_suite_fixture, logical(1))), "Comprehensive smoke fixture validation failed.")
expect_true(identical(smoke_inventory, smoke_inventory_again), "Comprehensive smoke fixture inventory is not deterministic.")
expect_true(identical(smoke_fixtures[["sequential_bernoulli_continuous_smoke"]]$w, smoke_again[["sequential_bernoulli_continuous_smoke"]]$w), "Sequential comprehensive fixture assignment is not deterministic.")

missing_response_types = setdiff(comprehensive_response_types, unique(smoke_inventory$response_type))
expect_true(!length(missing_response_types), paste("Missing smoke response fixtures:", paste(missing_response_types, collapse = ", ")))

missing_dataset_aliases = setdiff(names(comprehensive_dataset_aliases), unlist(strsplit(paste(smoke_inventory$comprehensive_dataset_aliases, collapse = ";"), ";", fixed = TRUE), use.names = FALSE))
expect_true(!length(missing_dataset_aliases), paste("Missing comprehensive dataset aliases:", paste(missing_dataset_aliases, collapse = ", ")))

missing_design_aliases = setdiff(names(comprehensive_design_aliases), unlist(strsplit(paste(smoke_inventory$comprehensive_design_aliases, collapse = ";"), ";", fixed = TRUE), use.names = FALSE))
expect_true(!length(missing_design_aliases), paste("Missing comprehensive design aliases:", paste(missing_design_aliases, collapse = ", ")))

nightly_fixtures = build_comprehensive_suite_fixtures("nightly")
nightly_inventory = comprehensive_fixture_inventory(nightly_fixtures)
release_fixtures = build_comprehensive_suite_fixtures("release")
release_inventory = comprehensive_fixture_inventory(release_fixtures)

expect_true(any(nightly_inventory$runtime_tier == "nightly"), "Nightly fixtures are not marked with runtime_tier = nightly.")
expect_true(any(release_inventory$runtime_tier == "release"), "Release fixtures are not marked with runtime_tier = release.")

survival_censoring_levels = unique(nightly_inventory$censoring_level[nightly_inventory$response_type == "survival"])
expect_true(all(c("none", "light") %in% survival_censoring_levels), "Nightly survival fixtures must include no and light censoring.")
expect_true("moderate" %in% release_inventory$censoring_level[release_inventory$response_type == "survival"], "Release survival fixtures must include moderate censoring.")

edge_families = unique(nightly_inventory$edge_case_family[nzchar(nightly_inventory$edge_case_family)])
expect_true(all(c("rare_event", "zero_heavy", "boundary_values") %in% edge_families), "Missing count/proportion/incidence edge fixtures.")

ordinal_levels = unique(release_inventory$ordinal_level_count[release_inventory$response_type == "ordinal"])
expect_true(all(c(3L, 4L, 5L) %in% ordinal_levels), "Ordinal fixtures must include multiple level counts.")

expect_true(any(nightly_inventory$has_cluster & nightly_inventory$has_strata), "Missing clustered/blocked comprehensive fixture.")
expect_true(any(release_inventory$has_matching), "Missing matched comprehensive fixture.")

message("comprehensive_suite_fixtures smoke test passed with ", nrow(release_inventory), " release-tier fixture rows")
