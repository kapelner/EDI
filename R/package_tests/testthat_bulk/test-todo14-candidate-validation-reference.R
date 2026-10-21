library(testthat)
library(EDI)

# This checks only the reconciliation contract. It does not run the
# comprehensive harness or establish that a real candidate was produced by
# the target package/DLL.
source(testthat::test_path("..", "validate_todo14_candidate.R"), local = TRUE)

test_that("TODO-14 source manifest binds the checked-in default candidate scope", {
	runner_path <- testthat::test_path("..", "comprehensive_tests.R")
	dataset_source_path <- testthat::test_path("..", "_dataset_load.R")
	manifest <- todo14_source_candidate_manifest(runner_path, dataset_source_path)

	expect_equal(nrow(manifest), 8640L)
	expect_false(anyDuplicated(manifest$id) > 0L)
	expect_setequal(unique(manifest$rep), seq_len(40L))
	expect_setequal(unique(manifest$beta_T), c(0, 0.5))
	expect_setequal(unique(manifest$dataset), .todo14_expected_datasets)
	expect_identical(unique(manifest$response_type), "survival")
	expect_setequal(unique(manifest$design), c("KK21stepwise", "FixedBinaryMatch"))
	expect_setequal(unique(manifest$inference_class), .todo14_expected_classes)
	expect_setequal(unique(manifest$function_run), .todo14_expected_functions)
	expect_identical(
		unique(manifest$candidate_status),
		"candidate_only_requires_setup_and_runtime_eligibility"
	)
	expect_identical(
		unique(manifest$scope_source),
		"checked_in_runner_defaults_without_cli_filters"
	)

	# The source-derived key set must agree with the existing fixed-scope key
	# construction while retaining its explicit candidate-only status.
	expected <- expand.grid(
		rep = seq_len(40L), beta_T = c(0, 0.5), dataset = .todo14_expected_datasets,
		response_type = "survival", design = c("KK21stepwise", "FixedBinaryMatch"),
		inference_class = .todo14_expected_classes,
		function_run = .todo14_expected_functions,
		KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
	)
	expected$id <- .todo14_build_id(expected)
	expect_setequal(manifest$id, expected$id)

	expect_error(
		todo14_source_candidate_manifest(runner_path, dataset_source_path, Nrep = 39L),
		"fixed to the checked-in 40-replicate run"
	)

	# A changed source formula axis must fail closed rather than silently emit a
	# roster that still looks like the approved 8,640-key scope.
	runner_lines <- readLines(runner_path, warn = FALSE)
	formula_line <- grep("formulas_to_test = list", runner_lines, fixed = TRUE)
	expect_length(formula_line, 1L)
	mutated_runner <- tempfile("todo14-scope-mismatch-", tmpdir = "/tmp", fileext = ".R")
	on.exit(unlink(mutated_runner), add = TRUE)
	runner_lines[formula_line] <- sub("~ .", "~ x", runner_lines[formula_line], fixed = TRUE)
	writeLines(runner_lines, mutated_runner)
	expect_error(
		todo14_source_candidate_manifest(mutated_runner, dataset_source_path),
		"two TODO-14 formula arms"
	)
})

test_that("TODO-14 candidate validation is read-only and checks the full key/result contract", {
	if (!dir.exists("/tmp/tests") && !dir.create("/tmp/tests", recursive = TRUE)) {
		skip("/tmp/tests is not available for isolated synthetic fixtures")
	}
	fixture_dir <- tempfile("todo14-validator-", tmpdir = "/tmp/tests")
	expect_true(dir.create(fixture_dir))
	on.exit(unlink(fixture_dir, recursive = TRUE), add = TRUE)

	datasets <- c("diamonds", "pte_example", "ionosphere", "abalone", "iris", "boston", "fuel", "cars", "airquality")
	classes <- c(
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC [design_formula=~1]",
		"InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC [design_formula=~.]"
	)
	functions <- c("compute_rand_two_sided_pval", "compute_rand_two_sided_pval(delta=0.5)", "compute_rand_confidence_interval")
	manifest <- expand.grid(
		rep = 1:40,
		beta_T = c(0, 0.5),
		dataset = datasets,
		response_type = "survival",
		design = c("KK21stepwise", "FixedBinaryMatch"),
		inference_class = classes,
		function_run = functions,
		KEEP.OUT.ATTRS = FALSE,
		stringsAsFactors = FALSE
	)
	manifest$id <- paste(
		as.integer(manifest$rep),
		format(as.numeric(manifest$beta_T), scientific = TRUE, digits = 17),
		manifest$dataset, manifest$response_type, manifest$design,
		manifest$inference_class, manifest$function_run,
		sep = "||"
	)
	manifest$candidate_status <- "candidate_only_requires_setup_and_runtime_eligibility"
	manifest$scope_source <- "checked_in_runner_defaults_without_cli_filters"
	expect_equal(nrow(manifest), 8640L)

	candidate <- manifest
	candidate$run_row_id <- seq_len(nrow(candidate))
	candidate$status <- "ok"
	candidate$error_message <- NA_character_
	candidate$skip_reason <- NA_character_
	candidate$method_family <- "rand"
	candidate$coverage_scope <- "comprehensive_workflow"
	candidate$argument_coverage_kind <- "not_argument_combination"
	candidate$github_commit_id <- paste(rep("a", 40), collapse = "")
	candidate$timestamp <- "2026-10-20 12:00:00 UTC"
	is_ci <- candidate$function_run == "compute_rand_confidence_interval"
	candidate$result_1 <- ifelse(is_ci, -1, 0.25)
	candidate$result_2 <- ifelse(is_ci, 1, NA_real_)
	candidate$coverage_truth <- candidate$beta_T
	candidate$beta_T_in_confidence_interval <- is_ci

	provenance_snapshot <- list(
		checkout_sha = paste(rep("a", 40), collapse = ""),
		r_version = "R Under development (r90668)",
		package_version = "1.0.3",
		library_path = "/tmp/fake-library/EDI",
		dll_path = "/tmp/fake-library/EDI/libs/EDI.so",
		dll_sha256 = paste(rep("b", 64), collapse = "")
	)
	provenance <- list(before = provenance_snapshot, after = provenance_snapshot)

	manifest_path <- file.path(fixture_dir, "manifest.csv")
	candidate_path <- file.path(fixture_dir, "candidate.csv")
	utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
	utils::write.csv(candidate, candidate_path, row.names = FALSE, na = "")
	manifest_hash <- unname(tools::md5sum(manifest_path))
	candidate_hash <- unname(tools::md5sum(candidate_path))

	valid <- validate_todo14_candidate(
		manifest_path, candidate_path, provenance,
		provenance_snapshot
	)
	expect_true(valid$ok, info = paste(valid$issues$check, collapse = ", "))
	expect_length(valid$missing_ids, 0L)
	expect_length(valid$extra_ids, 0L)
	expect_identical(unname(tools::md5sum(manifest_path)), manifest_hash)
	expect_identical(unname(tools::md5sum(candidate_path)), candidate_hash)

	# Matching keys and row results must not silently promote the source
	# candidate inventory into an asserted attempt manifest.
	mislabelled_manifest <- manifest
	mislabelled_manifest$candidate_status <- "attempted"
	mislabelled_result <- validate_todo14_candidate(
		mislabelled_manifest, candidate, provenance, provenance_snapshot
	)
	expect_false(mislabelled_result$ok)
	expect_true(any(mislabelled_result$issues$check == "manifest_candidate_status"))
	manifest_with_attempt_claim <- manifest
	manifest_with_attempt_claim$runtime_eligible <- TRUE
	manifest_with_attempt_claim$attempted <- TRUE
	attempt_claim_result <- validate_todo14_candidate(
		manifest_with_attempt_claim, candidate, provenance, provenance_snapshot
	)
	expect_false(attempt_claim_result$ok)
	expect_true(any(attempt_claim_result$issues$check == "manifest_attempt_fields"))
	wrong_scope_manifest <- manifest
	wrong_scope_manifest$scope_source <- "runtime_attempts"
	wrong_scope_result <- validate_todo14_candidate(
		wrong_scope_manifest, candidate, provenance, provenance_snapshot
	)
	expect_false(wrong_scope_result$ok)
	expect_true(any(wrong_scope_result$issues$check == "manifest_scope_source"))

	# This candidate contract admits only successful rows, so the terminal
	# skip_reason field must be present and empty as well as status == "ok".
	candidate_without_skip_reason <- candidate
	candidate_without_skip_reason$skip_reason <- NULL
	missing_skip_reason <- validate_todo14_candidate(
		manifest_path, candidate_without_skip_reason, provenance,
		provenance_snapshot
	)
	expect_false(missing_skip_reason$ok)
	expect_true(any(missing_skip_reason$issues$check == "candidate_schema"))

	for (skip in c("timeout", "error")) {
		candidate_with_skip <- candidate
		candidate_with_skip$skip_reason[1] <- skip
		contradictory_skip <- validate_todo14_candidate(
			manifest_path, candidate_with_skip, provenance,
			provenance_snapshot
		)
		expect_false(contradictory_skip$ok)
		expect_true(any(contradictory_skip$issues$check == "skip_reason_present"))
	}
	candidate_with_error_message <- candidate
	candidate_with_error_message$error_message[1] <- "worker failed"
	contradictory_error <- validate_todo14_candidate(
		manifest_path, candidate_with_error_message, provenance,
		provenance_snapshot
	)
	expect_false(contradictory_error$ok)
	expect_true(any(contradictory_error$issues$check == "error_message_present"))

	# The full expected roster includes both design formulas. A valid `~.`
	# observation must not mask an absent FixedBinaryMatch `~1` attempt group.
	missing_fixed_binary_intercept <- manifest$design == "FixedBinaryMatch" &
		manifest$dataset == "pte_example" & manifest$beta_T == 0.5 &
		manifest$inference_class == classes[1]
	expect_equal(sum(missing_fixed_binary_intercept), 40L * length(functions))
	retained_fixed_binary_covariate <- manifest$design == "FixedBinaryMatch" &
		manifest$dataset == "pte_example" & manifest$beta_T == 0.5 &
		manifest$inference_class == classes[2]
	expect_equal(sum(retained_fixed_binary_covariate), 40L * length(functions))
	candidate_without_intercept_group <- candidate[
		!missing_fixed_binary_intercept, , drop = FALSE
	]
	missing_intercept_path <- file.path(fixture_dir, "candidate_missing_fixed_binary_intercept.csv")
	utils::write.csv(candidate_without_intercept_group, missing_intercept_path, row.names = FALSE, na = "")
	missing_intercept_result <- validate_todo14_candidate(
		manifest_path, missing_intercept_path, provenance, provenance_snapshot
	)
	expect_false(missing_intercept_result$ok)
	expect_setequal(missing_intercept_result$missing_ids, manifest$id[missing_fixed_binary_intercept])
	expect_length(missing_intercept_result$extra_ids, 0L)
	retained_covariate_ids <- manifest$id[retained_fixed_binary_covariate]
	retained_covariate_rows <- match(retained_covariate_ids, candidate_without_intercept_group$id)
	expect_false(anyNA(retained_covariate_rows))
	expect_true(all(candidate_without_intercept_group$status[retained_covariate_rows] == "ok"))
	expect_true(any(missing_intercept_result$issues$check == "missing_id"))
	expect_true(any(missing_intercept_result$issues$check == "candidate_row_count"))
	expect_true(any(missing_intercept_result$issues$check == "candidate_replicates"))

	bad <- candidate
	bad$id[1] <- "unexpected||candidate||id"
	bad$id[2] <- bad$id[3]
	bad$rep[2] <- bad$rep[3]
	bad$run_row_id[4] <- bad$run_row_id[3]
	bad$status[5] <- "error"
	bad$github_commit_id[6] <- paste(rep("c", 40), collapse = "")
	bad$result_1[7] <- 1.1
	ci_row <- which(is_ci)[1]
	bad$result_1[ci_row] <- 2
	bad$result_2[ci_row] <- 1
	bad$beta_T_in_confidence_interval[ci_row] <- TRUE
	bad_path <- file.path(fixture_dir, "candidate_bad.csv")
	utils::write.csv(bad, bad_path, row.names = FALSE, na = "")
	bad_hash <- unname(tools::md5sum(bad_path))
	changed_provenance <- provenance
	changed_provenance$after$dll_sha256 <- paste(rep("d", 64), collapse = "")

	invalid <- validate_todo14_candidate(
		manifest_path, bad_path, changed_provenance,
		provenance_snapshot
	)
	expect_false(invalid$ok)
	expect_true(all(manifest$id[1:2] %in% invalid$missing_ids))
	expect_setequal(invalid$extra_ids, "unexpected||candidate||id")
	expect_true(all(c(
		"duplicate_candidate_id", "duplicate_natural_key", "duplicate_run_row_id",
		"candidate_id_key_mismatch", "status_not_ok", "github_commit_id_mismatch",
		"invalid_p_value", "invalid_ci", "coverage_membership_mismatch"
	) %in% invalid$issues$check))
	expect_true(any(grepl("provenance changed during run: dll_sha256", invalid$issues$detail, fixed = TRUE)))
	expect_identical(unname(tools::md5sum(manifest_path)), manifest_hash)
	expect_identical(unname(tools::md5sum(bad_path)), bad_hash)

	# Integer coercion used while serializing IDs must not silently accept a
	# fractional replicate such as 1.5 as replicate 1.
	fractional_rep <- candidate
	fractional_rep$rep[1] <- 1.5
	fractional_path <- file.path(fixture_dir, "candidate_fractional_rep.csv")
	utils::write.csv(fractional_rep, fractional_path, row.names = FALSE, na = "")
	fractional_hash <- unname(tools::md5sum(fractional_path))
	fractional_result <- validate_todo14_candidate(
		manifest_path, fractional_path, provenance, provenance_snapshot
	)
	expect_false(fractional_result$ok)
	expect_true(any(fractional_result$issues$check == "invalid_rep"))
	expect_identical(unname(tools::md5sum(fractional_path)), fractional_hash)
	fractional_manifest <- manifest
	fractional_manifest$rep[1] <- 1.5
	fractional_manifest_path <- file.path(fixture_dir, "manifest_fractional_rep.csv")
	utils::write.csv(fractional_manifest, fractional_manifest_path, row.names = FALSE, na = "")
	fractional_manifest_hash <- unname(tools::md5sum(fractional_manifest_path))
	fractional_manifest_result <- validate_todo14_candidate(
		fractional_manifest_path, candidate_path, provenance, provenance_snapshot
	)
	expect_false(fractional_manifest_result$ok)
	expect_true(any(fractional_manifest_result$issues$check == "invalid_manifest_rep"))
	expect_identical(unname(tools::md5sum(fractional_manifest_path)), fractional_manifest_hash)

	# The expected inventory is untrusted input too: duplicate IDs in the
	# manifest must fail closed, even when the candidate itself is complete.
	duplicate_manifest <- manifest
	duplicate_manifest[2, .todo14_key_columns] <- duplicate_manifest[1, .todo14_key_columns]
	duplicate_manifest$id[2] <- duplicate_manifest$id[1]
	duplicate_manifest_path <- file.path(fixture_dir, "manifest_duplicate_key.csv")
	utils::write.csv(duplicate_manifest, duplicate_manifest_path, row.names = FALSE, na = "")
	duplicate_manifest_result <- validate_todo14_candidate(
		duplicate_manifest_path, candidate_path, provenance, provenance_snapshot
	)
	expect_false(duplicate_manifest_result$ok)
	expect_true(any(duplicate_manifest_result$issues$check == "duplicate_manifest_id"))
	expect_true(any(duplicate_manifest_result$issues$check == "manifest_replicates"))

	# The manifest serializer is an independent input contract too: a stale or
	# hand-edited ID must not be accepted merely because its key columns still
	# happen to anti-join cleanly against the candidate.
	manifest_id_mismatch <- manifest
	manifest_id_mismatch$id[1] <- paste0(manifest_id_mismatch$id[1], "||tampered")
	manifest_id_mismatch_path <- file.path(fixture_dir, "manifest_id_key_mismatch.csv")
	utils::write.csv(manifest_id_mismatch, manifest_id_mismatch_path, row.names = FALSE, na = "")
	manifest_id_mismatch_hash <- unname(tools::md5sum(manifest_id_mismatch_path))
	manifest_id_mismatch_result <- validate_todo14_candidate(
		manifest_id_mismatch_path, candidate_path, provenance, provenance_snapshot
	)
	expect_false(manifest_id_mismatch_result$ok)
	expect_true(any(manifest_id_mismatch_result$issues$check == "manifest_id_key_mismatch"))
	expect_setequal(manifest_id_mismatch_result$missing_ids, manifest_id_mismatch$id[1])
	expect_setequal(manifest_id_mismatch_result$extra_ids, manifest$id[1])
	expect_identical(unname(tools::md5sum(manifest_id_mismatch_path)), manifest_id_mismatch_hash)

	# A duplicate named provenance field is ambiguous in R (`[[name]]` returns
	# only one value), so it must not be accepted as an approved expectation.
	duplicate_expected <- append(
		provenance_snapshot,
		list(dll_sha256 = paste(rep("d", 64), collapse = ""))
	)
	duplicate_provenance_result <- validate_todo14_candidate(
		manifest_path, candidate_path, provenance, duplicate_expected
	)
	expect_false(duplicate_provenance_result$ok)
	expect_true(any(grepl(
		"expected provenance has duplicate field names",
		duplicate_provenance_result$issues$detail, fixed = TRUE
	)))
	expect_identical(unname(tools::md5sum(manifest_path)), manifest_hash)
	expect_identical(unname(tools::md5sum(candidate_path)), candidate_hash)
})
