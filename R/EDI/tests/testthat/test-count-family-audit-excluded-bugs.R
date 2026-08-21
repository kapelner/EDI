library(testthat)
library(EDI)

# Regression tests for the four "pre-existing bugs" that
# test-design-inference-introspection-audit.R originally had to allowlist
# away (2026-08-21). Each is pinned here so the audit's allowlist could be
# removed without the audit perpetually failing.

make_nonkk_count_design = function(n = 24L, seed = 1000L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "count", prob_T = 0.5, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.2 * des$get_w() + 0.5)))
	des
}

test_that("InferenceCountHurdlePoisson / ZeroInflatedPoisson / ZeroInflatedNegBin construct on a plain count design", {
	des = make_nonkk_count_design()
	expect_no_error(InferenceCountHurdlePoisson$new(des))
	expect_no_error(InferenceCountHurdlePoisson$new(des, model_formula_hurdle = ~ x1))
	expect_no_error(InferenceCountZeroInflatedPoisson$new(des))
	expect_no_error(InferenceCountZeroInflatedNegBin$new(des))
})

test_that("InferenceCountKKHurdlePoissonOneLik refuses a non-KK design, matching its registry inapplicability", {
	des = make_nonkk_count_design()
	expect_false("InferenceCountKKHurdlePoissonOneLik" %in% des$applicable_inference_class_names())
	expect_error(InferenceCountKKHurdlePoissonOneLik$new(des), "requires a KK matching")
})

test_that("InferenceIncidCMH: realized-imbalance warning fires once at SE time, not at construction", {
	set.seed(7L)
	n = 21L # odd n: realized allocation can never be exactly balanced
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf = NULL
	expect_no_warning(inf <- InferenceIncidCMH$new(des, se_est_num_vectors = 200L))
	expect_no_warning(inf$compute_estimate())
	expect_warning(inf$compute_asymp_confidence_interval(), "not exactly balanced")
	# already warned: subsequent SE-dependent calls are silent
	expect_no_warning(inf$compute_asymp_two_sided_pval())
})
