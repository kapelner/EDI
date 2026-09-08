library(EDI)

# Cross-validation of EDI's rank-based randomization inference against coin's
# exact permutation distributions. See helper-coin-cross-validation.R for the
# principle, the design choice (DesignFixediBCRD / DesignFixedBlocking, never
# Bernoulli), and the two-sided p-value convention difference.

# ---------------------------------------------------------------------------
# InferenceOrdinalJonckheereTerpstraTest  <->  coin::wilcox_test(exact)
#
# Derivation. For two arms the JT statistic is the Mann-Whitney U with ties
# counted 1/2 (inference_ordinal_jonckheere_terpstra_test.R,
# compute_asymptotic_jt_components(): u_stat = sum over treated of
# (#controls below + 0.5 * #controls tied)), and the class's randomization
# statistic is beta = U / (n_T n_C) - 1/2. With midranks R_i of the pooled
# sample, sum_{i in T} R_i = U + n_T (n_T + 1) / 2 (the classical identity,
# valid with ties when both sides use midranks / half-counts), so
#   beta = (T_coin - n_T (n_T + 1) / 2) / (n_T n_C) - 1/2,
# an increasing affine map of coin's wilcox_test linear statistic T_coin =
# sum of midranks in the first factor level (which we make the treated arm).
# Ties: coin's rank_trafo uses midranks, EDI counts ties as 1/2 -- identical.
# Under DesignFixediBCRD every allocation with n_T = 6 of 12 is equally likely,
# which is exactly coin's conditional reference set.
# ---------------------------------------------------------------------------
test_that("JT (two-arm Mann-Whitney) randomization distribution matches coin's exact Wilcoxon distribution, ordinal with ties", {
	skip_if_not_installed("coin")
	n = 12L
	r = 10000L
	des = coin_cv_ibcrd_design(n, "ordinal", seed = 20260907L)
	y = as.integer(c(1, 2, 2, 3, 4, 1, 3, 3, 2, 4, 1, 2))
	des$add_all_subject_responses(y)
	w = des$get_w()
	n_T = sum(w == 1)
	n_C = n - n_T
	expect_equal(n_T, 6L)

	jt = InferenceOrdinalJonckheereTerpstraTest$new(des)
	perms = coin_cv_permutations(des, r, seed = 1L)
	expect_true(all(colSums(perms$w_mat) == n_T))
	set.seed(2L)
	t0s = jt$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = jt$compute_estimate()

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)))
	co = coin::wilcox_test(y ~ w, data = dat, distribution = "exact")
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(T_obs, sum(rank(y)[w == 1]))

	# (a) exact affine identity on every permutation EDI used
	lin = colSums(rank(y) * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / (n_T * n_C), tolerance = 1e-10)
	expect_equal(t_obs, map$a + map$b * T_obs, tolerance = 1e-10)

	# (b) full null distribution: EDI ECDF vs coin's exact CDF at every support point
	dist = coin_cv_exact_linear_distribution(co)
	expect_equal(sum(dist$p), 1, tolerance = 1e-10)
	max_dev = coin_cv_max_cdf_deviation(coin_cv_to_linear(t0s, map), dist)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	# (c) p-values: EDI's doubled-min MC p vs the same rule on coin's exact tails
	set.seed(2L)
	p_edi = jt$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	ex = coin_cv_exact_tails(dist, T_obs)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))
	cat(sprintf("\n[coin-cv] JT/iBCRD: EDI p = %.4f, exact doubled-min p = %.4f (coin two-sided |T-E| p = %.4f); tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev = %.4f (DKW %.4f)\n",
		p_edi, p_exact, as.numeric(coin::pvalue(co)), emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r)))
})

# ---------------------------------------------------------------------------
# Same JT statistic under a blocked (stratified) design  <->
# coin::wilcox_test(y ~ w | block, exact).
#
# DesignFixedBlocking with explicit m = 3 blocks of 4 redraws w by complete
# randomization within each block (2 T / 2 C per block, 6^3 = 216 allocations),
# which is coin's `| block` reference set. Important detail verified in a
# probe before writing this test: with `| block`, coin's wilcox_test linear
# statistic is still the sum of *global* midranks of the first level (coin does
# not re-rank within blocks in the formula interface), matching EDI's JT
# statistic, which ignores blocks and uses the pooled U. The shift algorithm
# supports blocks with (mid)rank scores, so the full distribution is available.
# ---------------------------------------------------------------------------
test_that("JT randomization distribution under within-block complete randomization matches coin's exact blocked Wilcoxon distribution", {
	skip_if_not_installed("coin")
	n = 12L
	r = 10000L
	m = rep(1:3, each = 4L)
	des = coin_cv_blocked_design(n, "ordinal", m = m, seed = 20260908L)
	y = as.integer(c(2, 1, 3, 3, 1, 2, 2, 4, 3, 1, 4, 2))
	des$add_all_subject_responses(y)
	w = des$get_w()
	expect_true(all(tapply(w, m, sum) == 2L))
	n_T = sum(w == 1)
	n_C = n - n_T

	jt = InferenceOrdinalJonckheereTerpstraTest$new(des)
	perms = coin_cv_permutations(des, r, seed = 3L)
	expect_true(all(apply(perms$w_mat, 2, function(col) all(tapply(col, m, sum) == 2L))))
	set.seed(4L)
	t0s = jt$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = jt$compute_estimate()

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)), block = factor(m))
	co = coin::wilcox_test(y ~ w | block, data = dat, distribution = "exact")
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(T_obs, sum(rank(y)[w == 1]))

	lin = colSums(rank(y) * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / (n_T * n_C), tolerance = 1e-10)
	expect_equal(t_obs, map$a + map$b * T_obs, tolerance = 1e-10)

	dist = coin_cv_exact_linear_distribution(co)
	max_dev = coin_cv_max_cdf_deviation(coin_cv_to_linear(t0s, map), dist)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	set.seed(4L)
	p_edi = jt$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	ex = coin_cv_exact_tails(dist, T_obs)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))
	cat(sprintf("\n[coin-cv] JT/blocked: EDI p = %.4f, exact doubled-min p = %.4f (coin two-sided p = %.4f); tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev = %.4f (DKW %.4f)\n",
		p_edi, p_exact, as.numeric(coin::pvalue(co)), emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r)))
})

# ---------------------------------------------------------------------------
# InferenceAllSimpleWilcox vs coin::wilcox_test -- an honest NEGATIVE, plus the
# one exact identity that does hold.
#
# InferenceAllSimpleWilcox's randomization statistic is the Hodges-Lehmann
# estimate HL = median{ y_i - y_j : i in T, j in C } (inference_all_simple_
# wilcox.R, hl_point_estimate() / compute_wilcox_hl_distr_parallel_cpp()), NOT
# the rank-sum. HL is not a linear rank statistic and is not even a function
# of the rank-sum T: the first test below exhibits allocations with identical
# T but different HL by exhaustive enumeration. Its permutation distribution
# therefore has no coin counterpart (coin's shift on the *observed* control
# arm -- the usual HL confidence-interval inversion -- is a different null
# distribution from re-computing HL on each permuted allocation), so no
# distribution-level or p-value-level equivalence is asserted for this class.
#
# What does hold exactly, and is asserted: with no ties in the pooled sample
# and N = n_T n_C odd, HL is the ((N+1)/2)-th order statistic of the N
# pairwise differences, none of which is 0, so
#   HL > 0  <=>  #{D_ij > 0} >= (N+1)/2  <=>  U >= (N+1)/2  <=>  T >= n_T(n_T+1)/2 + (N+1)/2,
#   HL < 0  <=>  T <= n_T(n_T+1)/2 + (N-1)/2,
# hence P_perm(HL > 0) = P_coin(T >= k) and P_perm(HL < 0) = P_coin(T <= k - 1)
# with k = n_T(n_T+1)/2 + (N+1)/2. Fixture: n_T = 5, n_C = 7 (N = 35).
# ---------------------------------------------------------------------------
test_that("Hodges-Lehmann statistic is not a function of the rank-sum (why no HL <-> coin distribution equivalence is asserted)", {
	skip_if_not_installed("coin")
	set.seed(20260909L)
	n = 12L
	n_T = 5L
	y = round(rnorm(n), 3)
	expect_false(any(duplicated(y)))
	rk = rank(y)
	combos = utils::combn(n, n_T)
	stats = apply(combos, 2, function(idx) {
		d = as.numeric(outer(y[idx], y[-idx], "-"))
		c(T = sum(rk[idx]), HL = stats::median(d))
	})
	by_T = split(stats["HL", ], stats["T", ])
	n_distinct_hl_within_T = vapply(by_T, function(h) length(unique(round(h, 10))), integer(1L))
	expect_true(any(n_distinct_hl_within_T > 1L))
})

test_that("Hodges-Lehmann randomization sign probabilities equal coin's exact Wilcoxon tail probabilities (n_T n_C odd, no ties)", {
	skip_if_not_installed("coin")
	n = 12L
	n_T = 5L
	n_C = n - n_T
	N = n_T * n_C
	r = 20000L
	des = coin_cv_ibcrd_design(n, "continuous", prob_T = n_T / n, seed = 20260910L)
	set.seed(11L)
	y = round(rnorm(n), 3)
	expect_false(any(duplicated(y)))
	des$add_all_subject_responses(y)
	w = des$get_w()
	expect_equal(sum(w), n_T)

	wil = InferenceAllSimpleWilcox$new(des)
	perms = coin_cv_permutations(des, r, seed = 12L)
	expect_true(all(colSums(perms$w_mat) == n_T))
	set.seed(13L)
	t0s = wil$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	expect_true(all(is.finite(t0s)))
	expect_false(any(t0s == 0))

	# EDI's C++ HL kernel vs a plain-R median of pairwise differences on the same permutations
	hl_r = apply(perms$w_mat[, 1:200], 2, function(col) stats::median(as.numeric(outer(y[col == 1], y[col == 0], "-"))))
	expect_equal(t0s[1:200], hl_r, tolerance = 1e-10)

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)))
	co = coin::wilcox_test(y ~ w, data = dat, distribution = "exact")
	dist = coin_cv_exact_linear_distribution(co)
	k = n_T * (n_T + 1) / 2 + (N + 1) / 2
	p_pos_exact = sum(dist$p[dist$t >= k - 1e-8])
	p_neg_exact = sum(dist$p[dist$t <= k - 1 + 1e-8])
	expect_equal(p_pos_exact + p_neg_exact, 1, tolerance = 1e-10)
	p_pos_edi = mean(t0s > 0)
	expect_lt(abs(p_pos_edi - p_pos_exact), coin_cv_mc_tol(p_pos_exact, r))
	# observed-sign consistency: sign(HL_obs) == sign(T_obs - E T)
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(sign(wil$compute_estimate()), sign(T_obs - n_T * (n + 1) / 2))
	cat(sprintf("\n[coin-cv] HL sign identity: EDI P(HL > 0) = %.4f vs coin exact P(T >= %g) = %.4f (MC tol %.4f)\n",
		p_pos_edi, k, p_pos_exact, coin_cv_mc_tol(p_pos_exact, r)))
})
