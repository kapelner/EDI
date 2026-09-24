library(testthat)
library(EDI)

# InferenceIncidKKCondLogitOneLik's private assess_combined_fit() (inference_incidence_KK_cond_
# logit.R) is a rich, self-contained "is this fit usable" predicate with 10 distinct failure reasons
# plus two success-path variance-extraction branches, called from shared_combined_likelihood(),
# compute_weighted_combined_estimate(), and elsewhere. Only 2 of its 10 failure reasons
# ("fit_unavailable", "extreme_treatment_coefficient") had any test reference anywhere
# (test-kk-clogit-onelik-combined-fit-and-design-guards-reference.R); the other 8 -- and the
# fixed_idx-driven cascading-exclusion logic, and both variance-extraction paths -- had none. Tested
# here by calling it directly with hand-constructed `mod` lists, since it needs no design/data fixture
# beyond an instance's private$max_abs_reasonable_coef.
#   1. Each of the 10 documented failure reasons fires under its own precisely constructed input.
#   2. check_treatment = FALSE skips the extreme-coefficient check (an otherwise-failing fit is
#      accepted).
#   3. The success path's variance comes directly from mod$ssq_b_j when finite and positive.
#   4. When ssq_b_j is missing or non-positive, variance falls back to the Cholesky-inverted
#      information matrix, matching an independent solve() of the same matrix exactly.
#   5. With fixed_idx excluding the treatment column, require_variance = TRUE is nonestimable
#      ("treatment_variance_unavailable") since the treatment's variance is structurally unidentified,
#      but require_variance = FALSE still returns usable = TRUE with variance = NA.

clogit_predicate_fixture <- function() {
	set.seed(1L); n <- 10L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidKKCondLogitOneLik$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

base_mod <- function(...) {
	modifyList(
		list(converged = TRUE, hit_iteration_cap = FALSE, gradient_norm = 1e-6, b = c(0.5, -0.2), fisher_information = diag(c(4, 9)), ssq_b_j = 0.25),
		list(...)
	)
}

test_that("each of the 10 documented failure reasons fires under its own precisely constructed input", {
	priv <- clogit_predicate_fixture()
	f <- priv$assess_combined_fit
	expect_equal(f(NULL, 1L)$reason, "fit_unavailable")
	expect_equal(f(base_mod(converged = FALSE), 1L)$reason, "not_converged")
	expect_equal(f(base_mod(hit_iteration_cap = TRUE), 1L)$reason, "iteration_cap_reached")
	expect_equal(f(base_mod(gradient_norm = NaN), 1L)$reason, "gradient_norm_nonfinite")
	expect_equal(f(base_mod(b = c(NA_real_, -0.2)), 1L)$reason, "coefficients_nonfinite")
	expect_equal(f(base_mod(), 5L)$reason, "coefficients_nonfinite")                # j_treat out of range
	expect_equal(f(base_mod(b = c(50, -0.2)), 1L)$reason, "extreme_treatment_coefficient")
	expect_equal(f(base_mod(fisher_information = NULL), 1L)$reason, "information_unavailable")
	expect_equal(f(base_mod(fisher_information = diag(3)), 1L)$reason, "information_unavailable")  # wrong dimension
	expect_equal(f(base_mod(fisher_information = matrix(c(1, 2, 2, 1), 2, 2)), 1L)$reason, "information_not_positive_definite")
	ill_conditioned <- matrix(c(1, 1 - 1e-12, 1 - 1e-12, 1), 2, 2)
	expect_equal(f(base_mod(fisher_information = ill_conditioned), 1L)$reason, "information_ill_conditioned")
})

test_that("check_treatment = FALSE skips the extreme-coefficient check", {
	priv <- clogit_predicate_fixture()
	res <- priv$assess_combined_fit(base_mod(b = c(50, -0.2)), 1L, check_treatment = FALSE)
	expect_true(res$usable)
})

test_that("the success path's variance comes directly from mod$ssq_b_j when finite and positive", {
	priv <- clogit_predicate_fixture()
	res <- priv$assess_combined_fit(base_mod(), 1L, require_variance = TRUE)
	expect_true(res$usable)
	expect_equal(res$variance, 0.25)
})

test_that("when ssq_b_j is missing or non-positive, variance falls back to the inverted information matrix", {
	priv <- clogit_predicate_fixture()
	info <- diag(c(4, 9))
	ref_variance <- solve(info)[1, 1]

	res_missing <- priv$assess_combined_fit(base_mod(ssq_b_j = NULL, fisher_information = info), 1L, require_variance = TRUE)
	expect_equal(res_missing$variance, ref_variance, tolerance = 1e-10)

	res_negative <- priv$assess_combined_fit(base_mod(ssq_b_j = -1, fisher_information = info), 1L, require_variance = TRUE)
	expect_equal(res_negative$variance, ref_variance, tolerance = 1e-10)
})

test_that("with fixed_idx excluding the treatment column, require_variance = TRUE is nonestimable but require_variance = FALSE still succeeds with NA variance", {
	priv <- clogit_predicate_fixture()
	mod <- base_mod(ssq_b_j = NA_real_)

	res_required <- priv$assess_combined_fit(mod, 1L, require_variance = TRUE, fixed_idx = 1L)
	expect_false(res_required$usable)
	expect_equal(res_required$reason, "treatment_variance_unavailable")

	res_not_required <- priv$assess_combined_fit(mod, 1L, require_variance = FALSE, fixed_idx = 1L)
	expect_true(res_not_required$usable)
	expect_true(is.na(res_not_required$variance))
})
