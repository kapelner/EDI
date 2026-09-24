library(testthat)
library(EDI)
library(survival)                                                                  # clogit()'s internal coxph()/strata() calls need it attached, not just namespaced

# conditional_logit_prepare_combined_design()'s data-construction branches, as reached via
# InferenceIncidKKCondLogitOneLik's private shared_combined_likelihood() (inference_incidence_KK_
# cond_logit.R), have the same three-way matched-pairs/reservoir structure as the continuous OneLik
# siblings whose pairs-only/reservoir-only branches were closed the last few iterations (OLS,
# robust-regr, quantile-regr). The combined (both present) branch and the fit-failure/no-informative-
# data guards are already covered (test-kk-clogit-onelik-combined-fit-and-design-guards-reference.R),
# but the matched-pairs-only (McNemar-style discordant-pairs conditional logit, a materially different
# code path -- collect_discordant_pairs_cpp() rather than build_matching_combined_clogit_design_cpp())
# and reservoir-only branches had no reference anywhere. Forced here by mutating the class's own
# already-cached KKstats partition. Verified against genuinely independent R references: the
# pairs-only branch is conditional logistic regression on the matched pairs, so it's checked against
# survival::clogit(strata = pair); the reservoir-only branch against glm(family = binomial()).
#   1. Matched-pairs-only (nRT forced to 0): closely matches an independent
#      survival::clogit(y ~ w + x1 + strata(pair), method = "exact") fit (small optimizer-tolerance
#      difference between the two independent implementations, same as this session's established
#      pattern for other KK fast-vs-reference comparisons).
#   2. Reservoir-only (m forced to 0): matches an independent glm(y ~ w + X, family = binomial())
#      fit closely.

clogit_onelik_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidKKCondLogitOneLik$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv, KKstats = priv$cached_values$KKstats)
}

test_that("matched-pairs-only (no reservoir) closely matches an independent survival::clogit() fit on the same matched pairs", {
	f <- clogit_onelik_fixture(1L)
	expect_gt(f$KKstats$m, 0L)
	f$priv$cached_values$KKstats$nRT <- 0L                                         # force the pairs-only branch

	f$priv$shared_combined_likelihood(estimate_only = TRUE)
	split <- EDI:::split_kk_matched_reservoir_idx(f$priv$m, f$priv$n)
	i_matched <- split$matched_idx
	dat <- data.frame(
		y = f$priv$y[i_matched], w = f$priv$w[i_matched],
		x1 = f$priv$get_X()[i_matched, 1L], pair = split$m_vec[i_matched]
	)
	ref <- clogit(y ~ w + x1 + strata(pair), data = dat, method = "exact")
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)["w"]), tolerance = 1e-3)
})

test_that("reservoir-only (no matched pairs) matches an independent glm(binomial()) fit on the reservoir data", {
	f <- clogit_onelik_fixture(2L)
	expect_gt(f$KKstats$nRT, 0L)
	expect_gt(f$KKstats$nRC, 0L)
	f$priv$cached_values$KKstats$m <- 0L                                           # force the reservoir-only branch

	f$priv$shared_combined_likelihood(estimate_only = TRUE)
	X_r <- as.matrix(f$KKstats$X_reservoir)
	ref <- glm(f$KKstats$y_reservoir ~ f$KKstats$w_reservoir + X_r, family = binomial())
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[2]), tolerance = 1e-5)
})
