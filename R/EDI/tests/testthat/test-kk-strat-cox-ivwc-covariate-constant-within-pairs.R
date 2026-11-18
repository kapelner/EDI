# v1.0.6-TODO-128: InferenceSurvivalKKStratCoxPHIVWC's matched-pair stratified Cox fit
# was given covariates that are constant within every pair (here a rare binary whose
# carriers are not in the matched pairs, or are dropped by a bootstrap draw). The C++
# fitter then returned a finite treatment coefficient with a NaN variance, so the
# matched half was dropped whenever a standard error was requested (compute_estimate(),
# hence the slow-path subset refit: NA) but kept when it was not (the reusable worker,
# which fits with estimate_only = TRUE). Aliased columns are now dropped first, as
# survival::coxph(strata = ) does. Any NA that remains warns.

kk_strat_cox_rare_covariate_design = function(n = 60L){
	set.seed(1)
	X = data.frame(x = rnorm(n), r = c(1, 1, rep(0, n - 2L)))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE, design_formula = ~ x + r)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, stats::rexp(1, exp(-0.5 * w_i)))
	}
	des
}

kk_strat_cox_draw_without_carriers = function(p){
	set.seed(3)
	for (k in 1:500) {
		d = p$bootstrap_sample_indices(60L)
		if (!any(d$i_b %in% c(1L, 2L))) return(d)
	}
	NULL
}

# Draws that drop the reservoir's only treated subject leave an empty arm, which warns
# (v1.0.6-TODO-133, owner decision 2026-11-18); these tests are about the matched half.
muffle_reservoir_dropped = function(expr) withCallingHandlers(expr, warning = function(w) {
	if (inherits(w, "edi_kk_strat_cox_ivwc_reservoir_dropped_warning")) invokeRestart("muffleWarning")
})

test_that("aliased-column helper drops within-strata-constant columns and leaves full-rank X untouched", {
	set.seed(2)
	strata = rep(1:10, each = 2L)
	X = cbind(w = rep(c(0, 1), 10L), x = rnorm(20L))
	expect_identical(kk_strat_cox_drop_within_strata_aliased_cols(X, strata), X)
	X_const = cbind(X, k = rep(rnorm(10L), each = 2L))
	expect_identical(kk_strat_cox_drop_within_strata_aliased_cols(X_const, strata), X)
	X_comb = cbind(X, z = 2 * X[, "x"] + rep(rnorm(10L), each = 2L))
	expect_identical(colnames(kk_strat_cox_drop_within_strata_aliased_cols(X_comb, strata)), c("w", "x"))
})

test_that("KK StratCox IVWC: slow-path refit equals the reusable worker on a draw that drops a rare covariate", {
	skip_if_not_installed("survival")
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_strat_cox_rare_covariate_design(), verbose = FALSE)
	p = inf$.__enclos_env__$private
	draw = kk_strat_cox_draw_without_carriers(p)
	expect_false(is.null(draw))
	expect_true(isTRUE(p$use_reusable_bootstrap_worker()))
	ws = p$create_reusable_bootstrap_worker()
	p$load_bootstrap_sample_into_worker(ws, draw)
	theta_worker = muffle_reservoir_dropped(p$compute_bootstrap_worker_estimate(ws))
	sub = p$bootstrap_subset_inference(draw)
	theta_slow = muffle_reservoir_dropped(sub$compute_estimate())
	expect_true(is.finite(theta_slow))
	expect_equal(theta_slow, theta_worker, tolerance = 1e-8)
	expect_equal(muffle_reservoir_dropped(p$bootstrap_subset_inference(draw)$compute_estimate(estimate_only = TRUE)), theta_worker, tolerance = 1e-8)
	expect_true(is.finite(sub$.__enclos_env__$private$cached_values$s_beta_hat_T))

	# This draw has no treated reservoir subject, so the IVWC estimate is the matched
	# stratified Cox fit alone; check it against survival::coxph on the same rows.
	K = sub$.__enclos_env__$private$cached_values$KKstats
	expect_true(K$nRT == 0L || K$nRC == 0L)
	dm = data.frame(y = K$y_matched_long, d = K$dead_matched_long, w = K$w_matched_long,
		s = K$m_matched_long, K$X_matched_long)
	ref = survival::coxph(survival::Surv(y, d) ~ w + x + r + survival::strata(s), data = dm, ties = "breslow")
	expect_equal(theta_slow, unname(stats::coef(ref)[1L]), tolerance = 1e-6)
	expect_equal(sub$.__enclos_env__$private$cached_values$s_beta_hat_T, sqrt(stats::vcov(ref)[1L, 1L]), tolerance = 1e-5)
})

test_that("KK StratCox IVWC full-data fit keeps the matched pairs when a covariate is constant within them", {
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_strat_cox_rare_covariate_design(), verbose = FALSE)
	p = inf$.__enclos_env__$private
	K = p$compute_basic_match_data()
	# Both carriers are in the reservoir, so r is constant within every pair.
	expect_true(all(K$X_matched_long[, "r"] == 0))
	expect_true(is.finite(inf$compute_estimate()))
	expect_true(is.finite(p$cached_values$s_beta_hat_T))
	# The IVWC SE is below the matched-only SE, i.e. both halves were combined.
	dm = data.frame(y = K$y_matched_long, d = K$dead_matched_long, w = K$w_matched_long,
		s = K$m_matched_long, K$X_matched_long)
	ref = survival::coxph(survival::Surv(y, d) ~ w + x + r + survival::strata(s), data = dm, ties = "breslow")
	expect_lt(p$cached_values$s_beta_hat_T, sqrt(stats::vcov(ref)[1L, 1L]))
})

test_that("KK StratCox IVWC warns when neither half is usable", {
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_strat_cox_rare_covariate_design(), verbose = FALSE)
	p = inf$.__enclos_env__$private
	sub = p$bootstrap_subset_inference(kk_strat_cox_draw_without_carriers(p))
	# Without hardening the aliased column stays in, the matched SE is NaN, and the
	# reservoir has no treated subject.
	sub$.__enclos_env__$private$harden = FALSE
	expect_warning(est <- muffle_reservoir_dropped(sub$compute_estimate()), class = "edi_kk_strat_cox_ivwc_nonestimable_warning")
	expect_true(is.na(est))
})

test_that("KK StratCox IVWC jackknife on the rare-covariate design is finite", {
	inf = InferenceSurvivalKKStratCoxPHIVWC$new(kk_strat_cox_rare_covariate_design(), verbose = FALSE)
	inf$num_cores = 1L
	jack = inf$approximate_jackknife_distribution_beta_hat_T()
	expect_true(all(is.finite(jack)))
})
