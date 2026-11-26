# v1.0.6-TODO-104 (from v1.0.6-TODO-67's owner decision): the bootstrap "extreme interval" cap
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

# v1.0.6-TODO-109 (owner decision 2026-11-18): (1) for link-scale estimands a bound beyond
# +-bootstrap_extreme_link_scale_max_abs (10) is always extreme when replicates are passed, whatever
# the outcome SD (counts with SD 20 put the outcome-SD cap at ~100 log units, so degenerate
# log-rate-ratio intervals passed); (2) the raw g-computation risk ratio is judged on log(RR) with
# the link-scale rule instead of the outcome-SD cap on the ratio scale. Without replicates
# (subsampling, m-out-of-n) (1) behaves as before; v1.0.6-TODO-121 extended (2) to them.

fixed_design_160 = function(n, response_type, seed, yfun){
	set.seed(seed)
	X = data.frame(x = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(yfun(des$get_w(), X))
	des
}

# Large-SD counts with a treated arm of zeros and one 1: replicates without that subject run to
# about -25 on the log-rate-ratio scale.
degenerate_big_sd_counts_160 = function(){
	fixed_design_160(30L, "count", 3L, function(w, X){
		y = stats::rnbinom(30L, mu = 30, size = 2)
		y[w == 1] = 0L
		y[which(w == 1)[1L]] = 1L
		y
	})
}

ci_and_reason_160 = function(f){
	set.seed(42)
	reason = NULL
	ci = withCallingHandlers(f(),
		edi_procedure_na_warning = function(cond){ reason <<- cond$reason; invokeRestart("muffleWarning") },
		warning = function(cond) invokeRestart("muffleWarning"))
	list(ci = unname(ci), reason = reason)
}

test_that("link-scale bounds beyond +-10 are extreme with replicates, whatever the outcome SD", {
	des = degenerate_big_sd_counts_160()
	p = InferenceCountPoisson$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_true(p$bootstrap_estimand_on_link_scale())
	expect_gt(p$bootstrap_outcome_scale(), 20)  # old cap 5 x SD is over 100 log units
	set.seed(5)
	theta = rnorm(500, -8, 6)
	expect_true(p$bootstrap_confidence_interval_extreme(c(-25.8, -5), est = -8, theta = theta))
	expect_true(p$bootstrap_confidence_interval_extreme(c(-1, 10.5), est = 2, theta = theta))
	# Within +-10: unchanged (under the outcome-SD cap).
	expect_false(p$bootstrap_confidence_interval_extreme(c(-9.5, -4), est = -6, theta = theta))
	# Without replicates (subsampling / m-out-of-n callers): previous behavior.
	expect_false(p$bootstrap_confidence_interval_extreme(c(-25.8, -5), est = -8))
})

test_that("degenerate Poisson and NegBin percentile intervals on large-SD counts are rejected with the warning", {
	des = degenerate_big_sd_counts_160()
	for (gen in list(InferenceCountPoisson, InferenceCountNegBin)) {
		inf = gen$new(des, verbose = FALSE)
		inf$num_cores = 1L
		r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE))
		expect_true(all(is.na(r$ci)))
		expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
	}
	# A regular large-SD count fixture keeps its interval.
	des = fixed_design_160(40L, "count", 2L, function(w, X) stats::rnbinom(40L, mu = exp(3 + 0.4 * w), size = 2))
	inf = InferenceCountPoisson$new(des, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE))
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
	expect_true(all(abs(r$ci) < 2))
})

test_that("the g-computation risk ratio is judged on log(RR): a skewed interval is kept, a degenerate one rejected", {
	des = fixed_design_160(30L, "incidence", 6L, function(w, X) stats::rbinom(30L, 1, stats::plogis(-1.2 + 1.2 * w)))
	for (gen in list(InferenceIncidGCompRiskRatio, InferenceIncidGCompRiskDiff)) {
		p = gen$new(des, verbose = FALSE)$.__enclos_env__$private
		expect_false(p$bootstrap_estimand_on_link_scale())
	}
	p = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)$.__enclos_env__$private
	set.seed(6)
	theta = exp(rnorm(500, log(1.7), 0.6))
	# [0.5, 6] is 5.5 wide on the ratio scale (over the old cap of 5) but log(12) = 2.5 on log(RR).
	expect_false(p$bootstrap_confidence_interval_extreme(c(0.5, 6), est = 1.7, theta = theta))
	# Without replicates the log(RR) rule now applies too (v1.0.6-TODO-121 (2)); before, the
	# ratio-scale check rejected this interval.
	expect_false(p$bootstrap_confidence_interval_extreme(c(0.5, 6), est = 1.7))
	# A bound at a ratio beyond e^-10: degenerate, although only 0.97 wide on the ratio scale.
	expect_true(p$bootstrap_confidence_interval_extreme(c(4.9e-10, 0.97), est = 0.2, theta = c(rep(1e-10, 100), theta)))
	# A non-positive bound has no log: the ratio-scale check runs as before.
	expect_false(p$bootstrap_confidence_interval_extreme(c(-0.2, 3), est = 1.2, theta = theta))
	# A risk difference is unchanged (outcome-scale cap).
	pd = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_true(pd$bootstrap_confidence_interval_extreme(c(-3, 3), est = 0, theta = rnorm(500)))

	# End to end: the Bayesian-bootstrap percentile interval reaches past 6 and is now kept.
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_bayesian_bootstrap_confidence_interval(B = 201, show_progress = FALSE))
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
	expect_gt(r$ci[2L] - r$ci[1L], 5)
	expect_gt(r$ci[1L], 0)

	# Treated arm with a single event: replicates without it give RR ~ 1e-10.
	des0 = fixed_design_160(40L, "incidence", 7L, function(w, X){
		y = stats::rbinom(40L, 1, 0.4)
		y[w == 1] = 0L
		y[which(w == 1)[1L]] = 1L
		y
	})
	inf = InferenceIncidGCompRiskRatio$new(des0, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "percentile", show_progress = FALSE))
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
})

test_that("the KK g-computation risk ratio uses the same log(RR) rule", {
	set.seed(10)
	n_pairs = 12L
	n = 2L * n_pairs
	x = rnorm(n)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n_pairs), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w = rep(c(0, 1), n_pairs)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.5 + 1.5 * w + 0.4 * x)))
	inf = suppressWarnings(InferenceIncidKKGCompRiskRatio$new(des, model_formula = ~ x, verbose = FALSE))
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	set.seed(6)
	theta = exp(rnorm(500, log(1.7), 0.6))
	expect_false(p$bootstrap_confidence_interval_extreme(c(0.5, 6), est = 1.7, theta = theta))
	expect_true(p$bootstrap_confidence_interval_extreme(c(1e-6, 30000), est = 2, theta = theta))
	# Was rejected on the ratio scale (about 37 wide); about 3.2 wide on log(RR).
	r = ci_and_reason_160(function() inf$compute_bayesian_bootstrap_confidence_interval(B = 201, show_progress = FALSE))
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
	expect_gt(r$ci[2L] - r$ci[1L], 5)
})

# v1.0.6-TODO-121 (from v1.0.6-TODO-109): the remaining raw-ratio-scale guards of the g-computation
# risk ratio. (1) The replicate guard of the bootstrap CI paths runs on log(RR), so one replicate
# with RR > 1e6 (near-zero control risk) no longer rejects the whole bootstrap; (2) callers without
# replicates (the risk-ratio subsampling / m-out-of-n pivots) get the log(RR) rule; (3) the log-scale
# basic bootstrap and basic / Wald Bayesian-bootstrap risk-ratio intervals now run both checks.

incid_rr_fixture_175 = function(n, seed, yfun) fixed_design_160(n, "incidence", seed, yfun)

test_that("the risk-ratio replicate guard of the bootstrap CI paths runs on log(RR)", {
	des = incid_rr_fixture_175(30L, 6L, function(w, X) stats::rbinom(30L, 1, stats::plogis(-1.2 + 1.2 * w)))
	p = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_true(p$bootstrap_estimand_is_raw_ratio())
	set.seed(6)
	theta = c(exp(rnorm(500, log(1.7), 0.6)), 5e6)
	expect_true(p$bootstrap_estimates_extreme(theta, est = 1.7))      # raw scale: one replicate rejects all
	expect_false(p$bootstrap_ci_estimates_extreme(theta, est = 1.7))  # log(RR): kept
	pd = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_false(pd$bootstrap_estimand_is_raw_ratio())
	expect_true(pd$bootstrap_ci_estimates_extreme(c(rnorm(500), 5e6), est = 0))
	po = InferenceIncidLogRegr$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_false(po$bootstrap_estimand_is_raw_ratio())

	# End to end (n = 30): percentile and BCa were NA (bootstrap_extreme_finite_estimates).
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	for (type in c("percentile", "bca")) {
		r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = type, show_progress = FALSE))
		expect_true(all(is.finite(r$ci)))
		expect_null(r$reason)
		expect_true(r$ci[1L] > 0.3 && r$ci[2L] < 20)
	}
})

test_that("risk-ratio subsampling / m-out-of-n intervals are judged on log(RR) without replicates", {
	des = incid_rr_fixture_175(60L, 5L, function(w, X) stats::rbinom(60L, 1, stats::plogis(-0.3 + 0.8 * w + 0.5 * X$x)))
	p = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)$.__enclos_env__$private
	expect_true(p$bootstrap_confidence_interval_extreme(c(3e-5, 2.83), est = 1.5))
	expect_false(p$bootstrap_confidence_interval_extreme(c(0.73, 2.67), est = 1.5))
	# Over the log-scale width cap without replicates to vouch for it: still extreme.
	expect_true(p$bootstrap_confidence_interval_extreme(c(0.01, 200), est = 1.5))
	# The m-out-of-n interval [3e-5, 2.83] on this fixture was accepted. Its lower bound came from
	# degenerate resamples (an arm with no events, or a separated fit: log RR* ~ -20). Since
	# v1.0.6-TODO-137 those draws are unusable: about 10% of them here. Under a 95% usable-draw
	# minimum the interval is NA for that reason before the extreme check runs; under the 80%
	# default (v1.0.6-TODO-164) or with no cap, the degenerate draws are dropped and the interval
	# is plausible.
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 201, show_progress = FALSE,
		min_fraction_usable_samples = 0.95))
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "m_out_of_n_too_few_usable_draws_fraction")
	for (frac in c(0.8, 0)) {
		r = ci_and_reason_160(function() inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 201, show_progress = FALSE,
			min_fraction_usable_samples = frac))
		expect_true(all(is.finite(r$ci)), info = frac)
		expect_null(r$reason)
		expect_true(r$ci[1L] > 0.3 && r$ci[2L] < 20, info = frac)
	}
	r_default = ci_and_reason_160(function() inf$compute_m_out_of_n_bootstrap_confidence_interval(B = 201, show_progress = FALSE))
	expect_identical(r_default$ci, r$ci)
	r = ci_and_reason_160(function() inf$compute_subsampling_confidence_interval(B = 201, show_progress = FALSE))
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
})

test_that("log-scale basic and Bayesian basic / Wald risk-ratio intervals run the extreme checks", {
	# Control arm with two events: the basic interval was [1.4e-8, 20], returned silently.
	des = incid_rr_fixture_175(40L, 8L, function(w, X){
		y = stats::rbinom(40L, 1, 0.5)
		y[w == 0] = 0L
		y[which(w == 0)[1:2]] = 1L
		y
	})
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "basic", show_progress = FALSE))
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
	# The Bayesian log-scale intervals on the same data are plausible and kept.
	for (type in c("basic", "wald")) {
		r = ci_and_reason_160(function() inf$compute_bayesian_bootstrap_confidence_interval(B = 201, type = type, show_progress = FALSE))
		expect_true(all(is.finite(r$ci)))
		expect_null(r$reason)
	}
	# A regular fixture keeps its basic intervals.
	des = incid_rr_fixture_175(60L, 5L, function(w, X) stats::rbinom(60L, 1, stats::plogis(-0.3 + 0.8 * w + 0.5 * X$x)))
	inf = InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
	inf$num_cores = 1L
	r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "basic", show_progress = FALSE))
	expect_true(all(is.finite(r$ci)))
	expect_null(r$reason)
	expect_equal(r$ci, c(0.8058, 2.5675), tolerance = 1e-3)
	# A degenerate Bayesian Wald interval is rejected by the same rule.
	p = inf$.__enclos_env__$private
	expect_true(p$bootstrap_confidence_interval_extreme(exp(log(1.5) + c(-1, 1) * 1.96 * 6), est = 1.5,
		theta = exp(rnorm(200, log(1.5), 6))))
})

test_that("the KK risk-ratio basic bootstrap interval runs the extreme check", {
	set.seed(10)
	n_pairs = 12L
	n = 2L * n_pairs
	x = rnorm(n)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", m = rep(seq_len(n_pairs), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	w = rep(c(0, 1), n_pairs)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.5 + 1.5 * w + 0.4 * x)))
	inf = suppressWarnings(InferenceIncidKKGCompRiskRatio$new(des, model_formula = ~ x, verbose = FALSE))
	inf$num_cores = 1L
	expect_true(inf$.__enclos_env__$private$bootstrap_estimand_is_raw_ratio())
	# Was [7.6e-9, 12.2], returned silently.
	r = ci_and_reason_160(function() inf$compute_bootstrap_confidence_interval(B = 201, type = "basic", show_progress = FALSE))
	expect_true(all(is.na(r$ci)))
	expect_identical(r$reason, "bootstrap_extreme_confidence_interval")
})
