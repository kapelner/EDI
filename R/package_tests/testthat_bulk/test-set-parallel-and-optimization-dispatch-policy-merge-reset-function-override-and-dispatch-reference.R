library(testthat)
library(EDI)

# set_parallel_dispatch_policy(policy, reset) and set_optimization_dispatch_policy(policy, reset) plus the dispatch
# lookups they drive (edi_parallel_dispatch_policy / edi_optimization_dispatch_policy). Reference: hand-specified
# merges. Defaults are restored on exit with reset = TRUE.

Z <- function(x) get(x, envir = asNamespace("EDI"))
disp <- Z("edi_parallel_dispatch_policy")
withr::defer({ set_parallel_dispatch_policy(reset = TRUE); set_optimization_dispatch_policy(reset = TRUE) }, teardown_env())

test_that("reset restores the built-in defaults and returns them invisibly", {
	set_parallel_dispatch_policy(list(bootstrap = list(serial_response_types = "count")))
	r <- withVisible(set_parallel_dispatch_policy(reset = TRUE))
	expect_false(r$visible)
	expect_identical(r$value, get_parallel_dispatch_policy())
	expect_identical(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial, FALSE)
})

test_that("with no arguments it returns the current configuration without changing it", {
	set_parallel_dispatch_policy(reset = TRUE)
	r <- withVisible(set_parallel_dispatch_policy())
	expect_false(r$visible); expect_identical(r$value, get_parallel_dispatch_policy())
	expect_identical(set_parallel_dispatch_policy(), r$value)
})

test_that("default policy forces incidence and survival-non-KK bootstraps serial, others not", {
	set_parallel_dispatch_policy(reset = TRUE)
	expect_true(disp("InferenceIncidLogRegr", "incidence", "bootstrap")$force_serial)
	expect_true(disp("InferenceSurvivalCoxPHRegr", "survival", "bootstrap")$force_serial)
	expect_false(disp("InferenceSurvivalKKGeneric", "survival", "bootstrap")$force_serial)
	expect_false(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial)
	d <- disp("InferenceIncidLogRegr", "incidence", "bootstrap")
	expect_match(d$reason, "bootstrap is forced serial by benchmark policy")
	expect_true(disp("InferenceIncidLogRegr", "incidence", "rand_ci")$force_serial)
	expect_match(disp("InferenceIncidLogRegr", "incidence", "rand_ci")$reason, "randomization confidence intervals")
	expect_false(disp("InferenceCountPoisson", "count", "rand_ci")$force_serial)
	expect_false(disp("InferenceIncidLogRegr", "incidence", "jackknife")$force_serial)     # unknown operation: never forced
})

test_that("a named-list policy is merged per section via modifyList; other sections are untouched", {
	set_parallel_dispatch_policy(reset = TRUE)
	base <- get_parallel_dispatch_policy()
	expect_null(set_parallel_dispatch_policy(list(bootstrap = list(serial_response_types = c("count", "incidence")))))
	expect_true(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial)
	expect_true(disp("InferenceCountPoisson", "count", "bootstrap")$reason == "bootstrap is forced serial by benchmark policy")
	# the sibling field within the section survives the merge, and rand_ci is untouched
	expect_true(disp("InferenceIncidLogRegr", "continuous", "bootstrap")$force_serial)
	expect_false(disp("InferenceCountPoisson", "count", "rand_ci")$force_serial)
	set_parallel_dispatch_policy(reset = TRUE)
	expect_false(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial)
})

test_that("invalid policies are rejected: unknown section, non-list section, unnamed list, bad reset flag", {
	set_parallel_dispatch_policy(reset = TRUE)
	expect_error(set_parallel_dispatch_policy(list(nonsense = list())), "Unknown policy section: nonsense")
	expect_error(set_parallel_dispatch_policy(list(bootstrap = "x")), "Policy section 'bootstrap' must be a list")
	expect_error(set_parallel_dispatch_policy(list(1, 2)))
	expect_error(set_parallel_dispatch_policy(reset = "yes"))
})

test_that("a function policy is used as an override for every dispatch until reset", {
	fn <- function(inference_class, response_type, operation) list(force_serial = TRUE, reason = paste("custom", operation))
	expect_null(set_parallel_dispatch_policy(fn))
	expect_identical(disp("InferenceCountPoisson", "count", "bootstrap")$reason, "custom bootstrap")
	expect_true(disp("Whatever", "continuous", "rand_ci")$force_serial)
	# a later list policy clears the function override
	set_parallel_dispatch_policy(list(bootstrap = list(serial_response_types = character(0))))
	expect_false(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial)
	set_parallel_dispatch_policy(fn); set_parallel_dispatch_policy(reset = TRUE)
	expect_false(disp("InferenceCountPoisson", "count", "bootstrap")$force_serial)
})

test_that("optimization policy: query/reset/merge semantics and the dispatch table it drives", {
	set_optimization_dispatch_policy(reset = TRUE)
	base <- get_optimization_dispatch_policy()
	r <- withVisible(set_optimization_dispatch_policy()); expect_false(r$visible); expect_identical(r$value, base)
	expect_null(set_optimization_dispatch_policy(list(default_alg = "lbfgs")))
	expect_identical(Z("edi_optimization_dispatch_policy")("InferenceSomethingUnlisted"), "lbfgs")
	cur <- set_optimization_dispatch_policy()
	expect_identical(cur$default_alg, "lbfgs")
	expect_identical(cur$inference_class_overrides, base$inference_class_overrides)     # untouched field survives the merge
	set_optimization_dispatch_policy(list(inference_class_overrides = c("^InferenceZzTest$" = "irls")))
	expect_identical(Z("edi_optimization_dispatch_policy")("InferenceZzTest"), "irls")
	expect_identical(set_optimization_dispatch_policy(reset = TRUE), base)
	expect_identical(Z("edi_optimization_dispatch_policy")("InferenceZzTest"), Z("edi_optimization_dispatch_policy")("InferenceSomethingUnlisted"))
	expect_error(set_optimization_dispatch_policy(list(1)))
	expect_error(set_optimization_dispatch_policy(reset = NA))
})
