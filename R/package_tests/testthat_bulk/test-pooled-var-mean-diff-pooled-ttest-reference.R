library(testthat)
library(EDI)

# InferenceAllSimpleMeanDiffPooledVar's compute_asymp_confidence_interval()/
# compute_asymp_two_sided_pval() implement the classical pooled-equal-variance
# Student's t-test (distinct from InferenceAllSimpleAverageDiff's Welch
# unequal-variance version, already covered elsewhere), but existing coverage
# (migration-golden/baseline tests) only checks legacy-vs-migrated equivalence
# and finiteness, never an independent statistical reference. This file
# verifies the full pooled-t formula against stats::t.test(var.equal = TRUE).

make_pooled_design <- function(n, seed) {
	set.seed(seed)
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("Pooled-variance mean-difference estimate, CI and p-value match an independent t.test(var.equal=TRUE) reference", {
	for (seed in c(5, 21, 88)) {
		des <- make_pooled_design(40L, seed)
		inf <- InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
		w <- des$get_w()
		y <- des$get_y()
		ref <- stats::t.test(y[w == 1], y[w == 0], var.equal = TRUE)

		expect_equal(inf$compute_estimate(), unname(ref$estimate[["mean of x"]] - ref$estimate[["mean of y"]]), tolerance = 1e-10)
		expect_equal(inf$compute_asymp_two_sided_pval(), ref$p.value, tolerance = 1e-10)
		ci_pkg <- inf$compute_asymp_confidence_interval(alpha = 0.05)
		expect_equal(unname(ci_pkg), as.numeric(ref$conf.int), tolerance = 1e-10)

		for (delta in c(-0.3, 0.4)) {
			t_ref <- stats::t.test(y[w == 1], y[w == 0], var.equal = TRUE, mu = delta)
			expect_equal(inf$compute_asymp_two_sided_pval(delta = delta), t_ref$p.value, tolerance = 1e-10)
		}
	}
})

test_that("Pooled-variance mean-difference CI/p-value are unavailable with fewer than 2 observations in an arm", {
	des <- DesignSeqOneByOneBernoulli$new(n = 6L, response_type = "continuous")
	set.seed(1)
	for (i in seq_len(6L)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	des$overwrite_all_subject_assignments(c(1, 0, 0, 0, 0, 0))
	des$add_all_subject_responses(rnorm(6L))
	inf <- InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	expect_true(all(is.na(inf$compute_asymp_confidence_interval())))
	expect_true(is.na(inf$compute_asymp_two_sided_pval()))
})
