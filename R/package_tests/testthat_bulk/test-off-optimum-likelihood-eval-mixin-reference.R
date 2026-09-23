library(testthat)
library(EDI)

# InferenceMixinOffOptimumLikelihoodEval (inference_mixin_off_optimum_likelihood_eval.R) had no test
# reference anywhere -- confirmed via a fresh repo-wide private-method scan. Its own header comment
# says no concrete class currently splices it in (opt-in only, for a future Firth/Jeffreys-penalty or
# profile-likelihood consumer that supplies neg_loglik_at()/information_at() in its
# get_likelihood_test_spec()), so it is tested here directly and standalone, using a minimal R6 probe
# class that splices `private = c(Mixin$private, list(get_likelihood_test_spec = ..., get_default_
# information_source = ...))` exactly as the file's own splice-in instructions document.
#   1. supports_off_optimum_likelihood_eval() is TRUE only when the spec supplies BOTH neg_loglik_at
#      and information_at as functions; FALSE if either is missing, non-function, or the spec is NULL.
#   2. evaluate_neg_loglik_at() delegates to spec$neg_loglik_at(theta); errors with the class name in
#      the message when the spec doesn't support it.
#   3. evaluate_information_at()'s source = "auto" resolves via get_default_information_source(),
#      with a "legacy" result mapped to "observed" before being passed through; an explicit source is
#      passed straight through without consulting get_default_information_source() at all.
#   4. evaluate_penalized_neg_loglik_at() combines both evaluators into
#      neg_loglik(theta) + 0.5*log|I(theta)|, matching an independently hand-computed reference value,
#      and returns Inf (not an error) for a singular or otherwise non-finite-log-determinant
#      information matrix.

Mixin <- EDI:::InferenceMixinOffOptimumLikelihoodEval

# R6 rebinds every private method's closure environment to the instance's own enclosing environment
# at construction time, so a method can't close over a `spec` argument local to this factory function
# -- it must read from private DATA FIELDS instead (exactly how a real consumer class would store its
# own get_likelihood_test_spec() state), and function-valued fields are individually lockBinding()'d
# by R6 after construction, so a call-counter is tracked via a plain integer field instead of by
# swapping in a new closure.
Probe <- R6::R6Class("OffOptimumProbe",
	private = c(Mixin$private, list(
		test_spec = NULL,
		test_default_source_value = "fisher",
		test_default_source_calls = 0L,
		get_likelihood_test_spec = function() private$test_spec,
		get_default_information_source = function() {
			private$test_default_source_calls <- private$test_default_source_calls + 1L
			private$test_default_source_value
		}
	)),
	parent_env = asNamespace("EDI")
)

make_probe <- function(spec, default_source_value = "fisher") {
	p <- Probe$new()
	priv <- p$.__enclos_env__$private
	priv$test_spec <- spec
	priv$test_default_source_value <- default_source_value
	p
}

test_that("supports_off_optimum_likelihood_eval() is TRUE only when the spec has both evaluator functions", {
	full_spec <- list(neg_loglik_at = function(theta) sum(theta^2), information_at = function(theta, source) diag(2))
	p <- make_probe(full_spec)$.__enclos_env__$private
	expect_true(p$supports_off_optimum_likelihood_eval())
	expect_true(p$supports_off_optimum_likelihood_eval(spec = full_spec))            # explicit spec bypasses get_likelihood_test_spec()

	no_info <- make_probe(list(neg_loglik_at = function(theta) sum(theta^2)))$.__enclos_env__$private
	expect_false(no_info$supports_off_optimum_likelihood_eval())

	no_ll <- make_probe(list(information_at = function(theta, source) diag(2)))$.__enclos_env__$private
	expect_false(no_ll$supports_off_optimum_likelihood_eval())

	non_function <- make_probe(list(neg_loglik_at = "not a function", information_at = function(theta, source) diag(2)))$.__enclos_env__$private
	expect_false(non_function$supports_off_optimum_likelihood_eval())

	null_spec <- make_probe(NULL)$.__enclos_env__$private
	expect_false(null_spec$supports_off_optimum_likelihood_eval())
})

test_that("evaluate_neg_loglik_at() delegates to spec$neg_loglik_at(theta) and errors with the class name when unsupported", {
	spec <- list(neg_loglik_at = function(theta) sum((theta - c(1, 2))^2), information_at = function(theta, source) diag(2))
	p <- make_probe(spec)$.__enclos_env__$private
	expect_equal(p$evaluate_neg_loglik_at(c(3, 5)), sum((c(3, 5) - c(1, 2))^2))

	unsupported <- make_probe(list(information_at = function(theta, source) diag(2)))$.__enclos_env__$private
	expect_error(unsupported$evaluate_neg_loglik_at(c(0, 0)), "OffOptimumProbe.*does not support off-optimum negative log-likelihood")
})

test_that("evaluate_information_at(): source = \"auto\" resolves via get_default_information_source(), \"legacy\" maps to \"observed\"; an explicit source bypasses that resolution entirely", {
	captured <- NULL
	spec <- list(neg_loglik_at = function(theta) 0, information_at = function(theta, source) { captured <<- source; diag(2) })

	p_fisher_obj <- make_probe(spec, default_source_value = "fisher")
	p_fisher <- p_fisher_obj$.__enclos_env__$private
	p_fisher$evaluate_information_at(c(0, 0))
	expect_equal(captured, "fisher")
	expect_equal(p_fisher$test_default_source_calls, 1L)

	p_legacy <- make_probe(spec, default_source_value = "legacy")$.__enclos_env__$private
	p_legacy$evaluate_information_at(c(0, 0))
	expect_equal(captured, "observed")                                             # "legacy" -> "observed" remap

	p_explicit_obj <- make_probe(spec, default_source_value = "fisher")
	p_explicit <- p_explicit_obj$.__enclos_env__$private
	p_explicit$evaluate_information_at(c(0, 0), source = "observed")
	expect_equal(captured, "observed")
	expect_equal(p_explicit$test_default_source_calls, 0L)                        # explicit source never consults get_default_information_source()

	unsupported <- make_probe(list(neg_loglik_at = function(theta) 0))$.__enclos_env__$private
	expect_error(unsupported$evaluate_information_at(c(0, 0)), "OffOptimumProbe.*does not support off-optimum information-matrix")
})

test_that("evaluate_penalized_neg_loglik_at() matches an independently hand-computed neg_loglik + 0.5*log|I|, and returns Inf (not an error) for a singular/non-finite-log-det information matrix", {
	theta0 <- c(3, -1)
	info_mat <- matrix(c(4, 1, 1, 6), 2, 2)
	spec <- list(
		neg_loglik_at = function(theta) sum((theta - c(1, 2))^2),
		information_at = function(theta, source) info_mat
	)
	p <- make_probe(spec)$.__enclos_env__$private
	ref <- sum((theta0 - c(1, 2))^2) + 0.5 * log(det(info_mat))
	expect_equal(p$evaluate_penalized_neg_loglik_at(theta0), ref, tolerance = 1e-10)

	singular_spec <- list(neg_loglik_at = function(theta) sum(theta^2), information_at = function(theta, source) matrix(0, 2, 2))
	p_singular <- make_probe(singular_spec)$.__enclos_env__$private
	expect_equal(p_singular$evaluate_penalized_neg_loglik_at(theta0), Inf)

	nonfinite_spec <- list(neg_loglik_at = function(theta) sum(theta^2), information_at = function(theta, source) matrix(c(NaN, 0, 0, 1), 2, 2))
	p_nonfinite <- make_probe(nonfinite_spec)$.__enclos_env__$private
	expect_equal(p_nonfinite$evaluate_penalized_neg_loglik_at(theta0), Inf)
})
