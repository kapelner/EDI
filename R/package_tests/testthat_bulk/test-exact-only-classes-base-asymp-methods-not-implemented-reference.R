library(testthat)
library(EDI)

# Inference's base compute_asymp_two_sided_pval()/compute_asymp_confidence_interval() default implementations
# (inference_all_abstract.R): "Asymptotic inference is not implemented for this inference class." -- reached by
# any concrete class that never overrides these two methods, i.e. every exact-only class. Confirmed by source
# inspection that InferenceIncidExactFisher and InferenceIncidExactZhang define no override of either method, so
# calling them on a real instance falls straight through to this base default. Neither class had a test calling
# either method (their own compute_exact_two_sided_pval_for_treatment_effect()/compute_exact_confidence_interval()
# are covered elsewhere, but those are different method names).

test_that("InferenceIncidExactFisher: the base asymp methods are unimplemented and error with the documented message", {
	set.seed(2); n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.2 + 0.9 * w)); des$add_all_subject_responses(y)
	inf <- InferenceIncidExactFisher$new(des, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(0), "Asymptotic inference is not implemented for this inference class\\.")
	expect_error(inf$compute_asymp_confidence_interval(0.05), "Asymptotic inference is not implemented for this inference class\\.")
	# the exact API on the same object works fine -- the class just has no asymptotic path
	expect_true(is.finite(inf$compute_exact_two_sided_pval_for_treatment_effect(0)))
})

test_that("InferenceIncidExactZhang: the base asymp methods are unimplemented and error with the documented message", {
	set.seed(321); n <- 24L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	treatment <- des$.__enclos_env__$private$w
	prob <- plogis(-0.2 + 0.8 * treatment)
	for (i in seq_len(n)) des$add_one_subject_response(i, rbinom(1, 1, prob[i]))
	inf <- InferenceIncidExactZhang$new(des, verbose = FALSE)
	expect_error(inf$compute_asymp_two_sided_pval(0), "Asymptotic inference is not implemented for this inference class\\.")
	expect_error(inf$compute_asymp_confidence_interval(0.05), "Asymptotic inference is not implemented for this inference class\\.")
})

test_that("an ordinary asymptotic-capable class does NOT trip this base default", {
	set.seed(1); n <- 30L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval(0)))
	expect_true(all(is.finite(inf$compute_asymp_confidence_interval(0.05))))
})
