library(testthat)
library(EDI)

# SimulationFramework's result-keying and cache-naming helpers (simulations_framework.R) had no test
# reference anywhere by name (confirmed via zero-hit greps for each, including the ".result_key_from_row
# expected a list, but got:" stop() message):
#   .result_key_for_values() -- pipe-joins the 9 identifying fields of a simulation cell into a single
#      cache/dedup key string, in a fixed documented order.
#   .result_key_from_row() -- the same key, pulled from a named list/row instead of positional
#      arguments; errors with a type-reporting message when given anything but a list.
#   .safe_cache_component() -- sanitizes a string into a filesystem-safe cache-path component:
#      non-alphanumeric runs become a single underscore, leading/trailing underscores are stripped,
#      and an empty result falls back to the literal "cache".
#   .hash_object() -- a thin digest::digest(algo = "md5") wrapper: deterministic for identical input,
#      different for different input, and identical to calling digest::digest() directly.
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

test_that(".result_key_for_values() pipe-joins the 9 fields in the documented order", {
	priv <- sim_fixture()$.__enclos_env__$private
	key <- priv$.result_key_for_values("continuous", "linear", 20, 1, 0, 1, "designA", "infB", "asymp_ci")
	expect_identical(key, "continuous|linear|20|1|0|1|designA|infB|asymp_ci")
})

test_that(".result_key_from_row() produces the identical key to .result_key_for_values() on the same values, and errors on a non-list input", {
	priv <- sim_fixture()$.__enclos_env__$private
	row <- list(
		response_type = "continuous", cond_exp_func_model = "linear", n = 20, p = 1, betaT = 0,
		rep = 1, design = "designA", inference = "infB", inference_type = "asymp_ci"
	)
	expect_identical(
		priv$.result_key_from_row(row),
		priv$.result_key_for_values("continuous", "linear", 20, 1, 0, 1, "designA", "infB", "asymp_ci")
	)
	expect_error(
		priv$.result_key_from_row("not a list"),
		".result_key_from_row expected a list, but got: character",
		fixed = TRUE
	)
	expect_error(
		priv$.result_key_from_row(42),
		".result_key_from_row expected a list, but got: double",
		fixed = TRUE
	)
})

test_that(".safe_cache_component() sanitizes non-alphanumeric runs to a single underscore, strips leading/trailing underscores, and falls back to 'cache' when empty", {
	priv <- sim_fixture()$.__enclos_env__$private
	expect_identical(priv$.safe_cache_component("foo bar!"), "foo_bar")
	expect_identical(priv$.safe_cache_component("___"), "cache")
	expect_identical(priv$.safe_cache_component(""), "cache")
	expect_identical(priv$.safe_cache_component("Already-Safe.Name_1"), "Already-Safe.Name_1")
	expect_identical(priv$.safe_cache_component("__leading and trailing__"), "leading_and_trailing")
})

test_that(".hash_object() is deterministic, sensitive to its input, and identical to calling digest::digest() directly", {
	priv <- sim_fixture()$.__enclos_env__$private
	h1 <- priv$.hash_object(list(a = 1, b = "x"))
	h2 <- priv$.hash_object(list(a = 1, b = "x"))
	h3 <- priv$.hash_object(list(a = 2, b = "x"))
	expect_identical(h1, h2)
	expect_false(identical(h1, h3))
	expect_identical(h1, digest::digest(list(a = 1, b = "x"), algo = "md5"))
})
