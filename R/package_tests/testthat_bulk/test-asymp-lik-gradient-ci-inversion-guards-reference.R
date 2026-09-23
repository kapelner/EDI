library(testthat)
library(EDI)

# InferenceExtCIInversion's invert_gradient_ci_uniroot() (inference_ext_ci_inversion.R, spliced into
# InferenceAsympLik -- the only host, reached here through InferenceIncidLogRegr, one of its 13
# direct subclasses) has two distinct nonestimable guards, neither of which had a test reference
# anywhere:
#   1. "gradient_test_unavailable": the gradient-test p-value at the point estimate itself is
#      non-finite.
#   2. "gradient_ci_inversion_failed": pval_invert_ci_cpp() itself errors.
# Reached by mocking get_memoized_likelihood_test_pval() (private, unlockBinding) and
# pval_invert_ci_cpp() (package-level EDI function, local_mocked_bindings) respectively.

lik_priv <- function(n = 40L, seed = 2L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("invert_gradient_ci_uniroot caches 'gradient_test_unavailable' when the gradient p-value at the estimate is non-finite", {
	f <- lik_priv()
	p <- f$priv
	unlockBinding("get_memoized_likelihood_test_pval", p)
	p$get_memoized_likelihood_test_pval <- function(...) NA_real_

	ci <- p$invert_gradient_ci_uniroot(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(f$inf$get_nonestimable_reason(), "gradient_test_unavailable")
})

test_that("invert_gradient_ci_uniroot caches 'gradient_ci_inversion_failed' when pval_invert_ci_cpp() errors", {
	f <- lik_priv(seed = 3L)
	local_mocked_bindings(pval_invert_ci_cpp = function(...) stop("forced failure"), .package = "EDI")

	ci <- f$priv$invert_gradient_ci_uniroot(0.05)
	expect_length(ci, 2L)
	expect_identical(f$inf$get_nonestimable_reason(), "gradient_ci_inversion_failed")
})
