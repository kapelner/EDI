library(EDI)

# Cross-validation of EDI's mean-difference / CMH randomization inference
# against coin's exact permutation distributions. See
# helper-coin-cross-validation.R for the principle, design choice and the
# two-sided p-value convention.

# ---------------------------------------------------------------------------
# InferenceAllSimpleAverageDiff  <->  coin::oneway_test(exact)
#
# Derivation. EDI's randomization statistic is ybar_T - ybar_C (inference_all_
# average_diff.R, compute_simple_mean_diff_parallel_cpp()). With S = sum_i y_i
# fixed under permutation and n_T fixed by DesignFixediBCRD,
#   ybar_T - ybar_C = S_T / n_T - (S - S_T) / n_C = -S / n_C + S_T (1/n_T + 1/n_C),
# an increasing affine map of coin's oneway_test linear statistic S_T = sum of
# y over the first factor level (made the treated arm).
#
# coin's shift algorithm refuses real-valued scores, so the full-distribution
# comparison uses an integer-valued response; a second fixture with a
# real-valued response uses the split-up algorithm (exact one-sided p-values
# only).
# ---------------------------------------------------------------------------
test_that("simple mean difference randomization distribution matches coin's exact oneway_test distribution (integer response)", {
	skip_if_not_installed("coin")
	n = 12L
	r = 20000L
	des = coin_cv_ibcrd_design(n, "continuous", seed = 20260911L)
	w = des$get_w()
	y = c(4, 7, 5, 9, 6, 3, 8, 5, 7, 4, 6, 8) + 2 * w
	des$add_all_subject_responses(y)
	n_T = sum(w == 1)
	n_C = n - n_T
	expect_equal(n_T, 6L)

	md = InferenceAllSimpleAverageDiff$new(des)
	perms = coin_cv_permutations(des, r, seed = 21L)
	expect_true(all(colSums(perms$w_mat) == n_T))
	set.seed(22L)
	t0s = md$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = md$compute_estimate()

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)))
	co = coin::oneway_test(y ~ w, data = dat, distribution = "exact")
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(T_obs, sum(y[w == 1]))

	lin = colSums(y * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / n_T + 1 / n_C, tolerance = 1e-10)
	expect_equal(map$a, -sum(y) / n_C, tolerance = 1e-10)
	expect_equal(t_obs, map$a + map$b * T_obs, tolerance = 1e-10)

	dist = coin_cv_exact_linear_distribution(co)
	max_dev = coin_cv_max_cdf_deviation(coin_cv_to_linear(t0s, map), dist)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	set.seed(22L)
	p_edi = md$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	ex = coin_cv_exact_tails(dist, T_obs)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))
	cat(sprintf("\n[coin-cv] mean diff/iBCRD (integer y): EDI p = %.4f, exact doubled-min p = %.4f (coin two-sided p = %.4f); tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev = %.4f (DKW %.4f)\n",
		p_edi, p_exact, as.numeric(coin::pvalue(co)), emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r)))
})

test_that("simple mean difference randomization tails match coin's exact split-up one-sided p-values (real-valued response)", {
	skip_if_not_installed("coin")
	n = 12L
	r = 20000L
	des = coin_cv_ibcrd_design(n, "continuous", seed = 20260912L)
	set.seed(23L)
	y = round(rnorm(n, 0, 1), 4)
	y[des$get_w() == 1] = y[des$get_w() == 1] + 0.8
	des$add_all_subject_responses(y)
	w = des$get_w()
	n_T = sum(w == 1)
	n_C = n - n_T

	md = InferenceAllSimpleAverageDiff$new(des)
	perms = coin_cv_permutations(des, r, seed = 24L)
	set.seed(25L)
	t0s = md$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = md$compute_estimate()
	lin = colSums(y * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / n_T + 1 / n_C, tolerance = 1e-10)

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)))
	ex = coin_cv_splitup_tails(y ~ w, dat)
	set.seed(25L)
	p_edi = md$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))
	cat(sprintf("\n[coin-cv] mean diff/iBCRD (real y, split-up): EDI p = %.4f, exact doubled-min p = %.4f; tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f\n",
		p_edi, p_exact, emp$ge, emp$le, ex$ge, ex$le))
})

# ---------------------------------------------------------------------------
# Same statistic under DesignFixedBlocking  <->  coin::oneway_test(y ~ w | block).
# Within-block complete randomization (2 T / 2 C in each of 3 blocks of 4)
# keeps the overall n_T fixed, so the affine map above still holds and coin's
# `| block` reference set is exactly the design's. Integer y for the shift
# algorithm (blocks are not supported by split-up).
# ---------------------------------------------------------------------------
test_that("simple mean difference under within-block complete randomization matches coin's exact blocked oneway_test distribution", {
	skip_if_not_installed("coin")
	n = 12L
	r = 20000L
	m = rep(1:3, each = 4L)
	des = coin_cv_blocked_design(n, "continuous", m = m, seed = 20260913L)
	w = des$get_w()
	y = c(3, 6, 4, 5, 8, 7, 9, 6, 2, 5, 3, 4) + 2 * w
	des$add_all_subject_responses(y)
	expect_true(all(tapply(w, m, sum) == 2L))
	n_T = sum(w == 1)
	n_C = n - n_T

	md = InferenceAllSimpleAverageDiff$new(des)
	perms = coin_cv_permutations(des, r, seed = 26L)
	expect_true(all(apply(perms$w_mat, 2, function(col) all(tapply(col, m, sum) == 2L))))
	set.seed(27L)
	t0s = md$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = md$compute_estimate()

	dat = data.frame(y = y, w = factor(w, levels = c(1, 0)), block = factor(m))
	co = coin::oneway_test(y ~ w | block, data = dat, distribution = "exact")
	T_obs = as.numeric(coin::statistic(co, "linear"))
	expect_equal(T_obs, sum(y[w == 1]))

	lin = colSums(y * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 1 / n_T + 1 / n_C, tolerance = 1e-10)

	dist = coin_cv_exact_linear_distribution(co)
	max_dev = coin_cv_max_cdf_deviation(coin_cv_to_linear(t0s, map), dist)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	set.seed(27L)
	p_edi = md$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	emp = coin_cv_empirical_tails(t0s, t_obs)
	expect_equal(p_edi, coin_cv_doubled_min(emp$ge, emp$le, emp$r), tolerance = 1e-12)
	ex = coin_cv_exact_tails(dist, T_obs)
	p_exact = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(p_edi - p_exact), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))
	cat(sprintf("\n[coin-cv] mean diff/blocked: EDI p = %.4f, exact doubled-min p = %.4f (coin two-sided p = %.4f); max CDF dev = %.4f (DKW %.4f)\n",
		p_edi, p_exact, as.numeric(coin::pvalue(co)), max_dev, coin_cv_dkw_bound(r)))
})

# ---------------------------------------------------------------------------
# InferenceIncidCMH under DesignFixedBlocking  <->  coin::cmh_test(y ~ w | block, exact)
#
# Derivation. InferenceIncidCMH composes SimpleMeanDifference, so its
# randomization statistic is ybar_T - ybar_C on the 0/1 response. Under
# within-block complete randomization with prob_T = 0.5 and equal block sizes
# (the class's own requirements), n_T = n/2 is fixed, so
#   ybar_T - ybar_C = (2/n) (2 S_T - S),  S_T = # treated events = sum_k a_k,
# an increasing affine map of the CMH linear statistic sum_k n_{11k}, which is
# coin's cmh_test linear statistic when the treated arm and the event are the
# first levels of their factors. coin's cmh_test reports the *quadratic*
# (chi-square-type) statistic and its support()/dperm() describe that
# quadratic form, so the full linear-statistic distribution is taken from
# independence_test(teststat = "scalar") on the same formula (identical linear
# statistic, expectation and variance -- asserted); cmh_test's own exact
# p-value P(|T - E| >= |t - E|) is compared to the same quantity estimated
# from EDI's draws.
#
# Note: compute_rand_two_sided_pval() refuses incidence responses on this
# design ("Randomization tests are not supported for incidence. Use Zhang
# method." -- InferenceRand$supports_rand_pval_for_incidence(): the Zhang
# dispatch requires a Bernoulli-capable or matched design, and
# DesignFixedBlocking is neither), so only the null draws from
# approximate_randomization_distribution_beta_hat_T() are validated here and
# the doubled-min p is computed from those draws directly.
# ---------------------------------------------------------------------------
test_that("CMH blocked-incidence randomization distribution matches coin's exact cmh_test / scalar linear-statistic distribution", {
	skip_if_not_installed("coin")
	n = 12L
	r = 20000L
	m = rep(1:3, each = 4L)
	des = coin_cv_blocked_design(n, "incidence", m = m, seed = 20260914L)
	w = des$get_w()
	expect_true(all(tapply(w, m, sum) == 2L))
	# Non-degenerate fixture built from the observed allocation: per block the
	# (treated, control) events are (1,1|0,1), (1,0|0,0), (1,1|1,0), so the
	# observed treated-event count 5 is the maximum of its support and
	# P(T >= 5) = (1/2)^3 = 1/8 exactly (each block: hypergeometric).
	y_T = list(c(1L, 1L), c(1L, 0L), c(1L, 1L))
	y_C = list(c(0L, 1L), c(0L, 0L), c(1L, 0L))
	y = integer(n)
	for (k in 1:3) {
		y[which(m == k & w == 1)] = y_T[[k]]
		y[which(m == k & w == 0)] = y_C[[k]]
	}
	des$add_all_subject_responses(y)
	expect_equal(sum(y[w == 1]), 5L)

	cmh = InferenceIncidCMH$new(des)
	expect_error(
		cmh$compute_rand_two_sided_pval(r = 10L, show_progress = FALSE),
		"Randomization tests are not supported for incidence"
	)
	perms = coin_cv_permutations(des, r, seed = 28L)
	set.seed(29L)
	t0s = cmh$approximate_randomization_distribution_beta_hat_T(r = r, permutations = perms, show_progress = FALSE)
	t_obs = cmh$compute_estimate()

	dat = data.frame(y = factor(y, levels = c(1, 0)), w = factor(w, levels = c(1, 0)), block = factor(m))
	co_cmh = coin::cmh_test(y ~ w | block, data = dat, distribution = "exact")
	co_lin = coin::independence_test(y ~ w | block, data = dat, distribution = "exact", teststat = "scalar")
	T_obs = as.numeric(coin::statistic(co_cmh, "linear"))
	expect_equal(T_obs, sum(y[w == 1]))
	expect_equal(as.numeric(coin::statistic(co_lin, "linear")), T_obs)
	expect_equal(as.numeric(coin::expectation(co_lin)), as.numeric(coin::expectation(co_cmh)))
	expect_equal(as.numeric(coin::variance(co_lin)), as.numeric(coin::variance(co_cmh)))

	lin = colSums(y * perms$w_mat)
	map = coin_cv_affine_map(t0s, lin)
	expect_true(map$ok, info = sprintf("max affine residual %.3g", map$max_resid))
	expect_equal(map$b, 4 / n, tolerance = 1e-10)
	expect_equal(t_obs, map$a + map$b * T_obs, tolerance = 1e-10)

	dist = coin_cv_exact_linear_distribution(co_lin)
	expect_true(all(abs(dist$t - round(dist$t)) < 1e-8))
	max_dev = coin_cv_max_cdf_deviation(coin_cv_to_linear(t0s, map), dist)
	expect_lt(max_dev, coin_cv_dkw_bound(r))

	emp = coin_cv_empirical_tails(t0s, t_obs)
	ex = coin_cv_exact_tails(dist, T_obs)
	expect_lt(abs(emp$ge - ex$ge), coin_cv_mc_tol(ex$ge, r))
	expect_lt(abs(emp$le - ex$le), coin_cv_mc_tol(ex$le, r))
	p_edi_rule = coin_cv_doubled_min(emp$ge, emp$le, emp$r)
	p_exact_rule = coin_cv_doubled_min(ex$ge, ex$le)
	expect_lt(abs(p_edi_rule - p_exact_rule), coin_cv_mc_tol(min(ex$ge, ex$le), r, doubled = TRUE))

	# coin's own CMH two-sided exact p, P(|T - E| >= |t_obs - E|), vs the same from EDI's draws
	E = dist$E
	lin_draws = coin_cv_to_linear(t0s, map)
	p_abs_edi = mean(abs(lin_draws - E) >= abs(T_obs - E) - 1e-8)
	p_abs_coin = as.numeric(coin::pvalue(co_cmh))
	expect_lt(abs(p_abs_edi - p_abs_coin), coin_cv_mc_tol(p_abs_coin, r))
	cat(sprintf("\n[coin-cv] CMH/blocked: doubled-min p from EDI draws = %.4f vs exact %.4f; |T-E| p EDI = %.4f vs coin cmh_test = %.4f; tails EDI ge/le = %.4f/%.4f vs exact %.4f/%.4f; max CDF dev = %.4f (DKW %.4f)\n",
		p_edi_rule, p_exact_rule, p_abs_edi, p_abs_coin, emp$ge, emp$le, ex$ge, ex$le, max_dev, coin_cv_dkw_bound(r)))
})
