library(testthat)
library(EDI)

make_ordinal_contract_design <- function(y, w = rep(c(0, 1), length.out = length(y))) {
	n <- length(y)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = seq(-1, 1, length.out = n)))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	des
}

test_that("Jonckheere-Terpstra estimate equals centered pairwise superiority", {
	y <- c(1L, 2L, 2L, 3L, 1L, 3L, 3L, 4L, 2L, 4L, 1L, 4L)
	w <- rep(c(0, 1), 6L)
	des <- make_ordinal_contract_design(y, w)
	inf <- InferenceOrdinalJonckheereTerpstraTest$new(des, verbose = FALSE)
	pairs <- outer(y[w == 1], y[w == 0], "-")
	expected <- mean((pairs > 0) + 0.5 * (pairs == 0)) - 0.5

	expect_equal(inf$compute_estimate(estimate_only = TRUE), expected, tolerance = 1e-12)
	expect_equal(inf$compute_estimate(), expected, tolerance = 1e-12)
	expect_true(is.finite(inf$compute_exact_two_sided_pval_for_treatment_effect()))
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_length(inf$compute_asymp_confidence_interval(alpha = 0.1), 2L)
})

test_that("exact Jonckheere-Terpstra kernel validates assignments and dimensions", {
	y <- c(1L, 2L, 3L, 4L)
	expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(y, c(0L, 1L)), "dimension mismatch")
	expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(y, c(0L, 2L, 0L, 1L)), "0/1")
	expect_error(EDI:::exact_jonckheere_terpstra_pval_cpp(y, rep(0L, 4L)), "both treatment arms")
})

test_that("partial proportional-odds model exposes finite common treatment inference", {
	skip_if_not_installed("ordinal")
	y <- rep(1:4, 8L)
	w <- rep(c(0, 1, 1, 0), 8L)
	des <- make_ordinal_contract_design(y, w)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(
		des, model_formula = ~ x1, nonparallel = "x1", verbose = FALSE
	)
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
	expect_true(is.finite(inf$compute_estimate()))
	expect_length(inf$compute_wald_confidence_interval(alpha = 0.1), 2L)
	expect_true(is.finite(inf$compute_wald_two_sided_pval()))
})

test_that("paired-sign compatibility predicate distinguishes matching designs", {
	fixed <- make_ordinal_contract_design(rep(1:4, 2L))
	predicate <- InferenceOrdinalPairedSignTest$private_methods$design_compatibility_reason
	expect_identical(predicate(fixed), "paired_sign_test_requires_matching_design")

	kk <- DesignSeqOneByOneKK14$new(n = 4L, response_type = "ordinal", verbose = FALSE)
	expect_true(is.na(predicate(kk)))
})

test_that("ordinal KK combined leaf advertises ordinal response and bootstrap policy", {
	priv <- EDI:::InferenceOrdinalKKGEE$private_methods
	expect_identical(priv$gee_response_type(), "ordinal")
	expect_false(priv$supports_bayesian_bootstrap())
})
