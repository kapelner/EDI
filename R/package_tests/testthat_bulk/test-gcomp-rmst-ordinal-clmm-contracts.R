library(testthat)
library(EDI)

make_fixed_response_design <- function(response_type, y) {
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = response_type, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(
		x1 = seq(-1, 1, length.out = n),
		x2 = rep(c(-0.5, 0.5), length.out = n)
	))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(y)
	des
}

test_that("incidence g-computation exposes coherent RD and RR contracts", {
	y <- c(0, 0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 0, 1)
	des <- make_fixed_response_design("incidence", y)
	rd <- InferenceIncidGCompRiskDiff$new(des, model_formula = ~ x1 + x2, verbose = FALSE)
	rr <- InferenceIncidGCompRiskRatio$new(des, model_formula = ~ x1 + x2, verbose = FALSE)

	for (inf in list(rd, rr)) {
		estimate_only <- inf$compute_estimate(estimate_only = TRUE)
		estimate <- inf$compute_estimate()
		expect_equal(estimate, estimate_only)
		expect_true(is.finite(estimate))
		expect_true(is.finite(inf$get_standard_error()))
		expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
		expect_equal(inf$compute_wald_two_sided_pval(), inf$compute_asymp_two_sided_pval())
		expect_equal(inf$compute_wald_confidence_interval(alpha = 0.1),
			inf$compute_asymp_confidence_interval(alpha = 0.1))
	}

	expect_error(InferenceIncidGCompRiskDiff$new(des, prob_clip_eps = 0.51), "prob_clip_eps")
})

test_that("restricted-mean survival inference supports estimates and weighted recomputation", {
	y <- c(2, 4, 5, 8, 3, 7, 9, 10, 4, 11, 6, 12, 7, 13, 8, 14)
	des <- make_fixed_response_design("survival", y)
	inf <- InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
	estimate_only <- inf$compute_estimate(estimate_only = TRUE)
	estimate <- inf$compute_estimate()
	expect_equal(estimate, estimate_only)
	expect_true(is.finite(estimate))
	expect_error(inf$compute_rand_confidence_interval(), "not supported")
	expect_error(inf$compute_asymp_two_sided_pval(delta = 1), "TO-DO")
})

test_that("ordinal KK CLMM leaves select their documented links", {
	links <- c(
		InferenceOrdinalKKCLMM = "logit",
		InferenceOrdinalKKCLMMProbit = "probit",
		InferenceOrdinalKKCLMMCauchit = "cauchit",
		InferenceOrdinalKKCLMMCloglog = "cloglog"
	)
	for (class_name in names(links)) {
		generator <- get(class_name, envir = asNamespace("EDI"))
		expect_identical(generator$private_methods$clmm_link(), unname(links[[class_name]]), info = class_name)
		expect_true(is.function(generator$public_methods$initialize), info = class_name)
	}
})
