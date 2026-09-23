library(testthat)
library(EDI)

# inference_all_abstract.R's base Inference class has two sibling exact-inference stubs --
# compute_exact_two_sided_pval_for_treatment_effect() and compute_exact_confidence_interval() -- both
# stop() "Exact inference is only supported for exact inference classes." Concrete non-exact classes
# (the overwhelming majority of the package, e.g. InferenceContinLin) never override these, so the
# stub is reached directly through the public API of any well-tested ordinary class. Distinct from
# the already-covered "Asymptotic inference is not implemented for this inference class." sibling
# stubs on the same class (test-exact-only-classes-base-asymp-methods-not-implemented-reference.R --
# note that file's name is about the asymp stubs on EXACT-only classes, the mirror-image gap of this
# one). Zero test references anywhere for the exact-stub message.

test_that("compute_exact_two_sided_pval_for_treatment_effect(): a non-exact class errors with the documented message", {
	set.seed(1)
	n <- 10L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinLin$new(des, verbose = FALSE)

	expect_error(
		inf$compute_exact_two_sided_pval_for_treatment_effect(),
		"Exact inference is only supported for exact inference classes\\."
	)
})

test_that("compute_exact_confidence_interval(): a non-exact class errors with the documented message", {
	set.seed(2)
	n <- 10L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinLin$new(des, verbose = FALSE)

	expect_error(
		inf$compute_exact_confidence_interval(),
		"Exact inference is only supported for exact inference classes\\."
	)
})
