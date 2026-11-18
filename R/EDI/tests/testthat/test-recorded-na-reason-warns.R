# v1.0.6-TODO-113: an NA whose reason is only recorded on the object must also warn (the v1.0.6-TODO-95 rule).
# Covers InferenceCountPoisson asymptotic inference on DesignFixedBlockedCluster (a documented gate, so
# edi_unsupported_procedure), the bootstrap CI's "extreme interval" NA, and the jackknife NA on a separated
# KK21 ordinal fit. None of these warnings may fire inside a resampling inner loop.

blocked_cluster_count_113 = function(){
	n = 40L
	set.seed(20261118)
	X = data.frame(
		x1 = rnorm(n),
		stratum = factor(rep(c("low", "high"), each = n / 2), levels = c("low", "high")),
		cluster_id = factor(rep(1:10, each = 4))
	)
	des = DesignFixedBlockedCluster$new(strata_cols = "stratum", cluster_col = "cluster_id", response_type = "count",
		n = n, seed = 20260809L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(stats::rpois(n, 2))
	des
}

test_that("Poisson asymptotic inference on a blocked-cluster design warns edi_unsupported_procedure instead of a silent NA", {
	inf = InferenceCountPoisson$new(blocked_cluster_count_113())
	expect_warning(ci <- inf$compute_asymp_confidence_interval(), class = "edi_unsupported_procedure")
	expect_true(all(is.na(ci)))
	expect_warning(p <- inf$compute_asymp_two_sided_pval(), class = "edi_unsupported_procedure")
	expect_true(is.na(p))
	expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$count_likelihood_asymp,
		"count_likelihood_asymp_block_size_gt_one_not_supported")
	# The point estimate is unaffected and silent.
	expect_silent(est <- inf$compute_estimate())
	expect_true(is.finite(est))
})

test_that("the gate is silent while a resampling operation is active", {
	inf = InferenceCountPoisson$new(blocked_cluster_count_113())
	inf$.__enclos_env__$private$active_resampling_operation = "rand"
	expect_silent(p <- inf$compute_asymp_two_sided_pval())
	expect_true(is.na(p))
})

cluster_ordinal_113 = function(){
	n = 40L
	set.seed(1)
	X = data.frame(x1 = rnorm(n), cluster_id = factor(rep(1:10, each = 4)))
	des = DesignFixedCluster$new(cluster_col = "cluster_id", response_type = "ordinal", n = n, seed = 1, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	des
}

test_that("a bootstrap CI rejected as extreme warns with its recorded reason", {
	inf = InferenceOrdinalPropOddsRegr$new(cluster_ordinal_113())
	# Force the "extreme interval" branch: any finite interval is wider than this cap.
	inf$.__enclos_env__$private$bootstrap_extreme_ci_width_threshold = 1e-8
	# v1.0.6-TODO-157: a log-odds interval over that cap is kept when it is narrow relative to the
	# replicates' spread, so the spread allowance is forced to ~0 too.
	inf$.__enclos_env__$private$bootstrap_extreme_ci_width_spread_multiple = 1e-8
	set.seed(1)
	w = NULL
	ci = withCallingHandlers(
		suppressWarnings(inf$compute_bootstrap_confidence_interval(B = 101, type = "percentile", show_progress = FALSE),
			classes = "edi_cluster_independence_warning"),
		edi_procedure_na_warning = function(cond){ w <<- cond; invokeRestart("muffleWarning") }
	)
	expect_true(all(is.na(ci)))
	expect_false(is.null(w))
	expect_identical(w$reason, "bootstrap_extreme_confidence_interval")
	expect_identical(inf$.__enclos_env__$private$cached_values$procedure_failure_reason$bootstrap,
		"bootstrap_extreme_confidence_interval")
})

separated_kk21_ordinal_113 = function(){
	n = 40L
	set.seed(20261118)
	des = DesignSeqOneByOneKK21$new(response_type = "ordinal", n = n, seed = 20260809L, verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c(0, 1), length.out = n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	# Every treated subject in the top category: the proportional-odds MLE does not exist.
	y = ifelse(w == 1, 4, sample(1:4, n, replace = TRUE))
	for (i in seq_len(n)) des$add_one_subject_response(i, y = y[i])
	des
}

test_that("an NA jackknife on a separated KK21 ordinal fit warns with the specific reason on every call", {
	inf = InferenceOrdinalKKGEE$new(separated_kk21_ordinal_113())
	suppressWarnings(inf$compute_estimate())
	expect_warning(ci <- inf$compute_jackknife_wald_confidence_interval(), class = "edi_procedure_na_warning")
	expect_true(all(is.na(ci)))
	w2 = tryCatch(inf$compute_jackknife_wald_two_sided_pval(), edi_procedure_na_warning = function(cond) cond)
	expect_s3_class(w2, "edi_procedure_na_warning")
	# The specific cause survives the generic reason the first call records.
	expect_false(w2$reason %in% c("jackknife_estimate_unavailable", "jackknife_standard_error_unavailable"))
	expect_warning(se <- inf$compute_jackknife_std_error(), class = "edi_procedure_na_warning")
	expect_true(is.na(se))
})
