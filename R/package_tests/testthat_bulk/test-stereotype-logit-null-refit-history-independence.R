library(testthat)
library(EDI)

# TODO-175 (release_v1_0_5.md, fixed 2026-11-07): InferenceOrdinalStereotypeLogitRegr's score / LR
# p-value at a given delta depended on which deltas had been evaluated before on the same object.
# Each delta-constrained null refit warm-started from the previous one (memoized warm cache), and the
# constrained profile has a branch per sign of beta_T, so the chain could stay on the wrong branch. Since
# the fix fit_null() ignores the carried start and uses deterministic, data-only starts (nudged full fit,
# cold, adjacent-category two-stage start, multistart offsets), so a p-value is a function of
# (data, delta) only.
#
# Data: the calibration fast tier's ordinal null replicate 1 at n = 200 (DesignFixedBernoulli, two
# covariates, cumulative-logit y, no treatment effect), rebuilt inline. Before the fix, on this data,
# the score p at delta = -0.7 / -0.6 after a grid scan was 0.121 / 0.205 vs 0.151 / 0.272 on a fresh
# object (LR 0.064 / 0.108 vs 0.049 / 0.081).

stereotype_null_rep <- function(rep = 1L, n = 200L, model_formula = ~ .) {
	set.seed(1e6 * 5 + 7L * n + rep)
	X <- data.frame(x1 = stats::rnorm(n), x2 = stats::rbinom(n, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	lat <- 0.5 * X$x1 + 0.5 * X$x2 + stats::rlogis(n)
	des$add_all_subject_responses(factor(cut(lat, c(-Inf, -1, 0, 1, Inf), labels = FALSE), levels = 1:4, ordered = TRUE))
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = model_formula, verbose = FALSE)
	inf$num_cores <- 1L
	inf
}

test_that("score and LR p-values on one object after a grid scan equal those of a fresh object", {
	skip_on_cran()
	grid <- c(-1.5, -1, -0.8, -0.7, -0.6, -0.4, 0, 0.4, 1)
	probe <- c(-0.7, -0.6)
	for (method in c("compute_score_two_sided_pval", "compute_lik_ratio_two_sided_pval")) {
		chained <- stereotype_null_rep()
		chained$compute_estimate()
		invisible(vapply(grid, function(d) suppressWarnings(chained[[method]](delta = d)), numeric(1)))
		p_chained <- vapply(probe, function(d) suppressWarnings(chained[[method]](delta = d)), numeric(1))
		p_fresh <- vapply(probe, function(d) {
			fresh <- stereotype_null_rep()
			fresh$compute_estimate()
			suppressWarnings(fresh[[method]](delta = d))
		}, numeric(1))
		expect_true(all(is.finite(p_fresh)), info = method)
		expect_identical(p_chained, p_fresh, info = method)
	}
})

test_that("the LR confidence interval is the inversion of the class's own LR test", {
	skip_on_cran()
	inf <- stereotype_null_rep()
	ci <- suppressWarnings(inf$compute_lik_ratio_confidence_interval())
	expect_true(all(is.finite(ci)))
	for (end in ci) {
		fresh <- stereotype_null_rep()
		fresh$compute_estimate()
		expect_equal(suppressWarnings(fresh$compute_lik_ratio_two_sided_pval(delta = end)), 0.05, tolerance = 0.005)
	}
})
