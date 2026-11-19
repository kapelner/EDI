library(testthat)
library(EDI)

# v1.0.6-TODO-209 (1): InferenceIncidLogBinomial's randomization statistic used to be its own
# warm-started refit, which also overwrote the stored warm start, while the reusable worker uses
# compute_estimate(). It now returns compute_estimate(estimate_only = TRUE), as v1.0.6-TODO-205 did for
# InferenceIncidBinomialIdentityRiskDiff. Checked: two seeded rand p-values on one object are identical,
# the observed estimate is unchanged by a rand call, and the worker and slow paths agree.

logbin_rand_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, 0.25 + 0.15 * w))
	des
}

logbin_rand_pval <- function(des, use_worker) {
	inf <- InferenceIncidLogBinomial$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf$.__enclos_env__$private$reusable_bootstrap_worker_enabled <- use_worker
	set.seed(11L)
	suppressWarnings(inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE))
}

test_that("two seeded rand p-values on one object are identical and leave the estimate unchanged", {
	inf <- InferenceIncidLogBinomial$new(logbin_rand_fixture(1L), verbose = FALSE)
	inf$num_cores <- 1L
	est <- suppressWarnings(inf$compute_estimate())
	set.seed(11L); pv1 <- suppressWarnings(inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE))
	set.seed(11L); pv2 <- suppressWarnings(inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE))
	expect_identical(pv1, pv2)
	expect_true(is.finite(pv1) && pv1 > 0 && pv1 < 1)
	expect_identical(suppressWarnings(inf$compute_estimate()), est)
	expect_identical(inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference(), est)
})

test_that("the reusable-worker and slow randomization paths give the same p-value", {
	for (seed in c(1L, 3L)) {
		des <- logbin_rand_fixture(seed)
		p_worker <- logbin_rand_pval(des, TRUE)
		p_slow <- logbin_rand_pval(des, FALSE)
		expect_true(is.finite(p_worker), info = paste("seed", seed))
		expect_equal(p_worker, p_slow, tolerance = 1e-12, info = paste("seed", seed))
	}
})
