library(testthat)
library(EDI)

# SimulationFramework$new() (simulations_framework.R:761-770) has two warn-rather-than-error
# guards, distinct from the already-covered sibling stop() guards on the same custom_dgp block
# ("custom_dgp cannot be combined with...", "custom_dgp must be a function"):
#   1. custom_dgp set together with any nonzero betaT value warns that betaT is ignored (the true
#      estimand comes from the DGP function itself) -- "custom_dgp is set; betaT is ignored as the
#      true estimand comes from the DGP function".
#   2. random_X_draws = FALSE together with a custom_replication_data_generator warns that the
#      generator overrides the fixed-X setting -- "custom_replication_data_generator overrides
#      random_X_draws=FALSE; a new X will be drawn every replication".
# A codebase-wide grep confirmed both exact messages had zero test references anywhere. Exercised
# via the plain public constructor, reusing the same minimal fixture already established in this
# session's other SimulationFramework guard files.

fx <- function(...) {
	args = list(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list()),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0.5,
		results_filename = tempfile(fileext = ".csv"), verbose = FALSE
	)
	extra = list(...)
	args[names(extra)] = extra
	do.call(SimulationFramework$new, args)
}

test_that("custom_dgp with a nonzero betaT warns that betaT is ignored", {
	expect_warning(
		fx(custom_dgp = function(...) NULL),
		"custom_dgp is set; betaT is ignored as the true estimand comes from the DGP function",
		fixed = TRUE
	)
})

test_that("custom_dgp with betaT = 0 does not trigger the warning", {
	expect_no_warning(fx(custom_dgp = function(...) NULL, betaT = 0))
})

test_that("random_X_draws = FALSE together with custom_replication_data_generator warns that it is overridden", {
	expect_warning(
		fx(random_X_draws = FALSE, seed = 1L, custom_replication_data_generator = function(...) NULL),
		"custom_replication_data_generator overrides random_X_draws=FALSE; a new X will be drawn every replication",
		fixed = TRUE
	)
})

test_that("random_X_draws = TRUE (the default) with custom_replication_data_generator does not trigger the warning", {
	expect_no_warning(fx(custom_replication_data_generator = function(...) NULL))
})
