library(testthat)
library(EDI)

# v1.0.6-TODO-205: InferenceIncidBinomialIdentityRiskDiff's randomization p-value was not reproducible
# (two seeded calls on one object gave 1 vs 0.555) and the reusable-worker and slow paths disagreed
# (1.000 vs 0.587). Cause: the warm start carried into each draw holds the Fisher information of a fit
# on another assignment; the constrained line search then rejected every step and the kernel returned
# the warm start unchanged (converged = FALSE). The worker's estimate-only fit dropped `converged`, so
# about 30% of draws equalled the observed estimate exactly, and the observed statistic itself was a
# fresh warm-started refit that drifted by ~1e-7 between calls, flipping those 143 ties between tails.
# Fixed in inference_incidence_binomial_identity.R: stalled warm fits are refit cold, the estimate-only
# fit keeps `converged`, and the observed statistic is the cached compute_estimate() value.

binid_rand_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

binid_rand_pval <- function(des, use_worker, estimand = "conditional") {
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	if (!identical(estimand, "conditional")) inf$set_estimand(estimand)
	inf$.__enclos_env__$private$reusable_bootstrap_worker_enabled <- use_worker
	set.seed(11L)
	inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE)
}

test_that("two seeded rand p-values on one object are identical", {
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(binid_rand_fixture(1L), verbose = FALSE)
	inf$num_cores <- 1L
	set.seed(11L); pv1 <- inf$compute_rand_two_sided_pval(show_progress = FALSE)
	set.seed(11L); pv2 <- inf$compute_rand_two_sided_pval(show_progress = FALSE)
	expect_identical(pv1, pv2)
	expect_true(is.finite(pv1) && pv1 > 0 && pv1 < 1)
})

test_that("the reusable-worker and slow randomization paths give the same p-value", {
	for (seed in c(1L, 3L)) {
		des <- binid_rand_fixture(seed)
		for (estimand in c("conditional", "marginal_mean_diff")) {
			p_worker <- binid_rand_pval(des, TRUE, estimand)
			p_slow <- binid_rand_pval(des, FALSE, estimand)
			expect_true(is.finite(p_worker), info = paste(seed, estimand))
			expect_equal(p_worker, p_slow, tolerance = 1e-12, info = paste(seed, estimand))
		}
	}
})

test_that("a warm start from another assignment does not stall the fit at the warm start", {
	des <- binid_rand_fixture(1L)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	est_obs <- inf$compute_estimate(estimate_only = TRUE)
	set.seed(5L)
	n_tied <- 0L
	for (b in 1:40) {
		w_b <- rbinom(20L, 1, 0.5)
		if (sum(w_b) %in% c(0L, 20L)) next
		priv$w <- w_b
		reset_reused_worker_private_caches(priv, changed = "assignment")
		priv$cached_values <- list()
		est_b <- suppressWarnings(inf$compute_estimate(estimate_only = TRUE),
			classes = c("edi_covariate_dropped_warning", "edi_binomial_mle_boundary_warning"))
		X_b <- cbind(1, w_b, priv$get_X())
		cold <- fast_identity_binomial_regression_cpp(X = X_b, y = as.numeric(priv$y))
		if (isTRUE(cold$converged)) expect_equal(est_b, cold$b[2], tolerance = 1e-4, info = paste("draw", b))
		if (isTRUE(abs(est_b - est_obs) < 1e-12)) n_tied <- n_tied + 1L
	}
	expect_identical(n_tied, 0L)
})
