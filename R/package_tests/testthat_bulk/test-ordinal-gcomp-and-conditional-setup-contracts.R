library(testthat)
library(EDI)

make_ordinal_gcomp_design <- function() {
	y <- rep(1:4, 8L)
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1, 1, 0), 8L))
	des$add_all_subject_responses(y)
	des
}

test_that("ordinal g-computation exposes coherent mean-difference inference", {
	des <- make_ordinal_gcomp_design()
	estimate_only <- InferenceOrdinalGCompMeanDiff$new(
		des, model_formula = ~ x1, verbose = FALSE
	)$compute_estimate(estimate_only = TRUE)
	inf <- InferenceOrdinalGCompMeanDiff$new(des, model_formula = ~ x1, verbose = FALSE)
	estimate <- inf$compute_estimate()
	expect_equal(estimate, estimate_only, tolerance = 1e-10)
	expect_true(is.finite(estimate))
	expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_equal(inf$compute_wald_confidence_interval(alpha = 0.1),
		inf$compute_asymp_confidence_interval(alpha = 0.1))
	expect_equal(inf$compute_wald_two_sided_pval(), inf$compute_asymp_two_sided_pval())
})

test_that("ordinal conditional-logit setup creates singleton reservoir strata", {
	private_env <- new.env(parent = emptyenv())
	private_env$m <- c(1L, 1L, NA, 2L, 2L, NA)
	private_env$n <- 6L
	private_env$y <- c("low", "mid", "high", "low", "high", "mid")
	setup <- EDI:::ordinal_cond_clogit_compute_setup(private_env)
	expect_identical(setup$strata_ids, c(1L, 1L, 3L, 2L, 2L, 4L))
	expect_identical(setup$K, 3L)
	expect_identical(setup$n_alpha, 2L)
	expect_identical(setup$y_ord, as.integer(factor(private_env$y, ordered = TRUE)))
})

test_that("ordinal conditional-logit setup handles an all-reservoir design", {
	private_env <- new.env(parent = emptyenv())
	private_env$m <- NULL
	private_env$n <- 4L
	private_env$y <- c(1L, 2L, 2L, 3L)
	setup <- EDI:::ordinal_cond_clogit_compute_setup(private_env)
	expect_identical(setup$strata_ids, 1:4)
	expect_identical(setup$K, 3L)
})

test_that("ordinal conditional and combined leaves advertise likelihood policy", {
	expect_false(EDI:::InferenceOrdinalKKCondAdjCatLogitRegr$private_methods$supports_likelihood_tests())
	gee <- EDI:::InferenceOrdinalKKGEE$private_methods
	expect_identical(gee$gee_response_type(), "ordinal")
	expect_false(gee$supports_bayesian_bootstrap())

	links <- c(logit = "InferenceOrdinalKKCLMM", probit = "InferenceOrdinalKKCLMMProbit",
		cauchit = "InferenceOrdinalKKCLMMCauchit", cloglog = "InferenceOrdinalKKCLMMCloglog")
	for (link in names(links)) {
		generator <- get(links[[link]], envir = asNamespace("EDI"))
		expect_identical(generator$private_methods$clmm_link(), link)
	}
})
