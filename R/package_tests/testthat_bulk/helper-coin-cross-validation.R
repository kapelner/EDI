# Shared helpers for the test-coin-cross-validation-*.R files: cross-validate
# EDI's Monte Carlo randomization (permutation) machinery against the *exact*
# permutation distributions computed by CRAN package `coin` (Hothorn, Hornik,
# van de Wiel & Zeileis, "A Lego System for Conditional Inference", and
# "Implementing a Class of Permutation Tests: The coin Package").
#
# Principle. coin's linear statistic is T = sum_i g(w_i) a_i for fixed
# per-subject scores a_i (ranks, raw values, log-rank scores, ...) with the
# labels w permuted while holding the arm sizes fixed. Whenever an EDI
# inference class's randomization statistic is an *affine* function of such a
# T (given fixed arm sizes), its randomization distribution under a design
# that redraws w as a uniformly random permutation with fixed n_T must coincide
# with coin's exact permutation distribution. Every test below (a) verifies
# that affine map column-by-column on the very permutations EDI used, and then
# (b) compares EDI's empirical null distribution / p-values to coin's exact
# ones on the p-value or CDF scale -- never on raw statistic values.
#
# Designs. coin conditions on the arm sizes, so the EDI design must redraw w as
# a permutation with fixed n_T: DesignFixediBCRD (complete randomization,
# n_T = round(n * prob_T), every one of the choose(n, n_T) allocations equally
# likely -- see design_fixed_ibcrd.R) for the unstratified comparisons, and
# DesignFixedBlocking with an explicit block vector `m` (complete randomization
# *within* each block via randomizr::block_ra / generate_permutations_
# blocking_cpp -- see design_fixed_blocking.R) for the stratified `| block`
# comparisons. DesignFixedBernoulli is deliberately NOT used: its n_T is
# Binomial, which is a different reference distribution from coin's.
#
# Two-sided convention. EDI's compute_rand_two_sided_pval() (see
# compute_two_sided_randomization_pval_from_t0s() in
# inference_all_abstract_rand.R) is the doubled smaller tail,
#   p = min(1, max(2 / r, 2 * min(P(t0 >= t), P(t0 <= t)))),
# whereas coin's two-sided p is P(|T - E T| >= |t - E T|). Those differ for an
# asymmetric permutation distribution, so we never compare EDI's two-sided p
# to coin's two-sided p directly; instead we take coin's exact one-sided tails
# and apply EDI's own doubled-min rule to them (coin_cv_doubled_min()).
#
# coin's exact algorithms. The shift algorithm (full distribution: support(),
# dperm(), pperm()) requires integer-valued scores (coin rescales midranks
# internally) and supports blocks; the split-up algorithm handles real-valued
# scores but only returns p-values (no support()) and does not support blocks.
# So integer-score comparisons (ranks, integer responses, 0/1 incidence) get a
# full-CDF comparison and real-score comparisons (log-rank / Gehan scores) get
# one-sided exact p-value comparisons.

coin_cv_ibcrd_design = function(n, response_type, prob_T = 0.5, seed) {
	set.seed(seed)
	des = DesignFixediBCRD$new(n = n, response_type = response_type, prob_T = prob_T)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des
}

# The block must be supplied as a factor covariate named in `strata_cols`:
# DesignFixedBlocking's draw_ws_raw() randomizes within the strata keys
# derived from the covariates (private$get_strata_keys()), NOT within an
# explicit `m` passed to the constructor -- probed 2026-09-07: with `m` only
# and a continuous covariate, get_block_ids() reports `m` but the redraws are
# balanced within the covariate's quantile bins instead. With the block as the
# only (factor) covariate the two coincide and every redraw is complete
# randomization within each block (all 6^3 = 216 allocations observed for 3
# blocks of 4 at prob_T = 0.5).
coin_cv_blocked_design = function(n, response_type, m, seed) {
	set.seed(seed)
	des = DesignFixedBlocking$new(n = n, response_type = response_type, strata_cols = "blk")
	des$add_all_subjects_to_experiment(data.frame(blk = factor(m)))
	des$assign_w_to_all_subjects()
	stopifnot(identical(as.integer(des$get_block_ids()), as.integer(m)))
	des
}

# Pre-draw the permutations from the design so that the same w columns feed
# both approximate_randomization_distribution_beta_hat_T() and
# compute_rand_two_sided_pval(), and so that the per-column affine identity
# between EDI's statistic and coin's linear statistic can be checked.
# Same list shape as InferenceRand's private generate_permutations().
coin_cv_permutations = function(des, r, seed) {
	set.seed(seed)
	w_mat = des$draw_ws_according_to_design(as.integer(r))
	storage.mode(w_mat) = "numeric"
	list(w_mat = w_mat, m_mat = NULL)
}

# coin's support()/dperm() live on the standardized scale (T - E) / sqrt(V);
# map back to the linear-statistic scale. Returns the exact distribution as
# (t = linear support, p = probability mass), rounded so exact integer /
# half-integer supports compare cleanly.
coin_cv_exact_linear_distribution = function(coin_obj, digits = 8L) {
	E = as.numeric(coin::expectation(coin_obj))
	V = as.numeric(coin::variance(coin_obj))
	s = as.numeric(coin::support(coin_obj))
	p = as.numeric(coin::dperm(coin_obj, s))
	t = round(s * sqrt(V) + E, digits)
	o = order(t)
	list(t = t[o], p = p[o], E = E, V = V)
}

coin_cv_exact_tails = function(dist, t_obs, eps = 1e-8) {
	list(
		ge = sum(dist$p[dist$t >= t_obs - eps]),
		le = sum(dist$p[dist$t <= t_obs + eps])
	)
}

# EDI's two-sided randomization p-value rule applied to arbitrary tail
# probabilities (r = Inf for an exact reference distribution).
coin_cv_doubled_min = function(ge, le, r = Inf) {
	min(1, max(2 / r, 2 * min(ge, le)))
}

coin_cv_empirical_tails = function(t0s, t_obs, eps = 1e-10) {
	t0s = t0s[is.finite(t0s)]
	list(ge = mean(t0s >= t_obs - eps), le = mean(t0s <= t_obs + eps), r = length(t0s))
}

# Monte Carlo tolerance: k standard errors of a binomial proportion with true
# value q over r draws (doubled for a doubled-min p-value).
coin_cv_mc_tol = function(q, r, k = 3, doubled = FALSE) {
	q = min(max(q, 1e-12), 1 - 1e-12)
	(if (doubled) 2 else 1) * k * sqrt(q * (1 - q) / r)
}

# Verify t0s = a + b * lin column-by-column (exact affine map between EDI's
# randomization statistic and coin's linear statistic on the same
# permutations). Returns the fitted map.
coin_cv_affine_map = function(t0s, lin, tol = 1e-8) {
	ok = is.finite(t0s) & is.finite(lin)
	fit = stats::lm(t0s[ok] ~ lin[ok])
	a = unname(stats::coef(fit)[1L])
	b = unname(stats::coef(fit)[2L])
	max_resid = max(abs(t0s[ok] - (a + b * lin[ok])))
	list(a = a, b = b, max_resid = max_resid, ok = max_resid < tol)
}

# Map EDI's draws onto coin's linear-statistic scale via the fitted map.
coin_cv_to_linear = function(t0s, map) {
	(t0s - map$a) / map$b
}

# Dvoretzky-Kiefer-Wolfowitz bound on sup |F_r - F| for r i.i.d. draws at
# confidence 1 - alpha.
coin_cv_dkw_bound = function(r, alpha = 1e-6) {
	sqrt(log(2 / alpha) / (2 * r))
}

# Max absolute deviation between the empirical CDF of EDI's (mapped) draws and
# coin's exact CDF, evaluated at every exact support point.
coin_cv_max_cdf_deviation = function(mapped_draws, dist, eps = 1e-6) {
	mapped_draws = mapped_draws[is.finite(mapped_draws)]
	F_exact = cumsum(dist$p)
	F_edi = vapply(dist$t, function(x) mean(mapped_draws <= x + eps), numeric(1L))
	max(abs(F_edi - F_exact))
}

# Exact one-sided tails P(T >= t_obs), P(T <= t_obs) via coin's split-up
# algorithm (needed for real-valued scores, where the shift algorithm refuses).
coin_cv_splitup_tails = function(formula, data, ytrafo = NULL) {
	args = list(formula, data = data)
	if (!is.null(ytrafo)) args$ytrafo = ytrafo
	ge = coin::pvalue(do.call(coin::independence_test, c(args, list(
		distribution = coin::exact(algorithm = "split-up"), alternative = "greater"
	))))
	le = coin::pvalue(do.call(coin::independence_test, c(args, list(
		distribution = coin::exact(algorithm = "split-up"), alternative = "less"
	))))
	list(ge = as.numeric(ge), le = as.numeric(le))
}

coin_cv_identity_ytrafo = function(data) {
	coin::trafo(data, numeric_trafo = function(x) x)
}
