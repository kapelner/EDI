# v1.0.6-TODO-87: InferenceSurvivalKKStratCoxPHIVWC's reservoir treatment-only fallback
# (run when no covariate-adjusted reservoir candidate fit is usable) was accepted without
# rcpp_cox_fit_is_usable(), so a separated reservoir passed an infinite-coefficient Cox
# fit (beta ~ -21.8, SE ~ 4.6e4) into the estimate. It also ran when a reservoir arm was
# empty, reading y_r/dead_r before they were defined (the error was hidden by tryCatch).
# The fallback now runs only with both arms present and must pass the usability check;
# a reservoir with both arms but no usable fit is dropped with a warning on direct calls
# (silent inside resampling). Owner decision 2026-11-18: a reservoir with an empty arm warns too.

kk_strat_cox_reservoir_design = function(n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), r = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, design_formula = ~ x + r)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, stats::rexp(1, exp(-0.5 * w_i)))
	}
	des
}

test_that("KK StratCox IVWC rejects an infinite-coefficient treatment-only reservoir fallback", {
	des = kk_strat_cox_reservoir_design()
	p = InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)$.__enclos_env__$private
	# Four reservoir subjects only (no pairs): one treated subject outlives the three
	# controls, so every reservoir Cox fit is separated.
	draw = list(i_b = c(2L, 58L, 58L, 1L), m_vec_b = rep(0L, 4L))
	sub = p$bootstrap_subset_inference(draw)
	sp = sub$.__enclos_env__$private
	K = sp$compute_basic_match_data()
	expect_equal(c(K$m, K$nRT, K$nRC), c(0L, 1L, 3L))
	X_w = matrix(K$w_reservoir, ncol = 1L, dimnames = list(NULL, "w"))
	fb = fast_coxph_regression_cpp(X_w, K$y_reservoir, K$dead_reservoir, estimate_only = FALSE)
	expect_true(abs(fb$coefficients[1L]) > 15)       # the old code returned this as the estimate
	expect_false(sp$rcpp_cox_fit_is_usable(fb))
	expect_warning(est <- sub$compute_estimate(), class = "edi_kk_strat_cox_ivwc_nonestimable_warning")
	expect_true(is.na(est))
	expect_true(is.na(sp$cached_values$s_beta_hat_T))
})

kk_strat_cox_matched_only_reference = function(KS){
	X_m = kk_strat_cox_drop_within_strata_aliased_cols(cbind(w = KS$w_matched_long, KS$X_matched_long), KS$m_matched_long)
	fast_stratified_coxph_regression_cpp(X_m, KS$y_matched_long, KS$dead_matched_long, as.integer(KS$m_matched_long), estimate_only = FALSE)
}

test_that("KK StratCox IVWC drops an unusable two-arm reservoir with a warning and keeps the matched pairs", {
	des = kk_strat_cox_reservoir_design()
	p = InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)$.__enclos_env__$private
	p$compute_basic_match_data()
	matched = which(p$m > 0L)
	sep = c(2L, 58L, 58L, 1L)   # the separated reservoir rows of the first test
	draw = list(i_b = c(matched, sep), m_vec_b = c(p$m[matched], rep(0L, length(sep))))
	sub = p$bootstrap_subset_inference(draw)
	expect_warning(est <- sub$compute_estimate(), class = "edi_kk_strat_cox_ivwc_reservoir_dropped_warning")
	KS = sub$.__enclos_env__$private$cached_values$KKstats
	expect_equal(c(KS$nRT, KS$nRC), c(1L, 3L))
	# Before the fix the beta ~ -21.8 fallback entered the IVW combination with weight
	# ~1e-10; now the estimate is exactly the matched-pair stratified Cox fit.
	ref = kk_strat_cox_matched_only_reference(KS)
	expect_identical(est, ref$coefficients[1L])
	expect_identical(sub$.__enclos_env__$private$cached_values$s_beta_hat_T, sqrt(ref$vcov[1L, 1L]))
})

test_that("KK StratCox IVWC drops a reservoir with an empty arm and warns on direct calls", {
	des = kk_strat_cox_reservoir_design()
	p = InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)$.__enclos_env__$private
	p$compute_basic_match_data()
	matched = which(p$m > 0L)
	res_ctrl = which(p$m == 0L & p$w == 0L)
	draw = list(i_b = c(matched, res_ctrl), m_vec_b = c(p$m[matched], rep(0L, length(res_ctrl))))
	sub = p$bootstrap_subset_inference(draw)
	# Used to run the fallback on undefined y_r/dead_r (error swallowed by tryCatch).
	expect_warning(est <- sub$compute_estimate(), "empty treated arm",
		class = "edi_kk_strat_cox_ivwc_reservoir_dropped_warning")
	KS = sub$.__enclos_env__$private$cached_values$KKstats
	expect_equal(c(KS$nRT, KS$nRC), c(0L, length(res_ctrl)))
	ref = kk_strat_cox_matched_only_reference(KS)
	expect_identical(est, ref$coefficients[1L])
	expect_identical(sub$.__enclos_env__$private$cached_values$s_beta_hat_T, sqrt(ref$vcov[1L, 1L]))
})

test_that("KK StratCox IVWC full-data fit with a usable reservoir is unchanged and the jackknife stays silent", {
	des = kk_strat_cox_reservoir_design()
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(des, verbose = FALSE)
	expect_no_warning(est <- inf$compute_estimate())
	K = inf$.__enclos_env__$private$cached_values$KKstats
	expect_true(K$nRT > 0L && K$nRC > 0L)
	expect_true(is.finite(est))
	# The single treated reservoir subject's deletion leaves that arm empty, so the
	# jackknife hits the dropped-reservoir branch; it must not warn per replicate.
	expect_equal(K$nRT, 1L)
	inf$num_cores = 1L
	seen = character(0)
	withCallingHandlers(
		jack <- inf$approximate_jackknife_distribution_beta_hat_T(),
		warning = function(w) {
			if (inherits(w, "edi_kk_strat_cox_ivwc_reservoir_dropped_warning")) seen <<- c(seen, conditionMessage(w))
			invokeRestart("muffleWarning")
		}
	)
	expect_length(seen, 0L)
	expect_true(all(is.finite(jack)))
})
