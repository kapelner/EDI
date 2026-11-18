# v1.0.6-TODO-123: on a rank-deficient draw the reusable bootstrap/jackknife worker sets
# private$X to NULL so the covariate matrix is rebuilt from the resampled design
# (load_bootstrap_sample_into_design_backed_worker). Classes that read private$X directly
# then either errored (as.matrix(NULL): KK OLS/RobustRegr/GLMM/Hurdle/CondLogit/RankRegr,
# StratCox) or silently fit the treatment-only model (X_cov = private$X then
# is.null(X_cov): logit, probit, modified Poisson, risk diff, quasi-Poisson, beta, ordinal
# regressions, Weibull, dep-cens transform, KK cond Poisson). They now read
# private$get_X(), which returns private$X whenever it is set, so full-data fits are
# unchanged. Each worker replicate must equal the slow-path refit on the same rows.

rank_deficient_worker_y = list(
	continuous = function(n, w) rnorm(n) + w,
	incidence = function(n, w) rbinom(n, 1, stats::plogis(-0.3 + 0.8 * w)),
	proportion = function(n, w) stats::plogis(rnorm(n) + w),
	count = function(n, w) rpois(n, exp(0.5 + 0.4 * w)),
	ordinal = function(n, w) as.integer(cut(rnorm(n) + w, c(-Inf, -0.5, 0.5, 1.2, Inf))),
	survival = function(n, w) stats::rexp(n, exp(-0.5 * w))
)

# Leave-one-block-out on a blocking design whose formula names the strata: the dropped
# stratum's dummy is constant, so every deletion draw is rank-deficient.
rank_deficient_blocking_design = function(response_type, n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), s = factor(rep(c("a", "b", "c"), each = n / 3)))
	des = DesignFixedBlocking$new(strata_cols = "s", response_type = response_type, n = n, seed = 1,
		design_formula = ~ x + s, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rank_deficient_worker_y[[response_type]](n, des$get_w()))
	des
}

# KK14 design with a rare binary covariate: a bootstrap draw that omits both carriers
# makes that column constant.
rank_deficient_kk_design = function(response_type, n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), r = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE, design_formula = ~ x + r)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, rank_deficient_worker_y[[response_type]](1L, w_i))
	}
	des
}

expect_worker_matches_slow_path = function(inf, draw){
	p = inf$.__enclos_env__$private
	expect_true(isTRUE(p$use_reusable_bootstrap_worker()))
	full_before = inf$compute_estimate()
	ws = p$create_reusable_bootstrap_worker()
	p$load_bootstrap_sample_into_worker(ws, draw)
	expect_null(ws$worker_priv$X)
	theta_worker = suppressWarnings(p$compute_bootstrap_worker_estimate(ws))
	theta_slow = suppressWarnings(p$bootstrap_subset_inference(draw)$compute_estimate())
	expect_true(is.finite(theta_worker))
	expect_equal(theta_worker, theta_slow, tolerance = 1e-6)
	expect_identical(inf$compute_estimate(), full_before)
}

rank_deficient_blocking_classes = list(
	incidence = c("InferenceIncidLogRegr", "InferenceIncidProbitRegr", "InferenceIncidModifiedPoisson",
		"InferenceIncidRiskDiff"),
	count = c("InferenceCountQuasiPoisson"),
	proportion = c("InferencePropBetaRegr"),
	ordinal = c("InferenceOrdinalPropOddsRegr", "InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr",
		"InferenceOrdinalOrderedProbitRegr", "InferenceOrdinalAdjCatLogitRegr", "InferenceOrdinalContRatioRegr",
		"InferenceOrdinalGCompMeanDiff", "InferenceOrdinalStereotypeLogitRegr"),
	survival = c("InferenceSurvivalWeibullRegr", "InferenceSurvivalDepCensTransformRegr",
		"InferenceSurvivalStratCoxPHRegr")
)

for (rt in names(rank_deficient_blocking_classes)) local({
	rt = rt
	des = rank_deficient_blocking_design(rt)
	for (cls in rank_deficient_blocking_classes[[rt]]) local({
		cls = cls
		test_that(paste0(cls, ": reusable worker on a leave-one-block-out draw equals the subset refit"), {
			inf = suppressWarnings(get(cls)$new(des$duplicate(verbose = FALSE), verbose = FALSE))
			draws = inf$.__enclos_env__$private$build_jackknife_deletion_draws(unit = "block")
			expect_worker_matches_slow_path(inf, draws[[1L]])
		})
	})
})

rank_deficient_kk_classes = list(
	continuous = c("InferenceContinKKOLSIVWC", "InferenceContinKKOLSOneLik", "InferenceContinKKRobustRegrIVWC",
		"InferenceContinKKRobustRegrOneLik"),
	incidence = c("InferenceIncidKKCondLogitOneLik"),
	count = c("InferenceCountKKGLMM", "InferenceCountKKHurdlePoissonIVWC", "InferenceCountKKHurdlePoissonOneLik",
		"InferenceCountKKCondPoissonOneLik"),
	ordinal = c("InferenceOrdinalKKGLMM"),
	survival = c("InferenceSurvivalKKRankRegrIVWC")
)

for (rt in names(rank_deficient_kk_classes)) local({
	rt = rt
	des = rank_deficient_kk_design(rt)
	for (cls in rank_deficient_kk_classes[[rt]]) local({
		cls = cls
		test_that(paste0(cls, ": reusable worker on a draw that drops a rare covariate equals the subset refit"), {
			inf = suppressWarnings(get(cls)$new(des$duplicate(verbose = FALSE), verbose = FALSE))
			p = inf$.__enclos_env__$private
			set.seed(3)
			draw = NULL
			for (k in 1:500) {
				d = p$bootstrap_sample_indices(60L)
				if (!any(d$i_b %in% c(1L, 2L))) {
					draw = d
					break
				}
			}
			expect_false(is.null(draw))
			expect_worker_matches_slow_path(inf, draw)
		})
	})
})

test_that("InferenceSurvivalStratCoxPHRegr leave-one-block-out jackknife is finite when the formula names the strata", {
	inf = InferenceSurvivalStratCoxPHRegr$new(rank_deficient_blocking_design("survival"), verbose = FALSE)
	inf$num_cores = 1L
	jack = inf$approximate_jackknife_distribution_beta_hat_T()
	expect_length(jack, 3L)
	expect_true(all(is.finite(jack)))
})
