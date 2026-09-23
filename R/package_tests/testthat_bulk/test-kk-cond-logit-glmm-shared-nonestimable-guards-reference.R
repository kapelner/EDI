library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM's shared() (inference_incidence_KK_cond_logit_glmm_abstract.R,
# spliced into InferenceIncidKKCondLogitGLMMOneLik/IVWC) has 4 distinct nonestimable guards, none of
# which had a genuine test reference anywhere: the reason strings DO appear in
# testthat_bulk/fixtures/legacy_kk_cond_logit_glmm.R, but only as duplicated source code inside a
# legacy migration-baseline generator, never as an actual test assertion (confirmed: no test_that()
# anywhere asserts get_nonestimable_reason() against any of these four strings).
#   1. "no_data_for_clogit_plus_glmm": prepare_clogit_plus_glmm_data() reports neither discordant nor
#      concordant data.
#   2. "joint_likelihood_failed_to_converge": fast_clogit_plus_glmm_cpp() itself fails or doesn't
#      converge.
#   3. "joint_likelihood_nonestimable": the fit converges, but either the beta coefficients are
#      non-finite/extreme, or (a separate call site, same reason string) the random-effect log_sigma
#      is non-finite/extreme.
#   4. "joint_likelihood_standard_error_unavailable": the point estimate is usable, but ssq_b_j is
#      non-finite/non-positive/too large.
# Reached via InferenceIncidKKCondLogitGLMMOneLik, mocking prepare_clogit_plus_glmm_data() (private,
# unlockBinding) and fast_clogit_plus_glmm_cpp() (package-level EDI function, local_mocked_bindings)
# with a small hand-built concordant-only data block -- no real KK design/discordant-pair assembly
# needed since it's shared()'s own guard logic being tested, not prepare_clogit_plus_glmm_data()'s
# internals (already covered by test-kk-cond-logit-glmm-data-split-reference.R).

glmm_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	InferenceIncidKKCondLogitGLMMOneLik$new(des, verbose = FALSE)
}

mock_concordant_only_data <- function(p) {
	unlockBinding("prepare_clogit_plus_glmm_data", p)
	p$prepare_clogit_plus_glmm_data <- function(...) {
		list(
			has_discordant = FALSE, has_concordant = TRUE,
			X_disc = matrix(numeric(0), nrow = 0L, ncol = 2L), y_disc = numeric(0),
			X_conc = cbind(1, c(0, 1, 0, 1)), y_conc = c(0, 1, 0, 1), group_conc = 1:4
		)
	}
}

test_that("shared() caches 'no_data_for_clogit_plus_glmm' when neither discordant nor concordant data is available", {
	inf <- glmm_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("prepare_clogit_plus_glmm_data", p)
	p$prepare_clogit_plus_glmm_data <- function(...) list(has_discordant = FALSE, has_concordant = FALSE)

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "no_data_for_clogit_plus_glmm")
})

test_that("shared() caches 'joint_likelihood_failed_to_converge' when the joint fitter fails", {
	inf <- glmm_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	mock_concordant_only_data(p)
	local_mocked_bindings(fast_clogit_plus_glmm_cpp = function(...) NULL, .package = "EDI")

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_failed_to_converge")
})

test_that("shared() caches 'joint_likelihood_nonestimable' when a finite beta coefficient exceeds the threshold", {
	inf <- glmm_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	mock_concordant_only_data(p)
	local_mocked_bindings(
		fast_clogit_plus_glmm_cpp = function(...) list(converged = TRUE, params = c(0.1, 1000, 0.5), fisher_information = diag(3), ssq_b_j = 0.01),
		.package = "EDI"
	)

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_nonestimable")
})

test_that("shared() caches 'joint_likelihood_nonestimable' when log_sigma is non-finite/extreme", {
	inf <- glmm_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	mock_concordant_only_data(p)
	local_mocked_bindings(
		fast_clogit_plus_glmm_cpp = function(...) list(converged = TRUE, params = c(0.1, 0.5, 1000), fisher_information = diag(3), ssq_b_j = 0.01),
		.package = "EDI"
	)

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_nonestimable")
})

test_that("shared() caches 'joint_likelihood_standard_error_unavailable' when ssq_b_j is unusable", {
	inf <- glmm_fixture(seed = 5L)
	p <- inf$.__enclos_env__$private
	mock_concordant_only_data(p)
	local_mocked_bindings(
		fast_clogit_plus_glmm_cpp = function(...) list(converged = TRUE, params = c(0.1, 0.5, 0.5), fisher_information = diag(3), ssq_b_j = NA_real_),
		.package = "EDI"
	)

	res <- inf$compute_estimate()
	expect_equal(res, 0.5)
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_standard_error_unavailable")
})
