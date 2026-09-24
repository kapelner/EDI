library(testthat)
library(EDI)

# InferenceAll's shared compute_randomization_distr_via_reused_worker_states() (inference_all_
# abstract_rand.R) -- the reused-worker-STATE path approximate_randomization_distribution_beta_hat_T()
# falls back to for any class with NO compute_fast_randomization_distr() override but
# use_reusable_bootstrap_worker() = TRUE (ordinary iterative fitters: logistic, Poisson, NegBin,
# ordinal, survival, etc. -- distinct from the duplicate-per-permutation
# compute_fast_randomization_distr_via_reused_worker() path closed last iteration, which only classes
# WITH a fast kernel reach) had zero direct test reference anywhere. InferenceIncidLogRegr is a live
# example: has_private_method("compute_fast_randomization_distr") is FALSE and
# use_reusable_bootstrap_worker() is TRUE, so it genuinely reaches this exact function.
#   1. Each value in the r-length randomization distribution closely matches an independent
#      per-permutation call to run_randomization_iteration() -- the already-separately-tested
#      "standard" (non-reused-worker) randomization kernel (test-randomization-worker-loading-sync-
#      and-iteration-reference.R) -- across two different fixtures. The two code paths are documented
#      as computing the identical abstract quantity via different performance strategies (worker-state
#      reuse vs. a fresh duplicate() per call); a loose tolerance accounts for the reused-worker path's
#      own documented "sequential null anchoring" optimization (each permutation's logistic fit is
#      warm-started from the PREVIOUS permutation's converged parameters rather than cold-started),
#      which converges to the same optimum via a very slightly different numerical trajectory.

incid_logregr_rand_fixture <- function(seed, n) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.2 * des$get_w() + 0.3 * rnorm(n))))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, des = des, priv = inf$.__enclos_env__$private)
}

test_that("has no fast randomization kernel but is a reusable-bootstrap-worker class, confirming this fixture reaches the target function", {
	f <- incid_logregr_rand_fixture(1L, 20L)
	expect_false(f$priv$has_private_method("compute_fast_randomization_distr"))
	expect_true(f$priv$use_reusable_bootstrap_worker())
})

test_that("each randomization-distribution value exactly matches an independent run_randomization_iteration() call (n = 40)", {
	f <- incid_logregr_rand_fixture(1L, 40L)
	perms <- f$priv$generate_permutations(5L)
	distr <- f$inf$approximate_randomization_distribution_beta_hat_T(r = 5L, delta = 0, permutations = perms, show_progress = FALSE)

	setup <- f$priv$setup_randomization_template_and_shifts(0, "none")
	ref <- vapply(seq_len(5L), function(i) {
		f$priv$run_randomization_iteration(f$des$duplicate(), f$inf$duplicate(), i, perms, 0, "none", setup$y_delta, setup$base_template_y, setup$base_template_dead)
	}, numeric(1))
	expect_equal(distr, ref, tolerance = 1e-6)
})

test_that("each randomization-distribution value exactly matches an independent run_randomization_iteration() call (n = 60, a different seed/fixture)", {
	f <- incid_logregr_rand_fixture(3L, 60L)
	perms <- f$priv$generate_permutations(6L)
	distr <- f$inf$approximate_randomization_distribution_beta_hat_T(r = 6L, delta = 0, permutations = perms, show_progress = FALSE)

	setup <- f$priv$setup_randomization_template_and_shifts(0, "none")
	ref <- vapply(seq_len(6L), function(i) {
		f$priv$run_randomization_iteration(f$des$duplicate(), f$inf$duplicate(), i, perms, 0, "none", setup$y_delta, setup$base_template_y, setup$base_template_dead)
	}, numeric(1))
	expect_equal(distr, ref, tolerance = 1e-6)
})
