library(testthat)
library(EDI)

# PROPOSED companion to cpp patch 05 (rmst-tau, TODO-108). Copy into R/EDI/tests/testthat/
# together with companions/A05-rmst-tau-R-callsite.patch AFTER the patched kernel is built.
# Skipped (loudly) when the installed kernel has no `rmst_tau` formal, so it is also safe to
# copy before the rebuild. Proves: (1) the kernel with rmst_tau equals an independent survfit
# RMST on each resampled replicate truncated at min(arm maxima, tau); (2) rmst_tau = NA keeps
# the default shared horizon; (3) the class fast path no longer returns NULL for a user tau.

kernel_fn = get("compute_survival_stat_diff_rand_bootstrap_parallel_cpp", envir = asNamespace("EDI"))
skip_if(!("rmst_tau" %in% names(formals(kernel_fn))),
	"cpp patch 05 (rmst_tau argument) is not built into the installed kernel")

ref_rmst_area = function(y, dead, tau){
	fit = survival::survfit(survival::Surv(y, dead) ~ 1)
	tt = c(0, fit$time); ss = c(1, fit$surv)
	area = 0
	for (i in seq_along(tt)) {
		if (tt[i] >= tau) break
		end = if (i < length(tt)) min(tt[i + 1L], tau) else tau
		area = area + ss[i] * (end - tt[i])
	}
	area
}
ref_rep = function(y0, dead, i_col, w_col, tau){
	y = y0[i_col]; d = dead[i_col]
	yt = y[w_col == 1]; yc = y[w_col == 0]
	tau_eff = min(max(yt), max(yc))
	if (!is.null(tau)) tau_eff = min(tau_eff, tau)
	ref_rmst_area(yt, d[w_col == 1], tau_eff) - ref_rmst_area(yc, d[w_col == 0], tau_eff)
}

test_that("kernel rmst_tau equals independent survfit RMST truncated at tau, per replicate", {
	set.seed(108L)
	n = 80L; B = 25L
	y0 = rexp(n, 0.15); dead = rbinom(n, 1L, 0.75)
	i_mat = matrix(sample.int(n, n * B, replace = TRUE), n, B)
	w_mat = matrix(rbinom(n * B, 1L, 0.5), n, B); storage.mode(w_mat) = "integer"
	for (tau in c(2, 5, 12)) {
		got = kernel_fn(y0, as.integer(dead), i_mat, w_mat, 0, TRUE, NULL, 1L, rmst_tau = tau)
		ref = vapply(seq_len(B), function(b){
			if (!any(w_mat[, b] == 1L) || !any(w_mat[, b] == 0L)) return(NA_real_)
			ref_rep(y0, dead, i_mat[, b], w_mat[, b], tau)
		}, numeric(1))
		expect_equal(got, ref, tolerance = 1e-9, info = paste("tau", tau))
	}
	# NA tau == default shared horizon, and equals the 8-argument call
	got_na = kernel_fn(y0, as.integer(dead), i_mat, w_mat, 0, TRUE, NULL, 1L, rmst_tau = NA_real_)
	got_8 = kernel_fn(y0, as.integer(dead), i_mat, w_mat, 0, TRUE, NULL, 1L)
	expect_identical(got_na, got_8)
	# a huge tau cannot change the default
	expect_equal(kernel_fn(y0, as.integer(dead), i_mat, w_mat, 0, TRUE, NULL, 1L, rmst_tau = 1e9), got_8)
	expect_error(kernel_fn(y0, as.integer(dead), i_mat, w_mat, 0, TRUE, NULL, 1L, rmst_tau = -1), "positive")
})

test_that("RMST class fast BRT hook is used for a user tau and equals the kernel (needs companion A05)", {
	set.seed(1L)
	n = 100L
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.15 * exp(0.4 * w)); dead = rbinom(n, 1, 0.75)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), ifelse(dead == 1, NA_real_, y), ifelse(dead == 1, NA_real_, Inf))
	inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE, tau = 4)
	p = inf$.__enclos_env__$private
	B = 20L
	draws = lapply(seq_len(B), function(b) list(i_b = sample.int(n, n, replace = TRUE), w_b = sample(w)))
	got = p$compute_fast_rand_bootstrap_distr(p$y, draws, 0, "none")
	skip_if(is.null(got), "companion A05 (R call-site change) is not applied: user tau still returns NULL")
	mats = p$rand_bootstrap_draw_matrices(draws)
	direct = kernel_fn(as.numeric(p$y), as.integer(p$dead), mats$i_mat, mats$w_mat, 0, TRUE, NULL, 1L, rmst_tau = 4)
	expect_equal(got, direct, tolerance = 1e-12)
	# unset tau still returns the default-horizon kernel result
	inf0 = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	p0 = inf0$.__enclos_env__$private
	got0 = p0$compute_fast_rand_bootstrap_distr(p0$y, draws, 0, "none")
	expect_equal(got0, kernel_fn(as.numeric(p0$y), as.integer(p0$dead), mats$i_mat, mats$w_mat, 0, TRUE, NULL, 1L), tolerance = 1e-12)
})
