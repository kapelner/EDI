library(testthat)
library(EDI)

# InferenceNonParamBootstrap's approximate_bootstrap_distribution_beta_hat_T(debug = TRUE) parallel
# path (inference_all_abstract_non_param_boot.R) hardens its per-replicate debug_results against
# worker crashes: after flattening private$par_lapply()'s per-chunk results, any entry that isn't a
# list with a non-NULL $val (a genuine process-level crash, not an R-level error already caught inside
# each replicate) is dropped, issuing warning("Some bootstrap iterations (", n_lost, ") were lost due
# to worker crashes or invalid results.") whenever at least one -- but not all -- entries were lost; if
# EVERY entry across all chunks was lost, it instead stops with "All bootstrap iterations failed or
# returned invalid results. Check for worker crashes or out-of-memory issues." A codebase-wide grep
# confirmed neither message had any test reference anywhere. Only reachable via the num_cores > 1
# (parallel, chunked) code path -- the serial path's run_debug_chunk() always returns a proper
# list(val=, errors=, warnings=) per iteration (val is NA_real_ at worst, never NULL/missing), so this
# hardening logic only matters for genuine par_lapply-level worker crashes. Reached by stubbing
# private$par_lapply() directly to return a controlled mix of valid and crashed (NULL) per-chunk
# results, independent of the real parallel-dispatch machinery (already tested elsewhere).

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 2L
	inf
}

test_that("a mix of valid and crashed (NULL) chunk results issues the documented 'lost' warning naming the count", {
	inf <- fx(1L)
	priv <- inf$.__enclos_env__$private
	unlockBinding("par_lapply", priv)
	priv$par_lapply <- function(X, FUN, n_cores = 1L, budget = 1L, show_progress = FALSE, export_list = NULL) {
		list(
			list(list(val = 1.0, errors = character(0), warnings = character(0)), NULL),
			list(list(val = 2.0, errors = character(0), warnings = character(0)), list(val = 3.0, errors = character(0), warnings = character(0)))
		)
	}
	expect_warning(
		res <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 4L, show_progress = FALSE, debug = TRUE),
		"Some bootstrap iterations (1) were lost due to worker crashes or invalid results.",
		fixed = TRUE
	)
	expect_length(res$values, 3L)
})

test_that("every chunk result being crashed (NULL) raises the documented all-failed error instead", {
	inf <- fx(2L)
	priv <- inf$.__enclos_env__$private
	unlockBinding("par_lapply", priv)
	priv$par_lapply <- function(X, FUN, n_cores = 1L, budget = 1L, show_progress = FALSE, export_list = NULL) {
		list(list(NULL, NULL), list(NULL, NULL))
	}
	expect_error(
		suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = 4L, show_progress = FALSE, debug = TRUE)),
		"All bootstrap iterations failed or returned invalid results. Check for worker crashes or out-of-memory issues.",
		fixed = TRUE
	)
})

test_that("no crashed chunk results triggers neither the warning nor the error", {
	inf <- fx(3L)
	priv <- inf$.__enclos_env__$private
	unlockBinding("par_lapply", priv)
	priv$par_lapply <- function(X, FUN, n_cores = 1L, budget = 1L, show_progress = FALSE, export_list = NULL) {
		list(
			list(list(val = 1.0, errors = character(0), warnings = character(0)), list(val = 2.0, errors = character(0), warnings = character(0)))
		)
	}
	expect_no_warning(res <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 2L, show_progress = FALSE, debug = TRUE))
	expect_length(res$values, 2L)
})
