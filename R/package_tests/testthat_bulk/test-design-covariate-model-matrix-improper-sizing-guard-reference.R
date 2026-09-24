library(testthat)
library(EDI)

# Design$covariate_impute_if_necessary_and_then_create_model_matrix() (design_abstract.R,
# called from every design's add_all_subjects_to_experiment()/add_one_subject_*() path) ends
# with a defensive invariant check: if the freshly built private$X has a row count that
# disagrees with private$Xraw or private$Ximp, it stop()s with "improper sizing for the
# internal X representation" rather than silently proceeding with mismatched data. A
# codebase-wide grep confirmed this exact message had zero test references anywhere. This is
# structurally unreachable through the normal public API -- create_model_matrix_from_features()
# (helper_model_matrix.R) always returns one row per input row for a normal formula/data
# combination -- so it is the same "defensive stop() on an already-validated invariant" shape
# as several other guards closed earlier this session (SimulationFramework's unsupported
# results-file-format guard, InferenceNonParamBootstrap's unreachable bootstrap-CI-type
# dispatch arm). Reached here by mocking create_model_matrix_from_features() (via
# with_mocked_bindings, .package = "EDI") to return a matrix with a deliberately wrong row
# count, independent of any real formula-expansion machinery.

test_that("a model matrix whose row count disagrees with Xraw/Ximp is rejected with the documented invariant error", {
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)

	with_mocked_bindings(
		create_model_matrix_from_features = function(...) matrix(1, nrow = 3L, ncol = 1L),
		.package = "EDI",
		{
			expect_error(
				des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))),
				"improper sizing for the internal X representation",
				fixed = TRUE
			)
		}
	)
})

test_that("a correctly-sized model matrix never triggers the guard", {
	set.seed(2)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	expect_silent(des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))))
})
