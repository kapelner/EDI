# v1.0.6-TODO-166: the sequential Monte Carlo p-value loops (randomization:
# compute_two_sided_pval_with_sequential_mc(); randomization bootstrap:
# compute_two_sided_brt_pval_with_sequential_mc()) returned NA as soon as one
# batch prefix had too few finite draws (fewer than 10), even when the full set
# of draws had plenty. They now draw the next batch instead; the early-stop rule
# for finite prefixes is unchanged.

library(testthat)
library(EDI)

smc_control = function(conf_level = 0.99, threshold = 0.05, min_draws = 50L) {
	list(mc_enable = TRUE, mc_batch_size = 25L, mc_min_draws = min_draws,
		mc_conf_level = conf_level, mc_stop_threshold = threshold)
}

# Observed assignment has w[1] = 0. The statistic is NA whenever w[1] = w[2] = 1,
# and the first n_bad permutation columns all have that property, so the first
# batches of the null distribution are entirely non-finite.
nonfinite_prefix_fixture = function(r = 200L, n_bad = 50L, effect = 0.3) {
	set.seed(166)
	n = 30L
	X = data.frame(x1 = rnorm(n))
	d = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	w = c(0, 1, rep(c(1, 0), (n - 2L) / 2L))
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(X$x1 + rnorm(n) + effect * w)
	draw = function(bad) {
		repeat {
			ww = sample(w)
			if (identical(ww[1] == 1 && ww[2] == 1, bad)) return(ww)
		}
	}
	W = cbind(
		vapply(seq_len(n_bad), function(j) draw(TRUE), numeric(n)),
		vapply(seq_len(r - n_bad), function(j) draw(FALSE), numeric(n))
	)
	stat = function(y, w, dead) {
		if (w[1] == 1 && w[2] == 1) return(NA_real_)
		mean(y[w == 1]) - mean(y[w == 0])
	}
	list(d = d, perms = list(w_mat = W, m_mat = NULL), r = r, stat = stat)
}

rand_pval = function(fx, mc_control = NULL) {
	o = InferenceRandCustom$new(fx$d, custom_randomization_statistic_function = fx$stat, verbose = FALSE)
	o$.__enclos_env__$private$randomization_mc_control = mc_control
	o$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms, show_progress = FALSE)
}

test_that("randomization sequential MC continues past an all-NA first batch", {
	fx = nonfinite_prefix_fixture()
	full = suppressWarnings(rand_pval(fx))
	expect_true(is.finite(full))
	expect_no_warning(smc <- rand_pval(fx, smc_control()))
	expect_true(is.finite(smc))
	# With min_draws = r there is no early stop, so the sequential path must give
	# exactly the full-draw p-value.
	expect_identical(rand_pval(fx, smc_control(min_draws = fx$r)), full)
})

test_that("randomization sequential MC still gives NA when the full draws are too sparse", {
	# 185 of 200 draws non-finite: 15 finite < max(10, floor(200 / 10)) = 20.
	fx = nonfinite_prefix_fixture(n_bad = 185L)
	expect_warning(smc <- rand_pval(fx, smc_control()), "finite")
	expect_true(is.na(smc))
})

test_that("randomization-bootstrap sequential MC continues past non-finite prefixes", {
	set.seed(7)
	n = 30L
	d = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	d$overwrite_all_subject_assignments(rep(c(1, 0), n / 2L))
	d$add_all_subject_responses(rnorm(n))
	o = InferenceAllSimpleAverageDiff$new(d, verbose = FALSE)
	priv = o$.__enclos_env__$private
	B = 200L
	# Stub the per-draw evaluator: the first 50 null draws are NA, the rest a
	# fixed finite sequence. Only the loop's stopping logic is under test.
	null_vals = c(rep(NA_real_, 50L), stats::qnorm(stats::ppoints(B - 50L)))
	stub = function(draws, target, delta, transform_arg, y0_full, zero_one_logit_clamp) null_vals[seq_len(target)]
	unlockBinding("get_brt_distribution_prefix", priv)
	priv$get_brt_distribution_prefix = stub
	draws = replicate(B, list(w_b = rep(c(1, 0), n / 2L)), simplify = FALSE)
	brt = function(t, min_draws) {
		priv$brt_mc_control = smc_control(min_draws = min_draws)
		priv$compute_two_sided_brt_pval_with_sequential_mc(t, B, 0, "none", d$get_y(), draws, .Machine$double.eps)
	}
	full = priv$compute_two_sided_randomization_pval_from_t0s(null_vals, 0.1)
	expect_no_warning(p <- brt(0.1, B))
	expect_identical(p, full)
	# With early stopping allowed the result is the p-value of some batch prefix
	# past the all-NA draws (never NA).
	expect_no_warning(p_early <- brt(0.1, 50L))
	prefix_pvals = vapply(seq(75L, B, by = 25L), function(k)
		priv$compute_two_sided_randomization_pval_from_t0s(null_vals[seq_len(k)], 0.1), numeric(1L))
	expect_true(is.finite(p_early))
	expect_true(p_early %in% prefix_pvals)
})
