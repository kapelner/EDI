library(testthat)
library(EDI)

# SimulationFramework's disk-cache round-trip and error-record formatting/abort
# machinery (.simulation_cache_file/.save_simulation_cache_object/
# .load_simulation_cache_object/.make_error_record/.format_error_record/
# .abort_from_error_record) had zero test references anywhere in the suite
# before this file, despite the class itself being well-exercised elsewhere.

minimal_sim <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE
	)
}

minimal_cs <- function(design_label = "balanced", n = 20L) {
	list(
		n = n, p = 1L, betaT = 0, cond_exp_func_model = "linear", norm_sq_beta_vec = 1,
		response_type = "continuous", random_X_draws = TRUE, shared_X = NULL, X_mat = NULL,
		cov_draw_method_args = list(mean = 0, sd = 1)
	)
}

test_that(".simulation_cache_file is deterministic and sensitive to design_label and cell state", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	cs <- minimal_cs()

	f1 <- p$.simulation_cache_file(cs, "balanced", list(), "design_w")
	f2 <- p$.simulation_cache_file(cs, "balanced", list(), "design_w")
	expect_identical(f1, f2)

	f_other_design <- p$.simulation_cache_file(cs, "unobserved", list(), "design_w")
	expect_false(identical(f1, f_other_design))

	f_other_n <- p$.simulation_cache_file(minimal_cs(n = 40L), "balanced", list(), "design_w")
	expect_false(identical(f1, f_other_n))

	expect_true(startsWith(basename(f1), "design_w__continuous__linear__n20__p1__balanced__"))
	expect_true(endsWith(f1, ".rds"))
	expect_identical(dirname(f1), p$.simulation_cache_dir())
})

test_that(".save_simulation_cache_object/.load_simulation_cache_object round-trip a design_w object", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	cs <- minimal_cs()

	obj <- list(ws = matrix(0L:1L, nrow = 20, ncol = 2), rep_to_col = c("1" = 1L, "2" = 2L))
	cache_file <- p$.save_simulation_cache_object(obj, cs, "balanced", list(), "design_w")
	expect_true(file.exists(cache_file))
	on.exit(unlink(cache_file), add = TRUE)

	loaded <- p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = c(1L, 2L))
	expect_identical(loaded$ws, obj$ws)
	expect_identical(loaded$rep_to_col, obj$rep_to_col)

	# Requesting a rep not present in the cached rep_to_col map invalidates the cache.
	expect_null(p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = c(1L, 3L)))

	# A cached ws matrix with the wrong row count (stale n) is also rejected.
	stale_obj <- list(ws = matrix(0L, nrow = 5, ncol = 1), rep_to_col = c("1" = 1L))
	stale_file <- p$.save_simulation_cache_object(stale_obj, cs, "balanced", list(), "design_w")
	on.exit(unlink(stale_file), add = TRUE)
	expect_null(p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = 1L))
})

test_that(".load_simulation_cache_object gracefully handles a missing or corrupted cache file", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	cs <- minimal_cs()

	missing_file <- file.path(p$.simulation_cache_dir(), "does_not_exist__abc123.rds")
	expect_null(p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = 1L, cache_file = missing_file))

	corrupted_file <- tempfile(fileext = ".rds")
	dir.create(dirname(corrupted_file), recursive = TRUE, showWarnings = FALSE)
	writeLines("not a valid rds file", corrupted_file)
	on.exit(unlink(corrupted_file), add = TRUE)
	expect_null(p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = 1L, cache_file = corrupted_file))
})

test_that(".load_simulation_cache_object rejects a non-design_w cache_type and a blocking-design sentinel passes through", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	cs <- minimal_cs()

	# Unrecognized cache_type: always NULL regardless of on-disk content.
	obj <- list(ws = matrix(0L, nrow = 20, ncol = 1), rep_to_col = c("1" = 1L))
	cache_file <- p$.save_simulation_cache_object(obj, cs, "balanced", list(), "some_other_type")
	on.exit(unlink(cache_file), add = TRUE)
	expect_null(p$.load_simulation_cache_object(cs, "balanced", list(), "some_other_type", reps_needing = 1L, cache_file = cache_file))

	# The blocking-design sentinel object is returned as-is without shape validation.
	sentinel_obj <- list(blocking_design = TRUE)
	sentinel_file <- p$.save_simulation_cache_object(sentinel_obj, cs, "balanced", list(), "design_w")
	on.exit(unlink(sentinel_file), add = TRUE)
	loaded_sentinel <- p$.load_simulation_cache_object(cs, "balanced", list(), "design_w", reps_needing = 1L, cache_file = sentinel_file)
	expect_true(isTRUE(loaded_sentinel$blocking_design))
})

test_that(".make_error_record and .format_error_record produce the documented structure and text", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	p$current_response_type <- "continuous"
	p$current_cond_exp_func_model <- "linear"
	p$current_n <- 20L
	p$current_p <- 1L
	p$current_betaT <- 0.5

	err <- p$.make_error_record(
		stage = "inference", rep = 3L, design = "balanced", design_params = list(),
		inference = "mean", inference_params = list(), inference_type = "asymp_ci",
		inference_type_params = list(), message = "boom"
	)
	expect_identical(err$stage, "inference")
	expect_identical(err$rep, 3L)
	expect_identical(err$design, "balanced")
	expect_identical(err$inference_type, "asymp_ci")
	expect_identical(err$error_message, "boom")
	expect_identical(err$n, 20L)
	expect_identical(err$betaT, 0.5)

	formatted <- p$.format_error_record(err)
	expect_true(grepl("stage: inference", formatted, fixed = TRUE))
	expect_true(grepl("rep: 3", formatted, fixed = TRUE))
	expect_true(grepl("path: balanced -> mean -> asymp_ci", formatted, fixed = TRUE))
	expect_true(grepl("message: boom", formatted, fixed = TRUE))
	expect_true(grepl("n=20, p=1, betaT=0.5", formatted, fixed = TRUE))

	# A design-stage error has no inference/inference_type -- the path collapses to design alone.
	design_err <- p$.make_error_record(
		stage = "design", rep = NULL, design = "balanced", design_params = list(),
		inference = NULL, inference_params = list(), inference_type = NULL,
		inference_type_params = list(), message = "design failed"
	)
	expect_true(is.na(design_err$rep))
	design_formatted <- p$.format_error_record(design_err)
	expect_true(grepl("path: balanced", design_formatted, fixed = TRUE))
	expect_true(grepl("rep: NA", design_formatted, fixed = TRUE))

	# No path components at all falls back to the documented placeholder.
	no_path_err <- p$.make_error_record(
		stage = "setup", rep = NULL, design = NULL, design_params = list(),
		inference = NULL, inference_params = list(), inference_type = NULL,
		inference_type_params = list(), message = "nothing ran"
	)
	no_path_formatted <- p$.format_error_record(no_path_err)
	expect_true(grepl("path: <no path>", no_path_formatted, fixed = TRUE))
})

test_that(".abort_from_error_record stops with the formatted message and writes a crash log", {
	sim <- minimal_sim()
	p <- sim$.__enclos_env__$private
	p$current_response_type <- "continuous"
	p$current_cond_exp_func_model <- "linear"
	p$current_n <- 20L
	p$current_p <- 1L
	p$current_betaT <- 0

	err <- p$.make_error_record(
		stage = "inference", rep = 7L, design = "balanced", design_params = list(),
		inference = "mean", inference_params = list(), inference_type = "asymp_ci",
		inference_type_params = list(), message = "catastrophic failure"
	)

	crash_log <- file.path(tempdir(), "edi_sim_crash.log")
	if (file.exists(crash_log)) unlink(crash_log)

	expect_error(p$.abort_from_error_record(err), "catastrophic failure", fixed = TRUE)
	expect_true(file.exists(crash_log))
	log_contents <- readLines(crash_log)
	expect_true(any(grepl("catastrophic failure", log_contents, fixed = TRUE)))
	expect_true(any(grepl("rep: 7", log_contents, fixed = TRUE)))
	unlink(crash_log)
})
