library(testthat)
library(EDI)

# SimulationFramework's small pure formatting/grid-building helpers (simulations_framework.R) had no
# test reference anywhere by name (confirmed via zero-hit greps for each), despite the core $run()
# machinery being otherwise thoroughly tested elsewhere:
#   .params_to_str() / .params_for_inference_type_to_str() -- serialize a named params list to
#      "k=v, ..." (via deparse(), so strings come back quoted), empty for NULL/zero-length, and wrap
#      the inference-type label around it only when non-empty.
#   .format_values() -- a scalar formats bare; length > 1 formats as "c(...)".
#   .filter_by_formals() -- keeps only the args a given R6 generator's initialize() actually declares
#      (unless it accepts '...', in which case everything passes through unchanged).
#   .has_private_method_on_object() -- checks a DIFFERENT object's own private environment directly
#      (not the caller's) -- TRUE only for a genuine private (not public) member.
#   .build_param_grid() -- expand.grid() over the five simulation axes, dropping cond_exp_func_model
#      = "nonlinear" cells with p < 5L, and erroring with the documented message when every cell is
#      filtered out.
# All reachable directly on a cheaply-constructed SimulationFramework instance, without ever calling
# $run().

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list(delta = 0)),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

test_that(".params_to_str() serializes a named list as 'k=v, ...', quoting strings via deparse(), and is empty for NULL/zero-length", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_identical(priv$.params_to_str(NULL), "")
	expect_identical(priv$.params_to_str(list()), "")
	expect_identical(priv$.params_to_str(list(a = 1, b = "x")), 'a=1, b="x"')
	expect_identical(priv$.params_to_str(list(delta = 0.5)), "delta=0.5")
})

test_that(".params_for_inference_type_to_str() wraps the type label around its params only when non-empty", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_identical(priv$.params_for_inference_type_to_str("asymp_pval"), "asymp_pval(delta=0)")
	expect_identical(priv$.params_for_inference_type_to_str("asymp_ci"), "")
})

test_that(".format_values() formats a scalar bare and a vector as 'c(...)'", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_identical(priv$.format_values(5), "5")
	expect_identical(priv$.format_values("x"), "x")
	expect_identical(priv$.format_values(c(1, 2, 3)), "c(1, 2, 3)")
})

test_that(".filter_by_formals() keeps only args the generator's initialize() declares, and passes everything through when it accepts '...'", {
	priv <- sim_fixture()$.__enclos_env__$private
	args <- list(n = 10, response_type = "continuous", bogus_arg_xyz = 5)
	filtered <- priv$.filter_by_formals(DesignFixedBernoulli, args)
	expect_setequal(names(filtered), intersect(names(args), names(formals(get_r6_init_fn(DesignFixedBernoulli)))))
	expect_false("bogus_arg_xyz" %in% names(filtered))
	expect_identical(priv$.filter_by_formals(DesignFixedBernoulli, list()), list())
})

test_that(".has_private_method_on_object() is TRUE only for a genuine private member of the target object", {
	priv <- sim_fixture()$.__enclos_env__$private
	sim2 <- sim_fixture()
	expect_true(priv$.has_private_method_on_object(sim2, ".build_param_grid"))
	expect_false(priv$.has_private_method_on_object(sim2, "run"))                  # public, not private
	expect_false(priv$.has_private_method_on_object(sim2, "nonexistent_method_xyz"))
})

test_that(".build_param_grid() expands the five axes and drops nonlinear/p<5 cells", {
	priv <- sim_fixture()$.__enclos_env__$private
	grid <- priv$.build_param_grid(
		n_values = c(20, 40), p_values = 1, betaT_values = 0,
		cond_exp_func_model_values = "linear", response_type_values = "continuous"
	)
	expect_equal(nrow(grid), 2L)
	expect_setequal(grid$n, c(20, 40))

	grid_mixed <- priv$.build_param_grid(
		n_values = 20, p_values = c(1, 7), betaT_values = 0,
		cond_exp_func_model_values = c("linear", "nonlinear"), response_type_values = "continuous"
	)
	# linear/p=1, linear/p=7, nonlinear/p=7 survive; nonlinear/p=1 (p < 5) is dropped
	expect_equal(nrow(grid_mixed), 3L)
	expect_false(any(grid_mixed$cond_exp_func_model == "nonlinear" & grid_mixed$p < 5L))
})

test_that(".build_param_grid() errors with the documented message when every cell is filtered out", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_error(
		priv$.build_param_grid(
			n_values = 20, p_values = 2, betaT_values = 0,
			cond_exp_func_model_values = "nonlinear", response_type_values = "continuous"
		),
		"No valid simulation cells remain after filtering cond_exp_func_model / p combinations",
		fixed = TRUE
	)
})
