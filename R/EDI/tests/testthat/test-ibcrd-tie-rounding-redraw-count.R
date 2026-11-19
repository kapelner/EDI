# v1.0.6-TODO-213: when n * prob_T ends in .5, DesignSeqOneByOneiBCRD's assign_wt() targets R's
# round() (half to even) but the C++ redraw kernel used std::round (half away from zero), so n = 21,
# prob_T = 0.5 realized 10 treated while every randomization redraw had 11. Owner decision
# 2026-11-19, option (b): the redraw is handed the realized count, so realized allocations are
# unchanged and only the redraws move. DesignFixediBCRD draws its realized allocation from the
# same kernel as its redraws, so it always agreed (ties round up there).

library(testthat)
library(EDI)

seq_ibcrd_enroll = function(n, prob_T, set_seed, y = NULL) {
	set.seed(set_seed)
	d = DesignSeqOneByOneiBCRD$new(n = n, prob_T = prob_T, response_type = "continuous", verbose = FALSE)
	for (t in seq_len(n)) d$add_one_subject_to_experiment_and_assign(data.frame(x1 = t / n))
	if (!is.null(y)) d$add_all_subject_responses(y)
	d
}

# n * prob_T ends in .5 in every case; the first rows round down under half-to-even.
tie_cases = list(
	list(n = 21L, p = 0.5), list(n = 5L, p = 0.5), list(n = 9L, p = 0.5), list(n = 23L, p = 0.5),
	list(n = 10L, p = 0.25), list(n = 14L, p = 0.75), list(n = 22L, p = 0.75), list(n = 6L, p = 0.25)
)

test_that("DesignSeqOneByOneiBCRD redraws have the realized number treated at a .5 tie", {
	for (cfg in tie_cases) for (s in 1:2) {
		d = seq_ibcrd_enroll(cfg$n, cfg$p, set_seed = s)
		n_T = sum(d$get_w())
		expect_equal(n_T, round(cfg$n * cfg$p), info = paste(cfg$n, cfg$p))
		set.seed(100L + s)
		ws = d$draw_ws_according_to_design(60)
		expect_identical(dim(ws), c(cfg$n, 60L))
		expect_true(all(colSums(ws) == n_T), info = paste(cfg$n, cfg$p, s))
	}
})

test_that("DesignSeqOneByOneiBCRD realized allocations are unchanged at a tie (recorded before the fix)", {
	paste_w = function(d) paste(d$get_w(), collapse = "")
	# Same goldens as test-seq-ibcrd-requires-n.R (n = 21 and 15 at prob_T = 0.5 are ties).
	expect_identical(paste_w(seq_ibcrd_enroll(21L, 0.5, set_seed = 1L)), "000010001111010100111")
	d = seq_ibcrd_enroll(10L, 0.25, set_seed = 3L)
	expect_equal(sum(d$get_w()), 2)
})

test_that("DesignSeqOneByOneiBCRD redraws keep every planned count on a grid of n and prob_T", {
	for (n in c(2L, 3L, 5L, 7L, 11L, 13L, 19L, 25L)) for (p in c(0.1, 0.25, 0.3, 0.5, 0.7, 0.75, 0.9)) {
		n_T = round(n * p)
		if (n_T < 1 || n_T > n - 1) next
		d = seq_ibcrd_enroll(n, p, set_seed = n)
		expect_equal(sum(d$get_w()), n_T, info = paste(n, p))
		set.seed(7L)
		expect_true(all(colSums(d$draw_ws_according_to_design(20)) == n_T), info = paste(n, p))
	}
})

test_that("DesignFixediBCRD realized allocation and redraws agree at a .5 tie (ties round up)", {
	for (cfg in tie_cases) {
		des = DesignFixediBCRD$new(n = cfg$n, prob_T = cfg$p, response_type = "continuous", seed = 4L)
		des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(cfg$n) / cfg$n))
		des$assign_w_to_all_subjects()
		n_T = sum(des$get_w())
		expect_equal(n_T, floor(cfg$n * cfg$p + 0.5), info = paste(cfg$n, cfg$p))
		set.seed(9L)
		expect_true(all(colSums(des$draw_ws_according_to_design(40)) == n_T), info = paste(cfg$n, cfg$p))
	}
})

test_that("DesignSeqOneByOneiBCRD randomization null at a tie uses the realized treated count", {
	# n = 5, prob_T = 0.5: 2 treated (round(2.5) = 2). With y = 2^(0:4) the mean differences of the
	# 2-treated and 3-treated allocations are disjoint sets, so the randomization distribution must
	# lie entirely in the 2-treated support (the old redraw, with 3 treated, never did).
	y = 2^(0:4)
	d = seq_ibcrd_enroll(5L, 0.5, set_seed = 2L, y = y)
	expect_equal(sum(d$get_w()), 2)
	diff_for = function(tr) mean(y[tr]) - mean(y[-tr])
	support2 = apply(combn(5, 2), 2, diff_for)
	support3 = apply(combn(5, 3), 2, diff_for)
	expect_length(intersect(round(support2, 10), round(support3, 10)), 0L)
	inf = InferenceAllSimpleAverageDiff$new(d)
	set.seed(11L)
	null_draws = inf$approximate_randomization_distribution_beta_hat_T(r = 200, show_progress = FALSE)
	null_draws = null_draws[is.finite(null_draws)]
	expect_gt(length(null_draws), 100L)
	expect_true(all(round(null_draws, 10) %in% round(support2, 10)))
	set.seed(12L)
	p = inf$compute_rand_two_sided_pval(r = 1000, show_progress = FALSE)
	expect_true(is.finite(p) && p > 0 && p <= 1)
	# The exact 2-treated doubled-tail p-value over all 10 allocations (0.6 here), against the
	# Monte Carlo one.
	obs = diff_for(which(d$get_w() == 1))
	tail_p = function(s) min(1, 2 * min(mean(s >= obs - 1e-12), mean(s <= obs + 1e-12)))
	expect_lt(abs(p - tail_p(support2)), 0.1)
})
