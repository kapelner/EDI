library(testthat)
library(EDI)

# InferenceRandTest$compute_rand_two_sided_pval() (inference_all_abstract_rand.R:262-268)
# guards on self$supports_rand_pval_for_incidence(): FALSE only for an incidence-response
# design that is NOT Zhang-eligible (should_use_zhang_incidence_randomization() -- Bernoulli
# or matched-pair, with no custom randomization statistic) AND does not use design-native
# randomization for incidence (should_use_design_randomization_for_incidence() -- the
# design's randomization_family() isn't "rerandomization"). A biased-coin sequential design
# (DesignSeqOneByOneEfron) is neither Bernoulli, matched, nor rerandomization-family, so it
# falls through to the plain permutation path, which genuinely can't handle incidence
# responses -- hence the documented refusal "Randomization tests are not supported for
# incidence. Use Zhang method." A codebase-wide grep confirmed this exact message had zero
# test references anywhere, even though its sibling supports_rand_pval_for_incidence()
# predicate and the analogous compute_rand_confidence_interval() Zhang-dispatch machinery
# are well covered elsewhere. Exercised via the plain public API, no mocking needed.

test_that("supports_rand_pval_for_incidence() is FALSE for a non-Bernoulli, non-matched, non-rerandomization incidence design", {
	set.seed(1)
	n <- 20L
	des <- DesignSeqOneByOneEfron$new(response_type = "incidence", n = n, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)

	expect_false(inf$supports_rand_pval_for_incidence())
})

test_that("compute_rand_two_sided_pval() refuses with the documented 'use Zhang method' message on such a design", {
	set.seed(2)
	n <- 20L
	des <- DesignSeqOneByOneEfron$new(response_type = "incidence", n = n, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_two_sided_pval(r = 21L, show_progress = FALSE),
		"Randomization tests are not supported for incidence. Use Zhang method.",
		fixed = TRUE
	)
})
