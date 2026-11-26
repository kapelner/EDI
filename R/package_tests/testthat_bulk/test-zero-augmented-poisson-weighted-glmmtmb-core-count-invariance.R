# Thread and random-number review audit, 2026-11-17: fit_zero_augmented_model() passes
# glmmTMBControl(parallel = self$num_cores) to glmmTMB, so TMB evaluates the likelihood on
# self$num_cores OpenMP threads. The per-thread partial sums of the negative log-likelihood and
# gradient are combined in a thread-count-dependent order, so the fitted coefficients differ in the
# low bits between 1 and 2 cores. The bootstrap-weighted estimate of InferenceCountHurdlePoisson (and
# the other zero-augmented subclasses, plus their use_rcpp = FALSE fits) therefore changes with
# set_num_cores(), and so do the seeded bootstrap distributions built from it.
# Where: R/EDI/R/inference_count_zero_augmented_poisson_abstract.R:1094 (kind: core_count_dependence).
# On commit 4fc58cd063bc this test failed with: Expected `r1$est` to be identical to `r2$est`.
# Differences: Objects equal but not identical
# Regression test for v1.0.6-TODO-28 (fixed 2026-11-19; the skip() was removed).

test_that("hurdle poisson bootstrap-weighted estimates do not depend on the core count", {
		n = 200L
		set.seed(20261118)
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		set.seed(77)
		W = lapply(1:6, function(b) { g = stats::rgamma(n, shape = 1, rate = 1); g / sum(g) * n })
		run = function(cores) {
			set_num_cores(cores)
			on.exit(unset_num_cores(), add = TRUE)
			d = DesignFixediBCRD$new(response_type = "count", n = n, seed = 5L, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			w = d$get_w()
			set.seed(321)
			zero = runif(n) < stats::plogis(-0.3 + 0.5 * w + 0.3 * X$x1)
			pos = stats::rpois(n, exp(0.8 + 0.3 * w + 0.2 * X$x2))
			y = ifelse(zero, 0, pmax(pos, 1))
			d$add_all_subject_responses(y)
			inf = InferenceCountHurdlePoisson$new(d, model_formula = ~ x1 + x2)
			inf$compute_estimate()
			priv = inf$.__enclos_env__$private
			priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
			est = vapply(W, function(wt) as.numeric(inf$compute_estimate_with_bootstrap_weights(wt, estimate_only = TRUE))[1L], numeric(1))
			list(nc = as.integer(inf$num_cores), est = est)
		}
		r1 = run(1L)
		r2 = run(2L)
		expect_identical(r1$nc, 1L)
		expect_identical(r2$nc, 2L)
		expect_true(all(is.finite(r1$est)))
		expect_identical(r1$est, r2$est)
})
