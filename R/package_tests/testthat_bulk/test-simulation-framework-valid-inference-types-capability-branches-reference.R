library(testthat)
library(EDI)

# SimulationFramework's private .valid_inference_types() (simulations_framework.R) dispatches on 5
# capability predicates -- .supports_asymp_inference/.supports_exact_inference/.supports_nonparam_
# bootstrap_inference (each a thin wrapper around the shared .supports_inference_capability(inf_obj,
# capability, fallback_class)) plus two direct .supports_inference_capability() calls for
# "randomization_test"/"randomization_ci" -- to decide which of private$inf_types are actually runnable
# for a given inference object. R/EDI/tests/testthat/test-simulation-framework-capability-dispatch.R
# already covers the randomization_test/randomization_ci branches directly, but a codebase-wide grep
# confirmed .supports_asymp_inference, .supports_exact_inference, .supports_inference_capability, and
# .supports_nonparam_bootstrap_inference themselves had ZERO direct test references anywhere -- the
# existing test never exercises the asymp_ci/asymp_pval, exact_ci/exact_pval, or boot_ci/boot_pval
# branches, nor .supports_inference_capability's own fallback_class mechanism (when inf_obj$supports()
# errors or isn't defined, it falls back to `is(inf_obj, fallback_class)` instead of assuming
# unsupported). Reached the same way as the existing capability-dispatch test: a minimal
# SimulationFramework fixture and hand-built fake inference objects (environments with their own
# $supports() closure, or with a class attribute and an always-erroring $supports() to force the
# fallback_class path), independent of any real Inference class's actual capability wiring.

sf_fixture <- function(inf_types, response_type = "continuous") {
	sf <- SimulationFramework$new(
		response_type = "continuous",
		design_classes_and_params = list(),
		inference_classes_and_params = list(),
		n = 4L, p = 1L, verbose = FALSE
	)
	priv <- sf$.__enclos_env__$private
	priv$inf_types <- inf_types
	priv$current_response_type <- response_type
	priv
}

fake_inference <- function(capabilities) {
	env <- new.env(parent = emptyenv())
	env$supports <- function(capability) stats::setNames(capability %in% capabilities, capability)
	env
}

fake_erroring_inference <- function(class_name) {
	env <- new.env(parent = emptyenv())
	class(env) <- c(class_name, "R6")
	env$supports <- function(capability) stop("supports() unavailable")
	env
}

test_that(".supports_asymp_inference selects asymp_ci/asymp_pval via the 'wald' capability", {
	priv <- sf_fixture(c("asymp_ci", "asymp_pval", "exact_ci", "boot_ci", "rand_pval"))
	expect_identical(priv$.valid_inference_types(fake_inference("wald")), c("asymp_ci", "asymp_pval"))
})

test_that(".supports_exact_inference selects exact_ci/exact_pval via the 'exact_test' capability", {
	priv <- sf_fixture(c("asymp_ci", "exact_ci", "exact_pval", "boot_ci", "rand_pval"))
	expect_identical(priv$.valid_inference_types(fake_inference("exact_test")), c("exact_ci", "exact_pval"))
})

test_that(".supports_nonparam_bootstrap_inference selects boot_ci/boot_pval via the 'nonparametric_bootstrap' capability, with no fallback_class", {
	priv <- sf_fixture(c("asymp_ci", "boot_ci", "boot_pval", "rand_pval"))
	expect_identical(priv$.valid_inference_types(fake_inference("nonparametric_bootstrap")), c("boot_ci", "boot_pval"))
	# no fallback_class is passed for the bootstrap predicate, so an erroring supports() with a
	# matching class name still yields nothing (unlike asymp/exact below)
	expect_identical(priv$.valid_inference_types(fake_erroring_inference("InferenceNonParamBootstrap")), character())
})

test_that("an object supporting no capabilities at all yields an empty inference-type vector", {
	priv <- sf_fixture(c("asymp_ci", "exact_ci", "boot_ci", "rand_pval"))
	expect_identical(priv$.valid_inference_types(fake_inference(character())), character())
})

test_that(".supports_inference_capability falls back to is(inf_obj, fallback_class) when supports() errors, for both the asymp and exact predicates", {
	priv <- sf_fixture(c("asymp_ci", "asymp_pval", "exact_ci", "exact_pval"))
	expect_identical(priv$.valid_inference_types(fake_erroring_inference("InferenceAsymp")), c("asymp_ci", "asymp_pval"))
	expect_identical(priv$.valid_inference_types(fake_erroring_inference("InferenceExact")), c("exact_ci", "exact_pval"))
	# a class name matching NEITHER fallback still yields nothing when supports() errors
	expect_identical(priv$.valid_inference_types(fake_erroring_inference("SomeUnrelatedClass")), character())
})

test_that("rand_ci is only offered for continuous/proportion/count response types, even when randomization_ci is supported", {
	both_caps <- c("randomization_test", "randomization_ci")
	priv_surv <- sf_fixture(c("rand_pval", "rand_ci"), response_type = "survival")
	expect_identical(priv_surv$.valid_inference_types(fake_inference(both_caps)), "rand_pval")

	priv_cont <- sf_fixture(c("rand_pval", "rand_ci"), response_type = "continuous")
	expect_identical(priv_cont$.valid_inference_types(fake_inference(both_caps)), c("rand_pval", "rand_ci"))
})
