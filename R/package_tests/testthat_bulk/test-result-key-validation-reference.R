library(testthat)

source(testthat::test_path("..", "validate_todo76_candidate_keys.R"), local = TRUE)

test_that("TODO-76 reconciliation requires an explicit formula pair and the full result key", {
	approved <- data.frame(
		design_formula = c("~1", "~."),
		model_formula = c("~1", "~1"),
		stringsAsFactors = FALSE
	)
	manifest <- data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0), dataset = c("diamonds", "diamonds"),
		response_type = c("ordinal", "ordinal"), design = c("FixedBinaryMatch", "FixedBinaryMatch"),
		design_formula = approved$design_formula, model_formula = approved$model_formula,
		inference_class = c("InferenceOrdinalKKGLMM", "InferenceOrdinalKKGLMM"),
		function_run = c("compute_bayesian_bootstrap_confidence_interval", "compute_bayesian_bootstrap_confidence_interval"),
		stringsAsFactors = FALSE
	)

	valid <- validate_todo76_candidate_keys(manifest, manifest, approved)
	expect_true(valid$ok, info = paste(valid$issues, collapse = "; "))
	expect_length(valid$missing_keys, 0L)
	expect_length(valid$extra_keys, 0L)

	# The current 50-row candidate roster lacks the outer design_formula field.
	# It must fail schema validation rather than be mistaken for an exact target.
	incomplete <- manifest
	incomplete$design_formula <- NULL
	bad_schema <- validate_todo76_candidate_keys(incomplete, incomplete, approved)
	expect_false(bad_schema$ok)
	expect_true(any(grepl("design_formula", bad_schema$issues, fixed = TRUE)))

	# Keep every field except design_formula identical; the missing/duplicate
	# rows prove that outer-formula identity participates in the full key.
	wrong_formula <- manifest
	wrong_formula$design_formula[2] <- "~1"
	bad_key <- validate_todo76_candidate_keys(manifest, wrong_formula, approved)
	expect_false(bad_key$ok)
	expect_true(any(grepl("duplicate full result keys", bad_key$issues, fixed = TRUE)))
	expect_length(bad_key$missing_keys, 1L)
	expect_length(bad_key$extra_keys, 0L)

	# Formula scope stays caller/owner supplied. Empty, malformed, duplicate,
	# or manifest-inconsistent approvals must fail closed; these are synthetic
	# validator cases, not a choice of production formula pair(s).
	empty_approved <- approved[FALSE, , drop = FALSE]
	bad_empty_scope <- validate_todo76_candidate_keys(manifest, manifest, empty_approved)
	expect_false(bad_empty_scope$ok)
	expect_true(any(grepl("approved_formula_pairs must be nonempty", bad_empty_scope$issues, fixed = TRUE)))

	empty_formula <- approved
	empty_formula$design_formula[1] <- "  "
	bad_empty_formula <- validate_todo76_candidate_keys(manifest, manifest, empty_formula)
	expect_false(bad_empty_formula$ok)
	expect_true(any(grepl("approved_formula_pairs must be nonempty", bad_empty_formula$issues, fixed = TRUE)))

	duplicate_approved <- rbind(approved, approved[1, , drop = FALSE])
	bad_duplicate_scope <- validate_todo76_candidate_keys(manifest, manifest, duplicate_approved)
	expect_false(bad_duplicate_scope$ok)
	expect_true(any(grepl("approved_formula_pairs contains duplicates", bad_duplicate_scope$issues, fixed = TRUE)))

	manifest_outside_scope <- manifest
	manifest_outside_scope$design_formula[2] <- "~other"
	bad_manifest_scope <- validate_todo76_candidate_keys(manifest_outside_scope, manifest_outside_scope, approved)
	expect_false(bad_manifest_scope$ok)
	expect_true(any(grepl("manifest formula pairs do not equal", bad_manifest_scope$issues, fixed = TRUE)))

	# Separator-containing values must not collide into a false approval.
	separator_approved <- data.frame(
		design_formula = "~left\r~right", model_formula = "~outcome",
		stringsAsFactors = FALSE
	)
	separator_manifest <- manifest[1, , drop = FALSE]
	separator_manifest$design_formula <- "~left"
	separator_manifest$model_formula <- "~right\r~outcome"
	bad_separator_scope <- validate_todo76_candidate_keys(
		separator_manifest, separator_manifest, separator_approved
	)
	expect_false(bad_separator_scope$ok)
	expect_true(any(grepl("manifest formula pairs do not equal", bad_separator_scope$issues, fixed = TRUE)))
})

test_that("TODO-76 validator rejects duplicate, missing, extra, and malformed key rows", {
	approved <- data.frame(design_formula = "~1", model_formula = "~1", stringsAsFactors = FALSE)
	manifest <- data.frame(
		rep = 1L, beta_T = 0, dataset = "diamonds", response_type = "ordinal",
		design = "FixedBinaryMatch", design_formula = "~1", model_formula = "~1",
		inference_class = "InferenceOrdinalKKGLMM",
		function_run = "compute_bayesian_bootstrap_confidence_interval",
		stringsAsFactors = FALSE
	)

	duplicate_manifest <- rbind(manifest, manifest)
	bad_manifest_duplicate <- validate_todo76_candidate_keys(duplicate_manifest, manifest, approved)
	expect_false(bad_manifest_duplicate$ok)
	expect_true(any(grepl("manifest contains duplicate full result keys",
		bad_manifest_duplicate$issues, fixed = TRUE)))

	missing_row <- validate_todo76_candidate_keys(manifest, manifest[FALSE, , drop = FALSE], approved)
	expect_false(missing_row$ok)
	expect_length(missing_row$missing_keys, 1L)
	expect_length(missing_row$extra_keys, 0L)

	extra_candidate <- manifest
	extra_candidate$function_run <- "compute_other_procedure"
	extra_row <- validate_todo76_candidate_keys(manifest, extra_candidate, approved)
	expect_false(extra_row$ok)
	expect_length(extra_row$missing_keys, 1L)
	expect_length(extra_row$extra_keys, 1L)
	expect_true(any(grepl("unexpected full result key", extra_row$issues, fixed = TRUE)))

	missing_candidate_schema <- manifest
	missing_candidate_schema$design_formula <- NULL
	bad_candidate_schema <- validate_todo76_candidate_keys(manifest, missing_candidate_schema, approved)
	expect_false(bad_candidate_schema$ok)
	expect_true(any(grepl("candidate missing key field.*design_formula",
		bad_candidate_schema$issues)))

	empty_candidate_design <- manifest
	empty_candidate_design$design <- "  "
	bad_empty_candidate <- validate_todo76_candidate_keys(manifest, empty_candidate_design, approved)
	expect_false(bad_empty_candidate$ok)
	expect_true(any(grepl("candidate contains empty key values",
		bad_empty_candidate$issues, fixed = TRUE)))

	missing_manifest_formula <- manifest
	missing_manifest_formula$model_formula <- NA_character_
	bad_missing_manifest <- validate_todo76_candidate_keys(missing_manifest_formula, manifest, approved)
	expect_false(bad_missing_manifest$ok)
	expect_true(any(grepl("manifest contains missing key values",
		bad_missing_manifest$issues, fixed = TRUE)))

	# A non-missing but non-finite beta must reach the dedicated numeric-key
	# guard (rather than being accepted as a distinct serialized key).
	nonfinite_manifest_beta <- manifest
	nonfinite_manifest_beta$beta_T <- Inf
	bad_nonfinite_manifest_beta <- validate_todo76_candidate_keys(
		nonfinite_manifest_beta, manifest, approved
	)
	expect_false(bad_nonfinite_manifest_beta$ok)
	expect_true(any(grepl("manifest beta_T values must be finite numbers",
		bad_nonfinite_manifest_beta$issues, fixed = TRUE)))

	nonfinite_candidate_beta <- manifest
	nonfinite_candidate_beta$beta_T <- -Inf
	bad_nonfinite_candidate_beta <- validate_todo76_candidate_keys(
		manifest, nonfinite_candidate_beta, approved
	)
	expect_false(bad_nonfinite_candidate_beta$ok)
	expect_true(any(grepl("candidate beta_T values must be finite numbers",
		bad_nonfinite_candidate_beta$issues, fixed = TRUE)))

	empty_manifest_design <- manifest
	empty_manifest_design$design <- ""
	bad_empty_manifest <- validate_todo76_candidate_keys(empty_manifest_design, manifest, approved)
	expect_false(bad_empty_manifest$ok)
	expect_true(any(grepl("manifest contains empty key values",
		bad_empty_manifest$issues, fixed = TRUE)))

	bad_approved_schema <- approved["design_formula"]
	bad_formula_columns <- validate_todo76_candidate_keys(manifest, manifest, bad_approved_schema)
	expect_false(bad_formula_columns$ok)
	expect_true(any(grepl("approved_formula_pairs must contain design_formula and model_formula",
		bad_formula_columns$issues, fixed = TRUE)))
})

test_that("TODO-76 source-potential inventory covers all runner axes without choosing acceptance scope", {
	# One bounded runner case from the existing TODO-76 scratch inventory. These
	# axes mirror comprehensive_tests.R: formulas_to_test = list(~1, ~.);
	# the five is_kk_design ordinal class calls; and default/basic/Wald/BCA/
	# studentized CI and p-value labels from the Bayesian-bootstrap loops.
	case_grid <- data.frame(
		rep = 1L, beta_T = 0, dataset = "diamonds",
		response_type = "ordinal", design = "FixedBinaryMatch",
		stringsAsFactors = FALSE
	)
	design_formulas <- c("~1", "~.")
	model_formulas <- c("~1", "~.")
	inference_classes <- c(
		"InferenceOrdinalKKGLMM", "InferenceOrdinalKKCLMM",
		"InferenceOrdinalKKCLMMProbit", "InferenceOrdinalKKCLMMCauchit",
		"InferenceOrdinalKKCLMMCloglog"
	)
	function_runs <- c(
		"compute_bayesian_bootstrap_confidence_interval",
		"compute_bayesian_bootstrap_confidence_interval_basic",
		"compute_bayesian_bootstrap_confidence_interval_wald",
		"compute_bayesian_bootstrap_confidence_interval_bca",
		"compute_bayesian_bootstrap_confidence_interval_studentized",
		"compute_bayesian_bootstrap_two_sided_pval",
		"compute_bayesian_bootstrap_two_sided_pval_symmetric",
		"compute_bayesian_bootstrap_two_sided_pval_wald",
		"compute_bayesian_bootstrap_two_sided_pval_bca",
		"compute_bayesian_bootstrap_two_sided_pval_studentized"
	)
	universe <- todo76_candidate_key_universe(
		case_grid, design_formulas, model_formulas, inference_classes, function_runs
	)
	expect_equal(nrow(universe), 200L)
	expect_equal(length(unique(.todo76_key(universe))), 200L)
	expect_setequal(unique(universe$design_formula), design_formulas)
	expect_setequal(unique(universe$model_formula), model_formulas)
	expect_setequal(unique(universe$function_run), function_runs)
	observed_pairs <- unique(universe[c("design_formula", "model_formula")])
	expected_pairs <- expand.grid(
		design_formula = design_formulas, model_formula = model_formulas,
		KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
	)
	pair_token <- function(x) paste(x$design_formula, x$model_formula, sep = "\r")
	expect_setequal(pair_token(observed_pairs), pair_token(expected_pairs))

	# A sample approved formula-pair subset is valid only as a subset check; the
	# test deliberately does not nominate it as the production target.
	approved_pair <- data.frame(design_formula = "~1", model_formula = "~.", stringsAsFactors = FALSE)
	approved_subset <- universe[
		universe$design_formula == approved_pair$design_formula &
			universe$model_formula == approved_pair$model_formula,
		, drop = FALSE
	]
	expect_equal(nrow(approved_subset), 50L)
	expect_true(all(.todo76_key(approved_subset) %in% .todo76_key(universe)))
	valid_subset <- validate_todo76_candidate_keys(approved_subset, approved_subset, approved_pair)
	expect_true(valid_subset$ok, info = paste(valid_subset$issues, collapse = "; "))
	expect_identical(valid_subset$validation_scope, "exact_key_set_only_not_attempt_validation")

	# A source-potential manifest must not acquire outcome/runtime fields that
	# could make its possible keys look like emitted attempts.
	mislabelled_manifest <- approved_subset
	mislabelled_manifest$status <- "attempted"
	mislabelled_result <- validate_todo76_candidate_keys(
		mislabelled_manifest, approved_subset, approved_pair
	)
	expect_false(mislabelled_result$ok)
	expect_true(any(grepl("source-potential manifest must remain key-only", mislabelled_result$issues, fixed = TRUE)))
	expect_identical(mislabelled_result$validation_scope, "exact_key_set_only_not_attempt_validation")
})

test_that("TODO-77 source-potential inventory records the incidence BB key axes without assigning outcomes", {
	case_grid <- data.frame(
		rep = 1L, beta_T = 0, dataset = "pima",
		response_type = "incidence", design = "KK21stepwise",
		stringsAsFactors = FALSE
	)
	formulas <- c("~1", "~.")
	classes <- c(
		"InferenceIncidKKCondLogitGLMMOneLik",
		"InferenceIncidKKCondLogitGLMMIVWC"
	)
	function_runs <- c(
		"compute_bayesian_bootstrap_confidence_interval",
		"compute_bayesian_bootstrap_confidence_interval_basic",
		"compute_bayesian_bootstrap_confidence_interval_wald",
		"compute_bayesian_bootstrap_confidence_interval_bca",
		"compute_bayesian_bootstrap_confidence_interval_studentized",
		"compute_bayesian_bootstrap_two_sided_pval",
		"compute_bayesian_bootstrap_two_sided_pval_symmetric",
		"compute_bayesian_bootstrap_two_sided_pval_wald",
		"compute_bayesian_bootstrap_two_sided_pval_bca",
		"compute_bayesian_bootstrap_two_sided_pval_studentized"
	)
	candidate_only <- todo76_candidate_key_universe(
		case_grid, formulas, formulas, classes, function_runs
	)

	expect_equal(nrow(candidate_only), 80L)
	expect_equal(length(unique(.todo76_key(candidate_only))), 80L)
	expect_setequal(names(candidate_only), .todo76_result_key_columns)
	expect_setequal(unique(candidate_only$design_formula), formulas)
	expect_setequal(unique(candidate_only$model_formula), formulas)
	expect_setequal(unique(candidate_only$function_run), function_runs)
	expect_setequal(
		unique(sub(" \\(model_formula=.*$", "", candidate_only$inference_class)),
		classes
	)
	expect_false(any(c("status", "expected_status", "skip_reason") %in% names(candidate_only)))

	# This is the full source-potential cross-product for one bounded runner
	# case; runtime support, setup success, and slow-path skips decide which
	# candidate keys actually become attempts/results.
	expect_equal(length(unique(paste(candidate_only$design_formula,
		candidate_only$model_formula, sep = "\r"))), 4L)
})

test_that("TODO-76 full result identity distinguishes beta_T values", {
	case_grid <- data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0.5), dataset = c("diamonds", "diamonds"),
		response_type = c("ordinal", "ordinal"), design = c("FixedBinaryMatch", "FixedBinaryMatch"),
		stringsAsFactors = FALSE
	)
	formula_pairs <- data.frame(design_formula = "~1", model_formula = "~1", stringsAsFactors = FALSE)
	universe <- todo76_candidate_key_universe(
		case_grid, design_formulas = "~1", model_formulas = "~1",
		inference_classes = "InferenceOrdinalKKGLMM",
		function_runs = "compute_bayesian_bootstrap_confidence_interval"
	)

	# The source runner's full key contains beta_T; otherwise these two attempts
	# with every other dimension identical would collide.
	expect_equal(nrow(universe), 2L)
	expect_equal(length(unique(.todo76_key(universe))), 2L)

	partial <- universe[universe$beta_T == 0, , drop = FALSE]
	reconciliation <- validate_todo76_candidate_keys(universe, partial, formula_pairs)
	expect_false(reconciliation$ok)
	expect_length(reconciliation$missing_keys, 1L)
	expect_length(reconciliation$extra_keys, 0L)
})

test_that("TODO-76 rejects malformed beta_T values instead of keying them as one sentinel", {
	approved <- data.frame(design_formula = "~1", model_formula = "~1", stringsAsFactors = FALSE)
	valid <- data.frame(
		rep = 1L, beta_T = 0, dataset = "diamonds", response_type = "ordinal",
		design = "FixedBinaryMatch", design_formula = "~1", model_formula = "~1",
		inference_class = "InferenceOrdinalKKGLMM",
		function_run = "compute_bayesian_bootstrap_confidence_interval",
		stringsAsFactors = FALSE
	)

	# Previously, any pair of nonnumeric beta labels collapsed to the same
	# <invalid-beta> token, allowing two malformed tables to reconcile.
	malformed <- valid
	malformed$beta_T <- "not-a-number"
	bad_pair <- validate_todo76_candidate_keys(malformed, malformed, approved)
	expect_false(bad_pair$ok)
	expect_true(any(grepl("manifest beta_T values must be finite numbers", bad_pair$issues, fixed = TRUE)))
	expect_true(any(grepl("candidate beta_T values must be finite numbers", bad_pair$issues, fixed = TRUE)))

	infinite <- valid
	infinite$beta_T <- Inf
	bad_infinite <- validate_todo76_candidate_keys(valid, infinite, approved)
	expect_false(bad_infinite$ok)
	expect_true(any(grepl("candidate beta_T values must be finite numbers", bad_infinite$issues, fixed = TRUE)))
})

test_that("TODO-76 length-prefixed full keys distinguish delimiter-shifted fields", {
	manifest <- data.frame(
		rep = c(1L, 1L), beta_T = c(0, 0),
		dataset = c("diamonds|incidence", "diamonds"),
		response_type = c("ordinal", "incidence|ordinal"),
		design = c("FixedBinaryMatch", "FixedBinaryMatch"),
		design_formula = c("~1", "~1"), model_formula = c("~1", "~1"),
		inference_class = c("InferenceOrdinalKKGLMM", "InferenceOrdinalKKGLMM"),
		function_run = c(
			"compute_bayesian_bootstrap_confidence_interval",
			"compute_bayesian_bootstrap_confidence_interval"
		),
		stringsAsFactors = FALSE
	)
	approved <- data.frame(design_formula = "~1", model_formula = "~1", stringsAsFactors = FALSE)

	# A naïve delimiter join of the adjacent dataset/response fields would make
	# these distinct tuples collide: both produce "diamonds|incidence|ordinal".
	expect_identical(
		paste(manifest$dataset[[1L]], manifest$response_type[[1L]], sep = "|"),
		paste(manifest$dataset[[2L]], manifest$response_type[[2L]], sep = "|")
	)
	expect_false(anyDuplicated(.todo76_key(manifest)) > 0L)

	result <- validate_todo76_candidate_keys(manifest, manifest, approved)
	expect_true(result$ok, info = paste(result$issues, collapse = "; "))
	expect_length(result$missing_keys, 0L)
	expect_length(result$extra_keys, 0L)
})
