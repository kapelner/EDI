library(testthat)
library(EDI)

# tune_EDI_for_this_machine() (local_machine_tuning.R) validates two explicitly-requested
# axes before any benchmarking begins (checked even under dry_run = TRUE, since these are
# argument-shape guards, not benchmark failures):
#   1. Requesting the "optimizer" axis without supplying `converged_fn` -- there is no
#      generic, class-independent convergence accessor, so the caller must supply one --
#      "The optimizer axis requires `converged_fn` (a function(inf) -> logical(1))...".
#   2. Requesting the "parallel" axis when edi_tuning_parallel_axis_available() is FALSE
#      (non-Unix, or fewer than 2 logical cores) -- "The parallel axis needs a Unix-alike
#      with >= 2 logical cores." Mocked here (via with_mocked_bindings, .package = "EDI")
#      since this machine genuinely has parallel support, so the real guard can't otherwise
#      be exercised without actually running on unsupported hardware.
# A codebase-wide grep confirmed both exact messages had zero test references anywhere.
# Deliberately no "does not trigger the guard" negative control that lets the call proceed
# past argument validation: force = TRUE is required to get past this machine's own
# busy-machine self-check under real contention, and doing so lets execution continue into
# the real (deliberately expensive, historically fragile per this project's convention)
# benchmark/calibration machinery -- exactly the risk this session's standing instructions
# warn against. Both guards below fire fast, before any of that.

test_that("requesting the optimizer axis without converged_fn is rejected", {
	expect_error(
		tune_EDI_for_this_machine(axes = c("optimizer"), converged_fn = NULL, quiet = TRUE, dry_run = TRUE),
		"The optimizer axis requires `converged_fn`",
		fixed = TRUE
	)
})

test_that("requesting the parallel axis when parallel support is unavailable is rejected", {
	with_mocked_bindings(
		edi_tuning_parallel_axis_available = function() FALSE,
		.package = "EDI",
		{
			expect_error(
				tune_EDI_for_this_machine(axes = c("parallel"), quiet = TRUE, dry_run = TRUE),
				"The parallel axis needs a Unix-alike with >= 2 logical cores.",
				fixed = TRUE
			)
		}
	)
})
