library(testthat)
library(EDI)

# local_machine_tuning_axes.R has two previously-untested early-argument guards on its exported-
# internal local-benchmarking helpers:
#
# 1. edi_tuning_warm_start_families(operation) stop()s "Unknown warm-start operation `<op>`." for
#    any operation not in EDI_TUNING_WARM_START_OPERATION_CALLS. Pure and deterministic (only
#    introspects the package's own live class families), no benchmarking triggered.
#
# 2. edi_tuning_tune_parallel_crossover(operation, num_cores, ...) stop()s "num_cores must be >= 2
#    to benchmark parallel against serial." for num_cores < 2, immediately after its checkmate
#    argument assertions and before any actual timing/benchmarking runs.

test_that("edi_tuning_warm_start_families(): an unrecognized operation errors with the documented message", {
	f <- getFromNamespace("edi_tuning_warm_start_families", "EDI")
	expect_error(
		f("not_a_real_operation"),
		"Unknown warm-start operation `not_a_real_operation`\\."
	)
})

test_that("edi_tuning_warm_start_families(): a recognized operation returns a data.frame without error", {
	f <- getFromNamespace("edi_tuning_warm_start_families", "EDI")
	res <- f("jackknife")
	expect_true(is.data.frame(res))
	expect_true(all(c("class", "response_type") %in% names(res)))
})

test_that("edi_tuning_tune_parallel_crossover(): num_cores < 2 errors with the documented message, before any benchmarking", {
	g <- getFromNamespace("edi_tuning_tune_parallel_crossover", "EDI")
	expect_error(
		g(operation = "bootstrap", num_cores = 1L),
		"num_cores must be >= 2 to benchmark parallel against serial\\."
	)
})
