# v1.0.6-TODO-58: cluster_robust_cr2_variance() used an absolute .Machine$double.eps floor, so a
# continuous response in small units (y * 1e-8) was "not estimable" and InferenceContinOLS / Lin
# silently fell back to the independent-subjects SE on a cluster design. The floor is now relative
# to the scale of y, so the CR2 variance scales with y^2 and the df is unchanged.

cr2_small_scale_data = function(seed = 1L) {
	set.seed(seed)
	n = 60
	cluster = rep(1:6, each = 10)
	w = rep(c(0, 1), 30)
	x = rnorm(n)
	y = 1 + 0.5 * w + 0.3 * x + rnorm(6)[cluster] + rnorm(n)
	list(X = cbind(1, w, x), y = y, cluster = cluster, w = w, x = x)
}

test_that("CR2 variance and df are scale-equivariant in y down to tiny and up to huge units", {
	d = cr2_small_scale_data()
	b = as.numeric(qr.coef(qr(d$X), d$y))
	ref = EDI:::cluster_robust_cr2_variance(d$X, d$y, b, d$cluster, 2L)
	expect_false(is.null(ref))
	for (s in c(1e-12, 1e-8, 1e-4, 1e8)) {
		cr = EDI:::cluster_robust_cr2_variance(d$X, d$y * s, b * s, d$cluster, 2L)
		expect_false(is.null(cr))
		expect_equal(cr$ssq, ref$ssq * s^2, tolerance = 1e-8)
		expect_equal(cr$df, ref$df, tolerance = 1e-8)
	}
})

test_that("CR2 variance for a small-unit response matches clubSandwich CR2", {
	skip_if_not_installed("clubSandwich")
	d = cr2_small_scale_data()
	s = 1e-8
	ys = d$y * s
	b = as.numeric(qr.coef(qr(d$X), ys))
	cr = EDI:::cluster_robust_cr2_variance(d$X, ys, b, d$cluster, 2L)
	w = d$w; x = d$x
	fit = stats::lm(ys ~ w + x)
	V = suppressMessages(clubSandwich::vcovCR(fit, cluster = d$cluster, type = "CR2"))
	ct = clubSandwich::coef_test(fit, vcov = V, test = "Satterthwaite")
	expect_equal(cr$ssq, unname(V[2, 2]), tolerance = 1e-8)
	expect_equal(cr$df, unname(ct$df_Satt[2]), tolerance = 1e-6)
})

test_that("CR2 variance is still NULL for a perfect fit at any scale or offset", {
	d = cr2_small_scale_data()
	for (s in c(1e-8, 1, 1e6)) for (off in c(0, 1e4)) {
		yp = s * (off + 0.5 * d$w + 0.3 * d$x)
		b = as.numeric(qr.coef(qr(d$X), yp))
		expect_null(EDI:::cluster_robust_cr2_variance(d$X, yp, b, d$cluster, 2L))
	}
	y0 = rep(0, nrow(d$X))
	expect_null(EDI:::cluster_robust_cr2_variance(d$X, y0, c(0, 0, 0), d$cluster, 2L))
})

test_that("OLS on a cluster design keeps the CR2 SE when the response is in small units", {
	set.seed(3)
	G = 12L; m = 8L; n = G * m
	cl = rep(seq_len(G), each = m)
	u = rnorm(G, sd = 2)[cl]
	X = data.frame(pretest = rnorm(n) + u / 2, school = factor(cl))
	y = 0.5 * X$pretest + u + rnorm(n)
	fit_se = function(scale) {
		set.seed(4)
		des = DesignFixedCluster$new(n = n, response_type = "continuous", cluster_col = "school", verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$add_all_subject_responses(scale * (y + des$get_w()))
		inf = InferenceContinOLS$new(des)
		inf$compute_estimate()
		priv = inf$.__enclos_env__$private
		list(se = priv$get_standard_error(), df = priv$get_degrees_of_freedom(),
			applied = isTRUE(priv$cached_values$cluster_robust_se_applied))
	}
	big = fit_se(1)
	small = fit_se(1e-8)
	expect_true(big$applied)
	expect_true(small$applied)
	expect_equal(small$se, big$se * 1e-8, tolerance = 1e-6)
	expect_equal(small$df, big$df, tolerance = 1e-6)
})
