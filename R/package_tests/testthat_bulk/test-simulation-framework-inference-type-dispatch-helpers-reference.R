library(testthat)
library(EDI)

# SimulationFramework's inference-type dispatch helpers (simulations_framework.R) had no test
# reference anywhere by name (confirmed via zero-hit greps for each, and for the "Unknown inference
# type" / "contains argument(s) not accepted by" stop() messages):
#   .has_inf_type() / .any_inf_type() -- membership checks against the requested inf_types.
#   .inf_type_method_name() -- maps each of the 8 documented inference-type sentinels (asymp_ci,
#      asymp_pval, exact_ci, exact_pval, boot_ci, boot_pval, rand_ci, rand_pval) to the Inference
#      method name it calls, erroring on anything else.
#   .args_for_inf_type() -- merges user-supplied inference_types_and_params[[inf_type]] over a
#      caller-supplied defaults list, after validating them via .validate_method_args().
#   .validate_method_args() -- rejects any user-supplied argument name the target method doesn't
#      declare (unless it accepts '...').
# All reachable directly on a cheaply-constructed SimulationFramework instance and a real Inference
# object, without ever calling $run().

sim_fixture <- function() {
	SimulationFramework$new(
		response_type = "continuous", design_classes_and_params = list(DesignFixedBernoulli),
		inference_classes_and_params = list(InferenceAllSimpleAverageDiff),
		inference_types_and_params = list(asymp_ci = list(), asymp_pval = list(delta = 0)),
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE)
}

inf_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	InferenceAllSimpleAverageDiff$new(des)
}

test_that(".has_inf_type()/.any_inf_type() check membership against the requested inf_types", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_true(priv$.has_inf_type("asymp_ci"))
	expect_false(priv$.has_inf_type("boot_ci"))
	expect_true(priv$.any_inf_type(c("boot_ci", "asymp_ci")))
	expect_false(priv$.any_inf_type(c("boot_ci", "rand_ci")))
})

test_that(".inf_type_method_name() maps every documented sentinel to its method name, and errors on an unknown one", {
	priv <- sim_fixture()$.__enclos_env__$private
	expected <- c(
		asymp_ci = "compute_asymp_confidence_interval",
		asymp_pval = "compute_asymp_two_sided_pval",
		exact_ci = "compute_exact_confidence_interval",
		exact_pval = "compute_exact_two_sided_pval_for_treatment_effect",
		boot_ci = "compute_bootstrap_confidence_interval",
		boot_pval = "compute_bootstrap_two_sided_pval",
		rand_ci = "compute_rand_confidence_interval",
		rand_pval = "compute_rand_two_sided_pval"
	)
	for (nm in names(expected)) {
		expect_identical(priv$.inf_type_method_name(nm), unname(expected[nm]), info = nm)
	}
	expect_error(priv$.inf_type_method_name("bogus_type"), "Unknown inference type: bogus_type", fixed = TRUE)
})

test_that(".args_for_inf_type() merges user params over defaults for a configured inference type, and returns defaults unchanged for an unconfigured one", {
	priv <- sim_fixture()$.__enclos_env__$private
	inf <- inf_fixture()
	merged <- priv$.args_for_inf_type(inf, "asymp_pval", defaults = list(delta = 99))
	expect_equal(merged, list(delta = 0))                                  # user's delta = 0 overrides the default
	merged_ci <- priv$.args_for_inf_type(inf, "asymp_ci", defaults = list(alpha = 0.05))
	expect_equal(merged_ci, list(alpha = 0.05))                            # asymp_ci has no user params configured
})

test_that(".validate_method_args() rejects an argument name the target method doesn't declare", {
	priv <- sim_fixture()$.__enclos_env__$private
	inf <- inf_fixture(seed = 2L)
	expect_error(
		priv$.validate_method_args(inf, "compute_asymp_two_sided_pval", list(bogus_arg_xyz = 1), "asymp_pval"),
		"inference_types_and_params\\[\\['asymp_pval'\\]\\] contains argument\\(s\\) not accepted by compute_asymp_two_sided_pval\\(\\): bogus_arg_xyz"
	)
	expect_true(priv$.validate_method_args(inf, "compute_asymp_two_sided_pval", list(delta = 0), "asymp_pval"))
	expect_true(priv$.validate_method_args(inf, "compute_asymp_two_sided_pval", list(), "asymp_pval"))
})

test_that(".validate_method_args() errors with a distinct message when the target method doesn't exist on the object", {
	priv <- sim_fixture()$.__enclos_env__$private
	inf <- inf_fixture(seed = 3L)
	expect_error(
		priv$.validate_method_args(inf, "no_such_method_xyz", list(a = 1), "asymp_pval"),
		"Cannot validate parameters for asymp_pval: function no_such_method_xyz\\(\\) is not available on"
	)
})
