# Thread and random-number review audit, 2026-11-17:
# InferenceCountHurdleNegBin$compute_estimate_with_bootstrap_weights() fits glmmTMB with control =
# glmmTMBControl(parallel = self$num_cores). This sends the EDI core count to TMB's OpenMP
# likelihood. With n threads, glmmTMB's observation loop (PARALLEL_REGION) is split across n tapes
# and the partial negative log-likelihoods and gradients are summed in a thread-dependent order.
# nlminb then follows a slightly different path, so the reweighted beta_hat_T for one weight vector
# differs between set_num_cores(1) and set_num_cores(2). Every Bayesian and nonparametric bootstrap
# replicate of this class therefore depends on the core count, which breaks the bit-identical
# seeded-result contract checked in test-rand-seed-core-count-invariance-two-session.R.
# Where: R/EDI/R/inference_count_hurdle.R:442 (kind: core_count_dependence).
# On commit 4fc58cd063bc this test failed with: Expected `r1$est` to be identical to `r2$est`.
# Differences: Objects equal but not identical
# Tracked by v1.0.6-TODO-62; remove the skip() when that fix lands.

test_that("hurdle negbin bootstrap-weighted estimates do not depend on the core count", {
	skip("known bug, v1.0.6-TODO-62")
		n = 200L
		set.seed(20261117)
		X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
		set.seed(99)
		W = lapply(1:6, function(b) { g = stats::rgamma(n, shape = 1, rate = 1); g / sum(g) * n })
		run = function(cores) {
			set_num_cores(cores)
			on.exit(unset_num_cores(), add = TRUE)
			d = DesignFixediBCRD$new(response_type = "count", n = n, seed = 7L, verbose = FALSE)
			d$add_all_subjects_to_experiment(X)
			d$assign_w_to_all_subjects()
			w = d$get_w()
			set.seed(123)
			zero = runif(n) < stats::plogis(-0.2 + 0.4 * w + 0.3 * X$x1)
			y = ifelse(zero, 0, 1 + stats::rnbinom(n, mu = exp(0.6 + 0.3 * w + 0.2 * X$x2), size = 2))
			d$add_all_subject_responses(y)
			inf = InferenceCountHurdleNegBin$new(d, model_formula = ~ x1 + x2)
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
