library(testthat)
library(EDI)

# compute_two_sided_brt_pval_with_sequential_mc() (bootstrap-randomization family):
# NULL guards (disabled control, no draws, draws without materialized w, batch >= B),
# the cached-full-distribution short circuit (keyed on B, delta, transform and the draws id),
# batch-wise stopping when the Clopper-Pearson band excludes the threshold, exhaustion at
# B, and clearing of the reusable-worker cache on exit. get_brt_distribution_prefix()
# is stubbed to a fixed pool of null statistics.

fx <- function(ctrl) {
	set.seed(1)
	n <- 12L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$brt_mc_control <- ctrl
	p
}
ctrl <- function(...) modifyList(list(mc_enable = TRUE, mc_batch_size = 300L, mc_min_draws = 300L,
	mc_conf_level = 0.99, mc_stop_threshold = 0.05), list(...))
stub_prefix <- function(p, pool) {
	targets <- integer(0)
	unlockBinding("get_brt_distribution_prefix", p)
	p$get_brt_distribution_prefix <- function(draws, target, delta, transform_arg, y0_full, zero_one_logit_clamp) {
		targets <<- c(targets, target)
		pool[seq_len(min(length(pool), target))]
	}
	function() targets
}
draws_ok <- function(B, id = NULL) {
	d <- lapply(seq_len(B), function(b) list(w_b = c(0L, 1L)))
	if (!is.null(id)) attr(d, "draws_id") <- id
	d
}
ref_p <- function(v, t) min(1, max(2 / length(v), 2 * min(sum(v >= t), sum(v <= t)) / length(v)))
run <- function(p, t, B, draws, delta = 0, transform_arg = "none") {
	p$compute_two_sided_brt_pval_with_sequential_mc(t = t, B = B, delta = delta, transform_arg = transform_arg,
		y0_full = numeric(0), draws = draws, zero_one_logit_clamp = 1e-12)
}

test_that("guards return NULL without drawing", {
	pool <- rnorm(1000)
	p <- fx(NULL); tg <- stub_prefix(p, pool)
	expect_null(run(p, 8, 1000L, draws_ok(1000L)))
	p <- fx(ctrl(mc_enable = FALSE)); tg <- stub_prefix(p, pool)
	expect_null(run(p, 8, 1000L, draws_ok(1000L)))
	p <- fx(ctrl()); tg <- stub_prefix(p, pool)
	expect_null(run(p, 8, 1000L, list()))                                        # no draws
	expect_null(run(p, 8, 1000L, list(list(w_b = NULL))))                        # w not materialized
	expect_null(run(p, 8, 300L, draws_ok(300L)))                                 # batch_size >= B
	expect_length(tg(), 0L)
})

test_that("an extreme statistic stops after the first batch, at the p-value of that prefix", {
	set.seed(3)
	pool <- rnorm(1000)
	p <- fx(ctrl()); tg <- stub_prefix(p, pool)
	out <- run(p, 8, 1000L, draws_ok(1000L))
	expect_equal(tg(), 300L)
	expect_equal(out, ref_p(pool[1:300], 8))
})

test_that("an ambiguous statistic draws successive batches until separation or B, and returns the p of the last prefix", {
	set.seed(5)
	pool <- rnorm(900)
	t_obs <- unname(quantile(pool, 0.975))
	p <- fx(ctrl(mc_batch_size = 100L, mc_min_draws = 100L)); tg <- stub_prefix(p, pool)
	out <- run(p, t_obs, 900L, draws_ok(900L))
	seen <- tg()
	expect_equal(seen, seq(100L, by = 100L, length.out = length(seen)))
	expect_equal(out, ref_p(pool[seq_len(max(seen))], t_obs))
	expect_gt(length(seen), 1L)
	# The final target is either B or a batch whose band separates from the threshold.
	if (max(seen) < 900L) {
		v <- pool[seq_len(max(seen))]; n <- length(v); a <- 0.01
		bb <- function(x) c(if (x <= 0) 0 else qbeta(a / 2, x, n - x + 1), if (x >= n) 1 else qbeta(1 - a / 2, x + 1, n - x))
		g <- bb(sum(v >= t_obs)); l <- bb(sum(v <= t_obs))
		band <- pmin(1, pmax(0, c(2 * min(g[1], l[1]), 2 * min(g[2], l[2]))))
		expect_true(band[2] < 0.05 || band[1] > 0.05)
	}
})

test_that("a fully cached distribution short-circuits the batch loop using the keyed cache entry", {
	pool <- rnorm(1000)
	p <- fx(ctrl()); tg <- stub_prefix(p, pool)
	set.seed(6)
	full <- rnorm(500)
	delta <- 0.25
	key <- paste(500L, formatC(delta, digits = 17L, format = "fg", flag = "#"), "none", "idA", sep = "|")
	p$set_cached_resampling_distribution("rand_bootstrap", key, full)
	out <- run(p, 1.1, 500L, draws_ok(500L, "idA"), delta = delta)
	expect_equal(out, ref_p(full, 1.1))
	expect_length(tg(), 0L)
	# A different draws id (or a shorter cached vector) is not a hit, so batches are drawn.
	out2 <- run(p, 1.1, 500L, draws_ok(500L, "idB"), delta = delta)
	expect_gt(length(tg()), 0L)
})

test_that("the reusable-worker cache is cleared on exit, and a non-finite p-value ends the loop", {
	p <- fx(ctrl()); tg <- stub_prefix(p, rep(NA_real_, 1000))
	p$cached_values$reusable_bootstrap_worker <- list(stale = TRUE)
	out <- run(p, 1, 1000L, draws_ok(1000L))
	expect_true(is.na(out))
	expect_equal(tg(), 300L)
	expect_null(p$cached_values$reusable_bootstrap_worker)
})
