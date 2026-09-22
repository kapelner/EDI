library(testthat)
library(EDI)

# Follow-up to test-wald-component-is-a-asymp-marker-reference.R's methodology correction: the
# "RandomizationCI" component (contracts_mixins.R) sources from the legacy InferenceRandCI R6
# generator (source_name = "InferenceRandCI", file inference_all_abstract_rand_ci.R) with no
# explicit provides_private_methods override, so inference_component_source_parts() splices ALL
# of InferenceRandCI's private methods -- including its is_a_rand_ci() type-marker predicate --
# into any class composing "RandomizationCI" directly (InferenceCustomRand) or transitively via a
# dependency (NonparametricBootstrap declares dependencies = "RandomizationCI", so virtually every
# class with bootstrap support gets it too, e.g. InferenceContinLin). No concrete class uses
# classic `inherit = InferenceRandCI` R6 inheritance anymore (that check alone would wrongly
# suggest this is dead code, same trap as is_a_asymp earlier). Zero callers of is_a_rand_ci()
# anywhere in the source (a purely declarative contract) and zero test references anywhere.
# inference_all_abstract_rand_ci.R itself is untouched by the concurrent worktree/diagnostics work
# this session has been avoiding (distinct from inference_all_abstract_rand.R, which is touched).

test_that("InferenceContinLin's is_a_rand_ci() (spliced from InferenceRandCI transitively via NonparametricBootstrap's dependency on RandomizationCI) exists, is callable, and returns TRUE", {
	set.seed(1); n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	X = data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf = InferenceContinLin$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_rand_ci))
	expect_identical(priv$is_a_rand_ci(), TRUE)
})

test_that("InferenceCustomRand's is_a_rand_ci() (spliced from directly composing the RandomizationCI component) exists, is callable, and returns TRUE", {
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceCustomRand = getFromNamespace("InferenceCustomRand", "EDI")
	ext_env$fit_fn = function(estimate_only) list(estimate = 1)
	eval(quote({
		Cls = R6Class("Cls", inherit = InferenceCustomRand, lock_objects = FALSE,
			public = list(fit = function(estimate_only = FALSE) fit_fn(estimate_only)))
	}), envir = ext_env)

	des = DesignFixedBernoulli$new(n = 10, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(10)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = 5))
	des$add_all_subject_responses(1:10)
	inf = ext_env$Cls$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_rand_ci))
	expect_identical(priv$is_a_rand_ci(), TRUE)
})
