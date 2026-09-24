library(testthat)
library(EDI)

# SimulationFramework$new()'s cluster of early scalar/vector argument-validation guards
# (simulations_framework.R, immediately following the response_type guard closed in
# test-simulation-framework-response-type-constructor-guard-reference.R): n, p, betaT,
# cond_exp_func_model, seed, X_mat, random_X_draws, and results_filename. A codebase-wide grep
# confirmed every one of these 8 exact messages had zero test references anywhere, despite
# SimulationFramework being one of the most heavily tested classes in the suite -- the normal,
# well-formed construction path is exercised constantly, but these specific early-exit guards never
# individually.

base_args <- function(...) {
	modifyList(
		list(
			response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
			inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
			inference_types_and_params = list(asymp_pval = list()),
			n = 20L, p = 1L, betaT = 0, cond_exp_func_model = "linear",
			results_filename = tempfile(fileext = ".csv"), verbose = FALSE
		),
		list(...)
	)
}

test_that("n must contain finite integers greater than 1", {
	expect_error(
		do.call(SimulationFramework$new, base_args(n = 1L)),
		"n must contain finite integers greater than 1", fixed = TRUE
	)
	suppressWarnings(expect_error(
		do.call(SimulationFramework$new, base_args(n = Inf)),
		"n must contain finite integers greater than 1", fixed = TRUE
	))
})

test_that("p must contain finite positive integers", {
	expect_error(
		do.call(SimulationFramework$new, base_args(p = 0L)),
		"p must contain finite positive integers", fixed = TRUE
	)
})

test_that("betaT must contain finite numeric values", {
	expect_error(
		do.call(SimulationFramework$new, base_args(betaT = NA_real_)),
		"betaT must contain finite numeric values", fixed = TRUE
	)
})

test_that("cond_exp_func_model must contain only 'linear' and/or 'nonlinear'", {
	expect_error(
		do.call(SimulationFramework$new, base_args(cond_exp_func_model = "quadratic")),
		"cond_exp_func_model must contain only 'linear' and/or 'nonlinear'", fixed = TRUE
	)
})

test_that("seed must be NULL or one finite numeric value", {
	expect_error(
		do.call(SimulationFramework$new, base_args(seed = c(1, 2))),
		"seed must be NULL or one finite numeric value", fixed = TRUE
	)
	expect_error(
		do.call(SimulationFramework$new, base_args(seed = "a")),
		"seed must be NULL or one finite numeric value", fixed = TRUE
	)
})

test_that("X_mat can only be used when n and p are scalar", {
	expect_error(
		do.call(SimulationFramework$new, base_args(X_mat = matrix(1, 2, 2), n = c(20L, 30L))),
		"X_mat can only be used when n and p are scalar", fixed = TRUE
	)
})

test_that("random_X_draws = FALSE requires seed to be non-NULL", {
	expect_error(
		do.call(SimulationFramework$new, base_args(random_X_draws = FALSE, seed = NULL)),
		"random_X_draws = FALSE requires seed to be non-NULL", fixed = TRUE
	)
})

test_that("results_filename must be a single non-missing character string", {
	expect_error(
		do.call(SimulationFramework$new, base_args(results_filename = 5)),
		"results_filename must be a single non-missing character string", fixed = TRUE
	)
	expect_error(
		do.call(SimulationFramework$new, base_args(results_filename = NA_character_)),
		"results_filename must be a single non-missing character string", fixed = TRUE
	)
})

test_that("well-formed constructor arguments construct without error", {
	expect_no_error(do.call(SimulationFramework$new, base_args()))
})
