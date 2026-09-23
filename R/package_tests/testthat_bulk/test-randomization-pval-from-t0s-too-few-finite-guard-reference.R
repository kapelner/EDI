library(testthat)
library(EDI)

# InferenceRand's private compute_two_sided_randomization_pval_from_t0s(t0s, t)
# (inference_all_abstract_rand.R) has a nonestimable guard -- fired when fewer than
# max(10L, 0.10 * length(t0s)) of the supplied randomization-distribution draws are finite -- that
# had no test reference anywhere. test-rand-bootstrap.R already exercises this exact method (line
# 348), but only its happy successful-p-value path; it never drives the too-few-finite branch or
# asserts the resulting reason string. Reached directly on InferenceAllSimpleAverageDiff (no real
# permutation/randomization simulation needed -- t0s is hand-built).

smd_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("'randomization_too_few_finite_estimates' fires when finite draws fall below max(10, 10% of length)", {
	f <- smd_fixture()
	t0s <- c(rep(NA_real_, 95), rnorm(5))  # 100 draws, only 5 finite; min_required = max(10, 10) = 10

	res <- f$priv$compute_two_sided_randomization_pval_from_t0s(t0s, t = 0.3)
	expect_true(is.na(res))
	expect_identical(f$inf$get_nonestimable_reason(), "randomization_too_few_finite_estimates")
})

test_that("just enough finite draws (at min_required) does NOT trigger the guard", {
	f <- smd_fixture(seed = 2L)
	t0s <- c(rep(NA_real_, 90), rnorm(10))  # 100 draws, 10 finite; min_required = max(10, 10) = 10

	res <- f$priv$compute_two_sided_randomization_pval_from_t0s(t0s, t = 0.3)
	expect_false(is.na(res))
	expect_false(isTRUE(f$inf$is_nonestimable("estimate")))
})
