library(testthat)
library(EDI)

# local_machine_tuning_axes.R: edi_tuning_construct_under_optimizer() (the optimizer policy is
# forced for exactly the class's own name while the experiment is built, and the prior policy is
# restored afterwards, even on error) and edi_tuning_parallel_run_setting() (runs the operation's
# generic call, swallows "not implemented"-style errors, re-throws every other error).

Z <- function(x) get(x, envir = asNamespace("EDI"))
ns <- asNamespace("EDI")

replace_in_ns <- function(name, value) {
	old <- get(name, envir = ns)
	unlockBinding(name, ns); assign(name, value, envir = ns)
	function() assign(name, old, envir = ns)
}

test_that("the requested algorithm is in force while the experiment is built and the prior policy is restored afterwards", {
	env <- Z("edi_env")
	before <- env$optimization_dispatch_policy_config
	seen <- NULL
	orig <- Z("edi_tuning_synthetic_experiment")
	restore <- replace_in_ns("edi_tuning_synthetic_experiment", function(response_type, n, seed) {
		seen <<- c(seen, Z("edi_optimization_dispatch_policy")("InferenceCountPoisson"), Z("edi_optimization_dispatch_policy")("InferenceCountNegBin"))
		orig(response_type, n = n, seed = seed)
	})
	on.exit({ restore(); lockBinding("edi_tuning_synthetic_experiment", ns) }, add = TRUE)
	inf <- Z("edi_tuning_construct_under_optimizer")("InferenceCountPoisson", "count", 40L, "lbfgs", 1L)
	expect_s3_class(inf, "InferenceCountPoisson")
	expect_equal(seen[1], "lbfgs")                                                    # forced for the named class
	expect_false(identical(seen[2], "lbfgs") && !identical(Z("edi_optimization_dispatch_policy")("InferenceCountNegBin"), "lbfgs"))
	expect_identical(env$optimization_dispatch_policy_config, before)                 # restored
	expect_equal(Z("edi_optimization_dispatch_policy")("InferenceCountPoisson"), "irls")
	expect_true(is.finite(inf$compute_estimate()))
})

test_that("the forced override is anchored to the exact class name and restored even when construction fails", {
	env <- Z("edi_env"); before <- env$optimization_dispatch_policy_config
	expect_error(Z("edi_tuning_construct_under_optimizer")("NoSuchInferenceClass", "count", 40L, "lbfgs", 1L))
	expect_identical(env$optimization_dispatch_policy_config, before)
	expect_error(Z("edi_tuning_construct_under_optimizer")("InferenceCountPoisson", "not_a_response_type", 40L, "lbfgs", 1L))
	expect_identical(env$optimization_dispatch_policy_config, before)
})

test_that("the same seed builds the same synthetic data for every algorithm", {
	g <- Z("edi_tuning_construct_under_optimizer")
	a <- g("InferenceCountPoisson", "count", 40L, "lbfgs", 7L)
	b <- g("InferenceCountPoisson", "count", 40L, "newton_raphson", 7L)
	expect_equal(a$get_response(), b$get_response())
	c2 <- g("InferenceCountPoisson", "count", 40L, "lbfgs", 8L)
	expect_false(identical(a$get_response(), c2$get_response()))
})

with_op_spec <- function(spec, code) {
	tbl <- Z("EDI_TUNING_WARM_START_OPERATION_CALLS")
	old <- tbl$non_param_boot
	restore <- replace_in_ns("EDI_TUNING_WARM_START_OPERATION_CALLS", { t <- tbl; t$non_param_boot <- spec; t })
	on.exit({ restore(); lockBinding("EDI_TUNING_WARM_START_OPERATION_CALLS", ns) }, add = TRUE)
	force(code)
}

test_that("parallel run: the operation's call runs and returns invisibly NULL", {
	res <- withVisible(Z("edi_tuning_parallel_run_setting")("InferenceAllSimpleAverageDiff", "continuous", 30L, 1L, "bootstrap"))
	expect_null(res$value); expect_false(res$visible)
})

test_that("parallel run: 'unavailable operation' errors are swallowed, every other error propagates", {
	run <- function() Z("edi_tuning_parallel_run_setting")("InferenceAllSimpleAverageDiff", "continuous", 30L, 1L, "bootstrap")
	# "Exact inference is only supported for exact inference classes." matches the unavailable-operation pattern.
	pat <- Z("EDI_TUNING_UNAVAILABLE_OPERATION_ERROR_PATTERN")
	expect_true(grepl(pat, "Exact inference is only supported for exact inference classes."))
	with_op_spec(list(method = "compute_exact_two_sided_pval_for_treatment_effect", args = list(delta = 0)), {
		res <- withVisible(run())
		expect_null(res$value); expect_false(res$visible)                        # swallowed
	})
	# An unrelated failure (assertion on a bad argument) is not masked.
	with_op_spec(list(method = "compute_asymp_two_sided_pval", args = list(delta = "bad")), {
		expect_error(run())
		expect_false(grepl(pat, tryCatch(run(), error = function(e) conditionMessage(e))))
	})
	# Every documented phrase is recognised; ordinary R errors are not.
	for (msg in c("x is not implemented", "not supported for y", "only supported for z", "does not support w",
		"does not expose v", "Must be implemented by the subclass", "temporarily disabled")) expect_true(grepl(pat, msg), info = msg)
	expect_false(grepl(pat, "object 'x' not found"))
})
