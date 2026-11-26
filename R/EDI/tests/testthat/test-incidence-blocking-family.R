test_that("blocked incidence inference works for CMH and Extended Robins", {
	des <- DesignFixedBlocking$new(
		n = 20,
		response_type = "incidence",
		strata_cols = "x1",
		verbose = FALSE
	)

	des$add_all_subjects_to_experiment(
		data.frame(x1 = factor(rep(1:2, 10), levels = 1:2))
	)
	des$overwrite_all_subject_assignments(rep(c(1, 0), 10))
	des$add_all_subject_responses(rep(c(1, 0, 0, 1), 5))

	inf_cmh <- InferenceIncidCMH$new(des, verbose = FALSE)
	inf_robins <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)

	expect_true(is.finite(inf_cmh$compute_estimate()))
	expect_true(is.finite(inf_robins$compute_estimate()))
	expect_equal(
		inf_cmh$compute_estimate(),
		inf_robins$compute_estimate(),
		tolerance = 1e-12
	)

	expect_equal(length(inf_cmh$compute_asymp_confidence_interval()), 2L)
	expect_equal(length(inf_robins$compute_asymp_confidence_interval()), 2L)
	expect_true(all(is.finite(inf_cmh$compute_asymp_confidence_interval())))
	expect_true(all(is.finite(inf_robins$compute_asymp_confidence_interval())))
	expect_true(is.finite(inf_cmh$compute_asymp_two_sided_pval()))
	expect_true(is.finite(inf_robins$compute_asymp_two_sided_pval()))
})

test_that("jackknife for blocking designs uses leave-one-block-out resampling", {
	# 5 blocks (was 3): since v1.0.6-TODO-89 a jackknife with fewer than 5 deletion units is NA
	# with a warning (test-jackknife-too-few-deletion-units-na-warns.R); 5 is the smallest
	# count for which the manual leave-one-block-out formula is still checked here.
	des <- DesignFixedBlocking$new(
		n = 20,
		response_type = "incidence",
		strata_cols = "x1",
		equal_block_sizes = FALSE,
		verbose = FALSE
	)

	des$add_all_subjects_to_experiment(
		data.frame(x1 = factor(rep(1:5, each = 4), levels = 1:5))
	)
	des$overwrite_all_subject_assignments(rep(c(1, 0, 1, 0), 5))
	des$add_all_subject_responses(c(
		1, 0, 1, 0,
		1, 1, 0, 0,
		0, 1, 0, 1,
		1, 0, 1, 1,
		0, 0, 1, 0
	))

	inf_cmh <- InferenceIncidCMH$new(des, verbose = FALSE)
	inf_robins <- InferenceIncidExtendedRobins$new(des, verbose = FALSE)

	block_ids <- des$get_block_ids()
	full_est <- mean(des$get_y()[des$get_w() == 1]) - mean(des$get_y()[des$get_w() == 0])
	jack_vals <- vapply(sort(unique(block_ids)), function(block_id) {
		keep <- block_ids != block_id
		y <- des$get_y()[keep]
		w <- des$get_w()[keep]
		mean(y[w == 1]) - mean(y[w == 0])
	}, numeric(1))
	n_blocks <- length(jack_vals)
	jack_bar <- mean(jack_vals)
	manual_est <- n_blocks * full_est - (n_blocks - 1) * jack_bar
	manual_se <- sqrt(((n_blocks - 1) / n_blocks) * sum((jack_vals - jack_bar)^2))

	# v1.0.6-TODO-1 (5bdb9dfb): the automatic unit on DesignFixedBlocking is now one subject within
	# its stratum, so leave-one-block-out is asked for explicitly.
	expect_equal(inf_cmh$compute_jackknife_estimate(unit = "block"), manual_est, tolerance = 1e-12)
	expect_equal(inf_cmh$compute_jackknife_std_error(unit = "block"), manual_se, tolerance = 1e-12)
	expect_true(is.finite(inf_cmh$compute_jackknife_wald_two_sided_pval(unit = "block")))
	expect_true(all(is.finite(inf_cmh$compute_jackknife_wald_confidence_interval(unit = "block"))))

	expect_equal(inf_robins$compute_jackknife_estimate(unit = "block"), manual_est, tolerance = 1e-12)
	expect_equal(inf_robins$compute_jackknife_std_error(unit = "block"), manual_se, tolerance = 1e-12)
	expect_true(is.finite(inf_robins$compute_jackknife_wald_two_sided_pval(unit = "block")))
	expect_true(all(is.finite(inf_robins$compute_jackknife_wald_confidence_interval(unit = "block"))))
})
