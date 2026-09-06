library(testthat)
library(EDI)

# The randomization test at a nonzero sharp-null effect delta must use the
# impute-then-permute construction (Rosenbaum 2002 ch. 2; Imbens & Rubin 2015
# ch. 5): first remove the hypothesised effect from the units that were
# actually treated to recover the control potential outcomes,
#   y0 = y - delta * w_obs,
# then, for each reference allocation w_b, add it back to the units w_b treats,
#   y_sim(b) = y0 + delta * w_b,
# and recompute the statistic with w_b. The alternative "shift-the-null"
# construction, y + delta * w_b (no imputation), leaves the observed effect in
# the data as between-arm heterogeneity and yields a different, wider null.
# These tests pin the construction on both the C++ fast-kernel path
# (InferenceAllSimpleAverageDiff) and the R reused-worker path
# (InferenceContinOLS, which has no fast kernel), using fixed reference
# allocations so the comparison is exact rather than statistical.
# Recorded 2026-09-05 (randomization_ci_construction_audit.md, section B).

make_null_construction_fixture = function(seed = 20260905L, n = 40L, r = 25L, tau = 1.0) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.table::data.table(x1 = rnorm(1), x2 = rnorm(1)))
	w_obs = as.numeric(des$.__enclos_env__$private$w)
	y = rnorm(n) + tau * w_obs
	EDI:::add_all_subject_responses_seq(des, y)
	w_mat = matrix(as.numeric(runif(n * r) < 0.5), nrow = n, ncol = r)
	# guarantee every reference allocation has both arms
	w_mat[1, ] = 1; w_mat[2, ] = 0
	list(des = des, y = y, w_obs = w_obs, w_mat = w_mat, r = r)
}

null_draws = function(inf, fx, delta) {
	if ("num_cores" %in% names(inf)) try(inf$num_cores <- 1L, silent = TRUE)
	d = inf$approximate_randomization_distribution_beta_hat_T(
		r = fx$r, delta = delta, permutations = list(w_mat = fx$w_mat, m_mat = NULL), show_progress = FALSE
	)
	as.numeric(unlist(d))
}

mean_diff_stat = function(y, w) mean(y[w == 1]) - mean(y[w == 0])

test_that("simple average difference (C++ fast path) uses impute-then-permute, not shift-the-null", {
	fx = make_null_construction_fixture()
	delta = 0.7
	inf = InferenceAllSimpleAverageDiff$new(fx$des, verbose = FALSE)
	got = null_draws(inf, fx, delta)
	expect_length(got, fx$r)
	y0 = fx$y - delta * fx$w_obs
	ref_impute = vapply(seq_len(fx$r), function(b) mean_diff_stat(y0 + delta * fx$w_mat[, b], fx$w_mat[, b]), numeric(1))
	ref_shift  = vapply(seq_len(fx$r), function(b) mean_diff_stat(fx$y + delta * fx$w_mat[, b], fx$w_mat[, b]), numeric(1))
	expect_equal(got, ref_impute, tolerance = 1e-8)
	# the two constructions genuinely differ on this fixture (delta * d_b term)
	expect_gt(max(abs(ref_impute - ref_shift)), 1e-3)
	expect_false(isTRUE(all.equal(got, ref_shift, tolerance = 1e-6)))
})

test_that("OLS (R reused-worker path, no fast kernel) uses impute-then-permute, not shift-the-null", {
	fx = make_null_construction_fixture()
	delta = 0.7
	inf = InferenceContinOLS$new(fx$des, verbose = FALSE)
	got = null_draws(inf, fx, delta)
	expect_length(got, fx$r)
	X = as.matrix(fx$des$.__enclos_env__$private$X)[, c("x1", "x2"), drop = FALSE]
	ols_w_coef = function(y, w) unname(coef(lm(y ~ w + X))[["w"]])
	y0 = fx$y - delta * fx$w_obs
	ref_impute = vapply(seq_len(fx$r), function(b) ols_w_coef(y0 + delta * fx$w_mat[, b], fx$w_mat[, b]), numeric(1))
	ref_shift  = vapply(seq_len(fx$r), function(b) ols_w_coef(fx$y + delta * fx$w_mat[, b], fx$w_mat[, b]), numeric(1))
	expect_equal(got, ref_impute, tolerance = 1e-6)
	expect_gt(max(abs(ref_impute - ref_shift)), 1e-3)
	expect_false(isTRUE(all.equal(got, ref_shift, tolerance = 1e-6)))
})

test_that("delta = 0 draws are the plain permutation distribution (both constructions coincide)", {
	fx = make_null_construction_fixture()
	inf = InferenceAllSimpleAverageDiff$new(fx$des, verbose = FALSE)
	got = null_draws(inf, fx, 0)
	ref = vapply(seq_len(fx$r), function(b) mean_diff_stat(fx$y, fx$w_mat[, b]), numeric(1))
	expect_equal(got, ref, tolerance = 1e-8)
})
