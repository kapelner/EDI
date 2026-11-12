library(testthat)
library(EDI)

# v1.0.5 TODO-18 (owner decision 2026-11-12, option A): the permanent check that
# smoothing does not change randomization-bootstrap calibration. The 9-cell true-null
# study (G4-C runbook R3, n = 148, B = 101, >= 500 cases per cell) found smoothed and
# percentile p-values rejecting at the same rate in every cell (paired discordance
# <= 2.4%); the two cells that missed the 5% target (OLS ~. and Poisson ~. on 24
# covariates at n = 148) failed equally for both variants, a limitation of the
# unstudentized bootstrap at high p / n, not of smoothing.
#
# What this pins: on a fixed-seed true-null fixture, the smoothed p-value, fed the
# SAME materialized draws as the percentile p-value, makes almost the same reject
# decisions. It does not assert a nominal 5% size: at small n the unstudentized
# bootstrap itself is anti-conservative (this fixture's count cell rejects about 11% for
# both variants; see the rand-bootstrap documentation), so a size band would test the
# bootstrap, not the smoothing.
#
# Fixture choice: InferenceAllSimpleAverageDiff on count and continuous responses,
# DesignSeqOneByOneBernoulli, n = 60, B = 51, 100 cases each (prototype 2026-11-12,
# 150 cases: count 16 vs 18 rejections, 2 discordant; continuous 5 vs 6, 1 discordant).

brt_paired_null_pvals = function(response_type, n_case = 100L, n = 60L, B = 51L) {
	out = matrix(NA_real_, n_case, 2L, dimnames = list(NULL, c("percentile", "smoothed")))
	for (i in seq_len(n_case)) {
		set.seed(1800L + i)
		X = data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
		des = DesignSeqOneByOneBernoulli$new(response_type = response_type, n = n)
		for (t in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[t, , drop = FALSE])
		y = if (identical(response_type, "count")) stats::rpois(n, exp(0.5 + 0.3 * X$x1)) else 1 + X$x1 + stats::rnorm(n)
		des$add_all_subject_responses(y)
		inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
		set.seed(9000000L + i)
		draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(B, materialize_w = TRUE)
		out[i, "percentile"] = inf$compute_rand_bootstrap_two_sided_pval(B = B, rand_bootstrap_draws = draws,
			type = "percentile", show_progress = FALSE)
		set.seed(20000000L + i)
		out[i, "smoothed"] = inf$compute_rand_bootstrap_two_sided_pval(B = B, rand_bootstrap_draws = draws,
			type = "smoothed", show_progress = FALSE)
	}
	out
}

for (rt in c("count", "continuous")) {
	test_that(sprintf("smoothed BRT p-value tracks the percentile p-value under the null (%s)", rt), {
		skip_on_cran()
		p = brt_paired_null_pvals(rt)
		expect_true(all(is.finite(p)))
		expect_true(all(p >= 0 & p <= 1))
		reject = p < 0.05
		# Paired on identical draws, smoothing moves a decision only when a p-value sits
		# at the threshold: at most 5 of 100 discordant, rejection counts within 4.
		expect_lte(sum(reject[, "percentile"] != reject[, "smoothed"]), 5L)
		expect_lte(abs(sum(reject[, "smoothed"]) - sum(reject[, "percentile"])), 4L)
		# Smoothing must not make the test grossly anti-conservative relative to percentile.
		expect_lte(sum(reject[, "smoothed"]), 20L)
	})
}
