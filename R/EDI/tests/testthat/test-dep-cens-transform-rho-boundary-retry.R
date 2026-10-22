# TODO-111 (fourth pass): InferenceSurvivalDepCensTransformRegr with a zero-covariate
# model lost ~45% of its bootstrap replicates.  The C++ objective clamps atanh(rho) to
# [-3, 3] but the analytic gradient is not zeroed there, so when a resample's MLE sits
# on the rho boundary LBFGS fails (value NaN, converged = FALSE).  generate_mod() now
# retries (cold zero start, then atanh(rho) pinned at the boundary for estimate-only fits).

.dc_zero_cov_design = function(n = 40L, seed = 111L){
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "survival", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	time = rexp(n); dead = rbinom(n, 1, 0.8)
	des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
		y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
	des
}

test_that("DepCensTransform zero-covariate bootstrap replicates are (almost) all finite", {
	skip_on_cran()
	inf = InferenceSurvivalDepCensTransformRegr$new(.dc_zero_cov_design(), model_formula = ~1, verbose = FALSE)
	est = inf$compute_estimate()
	expect_true(is.finite(est))
	set.seed(111)
	d = suppressWarnings(inf$approximate_bootstrap_distribution_beta_hat_T(B = 41, show_progress = FALSE))
	expect_length(d, 41L)
	# before the fix ~40-49% of replicates were NA; allow a couple of honest failures
	expect_lte(sum(!is.finite(d)), 2L)
})

test_that("DepCensTransform retry ladder recovers a boundary-rho resample and leaves converged fits alone", {
	skip_on_cran()
	inf = InferenceSurvivalDepCensTransformRegr$new(.dc_zero_cov_design(), model_formula = ~1, verbose = FALSE)
	inf$compute_estimate()
	priv = inf$.__enclos_env__$private
	X = cbind(`(Intercept)` = 1, treatment = priv$w)
	# a failed first fit with atanh(rho) drifted past the cap: estimate-only retry must converge on the boundary
	res = priv$dep_cens_fit_retry(X, failed = list(b = c(0, 0, 0, 0, 0, 0, 3.01)), estimate_only = TRUE)
	expect_false(is.null(res))
	expect_true(isTRUE(res$converged))
	expect_true(is.finite(res$b[2L]))
})
