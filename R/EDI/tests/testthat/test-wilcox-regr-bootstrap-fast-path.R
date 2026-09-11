library(EDI)

test_that("KK Wilcox rank-regression low-level components match wilcox.test", {

	set.seed(20260330)
	n = 12
	X = as.data.frame(matrix(rnorm(n * 2), nrow = n, ncol = 2))
	colnames(X) = c("x1", "x2")
	y = as.numeric(rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, y[i] + 0.1 * w_i)
	}
	inf = InferenceAllKKWilcoxIVWC$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$compute_basic_match_data()

	# Matched-pairs component: rank_for_matched_pairs() must agree with wilcox.test
	diffs = priv$cached_values$KKstats$y_matched_diffs
	priv$rank_for_matched_pairs()
	beta_m = priv$cached_values$beta_T_matched
	ref_m = suppressWarnings(wilcox.test(diffs, conf.int = TRUE))
	expect_equal(beta_m, as.numeric(ref_m$estimate), tolerance = 1e-10)

	# Reservoir component: rank_for_reservoir() must agree with wilcox.test
	y_r = priv$cached_values$KKstats$y_reservoir
	w_r = priv$cached_values$KKstats$w_reservoir
	priv$rank_for_reservoir()
	beta_r = priv$cached_values$beta_T_reservoir
	yT = y_r[w_r == 1]; yC = y_r[w_r == 0]
	ref_r = suppressWarnings(wilcox.test(yT, yC, conf.int = TRUE))
	expect_equal(beta_r, as.numeric(ref_r$estimate), tolerance = 1e-10)
})
