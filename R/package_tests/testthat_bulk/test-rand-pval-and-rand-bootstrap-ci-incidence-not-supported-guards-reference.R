library(testthat)
library(EDI)

# Two sibling incidence-response guards in the randomization-inference mixins:
#
# 1. inference_all_abstract_rand.R's compute_rand_two_sided_pval() stop()s "Randomization tests are
#    not supported for incidence. Use Zhang method." exactly when supports_rand_pval_for_incidence()
#    is FALSE -- i.e. an incidence-response instance whose design is NOT Zhang-eligible (not
#    Bernoulli, no matched-pair structure) and NOT eligible for design-randomization-based incidence
#    inference (randomization_family() != "rerandomization"). A Zhang-eligible incidence design (e.g.
#    Bernoulli or matched-pair) instead silently dispatches to the Zhang exact-combined test and
#    never reaches this stop() -- that escape hatch is already covered elsewhere. The non-eligible
#    path (e.g. DesignSeqOneByOneUrn, a covariate-adaptive urn design with neither Bernoulli
#    randomization nor matching) had zero test references for this exact message anywhere.
#
# 2. inference_all_abstract_rand_bootstrap_ci.R's compute_rand_bootstrap_confidence_interval() has a
#    simpler, unconditional incidence guard (no Zhang escape hatch on this CI-side method) -- ANY
#    incidence-response instance with no custom randomization statistic function stop()s "Bootstrap
#    randomization confidence intervals are not supported for incidence.", even for an otherwise
#    Zhang-eligible Bernoulli design. Also had zero test references anywhere.

test_that("compute_rand_two_sided_pval(): a non-Zhang-eligible incidence design (urn) errors with the documented message", {
	set.seed(1)
	n <- 20
	des <- DesignSeqOneByOneUrn$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)

	expect_false(inf$supports_rand_pval_for_incidence())
	expect_error(
		inf$compute_rand_two_sided_pval(r = 50, show_progress = FALSE),
		"Randomization tests are not supported for incidence\\. Use Zhang method\\."
	)
})

test_that("compute_rand_two_sided_pval(): a Zhang-eligible incidence design (Bernoulli) does NOT error and reports supports = TRUE", {
	set.seed(2)
	n <- 20
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)

	expect_true(inf$supports_rand_pval_for_incidence())
	pv <- inf$compute_rand_two_sided_pval(r = 50, show_progress = FALSE)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})

test_that("compute_rand_bootstrap_confidence_interval(): ANY incidence-response instance errors with the documented message, even a Zhang-eligible Bernoulli design", {
	set.seed(3)
	n <- 20
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidRiskDiff$new(des, verbose = FALSE)

	expect_error(
		inf$compute_rand_bootstrap_confidence_interval(B = 50, show_progress = FALSE),
		"Bootstrap randomization confidence intervals are not supported for incidence\\."
	)

	set.seed(4)
	des2 <- DesignSeqOneByOneUrn$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des2$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf2 <- InferenceIncidRiskDiff$new(des2, verbose = FALSE)
	expect_error(
		inf2$compute_rand_bootstrap_confidence_interval(B = 50, show_progress = FALSE),
		"Bootstrap randomization confidence intervals are not supported for incidence\\."
	)
})

test_that("compute_rand_bootstrap_confidence_interval(): a continuous-response instance does NOT error", {
	set.seed(5)
	n <- 20
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(des, verbose = FALSE)
	expect_no_error(inf$compute_rand_bootstrap_confidence_interval(B = 50, show_progress = FALSE))
})
