# v1.2.0-TODO-207 (owner ruling 2026-11-23): every Monte Carlo randomization p-value counts
# the observed statistic as one draw (Phipson and Smyth 2010). Per tail (1 + b) / (1 + B);
# two-sided by doubling the smaller tail, min(1, 2 * (1 + min(b_ge, b_le)) / (1 + B)); two-sided
# from an absolute statistic, min(1, (1 + #{|T_m| >= |T_obs|}) / (1 + B)). Never 0.

test_that("doubled-smaller-tail rule on known tail counts", {
	f = EDI:::rand_pval_from_tail_counts
	expect_identical(f(0, 200, 200), 2 / 201)
	expect_identical(f(200, 0, 200), 2 / 201)
	expect_equal(f(5, 196, 201), 2 * 6 / 202)
	expect_equal(f(196, 5, 201), 2 * 6 / 202)
	expect_equal(f(30, 80, 100), 2 * 31 / 101)
	# ties counted in both tails: n_ge + n_le can exceed n
	expect_equal(f(51, 51, 101), 1)
})

test_that("two-sided rule is capped at 1", {
	f = EDI:::rand_pval_from_tail_counts
	expect_identical(f(100, 100, 100), 1)
	expect_identical(f(50, 50, 100), 1)          # 2 * 51 / 101 > 1
	expect_equal(f(49, 51, 100), 100 / 101)      # 2 * 50 / 101 = 0.990..., not capped
})

test_that("one-sided variants use the matching single tail with no doubling", {
	f = EDI:::rand_pval_from_tail_counts
	expect_equal(f(3, 98, 100, "greater"), 4 / 101)
	expect_equal(f(3, 98, 100, "less"), 99 / 101)
	expect_equal(f(98, 3, 100, "less"), 4 / 101)
	expect_identical(f(0, 100, 100, "greater"), 1 / 101)
	expect_identical(f(100, 0, 100, "less"), 1 / 101)
	expect_identical(f(100, 100, 100, "greater"), 1)
	expect_identical(f(100, 100, 100, "less"), 1)
})

test_that("absolute-statistic rule is (1 + b) / (1 + B), capped at 1", {
	g = EDI:::rand_pval_from_abs_count
	expect_identical(g(0, 200), 1 / 201)
	expect_equal(g(9, 200), 10 / 201)
	expect_identical(g(200, 200), 1)
})

test_that("no rule ever returns 0 or a value below its smallest attainable p", {
	f = EDI:::rand_pval_from_tail_counts
	g = EDI:::rand_pval_from_abs_count
	for (B in c(10L, 101L, 201L, 501L)) {
		k = 0:B
		p2 = vapply(k, function(b) f(b, B - b, B), numeric(1))
		pg = vapply(k, function(b) f(b, B - b, B, "greater"), numeric(1))
		pl = vapply(k, function(b) f(B - b, b, B, "less"), numeric(1))
		pa = vapply(k, g, numeric(1), n = B)
		expect_true(all(p2 >= 2 / (B + 1) - 1e-15 & p2 <= 1))
		expect_true(all(pg >= 1 / (B + 1) - 1e-15 & pg <= 1))
		expect_true(all(pl >= 1 / (B + 1) - 1e-15 & pl <= 1))
		expect_true(all(pa >= 1 / (B + 1) - 1e-15 & pa <= 1))
		expect_false(any(c(p2, pg, pl, pa) == 0))
	}
})

test_that("the rules are exact: rejection probability <= alpha under exchangeable ranks", {
	# Under H0 the number of reference draws >= T_obs is uniform on {0, ..., B} (no ties),
	# so the exact size is #{k : p(k) <= alpha} / (B + 1).
	f = EDI:::rand_pval_from_tail_counts
	g = EDI:::rand_pval_from_abs_count
	for (B in c(101L, 201L, 501L)) for (alpha in c(0.01, 0.05)) {
		k = 0:B
		size_two = mean(vapply(k, function(b) f(b, B - b, B), numeric(1)) <= alpha)
		size_gt = mean(vapply(k, function(b) f(b, B - b, B, "greater"), numeric(1)) <= alpha)
		size_abs = mean(vapply(k, g, numeric(1), n = B) <= alpha)
		expect_lte(size_two, alpha)
		expect_lte(size_gt, alpha)
		expect_lte(size_abs, alpha)
	}
	# the pre-1.0.5 rule b / B with floor 2 / B was not: 12 / 202 at B = 201, alpha = 0.05
	old = function(b, B) min(1, max(2 / B, 2 * min(b, B - b) / B))
	expect_gt(mean(vapply(0:201, old, numeric(1), B = 201) <= 0.05), 0.05)
})

test_that("studentized and symmetric-percentile-t BRT p-values count the observed draw", {
	component = EDI:::inference_component_source_parts(EDI:::InferenceRandBootstrap)
	brt = component$private$compute_two_sided_brt_pval_studentized
	environment(brt) = asNamespace("EDI")
	t0_b = c(-3, -2, -1, 0.5, 1, 2, 4, NA)        # 7 finite draws
	se0_b = rep(1, length(t0_b))
	# signed pivot: z_obs = 3; one draw (4) above, six below
	p_signed = brt(t = 3, t0_b = t0_b, se0_b = se0_b, delta = 0, se_obs = 1, symmetric = FALSE)
	expect_equal(p_signed, EDI:::rand_pval_from_tail_counts(1, 6, 7))
	expect_equal(p_signed, 2 * 2 / 8)
	# absolute pivot: |z_obs| = 3; draws with |z| >= 3 are -3 and 4 (tie counted)
	p_abs = brt(t = 3, t0_b = t0_b, se0_b = se0_b, delta = 0, se_obs = 1, symmetric = TRUE)
	expect_equal(p_abs, 3 / 8)
	# far beyond every draw: smallest values, not 0
	expect_equal(brt(t = 100, t0_b = t0_b, se0_b = se0_b, delta = 0, se_obs = 1, symmetric = FALSE), 2 / 8)
	expect_equal(brt(t = 100, t0_b = t0_b, se0_b = se0_b, delta = 0, se_obs = 1, symmetric = TRUE), 1 / 8)
})

test_that("compute_rand_two_sided_pval on real draws matches the rule and is never 0", {
	set.seed(1)
	n = 16
	des = DesignFixediBCRD$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	# a huge effect: every reference draw is less extreme than the observed statistic
	des$add_all_subject_responses(rnorm(n, sd = 0.01) + 100 * w)
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$set_seed(7)
	r = 99L
	p_two = inf$compute_rand_two_sided_pval(r = r, show_progress = FALSE)
	p_gt = inf$compute_rand_two_sided_pval(r = r, show_progress = FALSE, alternative = "greater")
	p_lt = inf$compute_rand_two_sided_pval(r = r, show_progress = FALSE, alternative = "less")
	expect_equal(p_two, 2 / (r + 1))
	expect_equal(p_gt, 1 / (r + 1))
	expect_equal(p_lt, 1)
})
