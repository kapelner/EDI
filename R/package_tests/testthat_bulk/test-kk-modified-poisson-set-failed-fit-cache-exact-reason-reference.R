library(testthat)
library(EDI)

# InferenceIncidKKModifiedPoisson's private set_failed_fit_cache() (inference_incidence_KK_marginal.R,
# shared by the InferenceIncidKKGCompRiskDiff/RiskRatio abstract base) is already covered for its
# BOOLEAN nonestimable flag and its cache-clearing side effects
# (test-kk-modified-poisson-likelihood-spec-harden-retry-and-guards-reference.R and
# test-kk-modified-poisson-weighted-refit-branches-and-coefficient-guards-reference.R), but neither
# test asserts the EXACT cached reason string ("kk_modified_poisson_fit_unavailable") -- confirmed via
# a zero-hit grep for the literal string across the whole test suite, the same "boolean flag checked,
# exact reason text never asserted" gap already closed for InferenceIncidLogRegr's extreme-coefficient
# guards in the immediately preceding iteration.

modpois_fixture <- function(seed = 5L, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
}

test_that("set_failed_fit_cache() caches the exact reason string 'kk_modified_poisson_fit_unavailable'", {
	inf <- modpois_fixture()
	priv <- inf$.__enclos_env__$private
	priv$set_failed_fit_cache()
	expect_identical(inf$get_nonestimable_reason(), "kk_modified_poisson_fit_unavailable")
	expect_true(inf$is_nonestimable("estimate"))
})
