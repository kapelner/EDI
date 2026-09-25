library(testthat)
library(EDI)

# InferenceAllKKMeanDiffIVWC's own public compute_asymp_confidence_interval()/compute_asymp_two_sided_
# pval() overrides (inference_all_KK_mean_diff_IVWC.R) are thin wrappers: an alpha/delta assertion guard,
# a private$shared() trigger (so a fresh instance -- with no prior compute_estimate() call -- still
# works), then a delegation to the already-tested private compute_z_or_t_ci_from_s_and_df()/compute_z_or_
# t_two_sided_pval_from_s_and_df() (inference_all_abstract_asymp.R). This class's shared() never sets
# private$cached_values$df, so df stays NA and both helpers always take the z (normal), never t, branch.
# A codebase-wide grep confirmed neither override had ever actually been called anywhere: the 4 existing
# references to the class are golden/migration/contract tests that only check these two method NAMES are
# present on the generator (test-simple-mean-difference-migration-golden.R), never invoke them for this
# specific class. Exercised via the public API on a real KK14 design with both matched pairs and
# reservoir subjects (the same fixture pattern as the sibling compute_fast_randomization_distr() test),
# independent reference built from the z-formula applied to the already-cached point estimate and SE.

fx <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	list(des = des, n = n)
}

test_that("compute_asymp_confidence_interval() on a fresh instance (no prior compute_estimate() call) matches the z-formula applied to its own cached point estimate and SE", {
	f <- fx(1L)
	inf <- InferenceAllKKMeanDiffIVWC$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_null(priv$cached_values$beta_hat_T)  # confirms shared() has not run yet

	ci <- inf$compute_asymp_confidence_interval(alpha = 0.1)

	beta_hat_T <- priv$cached_values$beta_hat_T
	s_beta_hat_T <- priv$cached_values$s_beta_hat_T
	expect_true(is.finite(beta_hat_T) && is.finite(s_beta_hat_T) && s_beta_hat_T > 0)
	expect_null(priv$cached_values$df)  # this class's shared() never sets df -> always the z branch

	mult <- qnorm(1 - 0.1 / 2)
	ref <- c(beta_hat_T - mult * s_beta_hat_T, beta_hat_T + mult * s_beta_hat_T)
	names(ref) <- c("5%", "95%")
	expect_equal(ci, ref, tolerance = 1e-12)
})

test_that("compute_asymp_two_sided_pval() matches the z-formula and is consistent with compute_asymp_confidence_interval()'s cached estimate/SE, on the same instance", {
	f <- fx(2L)
	inf <- InferenceAllKKMeanDiffIVWC$new(f$des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	pval <- inf$compute_asymp_two_sided_pval(delta = 0)
	beta_hat_T <- priv$cached_values$beta_hat_T
	s_beta_hat_T <- priv$cached_values$s_beta_hat_T
	ref <- 2 * pnorm(-abs(beta_hat_T / s_beta_hat_T))
	expect_equal(pval, ref, tolerance = 1e-12)

	# a nonzero delta shifts the z-statistic accordingly
	pval2 <- inf$compute_asymp_two_sided_pval(delta = beta_hat_T)
	expect_equal(pval2, 1, tolerance = 1e-10)

	# calling compute_asymp_confidence_interval() afterwards reuses the same cached estimate/SE
	# (shared()'s short-circuit), so the two methods agree on a shared alpha <-> two-sided-pval boundary
	alpha <- 0.05
	ci <- inf$compute_asymp_confidence_interval(alpha = alpha)
	mult <- qnorm(1 - alpha / 2)
	expect_equal(unname(ci), c(beta_hat_T - mult * s_beta_hat_T, beta_hat_T + mult * s_beta_hat_T), tolerance = 1e-12)
})

test_that("an out-of-(0,1) alpha/delta is rejected by the shared assertion guards", {
	f <- fx(3L)
	inf <- InferenceAllKKMeanDiffIVWC$new(f$des, verbose = FALSE)
	expect_error(inf$compute_asymp_confidence_interval(alpha = 0))
	expect_error(inf$compute_asymp_confidence_interval(alpha = 1.5))
	expect_error(inf$compute_asymp_two_sided_pval(delta = "not a number"))
})
