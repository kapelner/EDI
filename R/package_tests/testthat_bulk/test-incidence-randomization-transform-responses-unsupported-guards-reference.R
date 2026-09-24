library(testthat)
library(EDI)

# Two sibling compute_rand_two_sided_pval() overrides -- InferenceRandCI's own (inference_all_
# abstract_rand_ci.R, composed into most incidence classes with a randomization-test capability) and
# the KK-GEE shared mixin's own (inference_mixin_kk_gee_shared.R, composed into InferenceIncidKKGEE
# and its siblings) -- each guard identically: whenever private$should_use_zhang_incidence_
# randomization() is TRUE (incidence response, no custom randomization statistic, and a Bernoulli or
# matched-structure design -- the condition under which the class dispatches to Zhang's exact combined
# randomization test instead of a Monte-Carlo permutation distribution), a transform_responses value
# other than "none" is rejected: "transform_responses is not supported for incidence randomization
# inference." (Zhang's exact test has no response-transformation concept.) A codebase-wide grep
# confirmed this exact message had zero test references anywhere, despite the classes exercising each
# call site (InferenceIncidLogRegr, InferenceIncidKKGEE) being otherwise heavily tested elsewhere.

test_that("InferenceIncidLogRegr (via InferenceRandCI's own guard) rejects a non-'none' transform_responses under Zhang-eligible conditions", {
	set.seed(1L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())
	expect_error(
		inf$compute_rand_two_sided_pval(r = 50L, transform_responses = "log", show_progress = FALSE),
		"transform_responses is not supported for incidence randomization inference.",
		fixed = TRUE
	)
})

test_that("InferenceIncidKKGEE (via the KK-GEE shared mixin's own copy of the guard) rejects a non-'none' transform_responses under Zhang-eligible conditions", {
	set.seed(2L); n <- 20L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))

	inf <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization())
	expect_error(
		inf$compute_rand_two_sided_pval(r = 50L, transform_responses = "log", show_progress = FALSE),
		"transform_responses is not supported for incidence randomization inference.",
		fixed = TRUE
	)
})

test_that("transform_responses = 'none' (the default) never triggers either guard", {
	set.seed(3L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	expect_no_error(inf$compute_rand_two_sided_pval(r = 50L, show_progress = FALSE))
})
