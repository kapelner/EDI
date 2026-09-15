library(testthat)
library(EDI)

make_abstract_contract_design = function(n = 16L, seed = 951L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(0.4 * des$get_w() + rnorm(n))
	des
}

test_that("resampling draw contracts and distribution caches are operation scoped", {
	boot = EDI:::resampling_draw_contract("non_param_boot")
	expect_identical(boot$operation, "non_param_boot")
	expect_identical(boot$draw_type, "row_sample")
	expect_identical(boot$loader, "load_non_param_bootstrap_draw_into_worker")
	sub = EDI:::resampling_draw_contract("subsampling")
	expect_identical(sub$draw_type, "unit_subsample_without_replacement")
	expect_identical(sub$cache_name, "subsampling_distr_cache")
	expect_error(EDI:::resampling_draw_contract("permutation"), "Unknown resampling operation")

	cache = list()
	expect_null(EDI:::resampling_distribution_cache_get(cache, "non_param_boot", "a"))
	cache = EDI:::resampling_distribution_cache_ensure(cache, "non_param_boot")
	expect_true(is.list(cache$boot_distr_cache))
	cache = EDI:::resampling_distribution_cache_set(cache, "non_param_boot", "a", c(1, 2))
	expect_identical(EDI:::resampling_distribution_cache_get(cache, "non_param_boot", "a"), c(1, 2))
	expect_null(EDI:::resampling_distribution_cache_get(cache, "subsampling", "a"))
})

test_that("likelihood testing and information aliases normalize canonically", {
	inf = InferenceContinOLS$new(make_abstract_contract_design())
	p = inf$.__enclos_env__$private
	expect_identical(p$normalize_testing_type("LR"), "lik_ratio")
	expect_identical(p$normalize_testing_type("likelihood_ratio"), "lik_ratio")
	expect_identical(p$normalize_testing_type("BARTLETT_APPROX"), "lik_ratio_bartlett_approx")
	expect_identical(p$normalize_testing_type(c("score", "wald")), "score")
	expect_error(p$normalize_testing_type("permutation"), "testing_type must be one of")
	expect_identical(p$normalize_information_preference("obs"), "observed")
	expect_identical(p$normalize_information_preference("FISHER"), "fisher")
	expect_error(p$normalize_information_preference("sandwich"), "information_preference")

	expect_identical(inf$set_testing_type("lr"), inf)
	expect_identical(inf$get_testing_type(), "lik_ratio")
	expect_identical(inf$set_information_preference("obs"), inf)
	expect_identical(inf$get_information_preference(), "observed")
})

test_that("asymptotic, exact, and randomization abstract ladders expose stable APIs", {
	expect_true(all(c("compute_asymp_confidence_interval", "compute_asymp_two_sided_pval") %in%
		names(EDI:::InferenceAsymp$public_methods)))
	expect_true(all(c("set_testing_type", "set_information_preference", "compute_score_two_sided_pval") %in%
		names(EDI:::InferenceAsympLik$public_methods)))
	expect_true("compute_exact_two_sided_pval_for_treatment_effect" %in% names(EDI:::exact_test_public))
	expect_true("compute_rand_two_sided_pval" %in% names(EDI:::InferenceRand$public_methods))
	expect_true("compute_rand_confidence_interval" %in% names(EDI:::InferenceRandCI$public_methods))
})

test_that("component constructors validate names, dependencies, and overrides", {
	component = EDI:::InferenceComponent(
		name = "ContractProbe",
		file = "contract_probe.R",
		public = list(probe = function() 1),
		private = list(helper = function() 2),
		provides_public_methods = "probe"
	)
	expect_identical(component$name, "ContractProbe")
	expect_silent(EDI:::validate_inference_component(component))
	expect_identical(EDI:::component_public_names(component), "probe")
	expect_identical(EDI:::component_private_names(component), "helper")

	expect_error(EDI:::InferenceComponent(name = "", file = "x.R", public = list(), private = list()), "name")
	expect_error(EDI:::normalise_inference_overrides("probe"), "list")
	normal = EDI:::normalise_inference_overrides(list(public = "probe"))
	expect_identical(normal$public, "probe")
	expect_identical(normal$private, character())
})

test_that("custom inference extensions cache valid fits and reject malformed callbacks", {
	des = make_abstract_contract_design()
	ProbeCustomAsymp = R6::R6Class("ProbeCustomAsymp", inherit = EDI:::InferenceCustomAsymp,
		public = list(fit = function(estimate_only = FALSE) {
			list(estimate = 0.75, se = 0.25, df = 12)
		}), private = list(cached_mod = NULL))
	inf = ProbeCustomAsymp$new(des)
	expect_equal(inf$compute_estimate(), 0.75)
	expect_equal(as.numeric(inf$compute_asymp_confidence_interval()), 0.75 + qt(c(0.025, 0.975), 12) * 0.25)
	pval = inf$compute_asymp_two_sided_pval(0)
	expect_true(is.finite(pval) && pval >= 0 && pval <= 1)

	BadCustomAsymp = R6::R6Class("BadCustomAsymp", inherit = EDI:::InferenceCustomAsymp,
		public = list(fit = function(estimate_only = FALSE) 1))
	bad = BadCustomAsymp$new(des)
	expect_error(bad$compute_estimate(), "list")
})
