test_that("InferenceAllSimpleWilcox's Wald methods delegate to the rank-based test on tied data", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# compute_wald_two_sided_pval/compute_wald_confidence_interval were not
	# overridden and fell through to the generic Wald component, which
	# divides (estimate - delta) by an SE derived from
	# stats::wilcox.test()'s CI width. On heavily tied, small-integer
	# count/ordinal data the Hodges-Lehmann estimate lands on exactly 0 far
	# more often than a continuous estimator would, forcing p = 1
	# deterministically (observed pinned at 1 in ~75-98% of runs), and the
	# CI-width-backsolved SE could converge to a near-zero-width interval as
	# a root-search artifact, producing a near-[0,0] Wald CI (observed in
	# over 1,200 rows). Fixed by delegating both methods to the already-
	# correct rank-based compute_asymp_two_sided_pval/compute_asymp_
	# confidence_interval.
	n <- 60L
	p_eq_1 <- 0L
	ci_degenerate <- 0L
	R <- 60L
	for (r in seq_len(R)) {
		set.seed(3000L + r)
		y <- sample(0:3, n, replace = TRUE)
		w <- rep(c(0, 1), n / 2)
		des <- DesignFixedTestFixture$new(n = n, response_type = "count", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)

		p_wald <- inf$compute_wald_two_sided_pval()
		p_asymp <- inf$compute_asymp_two_sided_pval()
		expect_equal(p_wald, p_asymp)
		if (is.finite(p_wald) && p_wald == 1) p_eq_1 <- p_eq_1 + 1L

		ci_wald <- inf$compute_wald_confidence_interval()
		ci_asymp <- inf$compute_asymp_confidence_interval()
		expect_equal(ci_wald, ci_asymp)
		if (all(is.finite(ci_wald)) && diff(ci_wald) < 1e-3) ci_degenerate <- ci_degenerate + 1L
	}
	expect_lt(p_eq_1 / R, 0.20)
	expect_lt(ci_degenerate / R, 0.10)
})
