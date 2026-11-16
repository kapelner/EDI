library(testthat)
library(EDI)

# The Zhang exact CI must be the inversion of the combined test it reports. Its endpoint
# search used to start from the reservoir-only log odds ratio, which is always 0 when every
# subject is matched (DesignFixedBinaryMatch): the interval then held 0 even when the test
# rejected at 0. Found by calibration campaign 2026-11-15-e36c7710 (coverage 1.00 on
# BinaryMatch at every n, 0.85-0.88 on KK21 / KK21stepwise at n = 1000, test size 0.02-0.05).

make_zhang_all_matched_design = function(n_win, n_lose, n_pairs = 20L) {
	set.seed(11)
	x_dat = data.frame(x1 = rnorm(2L * n_pairs), x2 = rnorm(2L * n_pairs))
	des = DesignFixedBinaryMatch$new(n = nrow(x_dat), response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(x_dat)
	des$assign_w_to_all_subjects()
	des$.__enclos_env__$private$ensure_matching_structure_computed()
	m = as.integer(des$.__enclos_env__$private$m)
	w = des$get_w()
	y = integer(length(w))
	for (pair_id in sort(unique(m[m > 0L]))) {
		idx = which(m == pair_id)
		if (pair_id <= n_win) {
			y[idx[w[idx] == 1L]] = 1L
		} else if (pair_id <= n_win + n_lose) {
			y[idx[w[idx] == 0L]] = 1L
		} else if (pair_id %% 2L == 0L) {
			y[idx] = 1L
		}
	}
	des$add_all_subject_responses(y)
	des
}

test_that("Zhang CI excludes 0 when the combined test rejects at 0 on an all-matched design", {
	skip_if_not_installed("nbpMatching")
	inf = InferenceIncidExactZhang$new(make_zhang_all_matched_design(n_win = 12L, n_lose = 1L), verbose = FALSE)
	stats = EDI:::zhang_get_exact_stats(inf)
	expect_equal(stats$nRT + stats$nRC, 0L)
	p0 = inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0)
	expect_lt(p0, 0.05)
	ci = inf$compute_exact_confidence_interval(alpha = 0.05)
	expect_true(all(is.finite(ci)))
	expect_gt(ci[1], 0)
	# Each endpoint is a boundary of the acceptance region: accepted just inside, rejected just outside.
	p_at = function(d) inf$compute_exact_two_sided_pval_for_treatment_effect(delta = d)
	expect_gt(p_at(ci[1] + 1e-4), 0.05)
	expect_lte(p_at(ci[1] - 1e-4), 0.05)
	expect_gt(p_at(ci[2] - 1e-4), 0.05)
	expect_lte(p_at(ci[2] + 1e-4), 0.05)
})

test_that("Zhang CI holds 0 when the combined test accepts at 0 on an all-matched design", {
	skip_if_not_installed("nbpMatching")
	inf = InferenceIncidExactZhang$new(make_zhang_all_matched_design(n_win = 5L, n_lose = 4L), verbose = FALSE)
	expect_gt(inf$compute_exact_two_sided_pval_for_treatment_effect(delta = 0), 0.05)
	ci = inf$compute_exact_confidence_interval(alpha = 0.05)
	expect_lt(ci[1], 0)
	expect_gt(ci[2], 0)
})
