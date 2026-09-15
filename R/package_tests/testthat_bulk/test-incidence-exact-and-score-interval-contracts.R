library(testthat)
library(EDI)

make_exact_incidence_design <- function() {
	y <- c(0, 1, 0, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("Newcombe and Miettinen-Nurminen estimate the observed risk difference", {
	des <- make_exact_incidence_design()
	w <- des$get_w()
	y <- des$get_y()
	expected <- mean(y[w == 1]) - mean(y[w == 0])
	for (generator in list(InferenceIncidNewcombeRiskDiff, InferenceIncidMiettinenNurminenRiskDiff)) {
		inf <- generator$new(des, verbose = FALSE)
		expect_equal(inf$compute_estimate(estimate_only = TRUE), expected, tolerance = 1e-12)
		expect_equal(inf$compute_estimate(), expected, tolerance = 1e-12)
		ci <- inf$compute_asymp_confidence_interval(alpha = 0.1)
		expect_length(ci, 2L)
		expect_lte(ci[[1]], expected)
		expect_gte(ci[[2]], expected)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	}
})

test_that("exact-binomial inference exposes a finite estimate and exact result", {
	y <- rep(c(0, 1, 1, 0), 2L)
	des <- DesignFixedBinaryMatch$new(
		n = 8L, m = rep(1:4, each = 2L), response_type = "incidence", verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(8L)))
	des$assign_w_to_all_subjects(w_precomputed = rep(c(0, 1), 4L))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidExactBinomial$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
	p <- inf$compute_exact_two_sided_pval_for_treatment_effect()
	expect_true(is.finite(p) && p >= 0 && p <= 1)
	ci <- inf$compute_exact_confidence_interval(alpha = 0.1)
	expect_length(ci, 2L)
})

test_that("Zhang exact-p combination handles single and dual components", {
	expect_equal(EDI:::zhang_combine_exact_pvals(0.2, NA, m = 3L, nRT = 0L, nRC = 0L, method = "Fisher"), 0.2)
	expect_equal(EDI:::zhang_combine_exact_pvals(NA, 0.3, m = 0L, nRT = 4L, nRC = 4L, method = "Fisher"), 0.3)
	combined <- EDI:::zhang_combine_exact_pvals(0.2, 0.3, m = 3L, nRT = 4L, nRC = 4L, method = "Fisher")
	expect_true(is.finite(combined) && combined >= 0 && combined <= 1)
	expect_true(is.na(EDI:::zhang_combine_exact_pvals(NA, NA, m = 0L, nRT = 0L, nRC = 0L, method = "Fisher")))
})

test_that("Zhang CI bisection locates both increasing and decreasing boundaries", {
	decreasing <- EDI:::zhang_bisect_ci_boundary(function(x) exp(-abs(x)), inside = 0, outside = 5,
		pval_th = 0.2, tol = 1e-7)
	increasing_side <- EDI:::zhang_bisect_ci_boundary(function(x) exp(-abs(x)), inside = 0, outside = -5,
		pval_th = 0.2, tol = 1e-7)
	expect_equal(decreasing, -log(0.2), tolerance = 1e-5)
	expect_equal(increasing_side, log(0.2), tolerance = 1e-5)
})

test_that("blocking-only incidence procedures explain incompatible designs", {
	des <- make_exact_incidence_design()
	er_reason <- InferenceIncidExtendedRobins$private_methods$design_compatibility_reason(des)
	cmh_reason <- InferenceIncidCMH$private_methods$design_compatibility_reason(des)
	expect_true(is.character(er_reason) && nzchar(er_reason))
	expect_true(is.character(cmh_reason) && nzchar(cmh_reason))
})
