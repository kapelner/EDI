library(testthat)
library(EDI)

# contracts_mixins.R's "Wald" component sources from the legacy InferenceAsymp R6 generator
# (source_name = "InferenceAsymp"): since it declares no explicit provides_private_methods
# override, inference_component_source_parts() defaults to splicing EVERY one of InferenceAsymp's
# private methods -- including its is_a_asymp() type-marker predicate -- into any modern class
# composing "Wald" (i.e. nearly every asymptotic-tier class in the package). This was initially
# mistaken for unreachable dead code earlier this session, because no concrete class file uses
# classic `inherit = InferenceAsymp` R6 inheritance anymore (grep-verified); that check misses the
# separate modern component-splicing path, which IS how every real class actually picks it up.
# Confirmed reachable by direct probe on real classes before writing this. Zero callers of
# is_a_asymp() anywhere in the source (it's a purely declarative contract, like the other is_a_*
# markers covered elsewhere this session) and zero test references anywhere.

make_asymp_fixture = function(cls_name, response_type, seed = 1L, n = 20L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	X = data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = switch(response_type,
		continuous = rnorm(n),
		incidence = rbinom(n, 1, plogis(0.3 * w))
	)
	des$add_all_subject_responses(y)
	get(cls_name, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
}

test_that("InferenceContinLin's is_a_asymp() (spliced from InferenceAsymp via the Wald component) exists, is callable, and returns TRUE", {
	inf = make_asymp_fixture("InferenceContinLin", "continuous", seed = 1L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_asymp))
	expect_identical(priv$is_a_asymp(), TRUE)
})

test_that("InferenceIncidLogRegr's is_a_asymp() (spliced from the same Wald component) exists, is callable, and returns TRUE", {
	inf = make_asymp_fixture("InferenceIncidLogRegr", "incidence", seed = 2L)
	priv = inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_asymp))
	expect_identical(priv$is_a_asymp(), TRUE)
})
