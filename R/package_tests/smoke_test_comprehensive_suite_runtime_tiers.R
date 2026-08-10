#!/usr/bin/env Rscript

script_path = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
if (!length(script_path) || is.na(script_path)) script_path = "package_tests/smoke_test_comprehensive_suite_runtime_tiers.R"
repo_root = normalizePath(file.path(dirname(script_path), ".."), mustWork = FALSE)
if (!dir.exists(file.path(repo_root, "EDI"))) {
	repo_root = normalizePath(getwd(), mustWork = TRUE)
}
repo_path = function(...) file.path(repo_root, ...)

source(repo_path("package_tests", "comprehensive_suite_runtime_tiers.R"))

expect_true = function(x, msg) {
	if (!isTRUE(x)) stop(msg, call. = FALSE)
}

out = tempfile(fileext = ".csv")
tiers = write_comprehensive_suite_runtime_tiers(out)
expect_true(file.exists(out), "Runtime tier CSV was not written.")
persisted = read.csv(out, stringsAsFactors = FALSE)
expect_true(identical(persisted$tier, c("smoke", "ci", "nightly", "release")), "Runtime tiers are missing or incorrectly ordered.")
expect_true(all(runtime_tier_columns %in% names(persisted)), "Runtime tier registry schema is incomplete.")
expect_true(all(persisted$argument_combination_tier %in% c("smoke", "ci")), "Runtime tiers must reuse smoke/ci argument-combination tiers.")
expect_true(all(grepl("import", persisted$argument_combination_mode[persisted$tier %in% c("nightly", "release")])), "Nightly/release must import argument-combination coverage.")
expect_true(!any(grepl("maximal|larger|exhaustive", paste(persisted$comprehensive_harness_mode[persisted$tier %in% c("smoke", "ci")], persisted$resampling_scale[persisted$tier %in% c("smoke", "ci")], persisted$method_family_scope[persisted$tier %in% c("smoke", "ci")]))), "Smoke/CI must stay bounded.")
expect_true(tier_policy_for("smoke")$resampling_scale == "tiny", "Smoke tier must use tiny resampling scale.")
expect_true(tier_policy_for("ci")$expected_scheduler == "ci", "CI tier must be scheduled for CI.")
expect_true(tier_policy_for("nightly")$expected_scheduler == "nightly", "Nightly tier must be scheduled/manual broader coverage.")
expect_true(tier_policy_for("release")$manual_or_scheduled == "manual_release", "Release tier must be explicitly manual/release scoped.")

message("comprehensive suite runtime tier smoke test passed with ", nrow(tiers), " tiers")
