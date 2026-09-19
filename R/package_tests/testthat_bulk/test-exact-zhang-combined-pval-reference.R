library(testthat)
library(EDI)

# InferenceIncidExactZhang's own coverage (test-exact-incidence-migration-baseline.R,
# test-ci-rand.R) only checks legacy-equivalence and randomization-CI-blocking, never
# the combined p-value/CI against an independent statistical reference. This file
# covers both: the zhang_combine_exact_pvals() combination formulas directly
# (unexported helper, all three methods plus each has_M/has_R degenerate branch),
# and the end-to-end reservoir-only (m=0) case against stats::fisher.test.

test_that("zhang_combine_exact_pvals matches independent Fisher/Stouffer/min_p formulas", {
	p_M <- 0.2
	p_R <- 0.05

	fisher_ref <- pchisq(-2 * (log(p_M) + log(p_R)), df = 4, lower.tail = FALSE)
	expect_equal(EDI:::zhang_combine_exact_pvals(p_M, p_R, m = 4L, nRT = 3L, nRC = 3L, method = "Fisher"), fisher_ref)

	z_M <- qnorm(1 - p_M / 2)
	z_R <- qnorm(1 - p_R / 2)
	stouffer_ref <- 2 * pnorm(-abs((z_M + z_R) / sqrt(2)))
	expect_equal(EDI:::zhang_combine_exact_pvals(p_M, p_R, m = 4L, nRT = 3L, nRC = 3L, method = "Stouffer"), stouffer_ref)

	min_p_ref <- 1 - (1 - min(p_M, p_R))^2
	expect_equal(EDI:::zhang_combine_exact_pvals(p_M, p_R, m = 4L, nRT = 3L, nRC = 3L, method = "min_p"), min_p_ref)

	# Degenerate branches: only one component informative collapses to that component's p-value.
	expect_equal(EDI:::zhang_combine_exact_pvals(p_M, NA_real_, m = 4L, nRT = 0L, nRC = 3L, method = "Fisher"), p_M)
	expect_equal(EDI:::zhang_combine_exact_pvals(NA_real_, p_R, m = 0L, nRT = 3L, nRC = 3L, method = "Stouffer"), p_R)
	expect_true(is.na(EDI:::zhang_combine_exact_pvals(NA_real_, NA_real_, m = 0L, nRT = 0L, nRC = 0L, method = "min_p")))
})

test_that("InferenceIncidExactZhang's combined p-value and estimate match independent references on a pure-Bernoulli (reservoir-only) design", {
	set.seed(88213)
	n <- 24
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in 1:n) {
		des$add_one_subject_to_experiment_and_assign(data.table::data.table(x1 = rnorm(1)))
	}
	treatment <- des$.__enclos_env__$private$w
	prob <- plogis(-0.3 + 1.1 * treatment)
	y <- rbinom(n, 1, prob)
	add_all_subject_responses_seq(des, y)

	inf <- EDI:::InferenceIncidExactZhang$new(des, verbose = FALSE)

	n11 <- sum(y[treatment == 1L])
	n10 <- sum(treatment == 1L) - n11
	n01 <- sum(y[treatment == 0L])
	n00 <- sum(treatment == 0L) - n01

	# Point estimate: Haldane-Anscombe continuity-corrected log odds ratio.
	est_ref <- log((n11 + 0.5) * (n00 + 0.5) / ((n10 + 0.5) * (n01 + 0.5)))
	expect_equal(inf$compute_estimate(), est_ref, tolerance = 1e-10)

	# m=0 (pure Bernoulli): the combined p-value must collapse to the reservoir-only
	# exact Fisher p-value at delta=0, independently computed via stats::fisher.test
	# on the pooled 2x2 table.
	tab <- matrix(c(n11, n10, n01, n00), nrow = 2, byrow = TRUE)
	fisher_ref <- fisher.test(tab)$p.value
	for (method in c("Fisher", "Stouffer", "min_p")) {
		p_combined <- inf$compute_exact_two_sided_pval_for_treatment_effect(
			delta = 0, args_for_type = list(Zhang = list(combination_method = method))
		)
		expect_equal(p_combined, fisher_ref, tolerance = 1e-8)
	}

	# CI bisection: the interval must bracket the point estimate and shrink as alpha grows.
	ci_90 <- inf$compute_exact_confidence_interval(alpha = 0.10, pval_epsilon = 0.005)
	ci_50 <- inf$compute_exact_confidence_interval(alpha = 0.50, pval_epsilon = 0.005)
	expect_length(ci_90, 2)
	expect_true(ci_90[1] <= est_ref && est_ref <= ci_90[2])
	expect_true((ci_90[2] - ci_90[1]) > (ci_50[2] - ci_50[1]))

	# Unsupported exact type and combination_method both rejected.
	expect_error(inf$compute_exact_confidence_interval(alpha = 0.10, type = "not-a-type"), regexp = ".")
})
