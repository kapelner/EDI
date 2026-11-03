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
# Reached via InferencePropKKGLMM (see below), mocking prepare_clogit_plus_glmm_data() (private,
# unlockBinding) and fast_clogit_plus_glmm_cpp() (package-level EDI function, local_mocked_bindings)
# with a small hand-built concordant-only data block -- no real KK design/discordant-pair assembly
# needed since it's shared()'s own guard logic being tested, not prepare_clogit_plus_glmm_data()'s
# internals (already covered by test-kk-cond-logit-glmm-data-split-reference.R).

# 2026-11-03 (v1.0.5 TODO-173): the incidence leaves now fit conditional logit
# plus a reservoir logistic regression (no GLMM), so the GLMM guards below are
# reached through InferencePropKKGLMM, the remaining user of that branch; the
# guards of the incidence path are tested at the end of this file.
glmm_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(runif(n, 0.1, 0.9))
	InferencePropKKGLMM$new(des, verbose = FALSE)
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
		# 1e5: InferencePropKKGLMM's max_abs_reasonable_coef default is 1e4.
		fast_clogit_plus_glmm_cpp = function(...) list(converged = TRUE, params = c(0.1, 1e5, 0.5), fisher_information = diag(3), ssq_b_j = 0.01),
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

# ---- Incidence path: conditional logit + reservoir logistic regression ----
rl_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "incidence", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	InferenceIncidKKCondLogitGLMMOneLik$new(des, verbose = FALSE)
}

mock_rl_data <- function(p, n_disc = 6L) {
	unlockBinding("prepare_clogit_reservoir_logit_data", p)
	p$prepare_clogit_reservoir_logit_data <- function(...) list(
		X_disc = cbind(treatment = rep(1, n_disc), x = seq(-1, 1, length.out = n_disc)),
		y_disc = rep(c(0, 1), length.out = n_disc), i_m_disc = seq_len(n_disc),
		X_res = matrix(numeric(0), 0L, 1L), w_res = numeric(0), y_res = numeric(0), i_res = integer(0),
		has_discordant = n_disc > 0L
	)
}

test_that("incidence path caches 'no_data_for_clogit_plus_reservoir_logit' with no discordant pairs and no usable reservoir", {
	inf <- rl_fixture()
	mock_rl_data(inf$.__enclos_env__$private, n_disc = 0L)
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "no_data_for_clogit_plus_reservoir_logit")
})

test_that("incidence path caches 'joint_likelihood_failed_to_converge' when the stacked logistic fit fails", {
	inf <- rl_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	mock_rl_data(p)
	unlockBinding("fit_clogit_reservoir_logit", p)
	p$fit_clogit_reservoir_logit <- function(...) NULL
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_failed_to_converge")
})

test_that("incidence path caches 'joint_likelihood_nonestimable' when a coefficient exceeds the threshold", {
	inf <- rl_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	mock_rl_data(p)
	unlockBinding("fit_clogit_reservoir_logit", p)
	p$fit_clogit_reservoir_logit <- function(...) list(params = c(treatment = 0.1, x = 1000), neg_loglik = 1,
		converged = TRUE, fisher_information = diag(2))
	expect_true(is.na(inf$compute_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_nonestimable")
})

test_that("incidence path caches 'joint_likelihood_standard_error_unavailable' when the information is singular", {
	inf <- rl_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	mock_rl_data(p)
	unlockBinding("fit_clogit_reservoir_logit", p)
	p$fit_clogit_reservoir_logit <- function(...) list(params = c(treatment = 0.5, x = 0.2), neg_loglik = 1,
		converged = TRUE, fisher_information = matrix(0, 2, 2))
	expect_equal(inf$compute_estimate(), 0.5)
	inf$compute_asymp_confidence_interval()
	expect_identical(inf$get_nonestimable_reason(), "joint_likelihood_standard_error_unavailable")
})

test_that("incidence path drops a covariate whose within-pair differences are all zero instead of failing", {
	# A covariate the design matched exactly has zero within-pair differences; under a free pair effect
	# its coefficient is not identified without a usable reservoir. The fit must drop it (as glm() would)
	# and still estimate beta_T, matching conditional logit on the identified covariates only.
	inf <- rl_fixture(seed = 6L)
	p <- inf$.__enclos_env__$private
	set.seed(61L)
	dx <- rnorm(30L)
	y_disc <- rbinom(30L, 1, plogis(0.4 + 0.7 * dx))
	unlockBinding("prepare_clogit_reservoir_logit_data", p)
	p$prepare_clogit_reservoir_logit_data <- function(...) list(
		X_disc = cbind(treatment = 1, x1 = dx, x2 = 0), y_disc = y_disc, i_m_disc = seq_len(30L),
		X_res = matrix(numeric(0), 0L, 2L), w_res = numeric(0), y_res = numeric(0), i_res = integer(0),
		has_discordant = TRUE
	)
	ref <- glm(y_disc ~ dx, family = binomial())
	expect_equal(inf$compute_estimate(), unname(coef(ref)[1]), tolerance = 1e-6)
	expect_false(inf$is_nonestimable("estimate"))
})
