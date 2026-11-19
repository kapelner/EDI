library(testthat)
library(EDI)

# v1.0.6-TODO-214: compute_rand_bootstrap_two_sided_pval(na.rm = FALSE) returns NA on any
# invalid null draw on every path (percentile, smoothed, studentized / symmetric-percentile-t,
# sequential Monte Carlo), with one edi_bootstrap_nonfinite_na_warning per object (silent
# inside an outer resampling operation), as the nonparametric and Bayesian bootstrap p-values
# do. Before, the studentized and sequential-MC paths dropped invalid draws regardless of
# na.rm, and the percentile / smoothed paths returned a silent NA. na.rm = TRUE (the default)
# is unchanged. Draws are stubbed so the invalid draws are exact.

make_cont_design = function(){
	set.seed(3); n = 60
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	des
}

stub_method = function(env, name, f){
	unlockBinding(name, env)
	assign(name, f, envir = env)
	lockBinding(name, env)
}

collect_warnings = function(expr){
	warns = list()
	val = withCallingHandlers(expr, warning = function(w){
		warns[[length(warns) + 1L]] <<- w
		invokeRestart("muffleWarning")
	})
	list(value = val, all = warns,
		nonfinite = Filter(function(w) inherits(w, "edi_bootstrap_nonfinite_na_warning"), warns))
}

B = 100L

# n_bad of the B null statistics are NA (the last ones), the rest finite.
null_stats = function(n_bad){
	set.seed(11)
	c(rnorm(B - n_bad, sd = 0.3), rep(NA_real_, n_bad))
}

new_inf = function(){
	inf = InferenceAllSimpleAverageDiff$new(make_cont_design())
	inf$num_cores = 1L
	inf
}

with_percentile_stub = function(n_bad){
	inf = new_inf()
	stub_method(inf, "approximate_rand_bootstrap_distribution_beta_hat_T", function(B = 501, ...) null_stats(n_bad))
	inf
}

# studentized draws: t0 always finite; se_bad draws have an NA standard error
with_studentized_stub = function(se_bad){
	inf = new_inf()
	priv = inf$.__enclos_env__$private
	stub_method(priv, "compute_brt_null_statistics_with_se", function(draws, ...) {
		set.seed(12)
		list(t0 = rnorm(B, sd = 0.3), se0 = c(rep(0.3, B - se_bad), rep(NA_real_, se_bad)))
	})
	inf
}

# sequential MC: batches of 25 over a stubbed pool of null statistics
with_smc_stub = function(pool){
	inf = new_inf()
	priv = inf$.__enclos_env__$private
	priv$brt_mc_control = list(mc_enable = TRUE, mc_batch_size = 25L, mc_min_draws = 25L,
		mc_conf_level = 0.99, mc_stop_threshold = 0.05)
	stub_method(priv, "get_brt_distribution_prefix", function(draws, target, ...) pool[seq_len(min(length(pool), target))])
	inf
}

test_that("percentile and smoothed: na.rm = FALSE is NA with one nonfinite warning; na.rm = TRUE unchanged", {
	for (type in c("percentile", "smoothed")) {
		inf = with_percentile_stub(1L)
		res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, type = type, show_progress = FALSE))
		expect_true(is.na(res$value))
		expect_length(res$nonfinite, 1L)
		expect_identical(res$nonfinite[[1L]]$n_nonfinite, 1L)
		expect_identical(res$nonfinite[[1L]]$n_total, B)
		# once per object
		res2 = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, type = type, show_progress = FALSE))
		expect_true(is.na(res2$value))
		expect_length(res2$nonfinite, 0L)
		# na.rm = TRUE drops the one NA draw (99% valid >= 95%)
		expect_true(is.finite(inf$compute_rand_bootstrap_two_sided_pval(B = B, type = type, show_progress = FALSE)))
		# all finite: na.rm makes no difference
		inf = with_percentile_stub(0L)
		res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, type = type, show_progress = FALSE))
		expect_length(res$all, 0L)
		if (type == "percentile") {
			expect_identical(res$value, inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = TRUE, type = type, show_progress = FALSE))
		}
	}
})

test_that("studentized: a draw with a missing SE makes na.rm = FALSE NA; na.rm = TRUE still drops it", {
	for (type in c("studentized", "symmetric-percentile-t")) {
		inf = with_studentized_stub(2L)
		res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, type = type, show_progress = FALSE))
		expect_true(is.na(res$value))
		expect_length(res$nonfinite, 1L)
		expect_identical(res$nonfinite[[1L]]$n_nonfinite, 2L)
		p_true = inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = TRUE, type = type, show_progress = FALSE)
		expect_true(is.finite(p_true))
		inf = with_studentized_stub(0L)
		res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, type = type, show_progress = FALSE))
		expect_length(res$all, 0L)
		expect_identical(res$value, inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = TRUE, type = type, show_progress = FALSE))
	}
})

test_that("sequential MC: na.rm = FALSE is NA once an evaluated prefix holds a non-finite draw", {
	pool = null_stats(0L); pool[30] = NA_real_   # in the second batch of 25
	inf = with_smc_stub(pool)
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, show_progress = FALSE))
	expect_true(is.na(res$value))
	expect_null(attributes(res$value))
	expect_length(res$nonfinite, 1L)
	expect_identical(res$nonfinite[[1L]]$n_total, 50L)   # the prefix evaluated when it stopped
	# na.rm = TRUE drops it
	inf = with_smc_stub(pool)
	expect_true(is.finite(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = TRUE, show_progress = FALSE)))
})

test_that("silent inside an outer resampling operation, still NA", {
	inf = with_percentile_stub(1L)
	priv = inf$.__enclos_env__$private
	priv$active_resampling_operation = "non_param_boot"
	res = collect_warnings(inf$compute_rand_bootstrap_two_sided_pval(B = B, na.rm = FALSE, show_progress = FALSE))
	priv$active_resampling_operation = NULL
	expect_true(is.na(res$value))
	expect_length(res$all, 0L)
})
