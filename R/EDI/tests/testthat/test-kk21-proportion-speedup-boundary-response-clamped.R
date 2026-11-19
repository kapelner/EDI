# v1.0.6-TODO-60: with proportion_use_speedup = TRUE (the default), KK21's compute_weights took
# log(ys / (1 - ys)) unclamped, so one response of exactly 0 or 1 made every per-covariate
# t-statistic non-finite and the kernel returned machine epsilon for every covariate (matching
# silently became unweighted). The first fix clamped to machine epsilon, which turned a 0/1 into a
# +/-36 logit outlier. Owner decision 2026-11-19 (option b): when any response in the fit is 0 or 1,
# compress every response to (y(n - 1) + 0.5) / n (Smithson and Verkuilen 2006), n = number of
# responses in the fit, in both KK21 and KK21stepwise. All-interior responses keep the plain logit,
# so their weights are bit-identical to the old transform.

kk21_prop_design_with_responses = function(boundary_value = NULL, seed = 5, cls = DesignSeqOneByOneKK21){
	set.seed(seed)
	des = cls$new(n = 30, response_type = "proportion", verbose = FALSE)
	for (i in 1 : 25){
		x1 = rnorm(1)
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1, x2 = rnorm(1)))
		y = if (!is.null(boundary_value) && i == 3) boundary_value else stats::plogis(1.5 * x1 + rnorm(1, sd = 0.2))
		des$add_one_subject_response(i, y)
	}
	priv = des$.__enclos_env__$private
	priv$all_subject_data_cache = list()
	list(des = des, priv = priv, asd = priv$compute_all_subject_data())
}

test_that("kk21_speedup_proportion_logit compresses all responses by (y(n - 1) + 0.5) / n when a 0 or 1 is present", {
	ys = c(0, 0.2, 0.5, 0.9, 1)
	n = length(ys)
	expect_equal(kk21_speedup_proportion_logit(ys), qlogis((ys * (n - 1) + 0.5) / n))
	# Boundary logits are +/- log(2n - 1), not +/- 36.
	out = kk21_speedup_proportion_logit(c(0, 1, runif(48, 0.1, 0.9)))
	expect_equal(range(out), c(-1, 1) * log(2 * 50 - 1))
	# Affine compression keeps the order of the responses (a boundary-only shift would not).
	ys2 = c(0, 0.001, 0.5, 0.999, 1)
	expect_false(is.unsorted(kk21_speedup_proportion_logit(ys2), strictly = TRUE))
	# n counts the responses in the fit, ignoring NA.
	expect_equal(kk21_speedup_proportion_logit(c(0, NA, 1, 0.5))[c(1, 3, 4)],
		qlogis((c(0, 1, 0.5) * 2 + 0.5) / 3))
})

test_that("kk21_speedup_proportion_logit leaves all-interior responses on the plain logit", {
	ys = c(0.01, 0.2, 0.5, 0.9, 0.99)
	expect_identical(kk21_speedup_proportion_logit(ys), log(ys / (1 - ys)))
})

test_that("KK21 proportion speedup weights stay finite and informative with a response of exactly 0 or 1", {
	for (b in c(0, 1)){
		obj = kk21_prop_design_with_responses(boundary_value = b)
		w_out = obj$priv$compute_weights(obj$asd)
		expect_true(all(is.finite(w_out)), info = paste("boundary", b))
		expect_true(max(w_out) > 1e-6, info = paste("boundary", b))
	}
})

test_that("both KK21 proportion speedups regress on the compressed logit when a response is 0 or 1", {
	for (b in c(0, 1)){
		obj = kk21_prop_design_with_responses(boundary_value = b)
		ys = obj$priv$y[!is.na(obj$priv$y)]
		n = length(ys)
		expect_equal(n, nrow(obj$asd$X_all_with_y_scaled))
		w_expected = kk21_continuous_weights_cpp(as.matrix(obj$asd$X_all_with_y_scaled),
			qlogis((ys * (n - 1) + 0.5) / n))
		expect_equal(obj$priv$compute_weights(obj$asd), w_expected, info = paste("KK21 boundary", b))

		obj_sw = kk21_prop_design_with_responses(boundary_value = b, cls = DesignSeqOneByOneKK21stepwise)
		asd = obj_sw$asd
		n_sw = length(asd$y_all)
		w_sw = kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled,
			qlogis((asd$y_all * (n_sw - 1) + 0.5) / n_sw), asd$w_all_with_y_scaled)
		w_sw[is.na(w_sw)] = 0
		expect_equal(obj_sw$priv$compute_weights(asd), w_sw, info = paste("KK21stepwise boundary", b))
		expect_true(all(is.finite(w_sw)) && max(w_sw) > 1e-6, info = paste("KK21stepwise boundary", b))
	}
})

test_that("KK21 proportion speedup weights are unchanged for interior responses", {
	obj = kk21_prop_design_with_responses(boundary_value = NULL)
	priv = obj$priv
	i_y = which(!is.na(priv$y))
	ys = priv$y[i_y]
	expect_true(all(ys > 0 & ys < 1))
	w_old = kk21_continuous_weights_cpp(as.matrix(obj$asd$X_all_with_y_scaled), as.numeric(log(ys / (1 - ys))))
	expect_identical(priv$compute_weights(obj$asd), w_old)

	obj_sw = kk21_prop_design_with_responses(boundary_value = NULL, cls = DesignSeqOneByOneKK21stepwise)
	asd = obj_sw$asd
	w_sw_old = kk21_stepwise_continuous_weights_cpp(asd$X_all_with_y_scaled, log(asd$y_all / (1 - asd$y_all)),
		asd$w_all_with_y_scaled)
	w_sw_old[is.na(w_sw_old)] = 0
	expect_identical(obj_sw$priv$compute_weights(asd), w_sw_old)
})
