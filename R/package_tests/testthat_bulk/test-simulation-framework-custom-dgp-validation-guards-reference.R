library(testthat)
library(EDI)

# SimulationFramework's custom_dgp validation, split across two stages of simulations_framework.R:
# two constructor-time guards and three run-time guards (fired inside the per-replication worker,
# captured into priv$error_log rather than propagating, matching this file's documented error-handling
# contract -- same pattern already established in test-simulation-framework-custom-apply-treatment-
# and-noise-malformed-return-guard-reference.R). A codebase-wide grep confirmed all 5 exact messages
# had zero test references anywhere: the only existing custom_dgp references
# (test-simulation-serial-custom-dgp-resume-reference.R) exercise only a well-formed custom_dgp's
# resume behavior, never these validation guards.
#   Constructor-time:
#     1. custom_dgp supplied together with custom_replication_data_generator (or custom_apply_
#        treatment_and_noise) -> "custom_dgp cannot be combined with custom_replication_data_
#        generator or custom_apply_treatment_and_noise"
#     2. custom_dgp is not a function -> "custom_dgp must be a function"
#   Run-time (Mode 3 observational-DGP branch, fired per replication):
#     3. custom_dgp is used with a sequential (DesignSeqOneByOne*) design class, which it doesn't
#        support -> "custom_dgp requires a fixed design class; '<classname>' is a sequential design"
#     4. custom_dgp's return value isn't a list with 'X', 'w', and 'y' -> "custom_dgp must return a
#        list with 'X', 'w', and 'y'"
#     5. custom_dgp's returned X has the wrong number of rows -> "custom_dgp returned X with <n> rows;
#        expected <n>"

test_that("custom_dgp is not a function raises the documented constructor-time error", {
	expect_error(
		SimulationFramework$new(
			response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
			inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
			inference_types_and_params = list(asymp_pval = list()),
			n = 10L, p = 1L, custom_dgp = "not a function",
			results_filename = tempfile(fileext = ".csv"), verbose = FALSE
		),
		"custom_dgp must be a function",
		fixed = TRUE
	)
})

test_that("custom_dgp combined with custom_replication_data_generator raises the documented constructor-time error", {
	dummy_dgp <- function(n, p, w) list(X = data.frame(x1 = rnorm(n)), w = w, y = rnorm(n))
	dummy_rep_gen <- function(...) NULL
	expect_error(
		SimulationFramework$new(
			response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
			inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
			inference_types_and_params = list(asymp_pval = list()),
			n = 10L, p = 1L, custom_dgp = dummy_dgp, custom_replication_data_generator = dummy_rep_gen,
			results_filename = tempfile(fileext = ".csv"), verbose = FALSE
		),
		"custom_dgp cannot be combined with custom_replication_data_generator or custom_apply_treatment_and_noise",
		fixed = TRUE
	)
})

test_that("custom_dgp on a sequential design class is captured with the documented run-time error, not a raised exception", {
	folder <- tempfile("edi_dgp_seq_")
	dir.create(folder)
	on.exit(unlink(folder, recursive = TRUE), add = TRUE)
	dgp <- function(n, p, w) list(X = data.frame(x1 = rnorm(n)), w = w, y = rnorm(n))

	sim <- suppressWarnings(SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignSeqOneByOneKK14),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_pval = list()),
		n = 10L, p = 1L, custom_dgp = dgp, num_cores = 1L,
		results_filename = file.path(folder, "res.csv"), verbose = FALSE, stop_on_error = FALSE
	))
	expect_no_error(sim$run())
	priv <- sim$.__enclos_env__$private
	expect_gt(length(priv$error_log), 0L)
	expect_true(any(vapply(priv$error_log, function(rec) {
		identical(rec$error_message, "custom_dgp requires a fixed design class; 'DesignSeqOneByOneKK14' is a sequential design")
	}, logical(1))))
})

test_that("a custom_dgp returning a malformed (missing 'y') list is captured with the documented run-time error", {
	folder <- tempfile("edi_dgp_malformed_")
	dir.create(folder)
	on.exit(unlink(folder, recursive = TRUE), add = TRUE)
	bad_dgp <- function(n, p, w) list(X = data.frame(x1 = rnorm(n)), w = w)

	sim <- suppressWarnings(SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_pval = list()),
		n = 10L, p = 1L, custom_dgp = bad_dgp, num_cores = 1L,
		results_filename = file.path(folder, "res.csv"), verbose = FALSE, stop_on_error = FALSE
	))
	expect_no_error(sim$run())
	priv <- sim$.__enclos_env__$private
	expect_gt(length(priv$error_log), 0L)
	expect_true(any(vapply(priv$error_log, function(rec) {
		identical(rec$error_message, "custom_dgp must return a list with 'X', 'w', and 'y'")
	}, logical(1))))
})

test_that("a custom_dgp returning X with the wrong number of rows is captured with the documented run-time error", {
	folder <- tempfile("edi_dgp_wrongrows_")
	dir.create(folder)
	on.exit(unlink(folder, recursive = TRUE), add = TRUE)
	bad_dgp <- function(n, p, w) list(X = data.frame(x1 = rnorm(n - 1)), w = w[-1], y = rnorm(n - 1))

	sim <- suppressWarnings(SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_pval = list()),
		n = 10L, p = 1L, custom_dgp = bad_dgp, num_cores = 1L,
		results_filename = file.path(folder, "res.csv"), verbose = FALSE, stop_on_error = FALSE
	))
	expect_no_error(sim$run())
	priv <- sim$.__enclos_env__$private
	expect_gt(length(priv$error_log), 0L)
	expect_true(any(vapply(priv$error_log, function(rec) {
		identical(rec$error_message, "custom_dgp returned X with 9 rows; expected 10")
	}, logical(1))))
})
