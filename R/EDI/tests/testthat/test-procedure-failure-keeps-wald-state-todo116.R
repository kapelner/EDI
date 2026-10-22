context("TODO-116: a procedure-specific failure must not clear the primary Wald estimate/SE")

fx_block_116 = function(n = 24L){
	set.seed(2)
	des = DesignFixedBlocking$new(strata_cols = "g", response_type = "continuous", n = n, seed = 2,
		verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(data.frame(g = factor(rep(c("a", "b", "c"), each = n / 3)), x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf = InferenceAllSimpleAverageDiff$new(des)
	list(inf = inf, p = inf$.__enclos_env__$private)
}

wald_state_116 = function(f){
	list(
		ci = unname(f$inf$compute_asymp_confidence_interval()),
		pval = f$inf$compute_asymp_two_sided_pval(),
		se = f$p$cached_values$s_beta_hat_T,
		est = f$p$cached_values$beta_hat_T
	)
}

test_that("block-size > 1 observation-level jackknife returns NA and leaves the Wald state intact", {
	f = fx_block_116()
	before = wald_state_116(f)
	expect_true(is.finite(before$se))
	expect_false(f$inf$is_nonestimable("any"))

	expect_true(is.na(f$inf$compute_jackknife_std_error(unit = "observation")))
	expect_true(is.na(f$inf$compute_jackknife_estimate(unit = "observation")))
	expect_true(is.na(f$inf$compute_jackknife_wald_two_sided_pval(unit = "observation")))
	expect_true(all(is.na(f$inf$compute_jackknife_wald_confidence_interval(unit = "observation"))))

	expect_false(f$inf$is_nonestimable("any"))
	expect_false(f$inf$is_nonestimable("se"))
	expect_null(f$inf$get_nonestimable_reason())
	expect_identical(f$p$cached_values$procedure_failure_reason$jackknife,
		"jackknife_block_size_gt_one_not_supported")
	after = wald_state_116(f)
	expect_identical(after, before)
})

test_that("a jackknife that fails on too few replicates does not wipe the Wald SE", {
	f = fx_block_116()
	before = wald_state_116(f)
	unlockBinding("approximate_jackknife_distribution_beta_hat_T_private", f$p)
	f$p$approximate_jackknife_distribution_beta_hat_T_private = function(unit = "auto") 1
	s = f$p$compute_jackknife_summary(unit = "block")
	expect_true(is.na(s$std_error))
	expect_true(is.na(f$inf$compute_jackknife_wald_two_sided_pval(unit = "block")))
	expect_false(f$inf$is_nonestimable("any"))
	expect_true(nzchar(f$p$cached_values$procedure_failure_reason$jackknife))
	expect_identical(wald_state_116(f), before)
})

test_that("BCa with an unsupported block-size jackknife records a procedure failure only", {
	f = fx_block_116()
	before = wald_state_116(f)
	unlockBinding("jackknife_block_size_gt_one_unsupported", f$p)
	f$p$jackknife_block_size_gt_one_unsupported = function(unit = "auto") TRUE
	boot = rnorm(200, 0.5, 0.3)
	expect_true(all(is.na(f$p$ci_bca(boot, 0.05, 0.5))))
	expect_true(is.na(f$p$pval_bca(boot, 0.5, 0.2)))
	expect_true(all(is.na(f$p$missing_bootstrap_ci(0.05, "jackknife_block_size_gt_one_not_supported", stage = "se"))))
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(f$p$cached_values$procedure_failure_reason$jackknife, "jackknife_block_size_gt_one_not_supported")
	expect_identical(wald_state_116(f), before)
})

test_that("the count-likelihood block guard makes asymptotic outputs NA without clearing the fitted state", {
	set.seed(3)
	n = 80L
	des = DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.4 + 0.3 * des$get_w())))
	inf = InferenceCountPoisson$new(des, verbose = FALSE)
	p = inf$.__enclos_env__$private
	ci0 = inf$compute_asymp_confidence_interval()
	se0 = p$cached_values$s_beta_hat_T
	est0 = p$cached_values$beta_hat_T
	expect_true(is.finite(se0))

	unlockBinding("count_likelihood_block_asymp_unsupported", p)
	p$count_likelihood_block_asymp_unsupported = function() TRUE
	expect_true(p$mark_count_likelihood_block_asymp_nonestimable())
	expect_false(inf$is_nonestimable("any"))
	expect_identical(p$cached_values$procedure_failure_reason$count_likelihood_asymp,
		"count_likelihood_asymp_block_size_gt_one_not_supported")
	expect_identical(p$cached_values$s_beta_hat_T, se0)
	expect_identical(p$cached_values$beta_hat_T, est0)
	expect_true(is.na(p$get_standard_error()))
	expect_true(all(is.na(inf$compute_asymp_confidence_interval())))
	expect_true(is.na(inf$compute_asymp_two_sided_pval()))
	expect_false(inf$is_nonestimable("any"))
	expect_identical(p$cached_values$s_beta_hat_T, se0)

	# lifting the guard restores the original Wald interval
	p$count_likelihood_block_asymp_unsupported = function() FALSE
	expect_equal(inf$compute_asymp_confidence_interval(), ci0)
})
