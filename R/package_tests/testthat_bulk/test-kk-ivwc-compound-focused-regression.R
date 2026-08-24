library(testthat)
library(EDI)

# Focused regression tests for the "KK And IVWC Estimators" section of
# fix_inference_hierarchy.md's follow-up item: "Add focused KK regression
# tests for matched-set weights, IVWC weighting, rank reduction, nonestimable
# fits, and block/cluster edge cases." InferenceContinKKOLSIVWC
# (inference_continuous_KK_ols_ivwc.R) was chosen as the single class family
# to cover all five behaviors authentically in one place:
#   - matched-set weights / block-cluster structure: KKstats$m matched pairs
#     vs. KKstats$nRT/nRC reservoir treatment/control counts, and the
#     matched-pair-differenced regression's degenerate df=0 case (a single
#     matched pair).
#   - IVWC weighting: the point estimate is a genuine inverse-variance-
#     weighted combination `w_star = ssq_r / (ssq_r + ssq_m)` of a matched-
#     pair-differenced OLS fit and a reservoir OLS fit (see
#     inference_continuous_KK_ols_ivwc.R's `shared()`), with the compound
#     dispatch machinery (`reduce_design_matrix_once`,
#     `only_matches`/`only_reservoir`) shared with every other KK compound
#     estimator via the composed `KKCompound` component
#     (inference_mixin_kk_passthrough_compound.R).
#   - rank reduction: `reduce_design_matrix_once()` QR-reduces a
#     rank-deficient design matrix while always preserving the treatment
#     column, caching only the column-keep decision (keyed by input column
#     count) rather than a frozen matrix -- see that function's own comment
#     for why (a real bug class it was written to prevent: stale cached
#     reductions surviving an nRT==0/nRC==0 branch flip).
#   - nonestimable fits: `fit_ols_with_treatment()` returns NULL (and the
#     caller sets NA_real_ throughout) whenever `nrow(X) <= ncol(X)` or the
#     fitted coefficient/SE is non-finite; `shared()`'s `m_ok`/`r_ok` guards
#     then fall back to whichever sub-fit is usable, or NA if neither is.
#
# Configurations below were found empirically (fixed seeds + covariate
# spread/drift tuned to land in the desired KKstats$m/nRT/nRC regime) rather
# than engineered analytically, since DesignSeqOneByOneKK14's Mahalanobis-
# distance matching threshold is adaptive (scales with n and covariate rank)
# -- see that class's own header comment. Each helper's target regime is
# verified by an explicit `expect_identical()`/`expect_true()` on the
# resulting KKstats counts before testing anything else, so a change in the
# design's matching behavior in the future will fail loudly at that
# assertion (naming the actual problem) instead of silently degrading these
# tests into exercising the wrong code path.

kk_ivwc_design = function(n, seed, spread, drift = 0, collinear = FALSE) {
	set.seed(seed)
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		x1 = rnorm(1L, sd = spread) + i * drift
		x2 = if (collinear) 2 * x1 + 5 + rnorm(1L, sd = 1e-6) else rnorm(1L, sd = spread) + i * drift
		w_i = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = x2))
		des$add_one_subject_response(i, 0.4 * ((w_i + 1) / 2) + 0.2 * x1 + rnorm(1L, sd = 0.5))
	}
	des
}

test_that("IVWC combines matched-pair and reservoir estimates by inverse-variance weight", {
	des = kk_ivwc_design(n = 20L, seed = 6L, spread = 100, drift = 300)
	inf = InferenceContinKKOLSIVWC$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	est = inf$compute_estimate()
	inf$compute_asymp_confidence_interval()
	cv = inf$.__enclos_env__$private$cached_values

	# Both sub-fits must be usable for this to be a real combination test,
	# not a degenerate fallback (see the "matched-set sub-fit failure" test
	# below for the fallback case).
	expect_true(cv$KKstats$m > 1L)
	expect_true(cv$KKstats$nRT > 1L && cv$KKstats$nRC > 1L)
	expect_true(is.finite(cv$ssq_beta_T_matched) && cv$ssq_beta_T_matched > 0)
	expect_true(is.finite(cv$ssq_beta_T_reservoir) && cv$ssq_beta_T_reservoir > 0)

	w_star = cv$ssq_beta_T_reservoir / (cv$ssq_beta_T_reservoir + cv$ssq_beta_T_matched)
	expect_equal(est, w_star * cv$beta_T_matched + (1 - w_star) * cv$beta_T_reservoir, tolerance = 1e-10)
	# The combined estimate must lie strictly between the two sub-estimates
	# (a genuine weighted average, not one side dominating outright).
	expect_true(est >= min(cv$beta_T_matched, cv$beta_T_reservoir))
	expect_true(est <= max(cv$beta_T_matched, cv$beta_T_reservoir))
})

test_that("a single matched pair (zero within-pair df) falls back to the reservoir estimate exactly", {
	des = kk_ivwc_design(n = 20L, seed = 2L, spread = 100, drift = 300)
	inf = InferenceContinKKOLSIVWC$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	est = inf$compute_estimate()
	inf$compute_asymp_confidence_interval()
	cv = inf$.__enclos_env__$private$cached_values

	# Block/cluster edge case: exactly one matched pair means the within-pair
	# differenced regression has 1 row and >=1 predictor columns, so
	# fit_ols_with_treatment()'s `nrow(X) <= ncol(X)` guard rejects it.
	expect_identical(cv$KKstats$m, 1L)
	expect_true(is.na(cv$ssq_beta_T_matched))
	expect_true(is.finite(cv$ssq_beta_T_reservoir) && cv$ssq_beta_T_reservoir > 0)
	expect_identical(est, cv$beta_T_reservoir)
})

test_that("rank-deficient covariates are QR-reduced to the same fit a manual reduction produces", {
	des = kk_ivwc_design(n = 20L, seed = 6L, spread = 100, drift = 300, collinear = TRUE)
	inf = InferenceContinKKOLSIVWC$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	est = inf$compute_estimate()
	cv = inf$.__enclos_env__$private$cached_values

	# x2 = 2*x1 + noise makes both the matched-diff and reservoir design
	# matrices numerically rank-deficient; confirm the fixture actually
	# landed in that regime before testing the reduction itself.
	Xd = as.matrix(cv$KKstats$X_matched_diffs)
	Xd_full = if (ncol(Xd) > 0L) cbind(1, Xd) else matrix(1, nrow = length(cv$KKstats$y_matched_diffs), ncol = 1L)
	expect_true(qr(Xd_full)$rank < ncol(Xd_full))
	expect_false(is.na(est))

	# Cross-check against reduce_design_matrix_once() applied directly to a
	# freshly-built copy of the matched design matrix, then a plain lm.fit()
	# on the reduced matrix -- this exercises the exact same reduction
	# function the class itself calls, without re-deriving its pivot logic
	# by hand (which would just test my own re-implementation, not theirs).
	priv = inf$.__enclos_env__$private
	reduced = priv$reduce_design_matrix_once(Xd_full, 1L, cache_key = "test_manual_reduction_check")
	manual_fit = lm.fit(reduced$X, cv$KKstats$y_matched_diffs)
	expect_equal(unname(coef(manual_fit)[reduced$j_treat]), cv$beta_T_matched, tolerance = 1e-8)
})

test_that("a KK design too small to estimate either sub-fit returns NA cleanly, not an error", {
	des = kk_ivwc_design(n = 3L, seed = 42L, spread = 1)
	inf = InferenceContinKKOLSIVWC$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	cv_before = inf$.__enclos_env__$private$cached_values

	est = inf$compute_estimate()
	ci = inf$compute_asymp_confidence_interval()
	pval = inf$compute_asymp_two_sided_pval()
	cv = inf$.__enclos_env__$private$cached_values

	# Block/cluster edge case: n=3 is too small to ever form a matched pair
	# under DesignSeqOneByOneKK14's adaptive caliper, and the resulting
	# reservoir has fewer rows than predictor columns (intercept + treatment
	# + 2 covariates = 4 columns vs. <=3 reservoir subjects).
	expect_identical(cv$KKstats$m, 0L)
	expect_true(is.na(cv$beta_T_matched) || is.null(cv$beta_T_matched))

	expect_true(is.na(est))
	expect_true(all(is.na(ci)))
	expect_true(is.na(pval))
})
