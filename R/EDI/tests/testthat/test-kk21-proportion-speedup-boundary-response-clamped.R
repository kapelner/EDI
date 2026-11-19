# v1.0.6-TODO-60: with proportion_use_speedup = TRUE (the default), KK21's compute_weights took
# log(ys / (1 - ys)) unclamped, so one response of exactly 0 or 1 made every per-covariate
# t-statistic non-finite and the kernel returned machine epsilon for every covariate (matching
# silently became unweighted). It now uses the clamped logit(), as KK21stepwise does. Interior
# responses must give bit-identical weights to the old transform.

kk21_prop_design_with_responses = function(boundary_value = NULL, seed = 5){
	set.seed(seed)
	des = DesignSeqOneByOneKK21$new(n = 30, response_type = "proportion", verbose = FALSE)
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

test_that("KK21 proportion speedup weights stay finite and informative with a response of exactly 0 or 1", {
	for (b in c(0, 1)){
		obj = kk21_prop_design_with_responses(boundary_value = b)
		w_out = obj$priv$compute_weights(obj$asd)
		expect_true(all(is.finite(w_out)), info = paste("boundary", b))
		expect_true(max(w_out) > 1e-6, info = paste("boundary", b))
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
})
