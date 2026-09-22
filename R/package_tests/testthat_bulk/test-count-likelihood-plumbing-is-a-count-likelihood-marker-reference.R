library(testthat)
library(EDI)

# contracts_mixins.R's CountLikelihoodPlumbing component (source: inference_all_abstract_
# count_likelihood.R's CountLikelihoodPlumbingSource) declares a private is_a_count_likelihood()
# type-marker predicate (always TRUE), spliced into every concrete count-response class that
# composes the component (InferenceCountPoisson, InferenceCountNegBin, InferenceCountQuasiPoisson,
# InferenceCountRobustPoisson, etc.) via provides_private_methods. It has zero callers anywhere in
# the package source (confirmed via repo-wide grep) -- the same purely declarative-contract pattern
# as is_a_glmm_family/is_a_kk_cond_logit_glmm/is_a_count_zero_augmented_poisson covered separately
# this session -- and had zero test references despite the host classes being otherwise
# well-tested via their public behavior. The legacy R6 ladder class this source used to also feed
# (InferenceCountLikelihood) has zero remaining concrete inheritors (per the file's own header
# comment, fix_inference_hierarchy.md "Static Cleanup" 2026-08-23), so only the component-composed
# path is a genuine reachable target.

make_count_fixture = function(cls_name, seed = 1L, n = 30L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	X = data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(stats::rpois(n, exp(0.5 + 0.5 * w)))
	get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
}

test_that("InferenceCountPoisson's is_a_count_likelihood() exists, is callable, and returns TRUE", {
	inf = make_count_fixture("InferenceCountPoisson", seed = 1L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_count_likelihood))
	expect_identical(priv$is_a_count_likelihood(), TRUE)
})

test_that("InferenceCountNegBin's is_a_count_likelihood() exists, is callable, and returns TRUE", {
	inf = make_count_fixture("InferenceCountNegBin", seed = 2L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_count_likelihood))
	expect_identical(priv$is_a_count_likelihood(), TRUE)
})

test_that("a non-count class does not expose the is_a_count_likelihood marker", {
	set.seed(3L); n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	X = data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf = InferenceContinLin$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	expect_null(priv$is_a_count_likelihood)
})
