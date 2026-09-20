library(testthat)
library(EDI)

make_public_contract_logit_design <- function(seed = 1L, n = 100L){
	set.seed(seed)
	x = rnorm(n)
	w = rep(c(1, 0), length.out = n)
	des = DesignFixedTestFixture$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1L, plogis(-0.2 + 0.5 * w + 0.3 * x)))
	des
}

make_public_contract_poisson_inference <- function(seed = 1L, n = 100L){
	set.seed(seed)
	x = rnorm(n)
	w = rep(c(1, 0), length.out = n)
	des = DesignFixedTestFixture$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rpois(n, exp(0.2 + 0.4 * w + 0.2 * x)))
	InferenceCountPoisson$new(des, verbose = FALSE)
}

# A count-Poisson variant with no Fisher information: keeps the "explicit fisher
# preference is rejected" branch covered now that classes that DO have Fisher
# information accept "fisher" (get_supported_information_preferences_impl).
make_no_fisher_poisson_inference <- function(seed = 12L, n = 100L){
	set.seed(seed)
	x = rnorm(n)
	w = rep(c(1, 0), length.out = n)
	des = DesignFixedTestFixture$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rpois(n, exp(0.2 + 0.4 * w + 0.2 * x)))
	inf = InferenceCountPoisson$new(des, verbose = FALSE)
	# Override on the instance: a derived R6 class cannot add the private
	# fields this class family sets at runtime (locked private environment).
	priv = inf$.__enclos_env__$private
	if (bindingIsLocked("supports_fisher_information", priv)) unlockBinding("supports_fisher_information", priv)
	priv$supports_fisher_information = function() FALSE
	inf
}

make_constant_score_pval_logit_inference <- function(des){
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceIncidLogRegr = InferenceIncidLogRegr
	evalq({
		ConstantScorePvalLogit = R6Class(
			"ConstantScorePvalLogit",
			inherit = InferenceIncidLogRegr,
			private = list(
				get_likelihood_test_spec = function() list(j = 2L),
				get_memoized_likelihood_test_pval = function(...) 1
			)
		)
	}, envir = ext_env)
	ext_env$ConstantScorePvalLogit$new(des, verbose = FALSE)
}

make_no_likelihood_spec_logit_inference <- function(des){
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceIncidLogRegr = InferenceIncidLogRegr
	evalq({
		NoLikelihoodSpecLogit = R6Class(
			"NoLikelihoodSpecLogit",
			inherit = InferenceIncidLogRegr,
			private = list(
				get_likelihood_test_spec = function() NULL,
				compute_likelihood_test_two_sided_pval = function(delta, testing_type, bartlett_B = NULL){
					eval(body(EDI:::InferenceExtLikelihoodTestMemoization$private$compute_likelihood_test_two_sided_pval))
				}
			)
		)
	}, envir = ext_env)
	ext_env$NoLikelihoodSpecLogit$new(des, verbose = FALSE)
}

test_that("public score CI falls back to the Wald interval when inversion cannot bracket", {
	inf = make_constant_score_pval_logit_inference(make_public_contract_logit_design(seed = 11L))

	ci = inf$compute_score_confidence_interval(alpha = 0.1)
	wald_ci = inf$compute_wald_confidence_interval(alpha = 0.1)

	expect_true(all(is.finite(ci)))
	expect_equal(as.numeric(ci), as.numeric(wald_ci), tolerance = 1e-12)
	expect_false(inf$is_nonestimable("se"))
})

test_that("public information preferences select available score-test information", {
	inf = make_public_contract_poisson_inference(seed = 12L)

	inf$set_information_preference("observed")
	p_observed = inf$compute_score_two_sided_pval(delta = 0)
	expect_true(is.finite(p_observed))
	expect_equal(inf$get_information_source_used(), "observed")

	inf$set_information_preference("auto")
	p_auto = inf$compute_score_two_sided_pval(delta = 0.1)
	expect_true(is.finite(p_auto))
	expect_equal(inf$get_information_source_used(), "fisher")
	# Poisson has Fisher information, so an explicit "fisher" preference is
	# supported (previously only "auto" could reach it) and is the source used.
	expect_true("fisher" %in% inf$get_supported_information_preferences())
	inf$set_information_preference("fisher")
	p_fisher = inf$compute_score_two_sided_pval(delta = 0.1)
	expect_true(is.finite(p_fisher))
	expect_equal(inf$get_information_source_used(), "fisher")
	expect_error(inf$set_information_preference("invalid"), "information_preference must be one of")

	no_fisher = make_no_fisher_poisson_inference(seed = 12L)
	expect_false("fisher" %in% no_fisher$get_supported_information_preferences())
	no_fisher$set_information_preference("observed")
	expect_error(no_fisher$set_information_preference("fisher"), "does not support information_preference")
})

test_that("public likelihood tests report an unavailable specification as non-estimable", {
	inf = make_no_likelihood_spec_logit_inference(make_public_contract_logit_design(seed = 13L))

	p_value = inf$compute_score_two_sided_pval(delta = 0)

	expect_true(is.na(p_value))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "likelihood_test_spec_unavailable")
})

make_no_likelihood_spec_std_mod_cache_logit_inference <- function(des){
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceIncidLogRegr = InferenceIncidLogRegr
	evalq({
		NoLikelihoodSpecStdModCacheLogit = R6Class(
			"NoLikelihoodSpecStdModCacheLogit",
			inherit = InferenceIncidLogRegr,
			private = list(
				get_likelihood_test_spec = function() NULL
			)
		)
	}, envir = ext_env)
	ext_env$NoLikelihoodSpecStdModCacheLogit$new(des, verbose = FALSE)
}

make_likelihood_tests_unsupported_logit_inference <- function(des){
	ext_env = new.env(parent = globalenv())
	ext_env$R6Class = R6::R6Class
	ext_env$InferenceIncidLogRegr = InferenceIncidLogRegr
	evalq({
		LikelihoodTestsUnsupportedLogit = R6Class(
			"LikelihoodTestsUnsupportedLogit",
			inherit = InferenceIncidLogRegr,
			private = list(
				supports_likelihood_tests = function() FALSE,
				get_likelihood_test_spec = function() NULL
			)
		)
	}, envir = ext_env)
	ext_env$LikelihoodTestsUnsupportedLogit$new(des, verbose = FALSE)
}

test_that("StandardModelCache likelihood tests report an unavailable specification as non-estimable when the class supports likelihood tests but this fit's spec is unavailable", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# InferenceSurvivalCoxPHRegr and InferenceSurvivalDepCensTransformRegr
	# (both composing StandardModelCacheSource) were calling stop() here
	# whenever THIS fit's own get_likelihood_test_spec() returned NULL (e.g.
	# generate_mod() failed on a given resample), even though the class
	# itself supports likelihood tests in general. That surfaced as hard
	# errors on compute_lik_ratio/score/gradient_two_sided_pval instead of
	# the graceful non-estimable NA every other failure mode in this package
	# already produces.
	inf = make_no_likelihood_spec_std_mod_cache_logit_inference(make_public_contract_logit_design(seed = 14L))

	p_value = inf$compute_score_two_sided_pval(delta = 0)

	expect_true(is.na(p_value))
	expect_true(inf$is_nonestimable("estimate"))
	expect_equal(inf$get_nonestimable_reason(), "likelihood_test_spec_unavailable")
})

test_that("StandardModelCache likelihood tests still hard-stop when the class does not support likelihood tests at all", {
	# The hard stop is preserved for a testing_type the class never
	# advertises (supports_likelihood_tests() hard-FALSE, e.g.
	# InferenceSurvivalCoxPHRegr with use_rcpp = FALSE) -- that is a caller
	# error, not a per-fit failure, and should not be silently swallowed.
	inf = make_likelihood_tests_unsupported_logit_inference(make_public_contract_logit_design(seed = 15L))

	expect_error(
		inf$compute_score_two_sided_pval(delta = 0),
		"does not expose a likelihood-test specification"
	)
})
