library(testthat)
library(EDI)

source(test_path("..", "comprehensive_results_path.R"), local = TRUE)
source(test_path("..", "comprehensive_run_provenance.R"), local = TRUE)

test_that("the default comprehensive result path remains exactly canonical", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = ""))
	canonical <- file.path(
		"/repo",
		"package_tests",
		"comprehensive_tests_results_nc_2_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv"
	)

	expect_identical(resolve_comprehensive_results_file(canonical), canonical)
})

test_that("an existing override directory receives the same filtered filename", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = tempdir()))
	canonical <- file.path(
		"/repo",
		"package_tests",
		"comprehensive_tests_results_nc_2_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv"
	)

	expect_identical(
		resolve_comprehensive_results_file(canonical),
		file.path(normalizePath(tempdir(), winslash = "/"), basename(canonical))
	)
})

test_that("a typo in the override fails closed instead of falling back to canonical output", {
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = file.path(tempdir(), "missing-output-dir")))
	canonical <- file.path("/repo", "package_tests", "comprehensive_tests_results_nc_2.csv")

	expect_error(
		resolve_comprehensive_results_file(canonical),
		"EDI_COMPREHENSIVE_RESULTS_DIR is not an existing directory"
	)
})

test_that("the startup prune scan is skipped only by explicit isolated-run opt-in", {
	checkout <- tempfile("edi-comprehensive-prune-checkout-")
	dir.create(checkout)
	on.exit(unlink(checkout, recursive = TRUE), add = TRUE)
	canonical_dir <- file.path(checkout, "R", "package_tests")
	dir.create(canonical_dir, recursive = TRUE)
	canonical_csv <- file.path(canonical_dir, "comprehensive_tests_results_nc_1_proportion.csv")
	writeBin(charToRaw("canonical rows\n"), canonical_csv)
	canonical_before <- readBin(canonical_csv, what = "raw", n = file.info(canonical_csv)$size)
	isolated_dir <- tempfile("edi-comprehensive-prune-output-")
	dir.create(isolated_dir)
	on.exit(unlink(isolated_dir, recursive = TRUE), add = TRUE)

	pruner_calls <- list()
	fake_system2 <- function(command, args, stdout, stderr) {
		pruner_calls[[length(pruner_calls) + 1L]] <<- list(command = command, args = args)
		character()
	}
	messages <- character()
	run_comprehensive_startup_prune_check(
		pruner_path = file.path(canonical_dir, "prune_stale_result_rows.R"),
		checkout_root = checkout,
		skip = "1",
		output_dir = isolated_dir,
		system2_fn = fake_system2,
		message_fn = function(...) messages <<- c(messages, paste0(..., collapse = ""))
	)
	expect_length(pruner_calls, 0L)
	expect_match(paste(messages, collapse = "\n"), "skipped by EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1")
	expect_identical(readBin(canonical_csv, what = "raw", n = file.info(canonical_csv)$size), canonical_before)

	expect_false(should_skip_comprehensive_prune_check(skip = "", output_dir = isolated_dir, checkout_root = checkout))
	expect_error(
		should_skip_comprehensive_prune_check(skip = "true", output_dir = isolated_dir, checkout_root = checkout),
		"must be unset or exactly '1'"
	)
	expect_error(
		should_skip_comprehensive_prune_check(skip = "1", output_dir = "", checkout_root = checkout),
		"requires EDI_COMPREHENSIVE_RESULTS_DIR outside the checkout"
	)
	expect_error(
		should_skip_comprehensive_prune_check(skip = "1", output_dir = canonical_dir, checkout_root = checkout),
		"outside the checkout"
	)
})

test_that("the default startup prune invocation remains report-only", {
	checkout <- tempfile("edi-comprehensive-prune-default-")
	dir.create(checkout)
	on.exit(unlink(checkout, recursive = TRUE), add = TRUE)
	pruner <- file.path(checkout, "R", "package_tests", "prune_stale_result_rows.R")
	dir.create(dirname(pruner), recursive = TRUE)
	writeLines("# fixture", pruner)
	pruner_calls <- list()
	fake_system2 <- function(command, args, stdout, stderr) {
		pruner_calls[[length(pruner_calls) + 1L]] <<- list(command = command, args = args)
		"prune_stale_result_rows: 3 stale row(s) would be removed; re-run with --apply."
	}
	messages <- character()
	run_comprehensive_startup_prune_check(
		pruner_path = pruner,
		checkout_root = checkout,
		skip = "",
		output_dir = "",
		system2_fn = fake_system2,
		message_fn = function(...) messages <<- c(messages, paste0(..., collapse = ""))
	)
	expect_length(pruner_calls, 1L)
	expect_identical(pruner_calls[[1L]]$command, "Rscript")
	expect_identical(pruner_calls[[1L]]$args, shQuote(pruner))
	expect_false("--apply" %in% pruner_calls[[1L]]$args)
	expect_match(paste(messages, collapse = "\n"), "3 stale row\\(s\\)")
})

test_that("comprehensive pilot provenance captures package, DLL, and checkout identity", {
	withr::local_seed(20261020)
	provenance = capture_comprehensive_run_provenance(
		repo_root = test_path("..", "..", ".."),
		runner_path = test_path("..", "comprehensive_tests.R")
	)
	expect_identical(provenance$rng_kind, RNGkind())
	expect_identical(provenance$rng_seed, get(".Random.seed", envir = .GlobalEnv, inherits = FALSE))
	expect_identical(provenance$edi_package_version, as.character(getNamespaceInfo(asNamespace("EDI"), "spec")[["version"]]))
	expect_identical(provenance$edi_package_path, normalizePath(find.package("EDI"), winslash = "/"))
	expect_identical(provenance$edi_namespace_path, normalizePath(getNamespaceInfo(asNamespace("EDI"), "path"), winslash = "/"))
	runner_path = normalizePath(test_path("..", "comprehensive_tests.R"), winslash = "/", mustWork = TRUE)
	expect_identical(
		provenance$edi_package_payload_path,
		normalizePath(file.path(dirname(dirname(runner_path)), "EDI"), winslash = "/")
	)
	expect_match(provenance$edi_package_payload_sha256, "^[[:xdigit:]]{64}$")
	expect_identical(
		provenance$edi_dll_path,
		normalizePath(getLoadedDLLs()[["EDI"]][["path"]], winslash = "/")
	)
	expect_match(provenance$edi_dll_sha256, "^[[:xdigit:]]{64}$")
	expect_match(provenance$checkout_head, "^[[:xdigit:]]{40}([[:xdigit:]]{24})?$")
	expect_match(provenance$checkout_diff_sha256, "^[[:xdigit:]]{64}$")
	expect_type(provenance$checkout_status_porcelain, "character")
	expect_match(provenance$runner_sha256, "^[[:xdigit:]]{64}$")
	expect_match(provenance$beta_filter_helper_sha256, "^[[:xdigit:]]{64}$")

	hash_fixture = tempfile("edi-provenance-sha256-")
	on.exit(unlink(hash_fixture), add = TRUE)
	writeBin(charToRaw("abc"), hash_fixture)
	expect_identical(comprehensive_sha256_file(hash_fixture), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	expect_identical(
		comprehensive_result_file_identity(hash_fixture),
		list(exists = TRUE, bytes = 3, sha256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	)
	missing_result = tempfile("edi-comprehensive-provenance-missing-")
	expect_identical(
		comprehensive_result_file_identity(missing_result),
		list(exists = FALSE, bytes = 0, sha256 = NA_character_)
	)

	started_at = as.POSIXct("2026-10-20 12:34:56", tz = "UTC")
	scratch = tempfile("edi-comprehensive-provenance-")
	dir.create(scratch)
	on.exit(unlink(scratch, recursive = TRUE), add = TRUE)
	withr::local_envvar(c(EDI_COMPREHENSIVE_RESULTS_DIR = scratch))
	results_file = resolve_comprehensive_results_file(file.path("/repo", "results.csv"))
	sidecar = comprehensive_run_provenance_sidecar_path(results_file, started_at, 123L)
	expect_identical(dirname(sidecar), normalizePath(scratch, winslash = "/"))
	expect_match(basename(sidecar), "^results\\.csv\\.provenance-20261020T123456\\.000000-pid123\\.rds$")
	expect_false(file.exists(sidecar))

	write_comprehensive_run_provenance(sidecar, list(schema_version = 2L, before = provenance, after = provenance))
	expect_identical(readRDS(sidecar)$schema_version, 2L)
	expect_error(
		write_comprehensive_run_provenance(sidecar, list(schema_version = 2L)),
		"refusing to overwrite"
	)
})

test_that("comprehensive provenance resolves helper paths beside a runner under a package root", {
	repo_root = tempfile("edi-comprehensive-runner-root-")
	dir.create(repo_root)
	on.exit(unlink(repo_root, recursive = TRUE), add = TRUE)

	checkout_r_root = file.path(repo_root, "R")
	package_root = file.path(checkout_r_root, "EDI")
	runner_dir = file.path(checkout_r_root, "package_tests")
	dir.create(runner_dir, recursive = TRUE)
	dir.create(file.path(package_root, "R"), recursive = TRUE)
	dir.create(file.path(package_root, "src"), recursive = TRUE)
	writeLines("Package: fixture", file.path(package_root, "DESCRIPTION"))
	writeLines("exportPattern(\".\")", file.path(package_root, "NAMESPACE"))
	writeLines("fixture <- function() 1L", file.path(package_root, "R", "fixture.R"))
	writeLines("// fixture", file.path(package_root, "src", "fixture.cpp"))
	runner_path = file.path(runner_dir, "comprehensive_tests.R")
	beta_helper_path = file.path(runner_dir, "comprehensive_beta_filter.R")
	provenance_helper_path = file.path(runner_dir, "comprehensive_run_provenance.R")
	writeLines("# temporary runner fixture", runner_path)
	writeLines("# temporary beta-filter fixture", beta_helper_path)
	writeLines("# temporary provenance fixture", provenance_helper_path)

	git_init_status = system2("git", c("-C", shQuote(repo_root), "init", "-q"), stdout = FALSE, stderr = FALSE)
	expect_identical(as.integer(git_init_status), 0L)
	git_commit_status = system2(
		"git",
		c(
			"-C", shQuote(repo_root), "-c", shQuote("user.name=EDI test"),
			"-c", shQuote("user.email=edi-test@example.invalid"),
			"commit", "--allow-empty", "-m", shQuote("temporary provenance fixture")
		),
		stdout = FALSE,
		stderr = FALSE
	)
	expect_identical(as.integer(git_commit_status), 0L)

	# comprehensive_tests.R's repo_root is the checkout's R/ tree; the package
	# source/runtime payload is its EDI child.
	runner_local_root = normalizePath(file.path(dirname(runner_path), ".."), winslash = "/")
	provenance = capture_comprehensive_run_provenance(runner_local_root, runner_path)
	expect_identical(provenance$edi_package_payload_path, normalizePath(package_root, winslash = "/"))
	expect_match(provenance$edi_package_payload_sha256, "^[[:xdigit:]]{64}$")
	expect_identical(provenance$beta_filter_helper_path, normalizePath(beta_helper_path, winslash = "/"))
	expect_identical(provenance$provenance_helper_path, normalizePath(provenance_helper_path, winslash = "/"))
})

test_that("package payload fingerprints include source/runtime files but not docs or tests", {
	package_root = tempfile("edi-comprehensive-payload-")
	dir.create(file.path(package_root, "R"), recursive = TRUE)
	dir.create(file.path(package_root, "src"), recursive = TRUE)
	dir.create(file.path(package_root, "tests"), recursive = TRUE)
	writeLines("Package: fixture", file.path(package_root, "DESCRIPTION"))
	writeLines("exportPattern(\".\")", file.path(package_root, "NAMESPACE"))
	writeLines("fixture <- function() 1L", file.path(package_root, "R", "fixture.R"))
	writeLines("// fixture", file.path(package_root, "src", "fixture.cpp"))
	on.exit(unlink(package_root, recursive = TRUE), add = TRUE)

	initial = comprehensive_package_payload_identity(package_root)
	writeLines("documentation only", file.path(package_root, "README.md"))
	writeLines("test only", file.path(package_root, "tests", "fixture.R"))
	docs_and_tests = comprehensive_package_payload_identity(package_root)
	expect_identical(docs_and_tests, initial)

	writeLines("fixture <- function() 2L", file.path(package_root, "R", "fixture.R"))
	changed_source = comprehensive_package_payload_identity(package_root)
	expect_identical(changed_source$path, initial$path)
	expect_false(identical(changed_source$sha256, initial$sha256))
	writeLines("// changed native source", file.path(package_root, "src", "fixture.cpp"))
	changed_native_source = comprehensive_package_payload_identity(package_root)
	expect_false(identical(changed_native_source$sha256, changed_source$sha256))
})

test_that("the runner captures provenance before and after a completed pilot", {
	runner_source = paste(
		readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE),
		collapse = "\n"
	)
	expect_match(runner_source, "run_provenance_before = capture_comprehensive_run_provenance\\(repo_root, script_path\\)")
	expect_match(runner_source, "run_provenance_after = capture_comprehensive_run_provenance\\(repo_root, script_path\\)")
	expect_match(runner_source, "run_results_file_before = comprehensive_result_file_identity\\(results_file, include_sha256 = FALSE\\)")
	expect_match(runner_source, "run_results_file_after = comprehensive_result_file_identity\\(results_file, include_sha256 = TRUE\\)")
	expect_match(runner_source, "command_args = args")
	expect_match(runner_source, "write_comprehensive_run_provenance\\(\\s*run_provenance_file")
	expect_match(runner_source, "comprehensive_run_provenance_sidecar_path\\(results_file, run_provenance_started_at, Sys.getpid\\(\\)\\)")
})

test_that("comprehensive artifact validation rejects stale or incomplete result rows", {
	scratch = tempfile("edi-comprehensive-artifact-validation-")
	dir.create(scratch)
	on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

	identity = list(
		r_version = "R test", edi_package_version = "1.0.3",
		edi_package_path = "/tmp/EDI", edi_namespace_path = "/tmp/EDI",
		edi_package_payload_path = "/tmp/checkout/R/EDI", edi_package_payload_sha256 = paste(rep("9", 64L), collapse = ""),
		edi_dll_path = "/tmp/EDI/libs/EDI.so", edi_dll_sha256 = paste(rep("a", 64L), collapse = ""),
		checkout_path = "/tmp/checkout", checkout_head = paste(rep("b", 40L), collapse = ""),
		checkout_status_porcelain = character(), checkout_diff_sha256 = paste(rep("c", 64L), collapse = ""),
		runner_path = "/tmp/comprehensive_tests.R", runner_sha256 = paste(rep("d", 64L), collapse = ""),
		beta_filter_helper_path = "/tmp/comprehensive_beta_filter.R", beta_filter_helper_sha256 = paste(rep("e", 64L), collapse = ""),
		provenance_helper_path = "/tmp/comprehensive_run_provenance.R", provenance_helper_sha256 = paste(rep("f", 64L), collapse = "")
	)
	started = "2026-10-20T10:00:00.000000Z"
	completed = "2026-10-20T10:01:00.000000Z"
	write_fixture = function(name, rows){
		csv = file.path(scratch, paste0(name, ".csv"))
		write.csv(rows, csv, row.names = FALSE, na = "")
		identity_after = comprehensive_result_file_identity(csv, include_sha256 = TRUE)
		provenance = list(
			schema_version = 2L,
			results_file = normalizePath(csv, winslash = "/"),
			results_file_before = list(exists = FALSE, bytes = 0, sha256 = NA_character_),
			results_file_after = identity_after,
			started_at_utc = started,
			completed_at_utc = completed,
			command_args = c("1", "2", "incidence"),
			before = identity,
			after = identity
		)
		sidecar = paste0(csv, ".provenance.rds")
		write_comprehensive_run_provenance(sidecar, provenance)
		list(csv = csv, sidecar = sidecar)
	}
	expected = data.frame(
		rep = c(1L, 1L), inference_class = c("InferenceExample", "InferenceExample"),
		function_run = c("compute_estimate", "compute_wald_two_sided_pval"),
		stringsAsFactors = FALSE
	)
	valid_rows = data.frame(
		rep = c(1L, 1L), inference_class = c("InferenceExample", "InferenceExample"),
		function_run = expected$function_run, result = c("0.2", "0.04"),
		stringsAsFactors = FALSE
	)
	valid = write_fixture("current", valid_rows)
	validated = validate_comprehensive_result_artifact(
		valid$csv, valid$sidecar, expected,
		key_columns = c("rep", "inference_class"),
		forbidden_methods = c("compute_score_two_sided_pval", "compute_lik_ratio_two_sided_pval"),
		expected_run_provenance = list(edi_package_version = "1.0.3")
	)
	expect_identical(validated$rows, 2L)
	expect_error(
		validate_comprehensive_result_artifact(
			valid$csv, file.path(scratch, "missing.rds"), expected,
			key_columns = c("rep", "inference_class")
		),
		"provenance sidecar is required"
	)

	write.table("stale", valid$csv, append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)
	expect_error(
		validate_comprehensive_result_artifact(
			valid$csv, valid$sidecar, expected,
			key_columns = c("rep", "inference_class")
		),
		"size or SHA-256 does not match"
	)

	extra_rows = rbind(valid_rows, data.frame(
		rep = 1L, inference_class = "InferenceExample", function_run = "compute_extra_method",
		result = "0.1", stringsAsFactors = FALSE
	))
	extra = write_fixture("extra", extra_rows)
	expect_error(
		validate_comprehensive_result_artifact(
			extra$csv, extra$sidecar, expected,
			key_columns = c("rep", "inference_class")
		),
		"key/method inventory mismatch .*extra=1"
	)
	expect_error(
		validate_comprehensive_result_artifact(
			extra$csv, extra$sidecar,
			rbind(expected, data.frame(rep = 1L, inference_class = "InferenceExample", function_run = "missing_method")),
			key_columns = c("rep", "inference_class")
		),
		"key/method inventory mismatch .*missing=1"
	)

	forbidden_rows = rbind(valid_rows, data.frame(
		rep = 1L, inference_class = "InferenceExample", function_run = "compute_score_two_sided_pval",
		result = "0.8", stringsAsFactors = FALSE
	))
	forbidden = write_fixture("forbidden", forbidden_rows)
	expect_error(
		validate_comprehensive_result_artifact(
			forbidden$csv, forbidden$sidecar, expected,
			key_columns = c("rep", "inference_class"),
			forbidden_methods = "compute_score_two_sided_pval"
		),
		"contains a forbidden method row"
	)

	provenance_mismatch = write_fixture("provenance", valid_rows)
	provenance = readRDS(provenance_mismatch$sidecar)
	provenance$after$edi_package_version = "1.0.4"
	unlink(provenance_mismatch$sidecar)
	write_comprehensive_run_provenance(provenance_mismatch$sidecar, provenance)
	expect_error(
		validate_comprehensive_result_artifact(
			provenance_mismatch$csv, provenance_mismatch$sidecar, expected,
			key_columns = c("rep", "inference_class")
		),
		"provenance changed or is incomplete"
	)

	diagnostic_diff_change = write_fixture("diagnostic-diff-change", valid_rows)
	diagnostic_provenance = readRDS(diagnostic_diff_change$sidecar)
	diagnostic_provenance$after$checkout_diff_sha256 = paste(rep("1", 64L), collapse = "")
	expect_false(identical(
		diagnostic_provenance$before$checkout_diff_sha256,
		diagnostic_provenance$after$checkout_diff_sha256
	))
	expect_identical(
		diagnostic_provenance$before$edi_package_payload_sha256,
		diagnostic_provenance$after$edi_package_payload_sha256
	)
	unlink(diagnostic_diff_change$sidecar)
	write_comprehensive_run_provenance(diagnostic_diff_change$sidecar, diagnostic_provenance)
	expect_no_error(validate_comprehensive_result_artifact(
		diagnostic_diff_change$csv, diagnostic_diff_change$sidecar, expected,
		key_columns = c("rep", "inference_class")
	))

	package_payload_change = write_fixture("package-payload-change", valid_rows)
	package_payload_provenance = readRDS(package_payload_change$sidecar)
	package_payload_provenance$after$edi_package_payload_sha256 = paste(rep("8", 64L), collapse = "")
	unlink(package_payload_change$sidecar)
	write_comprehensive_run_provenance(package_payload_change$sidecar, package_payload_provenance)
	expect_error(
		validate_comprehensive_result_artifact(
			package_payload_change$csv, package_payload_change$sidecar, expected,
			key_columns = c("rep", "inference_class")
		),
		"provenance changed or is incomplete"
	)

	dll_change = write_fixture("dll-change", valid_rows)
	dll_provenance = readRDS(dll_change$sidecar)
	dll_provenance$after$edi_dll_sha256 = paste(rep("7", 64L), collapse = "")
	unlink(dll_change$sidecar)
	write_comprehensive_run_provenance(dll_change$sidecar, dll_provenance)
	expect_error(
		validate_comprehensive_result_artifact(
			dll_change$csv, dll_change$sidecar, expected,
			key_columns = c("rep", "inference_class")
		),
		"provenance changed or is incomplete"
	)
})

test_that("TODO-77 binds the 80 formula-preserving attempts to provenance and terminal fields", {
	scratch <- tempfile("edi-todo77-terminal-contract-")
	expect_true(dir.create(scratch))
	on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

	base_classes <- c(
		"InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitGLMMIVWC"
	)
	class_grid <- expand.grid(
		base_class = base_classes,
		model_formula = c("~1", "~."),
		design_formula = c("~1", "~."),
		stringsAsFactors = FALSE
	)
	class_grid$inference_class <- paste0(
		class_grid$base_class,
		" (model_formula=", class_grid$model_formula,
		") [design_formula=", class_grid$design_formula, "]"
	)
	methods <- c(
		"compute_bayesian_bootstrap_confidence_interval",
		"compute_bayesian_bootstrap_confidence_interval_basic",
		"compute_bayesian_bootstrap_confidence_interval_bca",
		"compute_bayesian_bootstrap_confidence_interval_studentized",
		"compute_bayesian_bootstrap_confidence_interval_wald",
		"compute_bayesian_bootstrap_two_sided_pval",
		"compute_bayesian_bootstrap_two_sided_pval_bca",
		"compute_bayesian_bootstrap_two_sided_pval_studentized",
		"compute_bayesian_bootstrap_two_sided_pval_symmetric",
		"compute_bayesian_bootstrap_two_sided_pval_wald"
	)
	expected <- expand.grid(
		rep = 1L,
		beta_T = 0,
		dataset = "pima",
		response_type = "incidence",
		design = "KK21stepwise",
		inference_class = class_grid$inference_class,
		function_run = methods,
		KEEP.OUT.ATTRS = FALSE,
		stringsAsFactors = FALSE
	)
	expect_equal(nrow(expected), 80L)
	expect_equal(length(unique(expected$inference_class)), 8L)
	expect_true(any(grepl("(model_formula=~.) [design_formula=~.]", expected$inference_class, fixed = TRUE)))

	identity <- list(
		r_version = "R test", edi_package_version = "1.0.3",
		edi_package_path = "/tmp/EDI", edi_namespace_path = "/tmp/EDI",
		edi_package_payload_path = "/tmp/checkout/R/EDI", edi_package_payload_sha256 = paste(rep("9", 64L), collapse = ""),
		edi_dll_path = "/tmp/EDI/libs/EDI.so", edi_dll_sha256 = paste(rep("a", 64L), collapse = ""),
		checkout_path = "/tmp/checkout", checkout_head = paste(rep("b", 40L), collapse = ""),
		checkout_status_porcelain = character(), checkout_diff_sha256 = paste(rep("c", 64L), collapse = ""),
		runner_path = "/tmp/comprehensive_tests.R", runner_sha256 = paste(rep("d", 64L), collapse = ""),
		beta_filter_helper_path = "/tmp/comprehensive_beta_filter.R", beta_filter_helper_sha256 = paste(rep("e", 64L), collapse = ""),
		provenance_helper_path = "/tmp/comprehensive_run_provenance.R", provenance_helper_sha256 = paste(rep("f", 64L), collapse = "")
	)
	write_artifact <- function(name, rows) {
		csv <- file.path(scratch, paste0(name, ".csv"))
		utils::write.csv(rows, csv, row.names = FALSE, na = "")
		provenance <- list(
			schema_version = 2L,
			results_file = normalizePath(csv, winslash = "/"),
			results_file_before = list(exists = FALSE, bytes = 0, sha256 = NA_character_),
			results_file_after = comprehensive_result_file_identity(csv, include_sha256 = TRUE),
			started_at_utc = "2026-10-20T10:00:00.000000Z",
			completed_at_utc = "2026-10-20T10:01:00.000000Z",
			command_args = c("1", "2", "incidence", "InferenceIncidKKCondLogitGLMM", "pima"),
			before = identity,
			after = identity
		)
		sidecar <- paste0(csv, ".provenance.rds")
		write_comprehensive_run_provenance(sidecar, provenance)
		list(csv = csv, sidecar = sidecar)
	}
	valid_rows <- expected
	valid_rows$status <- "ok"
	valid_rows$error_message <- ""
	valid_rows$skip_reason <- ""
	valid_rows$result_1 <- "0.25"
	valid_rows$result_2 <- NA_character_
	valid <- write_artifact("valid", valid_rows)
	validated <- validate_comprehensive_result_artifact(
		valid$csv, valid$sidecar, expected,
		key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
		expected_run_provenance = list(edi_package_version = "1.0.3"),
		require_terminal_result_fields = TRUE
	)
	expect_identical(validated$rows, 80L)
	expect_error(
		validate_comprehensive_result_artifact(
			valid$csv, valid$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
		expected_run_provenance = list(edi_package_version = "1.0.4"),
			require_terminal_result_fields = TRUE
		),
		"does not match expected field: edi_package_version"
	)

	# A formula-bearing class label is a natural key, not a cosmetic suffix:
	# dropping the ~. model/design combination must remain visible as missing.
	formula_key <- which(grepl("(model_formula=~.) [design_formula=~.]", valid_rows$inference_class, fixed = TRUE))[1L]
	formula_omitted <- write_artifact("formula-omitted", valid_rows[-formula_key, , drop = FALSE])
	expect_error(
		validate_comprehensive_result_artifact(
			formula_omitted$csv, formula_omitted$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		),
		"key/method inventory mismatch \\(missing=1, extra=0\\)"
	)

	bad_terminal <- valid_rows
	bad_terminal$status[1L] <- "error"
	bad_terminal$error_message[1L] <- "worker failed"
	bad_terminal$skip_reason[1L] <- ""
	bad <- write_artifact("bad-terminal", bad_terminal)
	expect_error(
		validate_comprehensive_result_artifact(
			bad$csv, bad$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		),
		"error result rows require an error_message and skip_reason"
	)

	# Timeout rows are retryable attempts, not terminal successes. Preserve the
	# separate recorded-skip case while rejecting the status/error contradiction.
	recorded_skip <- valid_rows
	recorded_skip$error_message[1L] <- "Method is not supported"
	recorded_skip$skip_reason[1L] <- "unsupported"
	recorded_skip_artifact <- write_artifact("recorded-skip", recorded_skip)
	expect_identical(
		validate_comprehensive_result_artifact(
			recorded_skip_artifact$csv, recorded_skip_artifact$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		)$rows,
		80L
	)

	# The cache classifier treats this as an ordinary completed diagnostic, not
	# a runner timeout; terminal validation must not reject it by substring.
	non_timeout_mention <- valid_rows
	non_timeout_mention$error_message[1L] <- "timeout noted in diagnostic text but not a timeout outcome"
	non_timeout_mention$skip_reason[1L] <- "diagnostic"
	non_timeout_artifact <- write_artifact("non-timeout-mention", non_timeout_mention)
	expect_identical(
		validate_comprehensive_result_artifact(
			non_timeout_artifact$csv, non_timeout_artifact$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		)$rows,
		80L
	)

	ok_timeout <- valid_rows
	ok_timeout$error_message[1L] <- "Skipped due to timeout after 120 seconds"
	ok_timeout$skip_reason[1L] <- "timeout"
	ok_timeout_artifact <- write_artifact("ok-timeout", ok_timeout)
	expect_error(
		validate_comprehensive_result_artifact(
			ok_timeout_artifact$csv, ok_timeout_artifact$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		),
		"timeout result rows cannot have status='ok'"
	)

	missing_terminal <- valid_rows[, setdiff(names(valid_rows), "result_2"), drop = FALSE]
	missing_field <- write_artifact("missing-terminal", missing_terminal)
	expect_error(
		validate_comprehensive_result_artifact(
			missing_field$csv, missing_field$sidecar, expected,
			key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class"),
			require_terminal_result_fields = TRUE
		),
		"missing terminal result field.*result_2"
	)
})

test_that("the TODO-19 estimate-family roster is derived from the runner's class and call sites", {
	runner_source = readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE)
	target_dispatch = grep(
		'run_inference_checks_both_paths\\(InferenceIncidKKModifiedPoisson, "InferenceIncidKKModifiedPoisson"',
		runner_source, value = TRUE
	)
	expect_length(target_dispatch, 1L)
	target_line = which(runner_source == target_dispatch[[1L]])
	expect_true(any(grepl("if (is_kk_design)", runner_source[seq.int(max(1L, target_line - 20L), target_line - 1L)], fixed = TRUE)))

	path_source = paste(c(
		grep("univ_label = paste0(class_name", runner_source, value = TRUE, fixed = TRUE),
		grep("multi_label = paste0(class_name", runner_source, value = TRUE, fixed = TRUE)
	), collapse = " ")
	formula_suffixes = c(" (model_formula=~1)", " (model_formula=~.)")
	for (suffix in formula_suffixes) expect_true(grepl(suffix, path_source, fixed = TRUE))

	estimate_calls = grep('safe_call_family\\("estimate", "compute_estimate"', runner_source, value = TRUE)
	expect_length(estimate_calls, 2L) # one special-case and one general path
	estimate_labels = "compute_estimate"

	# Caller-owned scope: one explicit stable case. Replicate and beta remain
	# part of the full key; case_id alone does not distinguish those dimensions.
	case = data.frame(
		rep = 1L, beta_T = 0.25, dataset = "mtcars",
		response_type = "incidence", design = "KK21",
		stringsAsFactors = FALSE
	)
	inference_labels = paste0("InferenceIncidKKModifiedPoisson", formula_suffixes)
	manifest = case[rep(1L, length(inference_labels)), , drop = FALSE]
	manifest$inference_class = inference_labels
	manifest$function_run = rep(estimate_labels, length.out = nrow(manifest))
	manifest = manifest[c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")]
	rownames(manifest) = NULL

	expect_identical(manifest, data.frame(
		rep = c(1L, 1L), beta_T = c(0.25, 0.25),
		dataset = c("mtcars", "mtcars"), response_type = c("incidence", "incidence"),
		design = c("KK21", "KK21"),
		inference_class = c(
			"InferenceIncidKKModifiedPoisson (model_formula=~1)",
			"InferenceIncidKKModifiedPoisson (model_formula=~.)"
		),
		function_run = c("compute_estimate", "compute_estimate"),
		stringsAsFactors = FALSE
	))
	expect_identical(anyDuplicated(comprehensive_result_manifest_keys(
		manifest,
		c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	)), 0L)
})

test_that("one fixed Wald-eligible case yields the runner's exact direct-method keys", {
	runner_source = readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE)
	wald_pval_call = grep(
		'call_direct_asymp\\("compute_wald_two_sided_pval", "wald"',
		runner_source, value = TRUE
	)
	wald_ci_call = grep(
		'call_direct_asymp\\("compute_wald_confidence_interval", "wald"',
		runner_source, value = TRUE
	)
	expect_length(wald_pval_call, 1L)
	expect_length(wald_ci_call, 1L)
	helper_start = grep("^call_direct_asymp = function", runner_source)
	helper_end = grep("^}", runner_source)
	helper_end = helper_end[helper_end > helper_start][[1L]]
	direct_helper = paste(runner_source[helper_start:helper_end], collapse = " ")
	expect_true(grepl('should_run_test_family(testing_type)', direct_helper, fixed = TRUE))
	expect_true(grepl('seq_des_inf[[method_name]]', direct_helper, fixed = TRUE))
	expect_true(grepl('supports_direct_testing_type(testing_type)', direct_helper, fixed = TRUE))
	expect_true(grepl('safe_call(method_name, do.call(method_fn, list(...)))', direct_helper, fixed = TRUE))

	# This reduced roster fixes the source's relevant eligibility gates to true:
	# family filter = wald, skip_asymp = FALSE, and both direct methods exist and
	# support wald. It is a declared attempt slice, not a claim that a full run
	# attempted every class method or case.
	formula_suffixes = c(" (model_formula=~1)", " (model_formula=~.)")
	methods = c("compute_wald_two_sided_pval", "compute_wald_confidence_interval")
	case = data.frame(
		rep = 1L, beta_T = 0.25, dataset = "mtcars",
		response_type = "incidence", design = "KK21",
		stringsAsFactors = FALSE
	)
	case_index = rep(seq_len(nrow(case)), each = length(formula_suffixes) * length(methods))
	manifest = case[case_index, , drop = FALSE]
	manifest$inference_class = rep(
		paste0("InferenceIncidKKModifiedPoisson", formula_suffixes),
		each = length(methods)
	)
	manifest$function_run = rep(methods, times = nrow(case) * length(formula_suffixes))
	manifest = manifest[c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")]
	rownames(manifest) = NULL

	expected = data.frame(
		rep = rep(1L, 4L), beta_T = rep(0.25, 4L),
		dataset = rep("mtcars", 4L), response_type = rep("incidence", 4L),
		design = rep("KK21", 4L),
		inference_class = rep(c(
			"InferenceIncidKKModifiedPoisson (model_formula=~1)",
			"InferenceIncidKKModifiedPoisson (model_formula=~.)"
		), each = 2L),
		function_run = rep(methods, times = 2L),
		stringsAsFactors = FALSE
	)
	expect_identical(manifest, expected)
	key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	expect_identical(anyDuplicated(comprehensive_result_manifest_keys(manifest, key_columns)), 0L)
})

test_that("unsupported score and likelihood-ratio paths add no TODO-19 keys", {
	modified_poisson_source = readLines(test_path("..", "..", "EDI", "R", "inference_incidence_KK_marginal.R"), warn = FALSE)
	type_impl_lines = grep("get_supported_testing_types_impl = function(){", modified_poisson_source, fixed = TRUE)
	expect_gt(length(type_impl_lines), 0L)
	# The first private type implementation belongs to the abstract modified-
	# Poisson class; it explicitly returns Wald only.
	expect_true(grepl('"wald"', modified_poisson_source[type_impl_lines[[1L]] + 1L], fixed = TRUE))

	runner_source = readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE)
	score_calls = grep('call_direct_asymp\\("compute_score_(two_sided_pval|confidence_interval)", "score"', runner_source, value = TRUE)
	likelihood_ratio_calls = grep('call_direct_asymp\\("compute_lik_ratio_(two_sided_pval|confidence_interval)", "lik_ratio"', runner_source, value = TRUE)
	expect_length(score_calls, 2L)
	expect_length(likelihood_ratio_calls, 2L)
	helper_start = grep("^call_direct_asymp = function", runner_source)
	helper_end = grep("^}", runner_source)
	helper_end = helper_end[helper_end > helper_start][[1L]]
	direct_helper = paste(runner_source[helper_start:helper_end], collapse = " ")
	expect_true(grepl("supports_direct_testing_type(testing_type)", direct_helper, fixed = TRUE))
	expect_true(grepl("safe_call(method_name, do.call(method_fn, list(...)))", direct_helper, fixed = TRUE))

	# Fixed source-derived eligibility: one caller-scoped case, both class
	# formula paths, and only wald in the declared testing-type set. Thus
	# score/LR are not attempted and must not appear as method rows. Preserve
	# the full natural key schema even when this family slice has zero rows.
	case = data.frame(
		rep = 1L, beta_T = 0.25, dataset = "mtcars",
		response_type = "incidence", design = "KK21",
		stringsAsFactors = FALSE
	)
	formula_suffixes = c(" (model_formula=~1)", " (model_formula=~.)")
	case_paths = case[rep(1L, length(formula_suffixes)), , drop = FALSE]
	case_paths$inference_class = paste0("InferenceIncidKKModifiedPoisson", formula_suffixes)
	declared_methods = data.frame(
		function_run = c("compute_score_two_sided_pval", "compute_score_confidence_interval",
			"compute_lik_ratio_two_sided_pval", "compute_lik_ratio_confidence_interval"),
		testing_type = c("score", "score", "lik_ratio", "lik_ratio"),
		stringsAsFactors = FALSE
	)
	supported_testing_types = "wald"
	eligible_methods = declared_methods[declared_methods$testing_type %in% supported_testing_types, , drop = FALSE]
	manifest = case_paths[rep(seq_len(nrow(case_paths)), each = nrow(eligible_methods)), , drop = FALSE]
	manifest$function_run = rep(eligible_methods$function_run, times = nrow(case_paths))
	key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	expected = manifest[key_columns]
	expect_identical(names(expected), key_columns)
	expect_identical(nrow(expected), 0L)
	expect_identical(comprehensive_result_manifest_keys(expected, key_columns), character())
})

test_that("a likelihood-capable runner class produces a source-backed score roster", {
	runner_source = readLines(test_path("..", "comprehensive_tests.R"), warn = FALSE)
	class_dispatch = grep(
		'run_inference_checks_both_paths\\(InferenceIncidLogRegr, "InferenceIncidLogRegr"',
		runner_source, value = TRUE
	)
	score_dispatch = grep(
		'call_direct_asymp\\("compute_score_two_sided_pval", "score"',
		runner_source, value = TRUE
	)
	score_ci_dispatch = grep(
		'call_direct_asymp\\("compute_score_confidence_interval", "score"',
		runner_source, value = TRUE
	)
	expect_length(class_dispatch, 1L)
	expect_length(score_dispatch, 1L)
	expect_length(score_ci_dispatch, 1L)

	class_source = readLines(test_path("..", "..", "EDI", "R", "inference_incidence_logit.R"), warn = FALSE)
	expect_true(any(grepl("supports_likelihood_tests = function(){", class_source, fixed = TRUE)))
	expect_true(any(grepl("TRUE", class_source[grep("supports_likelihood_tests = function(){", class_source, fixed = TRUE) + 1L], fixed = TRUE)))
	likelihood_base = readLines(test_path("..", "..", "EDI", "R", "inference_all_abstract_asymp_lik.R"), warn = FALSE)
	base_source = paste(likelihood_base, collapse = " ")
	expect_true(grepl('if (isTRUE(private$supports_likelihood_tests())) { c("wald", "score", "gradient", "lik_ratio") }', gsub("[[:space:]]+", " ", base_source), fixed = TRUE))

	helper_start = grep("^call_direct_asymp = function", runner_source)
	helper_end = grep("^}", runner_source)
	helper_end = helper_end[helper_end > helper_start][[1L]]
	direct_helper = paste(runner_source[helper_start:helper_end], collapse = " ")
	expect_true(grepl("should_run_test_family(testing_type)", direct_helper, fixed = TRUE))
	expect_true(grepl("seq_des_inf[[method_name]]", direct_helper, fixed = TRUE))
	expect_true(grepl("supports_direct_testing_type(testing_type)", direct_helper, fixed = TRUE))

	# Fixed reduced eligibility: family filter = score, skip_asymp = FALSE,
	# method present/supporting score, and skip_score_ci_slow = TRUE. This leaves
	# only the score p-value call while retaining both runner formula labels.
	formula_suffixes = c(" (model_formula=~1)", " (model_formula=~.)")
	case = data.frame(
		rep = 1L, beta_T = 0, dataset = "pima",
		response_type = "incidence", design = "Bernoulli",
		stringsAsFactors = FALSE
	)
	manifest = case[rep(1L, length(formula_suffixes)), , drop = FALSE]
	manifest$inference_class = paste0("InferenceIncidLogRegr", formula_suffixes, " [design_formula=~1]")
	manifest$function_run = rep("compute_score_two_sided_pval", length(formula_suffixes))
	manifest = manifest[c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")]
	rownames(manifest) = NULL
	expected = data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0),
		dataset = c("pima", "pima"), response_type = c("incidence", "incidence"),
		design = c("Bernoulli", "Bernoulli"),
		inference_class = c(
			"InferenceIncidLogRegr (model_formula=~1) [design_formula=~1]",
			"InferenceIncidLogRegr (model_formula=~.) [design_formula=~1]"
		),
		function_run = c("compute_score_two_sided_pval", "compute_score_two_sided_pval"),
		stringsAsFactors = FALSE
	)
	expect_identical(manifest, expected)
	key_columns = c("rep", "beta_T", "dataset", "response_type", "design", "inference_class", "function_run")
	expect_identical(anyDuplicated(comprehensive_result_manifest_keys(manifest, key_columns)), 0L)
})
