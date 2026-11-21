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

# v1.0.6-TODO-293 (docs-scenarios fixed-designs F1): after a randomization p-value the asymptotic
# p-value and CI came back NA, because the randomization path cached beta_hat_T without the per-arm
# responses that the pooled-t components read.
test_that("Pooled-variance asymptotic p-value and CI do not depend on which procedure ran first", {
	set.seed(1)
	n = 20
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	y = X$x1 + rnorm(n)
	des = DesignFixediBCRD$new(response_type = "continuous", n = n, seed = 1, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(y)
	w = des$get_w()
	ref = stats::t.test(y[w == 1], y[w == 0], var.equal = TRUE)
	fresh = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
	p0 = fresh$compute_asymp_two_sided_pval()
	ci0 = fresh$compute_asymp_confidence_interval()
	expect_equal(p0, ref$p.value, tolerance = 1e-10)
	expect_equal(unname(ci0), as.numeric(ref$conf.int), tolerance = 1e-10)
	before = list(
		rand_pval = function(inf) inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE),
		rand_ci = function(inf) inf$compute_rand_confidence_interval(r = 101, show_progress = FALSE),
		bootstrap = function(inf) inf$compute_bootstrap_confidence_interval(B = 51, show_progress = FALSE)
	)
	for (nm in names(before)) {
		inf = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
		inf$set_seed(3)
		suppressWarnings(before[[nm]](inf))
		expect_equal(inf$compute_asymp_two_sided_pval(), p0, tolerance = 1e-10, info = nm)
		expect_equal(inf$compute_asymp_confidence_interval(), ci0, tolerance = 1e-10, info = nm)
		# and the reverse order: asymptotic first, then the resampling procedure, then asymptotic again
		inf2 = InferenceAllSimpleMeanDiffPooledVar$new(des, verbose = FALSE)
		inf2$set_seed(3)
		expect_equal(inf2$compute_asymp_two_sided_pval(), p0, tolerance = 1e-10, info = nm)
		suppressWarnings(before[[nm]](inf2))
		expect_equal(inf2$compute_asymp_two_sided_pval(), p0, tolerance = 1e-10, info = nm)
		expect_equal(inf2$compute_asymp_confidence_interval(), ci0, tolerance = 1e-10, info = nm)
	}
})
