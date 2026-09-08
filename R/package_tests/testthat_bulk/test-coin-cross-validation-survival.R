library(EDI)

# Cross-validation of EDI's survival rank-test randomization inference against
# coin's exact permutation distributions. See helper-coin-cross-validation.R
# for the principle, design choice and the two-sided p-value convention.
#
# Both survival statistics are real-valued, so coin's shift algorithm (full
# distribution) is unavailable and the exact one-sided tails come from coin's
# split-up algorithm. As a supplementary distribution-level check that is
# independent of coin, the exact null CDF is also computed by exhaustive
# enumeration of all choose(12, 6) = 924 allocations of the linear statistic
# (labelled "enumeration" below); it is not a coin quantity.

coin_cv_survival_design = function(n, tt, dd, seed) {
	des = coin_cv_ibcrd_design(n, "survival", seed = seed)
	des$add_all_subject_responses(
		ys = ifelse(dd == 1, tt, NA),
		y_Ls = ifelse(dd == 1, NA, tt),
		y_Rs = ifelse(dd == 1, NA, Inf)
	)
	des
}

coin_cv_enumerated_cdf_deviation = function(mapped_draws, scores, n_T) {
	n = length(scores)
	combos = utils::combn(n, n_T)
	all_T = round(apply(combos, 2, function(idx) sum(scores[idx])), 8)
	supp = sort(unique(all_T))
	p = as.numeric(table(factor(all_T, levels = supp))) / ncol(combos)
	coin_cv_max_cdf_deviation(mapped_draws, list(t = supp, p = p))
}

# ---------------------------------------------------------------------------
# InferenceSurvivalLogRank  <->  coin::logrank_test(Surv(t, d) ~ w, exact)
#
# Derivation. EDI's randomization statistic is the difference in mean
# martingale residuals under the pooled null hazard, M_i = d_i - Lambda_hat(t_i)
# with the Nelson-Aalen (Breslow-tie) cumulative hazard of the pooled sample
# (inference_survival_log_rank.R, fast_logrank_stats_cpp()). Under a label
# permutation the pooled sample is unchanged, so the M_i are fixed per-subject
# scores; since sum_i M_i = 0 (total observed = total expected),
#   mean_T(M) - mean_C(M) = S_T / n_T + S_T / n_C,  S_T = sum_{i in T} M_i.
# coin's log-rank scores (logrank_trafo, default ties.method = "mid-ranks") are
# a_i = Lambda_hat(t_i) - d_i = -M_i (verified numerically below, including at
# tied event times -- the "Hothorn-Lausen" and "average-scores" tie methods do
# NOT reproduce EDI's statistic), so EDI's statistic is a *decreasing* affine
# map, slope -(1/n_T + 1/n_C), of coin's linear statistic sum_{i in T} a_i.
# Tail probabilities are therefore swapped: P_EDI(t0 >= t) = P_coin(T <= T_obs).
# ---------------------------------------------------------------------------
test_that("log-rank randomization tails match coin's exact logrank_test one-sided p-values (with tied event times)", {
	skip_if_not_installed("coin")
	skip_if_not_installed("survival")
	n = 12L
	r = 20000L
	tt = c(1, 2, 2, 3, 3, 3, 4, 5, 5, 6, 7, 8)
	dd = c(1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1)
	des = coin_cv_survival_design(n, tt, dd, seed = 20260915L)
	w = des$get_w()
	n_T = sum(w == 1)
	n_C = n - n_T
	expect_equal(n_T, 6L)

	lr = InferenceSurvivalLogRank$new(des)
	perms = coin_cv_permutations(des, r, seed = 31L)
	expect_true(all(colSums(perms$w_mat) == n_T))
	set.seed(32L)
	t0s = lr$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = lr$compute_estimate()

	S = survival::Surv(tt, dd)
	scores = as.numeric(coin::logrank_trafo(S))
	expect_equal(sum(scores), 0, tolerance = 1e-10)
	lin = colSums(scores * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, -(1 / n_T + 1 / n_C), tolerance = 1e-8)
	expect_equal(map$a, 0, tolerance = 1e-8)
	# the other coin tie conventions are NOT affine in EDI's statistic
	for (tm in c("Hothorn-Lausen", "average-scores")) {
		lin_alt = colSums(as.numeric(coin::logrank_trafo(S, ties.method = tm)) * perms$w_mat)
		expect_false(coin_cv_affine_map(t0s, lin_alt)$ok, info = tm)
	}

	dat = data.frame(tt = tt, dd = dd, w = factor(w, levels = c(1, 0)))
	co = coin::logrank_test(survival::Surv(tt, dd) ~ w, data = dat, distribution = coin::exact(algorithm = "split-up"))
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(T_obs, sum(scores[w == 1]), tolerance = 1e-10)
	expect_equal(t_obs, map$a + map$b * T_obs, tolerance = 1e-8)
	ex_coin = coin_cv_splitup_tails(survival::Surv(tt, dd) ~ w, dat)
	# decreasing map: swap the tails
	ex = list(ge = ex_coin$le, le = ex_coin$ge)

	set.seed(32L)
	p_edi = lr$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))

	max_dev = coin_cv_enumerated_cdf_deviation(coin_cv_to_linear(t0s, map), scores, n_T)
	expect_lt(max_dev, coin_cv_dkw_bound(r))
	cat(sprintf("\n[coin-cv] log-rank/iBCRD: EDI p = %.4f, exact doubled-min p = %.4f (coin two-sided p = %.4f); tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev (enumeration) = %.4f (DKW %.4f)\n",
		p_edi, p_exact, as.numeric(coin::pvalue(co)), emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r)))
})

# ---------------------------------------------------------------------------
# InferenceSurvivalGehanWilcox  <->  coin::independence_test on EDI's own
# scores -- with an honest NEGATIVE against coin's weighted log-rank types.
#
# EDI's statistic is the difference in mean *Peto-Prentice-weighted martingale
# residuals*, a_i = S_KM(t_i-) * M_i with M_i the (Breslow-tie) martingale
# residual and S_KM the pooled Kaplan-Meier estimate just before t_i
# (inference_survival_gehan_wilcox.R, fast_gehan_wilcox_stats_cpp()). This is
# NOT the Gehan-Breslow / Peto-Peto / Prentice weighted log-rank score
# statistic: those apply the weight inside the cumulative-hazard sum
# (sum_j w_j (d_Tj - e_Tj)), whereas EDI weights each subject's whole residual
# by S(t_i-). A probe over random permutations found the best |correlation|
# with any coin::logrank_trafo type to be ~0.98 (Gehan-Breslow), not 1, so no
# equivalence with coin::logrank_test(type = "Gehan-Breslow") is asserted; the
# test below asserts that non-equivalence explicitly. What does hold: the a_i
# are fixed per-subject scores under permutation, so EDI's statistic is affine
# in S_T = sum_{i in T} a_i and its randomization distribution must equal the
# exact permutation distribution of that linear statistic, which coin's
# independence_test computes for user-supplied scores (identity ytrafo,
# split-up algorithm). This validates EDI's permutation engine and the
# design's reference set for this class, not the score definition.
# ---------------------------------------------------------------------------
test_that("Gehan-Wilcoxon (Peto-Prentice weighted residual) randomization tails match coin's exact permutation distribution of EDI's own scores, and are NOT coin's Gehan-Breslow test", {
	skip_if_not_installed("coin")
	skip_if_not_installed("survival")
	n = 12L
	r = 20000L
	tt = c(1, 2, 2, 3, 3, 3, 4, 5, 5, 6, 7, 8)
	dd = c(1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1)
	des = coin_cv_survival_design(n, tt, dd, seed = 20260916L)
	w = des$get_w()
	n_T = sum(w == 1)
	n_C = n - n_T

	gw = InferenceSurvivalGehanWilcox$new(des)
	perms = coin_cv_permutations(des, r, seed = 33L)
	set.seed(34L)
	t0s = gw$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = gw$compute_estimate()

	# EDI's scores from external tools only: coin's log-rank scores are -M_i
	# (Breslow-tie Nelson-Aalen), KM from survival::survfit on the pooled sample
	S = survival::Surv(tt, dd)
	M = -as.numeric(coin::logrank_trafo(S))
	km = survival::survfit(S ~ 1)
	idx = findInterval(tt, km$time, left.open = TRUE)
	S_minus = c(1, km$surv)[idx + 1L]
	scores = S_minus * M
	lin = colSums(scores * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / n_T + 1 / n_C, tolerance = 1e-8)
	expect_equal(map$a, -sum(scores) / n_C, tolerance = 1e-8)
	expect_equal(t_obs, map$a + map$b * sum(scores[w == 1]), tolerance = 1e-8)

	# honest negative: not affine in any of coin's weighted log-rank score types
	for (ty in c("Gehan-Breslow", "Peto-Peto", "Prentice", "Tarone-Ware")) {
		lin_alt = colSums(as.numeric(coin::logrank_trafo(S, type = ty)) * perms$w_mat)
		expect_false(coin_cv_affine_map(t0s, lin_alt)$ok, info = ty)
	}

	dat = data.frame(scores = scores, w = factor(w, levels = c(1, 0)))
	ex = coin_cv_splitup_tails(scores ~ w, dat, ytrafo = coin_cv_identity_ytrafo)
	set.seed(34L)
	p_edi = gw$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))

	max_dev = coin_cv_enumerated_cdf_deviation(coin_cv_to_linear(t0s, map), scores, n_T)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	# for the record: coin's Gehan-Breslow exact test p on the same data
	co_gb = coin::logrank_test(survival::Surv(tt, dd) ~ w, data = data.frame(tt = tt, dd = dd, w = factor(w, levels = c(1, 0))),
		distribution = coin::exact(algorithm = "split-up"), type = "Gehan-Breslow")
	cat(sprintf("\n[coin-cv] Gehan-Wilcoxon/iBCRD: EDI p = %.4f, exact doubled-min p (EDI scores via coin) = %.4f; tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev (enumeration) = %.4f (DKW %.4f); coin Gehan-Breslow two-sided p = %.4f (different statistic, not compared)\n",
		p_edi, p_exact, emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r), as.numeric(coin::pvalue(co_gb))))
})
