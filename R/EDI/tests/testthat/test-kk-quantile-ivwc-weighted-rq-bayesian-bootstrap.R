# v1.0.6-TODO-235 (2): the KK quantile IVWC classes (InferenceContinKKQuantileRegrIVWC,
# InferencePropKKQuantileRegrIVWC) get their Bayesian bootstrap back. v1.0.6-TODO-217 had
# opted them out because a replicate fell through to a raw mean-difference fallback; each
# replicate is now a weighted quantreg::rq() refit of both halves (matched-pair differences
# and reservoir), with standard errors from the weighted fits, pooled by inverse variance.
# Here: zero and tiny weights, the weighted-IQR fallback, repeatability under a seed, and a
# small coverage check (serial, one core).

kk_quantile_bb_design = function(seed, n = 60L, response_type = "continuous", effect = 0.5){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		eta = effect * w + 0.6 * X$x1[i] + rnorm(1)
		des$add_one_subject_response(i, if (response_type == "continuous") eta else plogis(eta))
	}
	des
}

kk_quantile_bb_classes = c(continuous = "InferenceContinKKQuantileRegrIVWC", proportion = "InferencePropKKQuantileRegrIVWC")

test_that("KK quantile IVWC classes support the Bayesian bootstrap again", {
	skip_if_not_installed("quantreg")
	for (rt in names(kk_quantile_bb_classes)) {
		nm = kk_quantile_bb_classes[[rt]]
		expect_false("bayesian_bootstrap" %in% EDI_INFERENCE_EXCLUDED_CAPABILITIES[[nm]], info = nm)
		inf = get(nm)$new(kk_quantile_bb_design(1L, response_type = rt), verbose = FALSE)
		expect_true(inf$.__enclos_env__$private$supports_bayesian_bootstrap(), info = nm)
		expect_true(inf$supports("bayesian_bootstrap"), info = nm)
	}
})

test_that("the weighted IQR fallback equals stats::IQR() at uniform weights", {
	set.seed(1)
	x = rnorm(37)
	expect_equal(kk_quantile_weighted_iqr(x, rep(1, 37)), stats::IQR(x))
	expect_equal(kk_quantile_weighted_iqr(x, rep(3.5, 37)), stats::IQR(x))
	# A zero weight drops the point.
	w = rep(1, 37); w[5] = 0
	expect_equal(kk_quantile_weighted_iqr(x, w), stats::IQR(x[-5]))
	expect_true(is.na(kk_quantile_weighted_iqr(1, 1)))
})

test_that("zero-weight units are dropped and tiny weights are handled", {
	skip_if_not_installed("quantreg")
	for (rt in names(kk_quantile_bb_classes)) {
		nm = kk_quantile_bb_classes[[rt]]
		inf = get(nm)$new(kk_quantile_bb_design(2L, response_type = rt), verbose = FALSE)
		inf$num_cores = 1L
		est = inf$compute_estimate()
		p = inf$.__enclos_env__$private
		ctx = p$build_bayesian_bootstrap_context()
		p$current_bayesian_bootstrap_context = ctx
		set.seed(3)
		u = rexp(ctx$n_units)
		u[1:3] = 0
		r0 = suppressWarnings(inf$compute_estimate_with_bootstrap_weights(u, estimate_only = TRUE))
		expect_true(is.finite(r0), info = nm)
		# A weight below 1e-10 times the mean is dropped like a zero weight, so the replicate
		# is the same (rq would otherwise keep the near-empty rows in its "nid" sparsity
		# estimate).
		u_tiny = u
		u_tiny[1:3] = 1e-300
		r_tiny = suppressWarnings(inf$compute_estimate_with_bootstrap_weights(u_tiny, estimate_only = TRUE))
		expect_true(is.finite(r_tiny), info = nm)
		expect_equal(r_tiny, r0, tolerance = 1e-6, info = nm)
		# Scaling all weights does not change the replicate.
		r_scaled = suppressWarnings(inf$compute_estimate_with_bootstrap_weights(1e-8 * u, estimate_only = TRUE))
		expect_equal(r_scaled, r0, tolerance = 1e-10, info = nm)
		# The isolation wrapper restores the point estimate.
		expect_identical(inf$compute_estimate(), est, info = nm)
	}
})

test_that("Bayesian-bootstrap draws and CIs are repeatable under a seed", {
	skip_if_not_installed("quantreg")
	for (rt in names(kk_quantile_bb_classes)) {
		nm = kk_quantile_bb_classes[[rt]]
		inf = get(nm)$new(kk_quantile_bb_design(4L, response_type = rt), verbose = FALSE)
		inf$num_cores = 1L
		set.seed(11)
		bb1 = suppressWarnings(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 30, show_progress = FALSE))
		set.seed(11)
		bb2 = suppressWarnings(inf$approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 30, show_progress = FALSE))
		expect_identical(bb1, bb2, info = nm)
		expect_true(all(is.finite(bb1)), info = nm)
		expect_gt(sd(bb1), 0)
		set.seed(12)
		ci1 = suppressWarnings(inf$compute_bayesian_bootstrap_confidence_interval(B = 30, type = "percentile", show_progress = FALSE))
		set.seed(12)
		ci2 = suppressWarnings(inf$compute_bayesian_bootstrap_confidence_interval(B = 30, type = "percentile", show_progress = FALSE))
		expect_identical(ci1, ci2, info = nm)
		expect_lt(ci1[1], ci1[2])
	}
})

test_that("Bayesian-bootstrap percentile CIs cover the quantile effect in a small simulation", {
	skip_if_not_installed("quantreg")
	skip_on_cran()
	# Normal errors, so the median (tau = 0.5) effect is the shift 0.5 on both the raw
	# (continuous) and the logit (proportion) scale.
	for (rt in names(kk_quantile_bb_classes)) {
		nm = kk_quantile_bb_classes[[rt]]
		hits = vapply(1:12, function(r) {
			inf = get(nm)$new(kk_quantile_bb_design(500L + r, response_type = rt), verbose = FALSE)
			inf$num_cores = 1L
			set.seed(r)
			ci = suppressWarnings(inf$compute_bayesian_bootstrap_confidence_interval(B = 60, type = "percentile", show_progress = FALSE))
			expect_true(all(is.finite(ci)), info = nm)
			ci[1] <= 0.5 && 0.5 <= ci[2]
		}, logical(1))
		expect_gte(mean(hits), 9 / 12, label = paste(nm, "coverage"))
	}
})
