library(testthat)
library(EDI)

# InferenceBayesianBootstrap$compute_bayesian_bootstrap_two_sided_pval()/
# compute_bayesian_bootstrap_confidence_interval() (inference_all_abstract_bayesian_bootstrap.R,
# ~lines 274-494) support type in {"percentile","symmetric","wald","studentized",
# "bootstrap-t","bca"} (pval) / {"percentile","basic","wald","studentized",
# "bootstrap-t","bca"} (CI). Existing tests only exercised "percentile"/"basic"/
# "wald" on these two Bayesian-bootstrap-specific methods (grep across
# testthat/ and testthat_bulk/ found no "symmetric"/"studentized"/"bootstrap-t"/
# "bca" call on compute_bayesian_bootstrap_two_sided_pval or
# compute_bayesian_bootstrap_confidence_interval specifically -- the
# "studentized"/"bca" hits elsewhere test the *rand*-bootstrap sibling methods
# or mock the shared bca_core/ci_core helpers directly, not this dispatch).

bbtype_design = function(response_type = "continuous", n = 30L, seed = 20260728L) {
	EDI:::inference_migration_complete_design(response_type, n = n, seed = seed)
}

test_that("symmetric two-sided p-value matches an independent recomputation from the same draws", {
	des = bbtype_design()
	obj1 = InferenceAllSimpleAverageDiff$new(des)
	obj1$num_cores = 1L
	obj1$set_seed(555L)
	boot_distr = as.numeric(obj1$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 41L, show_progress = FALSE))
	est = as.numeric(obj1$compute_estimate())[1L]

	D_obs = abs(est - 0)
	D_boot = abs(boot_distr - mean(boot_distr))
	n_bs = length(D_boot)
	ref_symmetric = min(1, max(2 / n_bs, mean(D_boot >= D_obs)))

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(555L)
	actual_symmetric = obj2$compute_bayesian_bootstrap_two_sided_pval(B = 41L, type = "symmetric", show_progress = FALSE)
	expect_equal(actual_symmetric, ref_symmetric, tolerance = 1e-12)
})

test_that("the type='wald' p-value falls through to the normal-approximation formula, matching an independent reference", {
	des = bbtype_design()
	obj1 = InferenceAllSimpleAverageDiff$new(des)
	obj1$num_cores = 1L
	obj1$set_seed(555L)
	boot_distr = as.numeric(obj1$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 41L, show_progress = FALSE))
	est = as.numeric(obj1$compute_estimate())[1L]

	se_boot = sd(boot_distr)
	n_bs = length(boot_distr)
	ref_wald = min(1, max(2 / n_bs, 2 * pnorm(-abs((est - 0) / se_boot))))

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(555L)
	actual_wald = obj2$compute_bayesian_bootstrap_two_sided_pval(B = 41L, type = "wald", show_progress = FALSE)
	expect_equal(actual_wald, ref_wald, tolerance = 1e-12)
})

test_that("studentized/bootstrap-t dispatch matches manually assembling the same private machinery it delegates to", {
	des = bbtype_design()
	obj = InferenceAllSimpleAverageDiff$new(des)
	obj$num_cores = 1L
	obj$set_seed(777L)
	est = as.numeric(obj$compute_estimate())[1L]
	priv = obj$.__enclos_env__$private
	boot_stats = priv$approximate_bayesian_bootstrap_statistics_beta_hat_T(B = 41L, show_progress = FALSE, require_se = TRUE)
	se_hat = priv$infer_original_se()
	t_obs = abs(est - 0) / se_hat
	t_boot = priv$studentized_bootstrap_pivots(
		theta = boot_stats$theta, se = boot_stats$se, est = est, se_hat = se_hat,
		min_number_usable_samples = 5L, symmetric = TRUE
	)
	ref_studentized = min(1, max(1 / length(t_boot), mean(t_boot >= t_obs)))

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(777L)
	actual_studentized = obj2$compute_bayesian_bootstrap_two_sided_pval(B = 41L, type = "studentized", show_progress = FALSE)
	expect_equal(actual_studentized, ref_studentized, tolerance = 1e-12)

	# "studentized" and its "bootstrap-t" alias must be exactly the same code path.
	obj3 = InferenceAllSimpleAverageDiff$new(des)
	obj3$num_cores = 1L
	obj3$set_seed(777L)
	actual_bootstrap_t = obj3$compute_bayesian_bootstrap_two_sided_pval(B = 41L, type = "bootstrap-t", show_progress = FALSE)
	expect_identical(actual_bootstrap_t, actual_studentized)
})

test_that("studentized/bootstrap-t confidence intervals are seed-reproducible, alias-identical, and differ from the percentile interval", {
	des = bbtype_design()
	obj1 = InferenceAllSimpleAverageDiff$new(des)
	obj1$num_cores = 1L
	obj1$set_seed(321L)
	ci_studentized = obj1$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 41L, type = "studentized", show_progress = FALSE)

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(321L)
	ci_bootstrap_t = obj2$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 41L, type = "bootstrap-t", show_progress = FALSE)
	expect_identical(ci_bootstrap_t, ci_studentized)

	obj3 = InferenceAllSimpleAverageDiff$new(des)
	obj3$num_cores = 1L
	obj3$set_seed(321L)
	ci_percentile = obj3$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 41L, type = "percentile", show_progress = FALSE)
	expect_true(all(is.finite(ci_studentized)))
	expect_true(any(abs(ci_studentized - ci_percentile) > 1e-8))
})

test_that("bca dispatch gates cleanly to a documented nonestimable reason on this design, for both p-value and CI", {
	des = bbtype_design()
	obj1 = InferenceAllSimpleAverageDiff$new(des)
	obj1$num_cores = 1L
	obj1$set_seed(111L)
	pv_bca = obj1$compute_bayesian_bootstrap_two_sided_pval(B = 61L, type = "bca", show_progress = FALSE)
	expect_true(is.na(pv_bca))
	expect_true(obj1$is_nonestimable())
	expect_identical(obj1$get_nonestimable_reason(), "bayesian_bootstrap_bca_adjustment_on_boundary")

	obj2 = InferenceAllSimpleAverageDiff$new(des)
	obj2$num_cores = 1L
	obj2$set_seed(321L)
	ci_bca = obj2$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, B = 41L, type = "bca", show_progress = FALSE)
	expect_true(all(is.na(ci_bca)))
	expect_true(obj2$is_nonestimable())
	expect_identical(obj2$get_nonestimable_reason(), "bayesian_bootstrap_bca_ci_unavailable")
})
