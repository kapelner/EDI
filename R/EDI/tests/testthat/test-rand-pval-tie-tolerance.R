# cross_platform_reproducibility.md (v1.1.0) TODO-3: tie tolerance in
# randomization p-value counting.
#
# A null draw equal to the observed statistic in exact arithmetic can land a
# few ulps on either side of it, depending on summation order (and so on the
# subject order, code path, libm or FMA contraction). rand_tail_counts() counts
# draws within EDI_TIE_REL_TOL * max(|t|, max|t0s|) of t as ties in both tails.
# Before the fix the tolerance scaled with |t| alone, so at t = 0 it was 0:
# with the Ridit fixture below, 127 of 248 exact ties sat at -5.55e-17, the
# one-sided p was 0.4968 instead of the enumerated 0.6342, and reversing the
# subject order moved the error to the other tail.

library(testthat)
library(EDI)

# Exact enumeration of all C(n, n_T) allocations for a two-arm ordinal outcome.
# The control-reference Ridit estimate is U / (n_T n_C) - 1/2, where 2U (the
# Mann-Whitney count with ties as 1/2) is an integer, so the enumerated
# p-value is computed in exact integer arithmetic.
tie_fixture = function(y, w_obs, levels, order = seq_along(y)) {
	y = y[order]; w_obs = w_obs[order]
	n = length(y)
	des = DesignFixediBCRD$new(n = n, response_type = "ordinal")
	des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n)))
	des$overwrite_all_subject_assignments(w_obs)
	des$add_all_subject_responses(factor(y, levels = levels, ordered = TRUE))
	cmb = utils::combn(n, sum(w_obs))
	W = matrix(0, n, ncol(cmb))
	for (j in seq_len(ncol(cmb))) W[cmb[, j], j] = 1
	two_u = function(w) {
		sum(outer(y[w == 1], y[w == 0], function(a, b) 2 * (a > b) + (a == b)))
	}
	u = apply(W, 2, two_u)
	u0 = two_u(w_obs)
	B = ncol(W)
	list(
		inf = InferenceOrdinalRidit$new(des, verbose = FALSE),
		perms = list(w_mat = W, m_mat = NULL),
		B = B,
		n_ties = sum(u == u0),
		# v1.2.0-TODO-207: EDI counts the observed allocation as one extra draw, (1 + b) / (1 + B),
		# also when the supplied draws are the full enumeration (which already contains it), so the
		# reference values apply that rule to the exact integer tail counts.
		exact = c(
			two.sided = min(1, 2 * (1 + min(sum(u >= u0), sum(u <= u0))) / (1 + B)),
			greater = (1 + sum(u >= u0)) / (1 + B),
			less = (1 + sum(u <= u0)) / (1 + B)
		)
	)
}

edi_rand_pvals = function(fx) {
	vapply(c("two.sided", "greater", "less"), function(alt)
		fx$inf$compute_rand_two_sided_pval(r = fx$B, permutations = fx$perms,
			show_progress = FALSE, alternative = alt), numeric(1))
}

# Treated levels {1,2,3,1,2,3}, control {3,2,1,3,2,1}: the observed Ridit
# contrast is 0 in exact arithmetic.
y_three = c(1, 3, 2, 2, 3, 1, 1, 3, 2, 2, 3, 1)
w_alt = rep(c(1, 0), 6)

test_that("tail counts treat rounding-level ties at t = 0 as ties, in units-free fashion", {
	draws = c(-5.55e-17, 0, 5.55e-17, 0.25, -0.25, 0.5)
	expect_identical(EDI:::rand_tail_counts(draws, 0), c(ge = 5L, le = 4L))
	# Rescaling the statistic (a change of response units) leaves the counts alone.
	for (s in c(1e-9, 1e-3, 1e3, 1e9)) {
		expect_identical(EDI:::rand_tail_counts(draws * s, 0), c(ge = 5L, le = 4L))
	}
	# A nonzero observed value with draws a few ulps away on either side.
	t = 1 / 3
	expect_identical(EDI:::rand_tail_counts(c(t * (1 - 4e-16), t, t * (1 + 4e-16), 0.5, 0.1), t),
		c(ge = 4L, le = 4L))
	# Genuinely distinct values are not merged.
	expect_identical(EDI:::rand_tail_counts(c(-1e-6, 1e-6, 1), 0), c(ge = 2L, le = 1L))
	expect_identical(EDI:::rand_tail_counts(c(0.5 - 1e-6, 0.5 + 1e-6), 0.5), c(ge = 1L, le = 1L))
	# Non-finite draws are ignored, including in the scale.
	expect_identical(EDI:::rand_tail_counts(c(NA, Inf, -5e-17, 1), 0), c(ge = 2L, le = 1L))
	expect_equal(EDI:::EDI_TIE_REL_TOL, sqrt(.Machine$double.eps))
})

test_that("enumerated randomization p-values with exact ties match the exact answer", {
	cases = list(
		three_level = tie_fixture(y_three, w_alt, levels = 1:3),
		binary_n12 = tie_fixture(c(1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0), w_alt, levels = 0:1),
		binary_n14 = tie_fixture(c(1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 1, 0, 1, 0), rep(c(1, 0), 7), levels = 0:1)
	)
	for (nm in names(cases)) {
		fx = cases[[nm]]
		expect_gt(fx$n_ties, 0L)
		expect_identical(edi_rand_pvals(fx), fx$exact, info = nm)
	}
	# The three-level fixture really does put exact ties on both sides of t.
	fx = cases$three_level
	t = fx$inf$compute_estimate()
	t0s = fx$inf$approximate_randomization_distribution_beta_hat_T(r = fx$B,
		permutations = fx$perms, show_progress = FALSE)
	near = t0s[abs(t0s - t) < 1e-12]
	expect_length(near, fx$n_ties)
	expect_true(any(near != t))
})

test_that("a different summation order (subject order) leaves the p-values unchanged", {
	forward = tie_fixture(y_three, w_alt, levels = 1:3)
	reversed = tie_fixture(y_three, w_alt, levels = 1:3, order = rev(seq_along(y_three)))
	shuffled = tie_fixture(y_three, w_alt, levels = 1:3, order = c(5, 2, 11, 8, 1, 12, 3, 10, 7, 4, 9, 6))
	# The observed statistic itself is computed differently in the two orders...
	expect_false(identical(forward$inf$compute_estimate(), reversed$inf$compute_estimate()))
	# ...but the p-values agree with each other and with the enumeration.
	expect_identical(edi_rand_pvals(reversed), edi_rand_pvals(forward))
	expect_identical(edi_rand_pvals(shuffled), edi_rand_pvals(forward))
	expect_identical(edi_rand_pvals(forward), forward$exact)
})

test_that("the bootstrap-randomization counting paths use the same tie rule", {
	fx = tie_fixture(y_three, w_alt, levels = 1:3)
	priv = fx$inf$.__enclos_env__$private
	# Studentized BRT p-value: z0 = (t0 - 0) / 1 with ties at z_obs = 0.
	t0 = c(-5.55e-17, 5.55e-17, 1:8, -1)
	p_signed = priv$compute_two_sided_brt_pval_studentized(t = 0, t0_b = t0, se0_b = rep(1, 11),
		delta = 0, se_obs = 1, symmetric = FALSE)
	expect_identical(p_signed, 2 * (1 + 3) / (1 + 11))   # v1.2.0-TODO-207 rule; was 2 * 3 / 11
	p_sym = priv$compute_two_sided_brt_pval_studentized(t = 0.25, t0_b = c(0.25 * (1 - 4e-16), -0.25, 0.1, 0.5),
		se0_b = rep(1, 4), delta = 0, se_obs = 1, symmetric = TRUE)
	expect_identical(p_sym, (1 + 3) / (1 + 4))           # v1.2.0-TODO-207 rule; was 3 / 4
	# Closed-form affine CI inversion: two constant (slope 0) draws that equal
	# t_obs up to rounding give the same interval as two bit-exact ties.
	set.seed(3)
	A_v = sort(rnorm(198))
	cs = c(0, 0, rep(1, 198))
	ci_exact = priv$closed_form_ci_from_affine_null_draws(c(0, 0, A_v), cs, t_obs = 0, alpha = 0.05)
	ci_round = priv$closed_form_ci_from_affine_null_draws(c(-5.55e-17, 5.55e-17, A_v), cs, t_obs = 0, alpha = 0.05)
	expect_length(ci_exact, 2L)
	expect_identical(ci_round, ci_exact)
})
