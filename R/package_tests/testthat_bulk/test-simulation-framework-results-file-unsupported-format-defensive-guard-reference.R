library(testthat)
library(EDI)

# SimulationFramework's private .read_results_file()/.append_result_row_to_file() (simulations_
# framework.R) each re-derive the results file's format via .results_file_format() and stop("Unsupported
# results file format: ", private$results_filename) if it's neither "csv" nor "csv.bz2". This is
# structurally unreachable through the public API as things stand: SimulationFramework$new()'s own
# constructor-time guard (already tested elsewhere, "results_filename must end in either '.csv' or
# '.csv.bz2'") rejects any other extension before construction even completes, so private$
# results_filename can never hold an unsupported extension for a normally-constructed object -- the
# same "defensive stop() on an already-validated invariant" shape as .default_inference_classes()'s
# "Unknown response_type" guard tested earlier this session. Real, directly-reachable code once
# private$results_filename is mutated post-construction (confirmed via a plain unlockBinding field
# assignment, no C++ involved). A codebase-wide grep confirmed the exact message had zero test
# references anywhere.

fx <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), verbose = FALSE
	)
}

test_that(".read_results_file() raises the documented error once results_filename is mutated to an unsupported extension", {
	sim <- fx()
	priv <- sim$.__enclos_env__$private
	unlockBinding("results_filename", priv)
	priv$results_filename <- tempfile(fileext = ".txt")
	expect_error(priv$.read_results_file(), "Unsupported results file format: ", fixed = TRUE)
})

test_that(".append_result_row_to_file() raises the same documented error under the same mutated extension", {
	sim <- fx()
	priv <- sim$.__enclos_env__$private
	unlockBinding("results_filename", priv)
	priv$results_filename <- tempfile(fileext = ".txt")
	expect_error(priv$.append_result_row_to_file(data.frame(x = 1)), "Unsupported results file format: ", fixed = TRUE)
})
