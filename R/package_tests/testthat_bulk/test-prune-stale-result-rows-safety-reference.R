testthat::test_that("stale result pruning is dry-run safe and applies only matched rows", {
	testthat::skip_if_not_installed("data.table")
	testthat::skip_if(Sys.which("git") == "", "git is required for the isolated repository fixture")

	root <- tempfile("edi-prune-stale-results-")
	dir.create(root)
	on.exit(unlink(root, recursive = TRUE), add = TRUE)

	harness_dir <- file.path(root, "R", "package_tests")
	source_dir <- file.path(root, "R", "EDI", "R")
	dir.create(harness_dir, recursive = TRUE)
	dir.create(source_dir, recursive = TRUE)
	pruner <- file.path(harness_dir, "prune_stale_result_rows.R")
	find_repo_file <- function(path) {
		at <- normalizePath(getwd())
		repeat {
			candidate <- file.path(at, path)
			if (file.exists(candidate)) return(candidate)
			parent <- dirname(at)
			if (identical(parent, at)) break
			at <- parent
		}
		stop("cannot locate repository file: ", path)
	}
	pruner_source <- find_repo_file(file.path("R", "package_tests", "prune_stale_result_rows.R"))
	stopifnot(file.copy(pruner_source, pruner))
	writeLines("initial source", file.path(source_dir, "fixture.R"))

	run_git <- function(args) {
		status <- system2("git", c("-C", root, args), stdout = FALSE, stderr = FALSE)
		stopifnot(identical(as.integer(status), 0L))
	}
	run_git(c("init", "-q"))
	run_git(c("config", "user.name", "EDI test"))
	run_git(c("config", "user.email", "edi-test@example.invalid"))
	run_git(c("add", "R/EDI/R/fixture.R", "R/package_tests/prune_stale_result_rows.R"))
	run_git(c("commit", "-q", "-m", "pre-fix"))
	pre_fix <- system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE)
	writeLines("post-fix source", file.path(source_dir, "fixture.R"))
	run_git(c("add", "R/EDI/R/fixture.R"))
	run_git(c("commit", "-q", "-m", "post-fix"))
	post_fix <- system2("git", c("-C", root, "rev-parse", "HEAD"), stdout = TRUE)

	checked_in_rules <- data.table::fread(find_repo_file(file.path("R", "package_tests", "stale_ok_row_rules.csv")))
	todo55_classes <- c("AllSimpleAverageDiff", "AllSimpleMeanDiffPooledVar", "PropGCompMeanDiff", "AllSimpleWilcox")
	todo55_rules <- checked_in_rules[
		response_type == "proportion" & class %in% todo55_classes &
			grepl("TODO-55", tracked_in, fixed = TRUE)
	]
	testthat::expect_setequal(todo55_rules$class, todo55_classes)
	testthat::expect_identical(as.character(todo55_rules$before_timestamp), rep("2026-10-22", 4L))
	testthat::expect_true(all(grepl("noisy-marginal owner decision", todo55_rules$reason, fixed = TRUE)))
	testthat::expect_true(all(is.na(todo55_rules$function_run) | !nzchar(todo55_rules$function_run)))

	todo55_plan_path <- file.path(root, "R", "package_metadata", "bug_fix_plans", "prop_mean_diff_closed_form_truth_stale.md")
	dir.create(dirname(todo55_plan_path), recursive = TRUE)
	testthat::expect_true(file.copy(
		find_repo_file(file.path("R", "package_metadata", "bug_fix_plans", "prop_mean_diff_closed_form_truth_stale.md")),
		todo55_plan_path
	))

	rules <- data.table::data.table(
		response_type = "incidence", class = "Example", function_run = "",
		before_timestamp = "2026-10-16", tracked_in = paste0("commit:", post_fix),
		reason = "synthetic class-wide stale coverage truth fixture"
	)
	rules[, before_timestamp := as.character(before_timestamp)]
	todo55_rules[, before_timestamp := as.character(before_timestamp)]
	rules <- data.table::rbindlist(list(rules, todo55_rules), use.names = TRUE)
	data.table::fwrite(rules, file.path(harness_dir, "stale_ok_row_rules.csv"))
	rows <- data.table::data.table(
		id = c("stale-error", "stale-ok-estimate", "stale-ok-ci", "cutoff-day", "fresh-ok", "other-class", "fresh-error"),
		status = c("error", "ok", "ok", "ok", "ok", "ok", "error"),
		github_commit_id = c(pre_fix, rep(post_fix, 6L)),
		inference_class = c("InferenceExample", rep("InferenceExample", 4L), "InferenceOther", "InferenceExample"),
		function_run = c("estimate", "estimate", "confidence_interval_basic", "pval", "estimate", "estimate", "pval"),
		timestamp = c("2026-10-15 12:00:00", "2026-10-15 12:00:00", "2026-10-15 12:00:00",
			"2026-10-16 00:00:00", "2026-10-17 12:00:00", "2026-10-15 12:00:00", "2026-10-17 12:00:00"),
		response_type = c("incidence", "incidence", "incidence", "incidence", "incidence", "count", "incidence")
	)
	csv <- file.path(harness_dir, "comprehensive_tests_results_nc_1_incidence.csv")
	data.table::fwrite(rows, csv)
	original_bytes <- readBin(csv, what = "raw", n = file.info(csv)$size)
	todo55_cases <- expand.grid(
		inference_class = paste0("Inference", todo55_classes),
		timestamp = c("2026-10-09 12:00:00", "2026-10-21 12:00:00", "2026-10-22 00:00:00"),
		function_run = c("estimate", "compute_confidence_interval_asymp", "compute_rand_two_sided_pval"),
		stringsAsFactors = FALSE
	)
	proportion_rows <- data.table::as.data.table(todo55_cases)
	proportion_rows[, `:=`(
		id = paste(inference_class, timestamp, function_run, sep = "|"),
		status = "ok", github_commit_id = post_fix, response_type = "proportion"
	)]
	proportion_csv <- file.path(harness_dir, "comprehensive_tests_results_nc_1_proportion.csv")
	data.table::fwrite(proportion_rows, proportion_csv)
	proportion_original_bytes <- readBin(proportion_csv, what = "raw", n = file.info(proportion_csv)$size)

	run_pruner <- function(args = character()) {
		out <- system2(file.path(R.home("bin"), "Rscript"), c(pruner, args), stdout = TRUE, stderr = TRUE)
		status <- attr(out, "status")
		if (is.null(status)) status <- 0L
		list(status = as.integer(status), output = paste(out, collapse = "\n"))
	}

	dry_run <- run_pruner()
	testthat::expect_identical(dry_run$status, 0L)
	testthat::expect_match(dry_run$output, "would be removed")
	testthat::expect_identical(readBin(csv, what = "raw", n = file.info(csv)$size), original_bytes)
	testthat::expect_identical(readBin(proportion_csv, what = "raw", n = file.info(proportion_csv)$size), proportion_original_bytes)

	checked <- run_pruner("--check-rules")
	testthat::expect_identical(checked$status, 0L)
	testthat::expect_match(checked$output, "all 5 rule")

	applied <- run_pruner("--apply")
	testthat::expect_identical(applied$status, 0L)
	remaining <- data.table::fread(csv)
	testthat::expect_setequal(remaining$id, c("cutoff-day", "fresh-ok", "other-class", "fresh-error"))
	proportion_remaining <- data.table::fread(proportion_csv)
	testthat::expect_length(unique(proportion_remaining$timestamp), 1L)
	testthat::expect_identical(
		format(unique(proportion_remaining$timestamp), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
		"2026-10-22 00:00:00"
	)
	testthat::expect_equal(nrow(proportion_remaining), length(todo55_classes) * 3L)
	testthat::expect_false(file.exists(paste0(csv, ".prune_tmp")))
	testthat::expect_false(file.exists(paste0(proportion_csv, ".prune_tmp")))
})
