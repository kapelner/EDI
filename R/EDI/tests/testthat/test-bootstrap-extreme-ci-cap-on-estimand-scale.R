# v1.0.6-TODO-157 (from v1.0.6-TODO-113's owner decision): the bootstrap "extreme interval" cap
# (bootstrap_extreme_ci_width_threshold = 5 times bootstrap_outcome_scale(), the outcome SD) is in
# outcome units but was also applied to log-ratio / link-scale coefficients, so a 5.6-wide log-OR
# interval from 10 clusters was rejected. For those estimands an interval over the cap is now kept
# when its width is at most 10 robust (MAD) SDs of the bootstrap replicates and both bounds are
# within +-10 on the link scale; separation-driven intervals are still rejected. Intervals within
# the cap, and every outcome-scale estimand, are unchanged.

# Inline copy of the data-shape fixture
# data_shape__fixed_cluster__ordinal__fixed__equal__none__no__null
# (R/package_tests/public_argument_combination_fixtures.R, build_data_shape_fixture()).
cluster_ordinal_fixture_157 = function(){
	n = 40L
	X = data.frame(
		x1 = stats::qnorm(seq(0.5, n - 0.5) / n)[c(seq(1L, n, by = 2L), seq(2L, n, by = 2L))],
		x2 = rep(c(0, 1), length.out = n),
		stratum = factor(ifelse(seq_len(n) <= 20L, "low", "high"), levels = c("low", "high")),
		cluster_id = factor(rep(1:10, each = 4L))
	)
	des = DesignFixedCluster$new(cluster_col = "cluster_id", response_type = "ordinal", n = n,
		seed = 20260809L, design_formula = ~ x1 + x2 + stratum, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(c(2, 4, 2, 3, 4, 4, 3, 4, 3, 4, 3, 3, 4, 4, 2, 3, 3, 2, 3, 1,
		4, 2, 2, 4, 2, 3, 2, 3, 3, 2, 3, 3, 3, 2, 2, 3, 2, 2, 3, 2))
	des
}

# Logistic data whose bootstrap replicates are separated: y = w except `k` discordant subjects per
# arm (k = 0: one treated subject flipped, so the original fit is separated too).
separated_incidence_157 = function(k, seed){
	n = 30L
	set.seed(seed)
	des = DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = w
	if (k == 0L) {
		y[sample(which(w == 1), 1L)] = 0
	} else {
		y[sample(which(w == 1), k)] = 0
		y[sample(which(w == 0), k)] = 1
	}
	des$add_all_subject_responses(y)
	des
}

boot_ci_and_reason_157 = function(inf, B = 501L){
	set.seed(1)
	reason = NULL
	ci = withCallingHandlers(
		suppressWarnings(inf$compute_bootstrap_confidence_interval(B = B, type = "percentile", show_progress = FALSE),
			classes = c("edi_cluster_independence_warning", "edi_logistic_separation_warning")),
		edi_procedure_na_warning = function(cond){ reason <<- cond$reason; invokeRestart("muffleWarning") }
	)
	list(ci = ci, reason = reason)
}

test_that("PropOddsRegr on the 10-cluster fixture: the wide log-OR percentile interval is no longer rejected", {
	inf = InferenceOrdinalPropOddsRegr$new(cluster_ordinal_fixture_157(), verbose = FALSE)
	r = boot_ci_and_reason_157(inf)
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
	expect_gt(diff(unname(r$ci)), 5)  # wider than the old cap of 5 (outcome SD < 1)
	expect_lt(r$ci[[1L]], -2.5)
	expect_gt(r$ci[[2L]], 2)
})

test_that("separation-driven logistic intervals are still rejected", {
	# Original fit separated: replicates stop at about 25-50 on the log-odds scale.
	inf = suppressWarnings(InferenceIncidLogRegr$new(separated_incidence_157(0L, 1L), verbose = FALSE))
	r = boot_ci_and_reason_157(inf)
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
	# Original fit finite but most replicates separated: the MAD is inflated, the magnitude rule catches it.
	inf = InferenceIncidLogRegr$new(separated_incidence_157(1L, 1L), verbose = FALSE)
	r = boot_ci_and_reason_157(inf)
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
	# A minority of replicates separated: width is many robust SDs.
	inf = InferenceIncidLogRegr$new(separated_incidence_157(3L, 1L), verbose = FALSE)
	r = boot_ci_and_reason_157(inf)
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
})

test_that("the predicate: spread and magnitude rules apply only over the cap and only on the link scale", {
	inf = InferenceOrdinalPropOddsRegr$new(cluster_ordinal_fixture_157(), verbose = FALSE)
	p = inf$.__enclos_env__$private
	expect_true(p$bootstrap_estimand_on_link_scale())
	expect_equal(p$bootstrap_outcome_scale(), 1)
	set.seed(2)
	theta = rnorm(500)  # robust SD about 1, so up to about 10 wide is plausible
	# Within the old cap: never extreme, with or without replicates (unchanged results).
	expect_false(p$bootstrap_confidence_interval_extreme(c(-2, 2), est = 0))
	expect_false(p$bootstrap_confidence_interval_extreme(c(-2, 2), est = 0, theta = rep(0, 500) + 1e-3 * theta))
	# Over the cap: extreme without replicates (old behavior) ...
	expect_true(p$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0))
	# ... kept when narrow relative to the replicates' robust spread ...
	expect_false(p$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0, theta = theta))
	# ... but not when the replicates are tight (width > 10 robust SDs) ...
	expect_true(p$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0, theta = 0.5 * theta))
	# ... nor when a bound is beyond +-10 on the link scale, however spread out the replicates.
	expect_true(p$bootstrap_confidence_interval_extreme(c(4, 11), est = 6, theta = 20 * theta))
	# Too few finite replicates: the cap stands.
	expect_true(p$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0, theta = c(theta[1:10], rep(NA, 50))))

	# Outcome-scale estimand (mean difference): the outcome-SD cap stands even with replicates.
	set.seed(3)
	des = DesignFixediBCRD$new(n = 30, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(30)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(30, sd = 0.5))
	pm = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_false(pm$bootstrap_estimand_on_link_scale())
	expect_true(pm$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0, theta = theta))

	# A marginal estimand of a logistic class (risk difference) is not on the link scale.
	set.seed(4)
	des = DesignFixediBCRD$new(n = 40, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(40)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(40, 1, 0.5))
	logit = InferenceIncidLogRegr$new(des, verbose = FALSE)
	expect_true(logit$.__enclos_env__$private$bootstrap_estimand_on_link_scale())
	logit$set_estimand("marginal_mean_diff")
	expect_false(logit$.__enclos_env__$private$bootstrap_estimand_on_link_scale())
})
