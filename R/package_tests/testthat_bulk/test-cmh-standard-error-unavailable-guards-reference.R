library(testthat)
library(EDI)

# InferenceIncidCMH$get_standard_error() (inference_incidence_cmh.R) has two distinct sites that
# cache "cmh_standard_error_unavailable" when the CMH standard error is non-finite or non-positive:
#   1. a fast-path re-check: if private$cached_values$cmh_s_beta_hat_T is already cached but
#      non-finite/<=0 (e.g. left over from a previous failed attempt), it's rejected immediately
#      without recomputing.
#   2. after a fresh computation (either the blocking-design closed-form path or the non-blocking
#      Monte-Carlo-over-randomization-vectors path), the freshly computed SE is rejected the same
#      way if it comes out non-finite/<=0.
# Neither had a test reference anywhere. get_standard_error() is a purely private method (not part
# of the public API at all -- InferenceIncidCMH exposes no public get_standard_error()), so it is
# called directly via inf$.__enclos_env__$private, the same private-method-access pattern this suite
# already uses extensively. Branch 1 is reached by directly seeding the cache with an invalid value;
# branch 2 is reached by overriding get_w_signed() (unlockBinding) to force every non-blocking
# randomization draw's signed treatment vector to be all zeros, which drives the y'w-based variance
# estimate to exactly zero regardless of the (non-constant, otherwise ordinary) response.

test_that("a cached-but-invalid SE is rejected without recomputing (fast-path guard)", {
	set.seed(1); n <- 20L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	inf <- InferenceIncidCMH$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$cached_values$cmh_s_beta_hat_T <- 0

	res <- p$get_standard_error()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "cmh_standard_error_unavailable")
})

test_that("a freshly computed non-positive SE (non-blocking design) is rejected the same way", {
	set.seed(2); n <- 20L
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))

	inf <- InferenceIncidCMH$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_values$cmh_s_beta_hat_T)  # confirms this exercises the "no cache yet" path
	unlockBinding("get_w_signed", p)
	p$get_w_signed <- function(w) matrix(0, nrow(w), ncol(w))

	res <- p$get_standard_error()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "cmh_standard_error_unavailable")
	expect_true(is.na(p$cached_values$cmh_s_beta_hat_T))
})
