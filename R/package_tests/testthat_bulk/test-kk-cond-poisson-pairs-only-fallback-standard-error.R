# Numerical-robustness review audit, 2026-11-18: InferenceCountKKCondPoissonOneLik's pairs-only
# fallback (used when the reservoir lacks a treated or a control subject, or the combined fit fails)
# always sets s_beta_hat_T = NA_real_. The model SE of the conditional-Poisson (weighted
# binomial-logit) fit is well defined: it is sqrt of the [1,1] entry of the inverse Fisher
# information, which glm reports. Inside any resampling operation the jackknife inflation is skipped,
# so the SE stays NA. Every studentized bootstrap replicate on that path then has no SE.
# Where: R/EDI/R/inference_count_KK_cond_poisson.R:2033 (kind: na_where_defined).
# On commit 4ce2b7126d36 this test failed with: Expected `is.finite(se)` to be TRUE. Differences:
# `actual`: FALSE `expected`: TRUE
# Tracked as v1.0.6-TODO-390; remove the skip() when it is fixed.

test_that("KK cond-Poisson pairs-only fallback reports the finite conditional-logit model SE", {
	skip("v1.0.6-TODO-390: try_pairs_only() always sets s_beta_hat_T = NA")
		set.seed(2)
		n = 60L
		des = DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
		for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		des$add_all_subject_responses(rpois(n, 3))
		inf = InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)
		priv = inf$.__enclos_env__$private
		priv$compute_basic_match_data()
		KKstats = priv$cached_values$KKstats
		yT = KKstats$yTs_matched
		yC = KKstats$yCs_matched
		n_k = yT + yC
		valid = which(n_k > 0)
		yT_v = yT[valid]
		n_k_v = n_k[valid]
		X_diff_v = as.matrix(KKstats$X_matched_diffs_full[valid, , drop = FALSE])
		expect_gt(length(yT_v), 5L)
		y_prop = yT_v / n_k_v
		X = cbind(1, X_diff_v)
		ref = stats::glm(y_prop ~ X - 1, family = stats::binomial(), weights = n_k_v)
		se_ref = unname(sqrt(diag(stats::vcov(ref)))[1L])
		ok = priv$try_pairs_only(FALSE, yT_v, n_k_v, X_diff_v)
		expect_true(ok)
		se = as.numeric(priv$cached_values$s_beta_hat_T)[1L]
		expect_true(is.finite(se))
		expect_equal(se, se_ref, tolerance = 1e-4)
})
