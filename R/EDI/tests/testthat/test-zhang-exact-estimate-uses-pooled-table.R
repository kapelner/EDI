library(testthat)
library(EDI)

# v1.0.6-TODO-147: InferenceIncidExactZhang's point estimate is the Haldane-Anscombe log
# odds ratio of the pooled 2x2 table over all subjects (matched and reservoir together),
# as documented. It used the reservoir-only table, so on a KK design with every subject
# matched it was identically 0. The exact test (matched-pair binomial + reservoir Fisher,
# combined) and its CI are unchanged: they still use the separate matched / reservoir
# statistics.

pooled_log_or = function(y, w) {
	log((sum(y[w == 1]) + 0.5) * (sum(1 - y[w == 0]) + 0.5) /
		((sum(1 - y[w == 1]) + 0.5) * (sum(y[w == 0]) + 0.5)))
}

# A real KK14 design whose match vector is then set so every subject is in a pair.
all_matched_kk_fx = function(seed, n_pairs = 15L) {
	set.seed(seed)
	n = 2L * n_pairs
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X = data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	m = integer(n)
	tr = which(w == 1L); ct = which(w == 0L)
	k = min(length(tr), length(ct))
	m[tr[seq_len(k)]] = seq_len(k); m[ct[seq_len(k)]] = seq_len(k)
	if (k < n_pairs) {   # pair any leftover same-arm subjects with each other
		rest = which(m == 0L)
		m[rest] = k + rep(seq_len(length(rest) / 2L), each = 2L)
	}
	des$.__enclos_env__$private$m = m
	y = rbinom(n, 1, plogis(-0.3 + 1.2 * w))
	des$add_all_subject_responses(y)
	list(des = des, w = w, y = y, m = m)
}

test_that("on a KK design with every subject matched the estimate is the pooled-table log odds ratio, not 0", {
	for (seed in c(1L, 4L, 9L)) {
		f = all_matched_kk_fx(seed)
		inf = InferenceIncidExactZhang$new(f$des, verbose = FALSE)
		stats = EDI:::zhang_get_exact_stats(inf)
		expect_equal(stats$nRT + stats$nRC, 0L, info = seed)                      # no reservoir at all
		est = inf$compute_estimate()
		expect_equal(est, pooled_log_or(f$y, f$w), tolerance = 1e-12, info = seed)
		expect_false(isTRUE(all.equal(est, 0)), info = seed)
		# The reservoir-only estimate the class used to return is 0 here.
		expect_equal(EDI:::zhang_incid_treatment_estimate(stats), 0, info = seed)
	}
})

test_that("on a fully matched DesignFixedBinaryMatch the estimate is the pooled-table log odds ratio", {
	skip_if_not_installed("nbpMatching")
	set.seed(21)
	n = 30L
	des = DesignFixedBinaryMatch$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rbinom(n, 1, plogis(-0.3 + 1.2 * w))
	des$add_all_subject_responses(y)
	inf = InferenceIncidExactZhang$new(des, verbose = FALSE)
	expect_equal(inf$compute_estimate(), pooled_log_or(y, w), tolerance = 1e-12)
})

test_that("with matched pairs and a reservoir the estimate uses all subjects, while the exact test keeps its components", {
	f = all_matched_kk_fx(5L)
	n = length(f$y)
	m = f$m
	m[m > 10L] = 0L                                                              # pairs 11..15 back to the reservoir
	f$des$.__enclos_env__$private$m = m
	inf = InferenceIncidExactZhang$new(f$des, verbose = FALSE)
	stats = EDI:::zhang_get_exact_stats(inf)
	expect_gt(stats$nRT + stats$nRC, 0L)
	expect_equal(inf$compute_estimate(), pooled_log_or(f$y, f$w), tolerance = 1e-12)
	# p-value at 0 is still the combination of the matched-pair binomial and reservoir Fisher tests.
	res = m == 0L
	p_R = fisher.test(matrix(c(sum(f$y[res & f$w == 1]), sum(f$y[res & f$w == 0]),
		sum(1 - f$y[res & f$w == 1]), sum(1 - f$y[res & f$w == 0])), 2))$p.value
	k = stats$d_plus + stats$d_minus
	p_M = if (k > 0L) binom.test(stats$d_plus, k)$p.value else NA_real_
	expected = EDI:::zhang_combine_exact_pvals(p_M, p_R, stats$m, stats$nRT, stats$nRC, "Fisher")
	expect_equal(inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0), expected, tolerance = 1e-8)
})

test_that("with no matching (Bernoulli) the estimate is unchanged: the pooled table is the exact-test table", {
	set.seed(3)
	n = 40L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rbinom(n, 1, plogis(-0.2 + 0.8 * w))
	des$add_all_subject_responses(y)
	inf = InferenceIncidExactZhang$new(des, verbose = FALSE)
	est = inf$compute_estimate()
	expect_equal(est, pooled_log_or(y, w), tolerance = 1e-12)
	expect_identical(est, EDI:::zhang_incid_treatment_estimate(EDI:::zhang_get_exact_stats(inf)))
})
