#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_generate_public_argument_combinations.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}

source(file.path(repo_root, "package_tests", "generate_public_argument_combinations.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

cases = generate_public_argument_combinations(
	tier = "smoke",
	target_filter = "^InferenceAllSimpleAverageDiff::compute_bootstrap_confidence_interval$|^DesignFixedBernoulli::add_all_subject_responses$",
	fixture_ids = c("fixed_bernoulli_continuous_smoke", "fixed_bernoulli_survival_censored_smoke")
)

required_cols = c(
	"case_id", "api_kind", "class_name", "function_name", "method_name",
	"fixture_id", "tier", "argument_signature", "argument_coverage_kind",
	"source_contracts", "constraint_status", "constraint_reason"
)
expect_true(all(required_cols %in% names(cases)), "Generated cases are missing required schema columns.")
expect_true(nrow(cases) > 0L, "No cases generated.")
expect_true(!anyDuplicated(cases$case_id), "case_id values are not unique.")
expect_true(any(cases$argument_coverage_kind == "default"), "Default cases are missing.")
expect_true(any(cases$argument_coverage_kind == "one_non_default"), "One-non-default cases are missing.")
expect_true(any(cases$argument_coverage_kind == "pairwise"), "Pairwise cases are missing.")
expect_true(any(cases$constraint_status != "valid"), "Rejected candidates are missing from generated cases.")
expect_true(all(cases$constraint_status %in% valid_constraint_statuses), "Generated cases contain invalid constraint statuses.")

coverage = coverage_from_cases(cases)
expect_true(nrow(coverage) > 0L, "Coverage table is empty.")
expect_true(all(coverage$valid_cases <= coverage$total_cases), "Coverage valid counts exceed total counts.")

tmp_dir = file.path(tempdir(), paste0("public_arg_combo_smoke_", Sys.getpid()))
dir.create(tmp_dir, showWarnings = FALSE)
write_generation_outputs(
	cases,
	cases_file = file.path(tmp_dir, "cases.csv"),
	rejected_file = file.path(tmp_dir, "rejected.csv"),
	coverage_file = file.path(tmp_dir, "coverage.csv")
)
expect_true(file.exists(file.path(tmp_dir, "cases.csv")), "Cases CSV was not written.")
expect_true(file.exists(file.path(tmp_dir, "rejected.csv")), "Rejected CSV was not written.")
expect_true(file.exists(file.path(tmp_dir, "coverage.csv")), "Coverage CSV was not written.")

cases_again = generate_public_argument_combinations(
	tier = "smoke",
	target_filter = "^InferenceAllSimpleAverageDiff::compute_bootstrap_confidence_interval$|^DesignFixedBernoulli::add_all_subject_responses$",
	fixture_ids = c("fixed_bernoulli_continuous_smoke", "fixed_bernoulli_survival_censored_smoke")
)
expect_true(identical(cases, cases_again), "Generation is not deterministic.")

# Data-shape cells (v1.0.7-TODO-41): legal only, every legal pair covered, deterministic.
legal = legal_data_shape_cells()
cells = pairwise_data_shape_cells(legal)
expect_true(nrow(cells) > 0L && nrow(cells) < nrow(legal), "Data-shape covering array is empty or not smaller than the full factorial.")
uncovered = 0L
for (p in utils::combn(names(legal), 2L, simplify = FALSE)) {
	uncovered = uncovered + length(setdiff(unique(paste(legal[[p[1L]]], legal[[p[2L]]])), unique(paste(cells[[p[1L]]], cells[[p[2L]]]))))
}
expect_true(uncovered == 0L, paste("Data-shape covering array misses", uncovered, "legal value pairs."))
expect_true(!any(nzchar(data_shape_cell_violations(cells, data_shape_inference_classes, data_shape_kk_classes,
	sequential_designs = c("seq_bernoulli", "seq_kk21"), grouped_designs = c("fixed_blocking", "fixed_cluster", "fixed_blocked_cluster")))),
	"Data-shape covering array contains an illegal cell.")
fixed_n = cells[cells$sample_size == "fixed", , drop = FALSE]
fixed_legal = legal[legal$sample_size == "fixed", , drop = FALSE]
fixed_pairs_missing = length(setdiff(unique(paste(fixed_legal$inference_class, fixed_legal$censoring)), unique(paste(fixed_n$inference_class, fixed_n$censoring))))
expect_true(fixed_pairs_missing == 0L, "Some (inference class, censoring) pair is covered only on n = NULL cells.")
expect_true(all(c("null_mid", "null_end") %in% cells$sample_size), "n = NULL cells are missing.")
expect_true(all(c("unequal") %in% cells$group_sizes) && all(c("right", "interval") %in% cells$censoring) && "yes" %in% cells$missing_covariate && "strong" %in% cells$effect,
	"A data-shape axis value is missing from the covering array.")
shape_cases = generate_public_argument_data_shape_cases(max_cells = 3L)
expect_true(!anyDuplicated(shape_cases$case_id), "Data-shape case_id values are not unique.")
expect_true(all(shape_cases$argument_coverage_kind == "data_shape") && all(is_data_shape_fixture_id(shape_cases$fixture_id)), "Data-shape cases are mislabeled.")
expect_true(all(custom_statistic_kinds %in% sub("^custom_stat=", "", shape_cases$argument_labels[shape_cases$class_name == "InferenceRandCustom"])), "InferenceRandCustom statistic kinds are missing.")
expect_true(identical(shape_cases, generate_public_argument_data_shape_cases(max_cells = 3L)), "Data-shape generation is not deterministic.")
for (id in unique(shape_cases$fixture_id)) {
	expect_true(identical(data_shape_fixture_id(parse_data_shape_fixture_id(id)), id), paste("Data-shape fixture id does not round-trip:", id))
}

message("public argument combination generator smoke test passed with ", nrow(cases), " candidates")
