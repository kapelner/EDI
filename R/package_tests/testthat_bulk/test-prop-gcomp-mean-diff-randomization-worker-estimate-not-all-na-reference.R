library(testthat)
library(EDI)

# InferencePropGCompMeanDiff's private compute_randomization_worker_estimate() override (inference_
# proportion_gcomp.R:482-492) fixes a real, high-impact bug (root-caused 2026-09-22, fixed 2026-09-23;
# see prop_gcomp_sample_usable_gating.md and stale_worker_cache_resampling.md's own summary): the
# generic default (inference_all_abstract_rand.R's compute_randomization_worker_estimate()) delegates
# to compute_bootstrap_worker_estimate(), which reads worker_state$runtime$sample_usable/current_X_full/
# current_y -- fields only the BOOTSTRAP row-sample loader ever populates. The generic, shared-by-every-
# class randomization loader never touches this class's private `runtime` env, so `sample_usable` stayed
# stuck at its init value FALSE forever on the randomization path -- every single randomization draw
# returned NA_real_ in production. The fix overrides with a randomization-specific estimator mirroring
# compute_treatment_estimate_during_randomization_inference()'s logic (shared() + cached_values$md)
# applied to the actual worker clone the randomization loader populates. A codebase-wide grep confirmed
# zero test references anywhere to this override or to "sample_usable" at all, despite this being the
# entire reused-worker randomization-distribution path for this class (use_reusable_bootstrap_worker()
# is TRUE here). Exercised end-to-end via the public API on a real fixture, directly regression-guarding
# the reported symptom (all-NA draws) the original fix was verified against.

prop_gcomp_rand_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- plogis(-0.2 + 0.6 * w + 0.4 * x + rnorm(n, sd = 0.3))
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("this fixture genuinely reaches the reused-worker randomization path (use_reusable_bootstrap_worker() = TRUE)", {
	f <- prop_gcomp_rand_fixture()
	expect_true(f$priv$use_reusable_bootstrap_worker())
})

test_that("the identity permutation (the observed w itself) reproduces compute_estimate()'s own cached value exactly -- not NA", {
	f <- prop_gcomp_rand_fixture(2L)
	main_est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_true(is.finite(main_est))

	w_int <- as.integer(f$priv$w)
	distr_identity <- f$inf$approximate_randomization_distribution_beta_hat_T(
		r = 1L, delta = 0, permutations = list(w_mat = cbind(w_int)), show_progress = FALSE
	)
	expect_equal(as.numeric(distr_identity), main_est, tolerance = 1e-8)
})

test_that("a real randomization distribution over many permutations is entirely finite (the exact bug: every draw used to be NA_real_) and shows genuine per-permutation variation, not a frozen/stuck value", {
	f <- prop_gcomp_rand_fixture(3L)
	perms <- f$priv$generate_permutations(30L)
	distr <- f$inf$approximate_randomization_distribution_beta_hat_T(r = 30L, delta = 0, permutations = perms, show_progress = FALSE)

	expect_length(distr, 30L)
	expect_true(all(is.finite(distr)))
	expect_gt(length(unique(round(distr, 8))), 1L)  # not all identical (rules out a stuck/cached value)
})
