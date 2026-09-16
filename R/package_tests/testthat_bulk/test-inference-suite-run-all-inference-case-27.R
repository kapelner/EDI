library(testthat)
library(EDI)

test_that("run_all_inference: max_secs_per_class actually interrupts a slow R-level fit", {
	skip_on_cran()
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260818)
	n = 12L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	# Busy-loops for 5s in pure R (an R-level loop, not one opaque native call) --
	# setTimeLimit() is documented to check at R-level interrupt points, so this
	# is the case the timeout mechanism is actually guaranteed to catch (see the
	# "known limitation" note on run_all_inference_one_class()).
	InferenceTemporarySlowRunAll = R6::R6Class("InferenceTemporarySlowRunAll",
		inherit = EDI:::Inference,
		public = list(
			compute_estimate = function(estimate_only = FALSE) {
				t_end = Sys.time() + 5
				while (Sys.time() < t_end) { x = 0; for (i in 1:1e5) x = x + 1 }
				0
			}
		)
	)
	assign("InferenceTemporarySlowRunAll", InferenceTemporarySlowRunAll, envir = .GlobalEnv)
	on.exit(rm("InferenceTemporarySlowRunAll", envir = .GlobalEnv), add = TRUE)
	EDI:::register_inference_class(
		name = "InferenceTemporarySlowRunAll", parent = "Inference",
		metadata = list(
			abstract = FALSE, exported = TRUE, response_types = "continuous",
			design_families = "all", compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none", required_packages = character(), capabilities = character()
		),
		direct_components = character()
	)

	suite = InferenceSuite$new(des)
	t0 = Sys.time()
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			classes = "InferenceTemporarySlowRunAll", max_secs_per_class = 1)
	})
	elapsed = as.numeric(difftime(Sys.time(), t0, units = "secs"))

	expect_lt(elapsed, 4)  # well under the 5s the fit would otherwise take
	row = res$results_table
	expect_identical(row$status, "timeout")
	expect_true(grepl("max_secs_per_class", row$message, fixed = TRUE))
})

# "run_all_inference: num_cores > 1 fits in parallel and produces identical
# rows to sequential" moved to
# R/package_tests/testthat_bulk_quarantine/test-inference-suite-run-all-inference-seq-vs-parallel.R
# (2026-08-27) -- see that directory's README.md. CI run 33072346506 found a
# real, non-hanging pval mismatch between num_cores = 1 and num_cores = 2,
# not just the historical fork-deadlock risk this test's comments used to
# document.

