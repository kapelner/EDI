library(testthat)
library(EDI)

# compute_two_sided_pval_with_sequential_mc(): the sequential Monte Carlo stopping loop,
# with get_randomization_distribution_prefix() stubbed to grow the null distribution by
# one batch per call. Checked: disabled / oversized-batch control -> NULL; early stop when
# the p-value confidence band excludes the threshold (independent Clopper-Pearson
# reference); full r draws when it never does; min_draws respected; non-finite p ends the
# loop; the p-value equals the two-sided randomization p on the drawn prefix.

fx <- function(ctrl) {
	set.seed(1)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$randomization_mc_control <- ctrl
	p
}
ctrl <- function(...) modifyList(list(mc_enable = TRUE, mc_batch_size = 20L, mc_min_draws = 20L,
	mc_conf_level = 0.99, mc_stop_threshold = 0.05), list(...))

stub_prefix <- function(p, pool) {
	calls <- 0L
	unlockBinding("get_randomization_distribution_prefix", p)
	p$get_randomization_distribution_prefix <- function(r, delta, transform_responses, show_progress, permutations, cache_key, batch_size, zero_one_logit_clamp) {
		calls <<- calls + 1L
		pool[seq_len(min(length(pool), calls * batch_size))]
	}
	function() calls
}
ref_p <- function(t0s, t) {
	v <- t0s[is.finite(t0s)]
	min(1, max(2 / length(v), 2 * min(sum(v >= t), sum(v <= t)) / length(v)))
}
ref_band <- function(t0s, t, conf) {
	v <- t0s[is.finite(t0s)]; n <- length(v); a <- 1 - conf
	bb <- function(x) c(if (x <= 0) 0 else qbeta(a / 2, x, n - x + 1), if (x >= n) 1 else qbeta(1 - a / 2, x + 1, n - x))
	g <- bb(sum(v >= t)); l <- bb(sum(v <= t))
	pmin(1, pmax(0, c(2 * min(g[1], l[1]), 2 * min(g[2], l[2]))))
}
call_smc <- function(p, r = 200L, t = 0) p$compute_two_sided_pval_with_sequential_mc(t = t, r = r, delta = 0,
	transform_responses = "none", show_progress = FALSE, permutations = NULL, cache_key = "k")

test_that("a disabled control, non-finite threshold or a batch covering all r draws returns NULL without drawing", {
	pool <- rnorm(200)
	for (cc in list(NULL, ctrl(mc_enable = FALSE), ctrl(mc_stop_threshold = NA_real_), ctrl(mc_batch_size = 500L))) {
		p <- fx(cc)
		calls <- stub_prefix(p, pool)
		expect_null(call_smc(p))
		expect_equal(calls(), 0L)
	}
	p <- fx(ctrl()); calls <- stub_prefix(p, pool)
	expect_null(call_smc(p, r = 20L))                # batch_size >= r
	expect_equal(calls(), 0L)
})

test_that("an extreme observed statistic stops after the first batch once the band excludes the threshold", {
	set.seed(3)
	pool <- rnorm(1000)
	p <- fx(ctrl(mc_batch_size = 300L, mc_min_draws = 300L)); calls <- stub_prefix(p, pool)
	t_obs <- 8                                        # far in the upper tail: no exceedances
	out <- call_smc(p, r = 1000L, t = t_obs)
	first <- pool[1:300]
	expect_equal(calls(), 1L)
	expect_equal(out, ref_p(first, t_obs))
	expect_true(ref_band(first, t_obs, 0.99)[2] < 0.05)
	# With only 20 draws the same statistic is NOT yet separable: the band is too wide, so more batches are drawn.
	p2 <- fx(ctrl()); calls2 <- stub_prefix(p2, pool)
	call_smc(p2, r = 200L, t = t_obs)
	expect_gt(calls2(), 1L)
	expect_false(ref_band(pool[1:20], t_obs, 0.99)[2] < 0.05)
})

test_that("a clearly non-significant statistic also stops early (band above the threshold)", {
	set.seed(4)
	pool <- rnorm(400)
	p <- fx(ctrl(mc_batch_size = 100L, mc_min_draws = 100L)); calls <- stub_prefix(p, pool)
	out <- call_smc(p, r = 400L, t = 0)               # centre of the null: p ~ 1
	expect_equal(calls(), 1L)
	expect_equal(out, ref_p(pool[1:100], 0))
	expect_gt(ref_band(pool[1:100], 0, 0.99)[1], 0.05)
})

test_that("an ambiguous p-value near the threshold keeps drawing until the band separates or r is exhausted", {
	set.seed(5)
	pool <- rnorm(200)
	t_obs <- unname(quantile(pool, 0.975))            # p close to 0.05
	p <- fx(ctrl(mc_stop_threshold = 0.05)); calls <- stub_prefix(p, pool)
	out <- call_smc(p, r = 200L, t = t_obs)
	k <- calls()
	expect_gt(k, 1L)
	drawn <- pool[seq_len(min(200L, k * 20L))]
	expect_equal(out, ref_p(drawn, t_obs))
	if (length(drawn) < 200L) {
		band <- ref_band(drawn, t_obs, 0.99)
		expect_true(band[2] < 0.05 || band[1] > 0.05)
		# and no earlier batch had already separated
		for (j in seq_len(k - 1L)) {
			b <- ref_band(pool[seq_len(j * 20L)], t_obs, 0.99)
			expect_false(b[2] < 0.05 || b[1] > 0.05, info = paste("batch", j))
		}
	} else expect_equal(k, 10L)
})

test_that("min_draws delays the check: fewer valid draws than mc_min_draws never trigger early stopping", {
	set.seed(6)
	pool <- rnorm(200)
	p <- fx(ctrl(mc_batch_size = 20L, mc_min_draws = 60L)); calls <- stub_prefix(p, pool)
	out <- call_smc(p, t = 8)
	# 20 and 40 valid draws are below min_draws = 60, so at least three batches are drawn (and here the
	# 60 draws still cannot separate, so the loop runs on to all r).
	expect_gte(calls(), 3L)
	expect_equal(out, ref_p(pool[seq_len(min(200L, calls() * 20L))], 8))
})

test_that("a non-finite p-value (no valid draws) ends the loop and is returned", {
	p <- fx(ctrl()); calls <- stub_prefix(p, rep(NA_real_, 200))
	out <- call_smc(p, t = 1)
	expect_true(is.na(out))
	expect_equal(calls(), 1L)
})
