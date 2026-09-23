library(testthat)
library(EDI)

# InferenceOrdinalJonckheereTerpstraTest$compute_asymptotic_jt_components()
# (inference_ordinal_jonckheere_terpstra_test.R) caches "jt_empty_treatment_arm" when either the
# treatment or control arm is empty (n_treat == 0 || n_control == 0), checked before any J-T
# statistic computation. This had no test reference anywhere. Reached by directly overwriting
# private$w to an all-control (or all-treatment) vector post-construction (unlockBinding), the same
# private-state-injection technique already used elsewhere in this suite -- a real design/response
# fixture is still constructed first (an empty arm generally can't be produced by a normal random
# design assignment), so only this specific degenerate downstream state is synthetic.

test_that("an all-control assignment ('no treatment arm') is nonestimable ('jt_empty_treatment_arm')", {
	set.seed(1); n <- 20L
	des <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	inf <- InferenceOrdinalJonckheereTerpstraTest$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("w", p)
	p$w <- rep(0, n)

	p$compute_asymptotic_jt_components(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "jt_empty_treatment_arm")
	expect_true(is.na(p$cached_values$beta_hat_T))
})

test_that("an all-treatment assignment ('no control arm') is nonestimable the same way", {
	set.seed(2); n <- 20L
	des <- DesignFixedBernoulli$new(response_type = "ordinal", n = n, seed = 2L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))

	inf <- InferenceOrdinalJonckheereTerpstraTest$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	unlockBinding("w", p)
	p$w <- rep(1, n)

	p$compute_asymptotic_jt_components(estimate_only = TRUE)
	expect_identical(inf$get_nonestimable_reason(), "jt_empty_treatment_arm")
})
