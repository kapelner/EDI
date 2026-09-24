library(testthat)
library(EDI)

# SimulationFramework's private .parse_inference_types_and_params(spec, valid_inf_types)
# (simulations_framework.R) has a NULL/error-guard branch already exercised through the constructor by
# test-simulation-framework-classes-and-params-parsing-guards-reference.R (bad-shape spec, invalid
# names, bad per-type shape) -- but NOT this method's own three remaining branches, which that file's
# grep-based gap check missed because the method's name is split across two wrapped comment lines
# there ("...parse_inference_types_and_" / "params()..."), making it look referenced when it isn't:
#   1. spec = NULL: returns every entry of valid_inf_types as its own name, each mapped to an empty
#      list() (the "no per-type params supplied at all" default).
#   2. A duplicate name in spec: `spec = spec[!duplicated(names(spec))]` keeps the FIRST occurrence's
#      params and silently drops the rest, rather than merging or erroring.
#   3. An explicit NULL value for a named entry (`list(asymp_ci = NULL)`, which in R is a length-1 list
#      whose single element is NULL, not an absent key): normalized to list() rather than left NULL or
#      treated as "not a list" (a plain unnamed non-list value like `"not a list"` DOES error, per the
#      existing guard file -- NULL is a deliberate, documented exception).
# Reached via a direct private-method call on a minimal SimulationFramework instance, independent of
# the constructor's own argument-validation call site (already covered elsewhere).

sf_fixture <- function() {
	sf <- SimulationFramework$new(
		response_type = "continuous",
		n = 20L, p = 1L, Nrep_W = 1L, Nrep_Y_w = 1L, betaT = 0,
		results_filename = tempfile(fileext = ".csv"), continue_from_last_result_row = FALSE,
		verbose = FALSE, turn_off_asserts_for_speed = FALSE
	)
	sf$.__enclos_env__$private
}

test_that("a NULL spec returns every valid inference type mapped to an empty list()", {
	priv <- sf_fixture()
	out <- priv$.parse_inference_types_and_params(NULL, c("asymp_ci", "asymp_pval", "exact_ci"))
	expect_identical(out, list(asymp_ci = list(), asymp_pval = list(), exact_ci = list()))
})

test_that("a duplicated inference-type name keeps only the FIRST occurrence's params", {
	priv <- sf_fixture()
	out <- priv$.parse_inference_types_and_params(
		list(asymp_ci = list(delta = 1), asymp_ci = list(delta = 2)),
		c("asymp_ci", "asymp_pval")
	)
	expect_identical(out, list(asymp_ci = list(delta = 1)))
})

test_that("an explicit NULL value for a named entry is normalized to list(), not left NULL or rejected", {
	priv <- sf_fixture()
	out <- priv$.parse_inference_types_and_params(list(asymp_ci = NULL), c("asymp_ci", "asymp_pval"))
	expect_identical(out, list(asymp_ci = list()))
})
