# v1.0.6-TODO-217 (1): a KK IVWC class's Bayesian-bootstrap replicate must be a weighted refit
# of its own estimator. Classes without compute_weighted_estimate_ivwc() used to fall through
# to the KK compound's generic fallback, a weighted raw mean difference of
# KKstats$y_matched_diffs and the reservoir responses pooled with the observed w_star. For
# InferenceSurvivalKKStratCoxPHIVWC (no y_matched_diffs) every replicate was 0 and the CI
# [0, 0]; the other Cox / AFT / logit / OLS classes got replicates of a different, raw-scale
# quantity. The fixed classes refit both halves under the weights and pool them by inverse
# variance (v1.0.6-TODO-132 rule); the classes without a weighted refit opt out.

kk_bb_design = function(response_type, seed = 1L, n = 80L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), b = rbinom(n, 1, 0.4))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE, design_formula = ~ x1 + x2 + b)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = 0.5 * w + 0.6 * X$x1[i] - 0.3 * X$x2[i] + 0.4 * X$b[i]
		y = switch(response_type,
			incidence = rbinom(1, 1, plogis(eta)),
			continuous = eta + rnorm(1),
			survival = rexp(1, exp(-eta)))
		des$add_one_subject_response(i, y)
	}
	des
}

quiet_bb = function(expr) suppressWarnings(suppressMessages(expr))

# A replicate at weights 1 + 1e-7 * noise (not "effectively constant", so the weighted
# refit runs) must equal the point estimate: the weighted refit is the same estimator.
expect_near_uniform_replicate_is_estimate = function(inf, tolerance = 1e-5){
	est = quiet_bb(inf$compute_estimate())
	p = inf$.__enclos_env__$private
	draw = p$bayesian_bootstrap_sample_weight_draws(B = 1L, weighting_unit_type = NULL)[[1L]]
	p$current_bayesian_bootstrap_context = draw$context
	set.seed(9)
	weights = 1 + 1e-7 * runif(length(draw$subject_or_block_weights))
	expect_false(weights_are_effectively_constant(weights))
	rep = quiet_bb(inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE))
	expect_equal(rep, est, tolerance = tolerance)
	# The isolation wrapper restores the point estimate afterwards.
	expect_identical(quiet_bb(inf$compute_estimate()), est)
	est
}

# The replicates are on the estimate's scale: finite, not constant, centred within a few
# standard errors of the estimate, with spread comparable to the asymptotic SE.
expect_bb_replicates_on_estimate_scale = function(inf, B = 60L){
	est = quiet_bb(inf$compute_estimate())
	ci = quiet_bb(inf$compute_asymp_confidence_interval())
	se = (ci[2] - ci[1]) / (2 * qnorm(0.975))
	set.seed(5)
	bb = quiet_bb(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE))
	expect_true(all(is.finite(bb)))
	expect_gt(sd(bb), 0.25 * se)
	expect_lt(sd(bb), 4 * se)
	expect_lt(abs(mean(bb) - est), 1.5 * se)
	bb
}

fixed_cases = list(
	list(gen = "InferenceSurvivalKKStratCoxPHIVWC", rt = "survival"),
	list(gen = "InferenceSurvivalKKLWACoxPHIVWC", rt = "survival"),
	list(gen = "InferenceContinKKOLSIVWC", rt = "continuous"),
	list(gen = "InferenceIncidKKCondLogitIVWC", rt = "incidence"),
	list(gen = "InferenceAllKKMeanDiffIVWC", rt = "continuous"),
	list(gen = "InferenceIncidKKNewcombeRiskDiff", rt = "incidence"),
	# v1.0.6-TODO-235 (2): weighted quantreg::rq() refits of both halves.
	list(gen = "InferenceContinKKQuantileRegrIVWC", rt = "continuous")
)

for (case in fixed_cases) {
	local({
		cs = case
		test_that(paste0(cs$gen, ": a near-uniform Bayesian-bootstrap replicate is the point estimate"), {
			if (cs$rt == "survival") skip_if_not_installed("survival")
			if (identical(cs$gen, "InferenceContinKKQuantileRegrIVWC")) skip_if_not_installed("quantreg")
			for (seed in 1:2) {
				inf = get(cs$gen)$new(kk_bb_design(cs$rt, seed = seed), verbose = FALSE)
				inf$num_cores = 1L
				expect_near_uniform_replicate_is_estimate(inf)
			}
		})
		test_that(paste0(cs$gen, ": Bayesian-bootstrap replicates are on the estimate's scale"), {
			if (cs$rt == "survival") skip_if_not_installed("survival")
			if (identical(cs$gen, "InferenceContinKKQuantileRegrIVWC")) skip_if_not_installed("quantreg")
			inf = get(cs$gen)$new(kk_bb_design(cs$rt, seed = 1L), verbose = FALSE)
			inf$num_cores = 1L
			expect_bb_replicates_on_estimate_scale(inf)
		})
	})
}

test_that("KK StratCox IVWC: the Bayesian-bootstrap CI is no longer [0, 0]", {
	skip_if_not_installed("survival")
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_bb_design("survival", seed = 1L), verbose = FALSE)
	inf$num_cores = 1L
	set.seed(3)
	bb = quiet_bb(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 40, show_progress = FALSE))
	expect_false(any(bb == 0))
	set.seed(3)
	ci = quiet_bb(inf$compute_bayesian_bootstrap_confidence_interval(B = 40, type = "percentile", show_progress = FALSE))
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], quiet_bb(inf$compute_estimate()))
	expect_gt(ci[2], quiet_bb(inf$compute_estimate()))
})

test_that("KK RankRegr IVWC: Bayesian-bootstrap replicates are weighted aftsrr refits", {
	skip_if_not_installed("aftgee")
	inf = InferenceSurvivalKKRankRegrIVWC$new(kk_bb_design("survival", seed = 1L, n = 60L), verbose = FALSE)
	inf$num_cores = 1L
	# The ISMB variances are a seeded multiplier bootstrap whose seed hashes the data,
	# weights included, so a near-uniform replicate moves the IVW weights slightly.
	expect_near_uniform_replicate_is_estimate(inf, tolerance = 0.05)
	est = quiet_bb(inf$compute_estimate())
	set.seed(5)
	bb = quiet_bb(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 8, show_progress = FALSE))
	expect_true(all(is.finite(bb)))
	# The old fallback averaged raw survival-time differences (around 2.3 on this fixture).
	expect_lt(abs(mean(bb) - est), 0.6)
})

refused = list(
	InferenceBaiAdjustedTKK14 = "continuous",
	InferenceBaiAdjustedTKK21 = "continuous",
	InferenceContinKKRobustRegrIVWC = "continuous",
	InferenceSurvivalGLMMWeibullFrailtyNormalIVWC = "survival",
	InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik = "survival",
	# v1.0.6-TODO-235 (1): its own weighted hook refit a marginal-Weibull surrogate
	# (no copula, no IVW pooling), not this estimator; removed, so it refuses too.
	InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC = "survival"
)

test_that("KK compound classes without a weighted refit refuse the Bayesian bootstrap", {
	for (nm in names(refused)) {
		expect_true("bayesian_bootstrap" %in% EDI_INFERENCE_EXCLUDED_CAPABILITIES[[nm]], info = nm)
	}
	for (nm in names(refused)) {
		des = if (nm == "InferenceBaiAdjustedTKK21") {
			set.seed(4)
			d = DesignSeqOneByOneKK21$new(n = 40, response_type = "continuous", verbose = FALSE)
			for (i in 1:40) {
				w = d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
				d$add_one_subject_response(i, 0.5 * w + rnorm(1))
			}
			d
		} else kk_bb_design(refused[[nm]], seed = 1L, n = 40L)
		inf = get(nm)$new(des, verbose = FALSE)
		expect_false(inf$.__enclos_env__$private$supports_bayesian_bootstrap(), info = nm)
		expect_error(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 5, show_progress = FALSE),
			"does not support Bayesian bootstrap", info = nm)
		# A direct call of the weighted hook no longer returns a raw mean difference.
		p = inf$.__enclos_env__$private
		draw = p$bayesian_bootstrap_sample_weight_draws(B = 1L, weighting_unit_type = NULL)[[1L]]
		p$current_bayesian_bootstrap_context = draw$context
		expect_error(inf$compute_estimate_with_bootstrap_weights(draw$subject_or_block_weights, estimate_only = TRUE),
			"has no weighted refit of its estimator", info = nm)
	}
})
