library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d10536fd2 (InferencePropKKGLMM):
# - defaults max_abs_reasonable_coef = 1e4 and max_abs_log_sigma = 8 (inference_proportion_KK_combined.R:153),
#   checked right at the thresholds with a mocked joint fitter (the existing guard tests use 1e5 and 1000,
#   which would pass under other defaults too);
# - optimization_alg defaults to "lbfgs" (inference_proportion_KK_combined.R:157).

prop_kk_glmm_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(runif(n, 0.1, 0.9))
	InferencePropKKGLMM$new(des, verbose = FALSE)
}

mock_prop_glmm_concordant_only <- function(p) {
	unlockBinding("prepare_clogit_plus_glmm_data", p)
	p$prepare_clogit_plus_glmm_data <- function(...) {
		list(
			has_discordant = FALSE, has_concordant = TRUE,
			X_disc = matrix(numeric(0), nrow = 0L, ncol = 2L), y_disc = numeric(0),
			X_conc = cbind(1, c(0, 1, 0, 1)), y_conc = c(0.2, 0.7, 0.3, 0.6), group_conc = 1:4
		)
	}
}

estimate_with_mocked_params <- function(params) {
	inf <- prop_kk_glmm_fixture()
	mock_prop_glmm_concordant_only(inf$.__enclos_env__$private)
	est <- with_mocked_bindings(
		fast_clogit_plus_glmm_cpp = function(...) list(converged = TRUE, params = params, fisher_information = diag(length(params)), ssq_b_j = 0.01),
		.package = "EDI",
		code = inf$compute_estimate()
	)
	list(est = est, reason = inf$get_nonestimable_reason(), inf = inf)
}

test_that("constructor defaults are max_abs_reasonable_coef = 1e4 and max_abs_log_sigma = 8", {
	p <- prop_kk_glmm_fixture()$.__enclos_env__$private
	expect_identical(p$max_abs_reasonable_coef, 1e4)
	expect_identical(p$max_abs_log_sigma, 8)
})

test_that("a coefficient of 9e3 is accepted and 1.1e4 is nonestimable under the default cap", {
	ok <- estimate_with_mocked_params(c(0.1, 9e3, 0.5))
	expect_equal(ok$est, 9e3)
	expect_false(ok$inf$is_nonestimable("estimate"))
	bad <- estimate_with_mocked_params(c(0.1, 1.1e4, 0.5))
	expect_true(is.na(bad$est))
	expect_identical(bad$reason, "joint_likelihood_nonestimable")
})

test_that("log_sigma 7.9 is accepted and 8.1 is nonestimable under the default cap", {
	ok <- estimate_with_mocked_params(c(0.1, 0.5, 7.9))
	expect_equal(ok$est, 0.5)
	expect_false(ok$inf$is_nonestimable("estimate"))
	bad <- estimate_with_mocked_params(c(0.1, 0.5, 8.1))
	expect_true(is.na(bad$est))
	expect_identical(bad$reason, "joint_likelihood_nonestimable")
})

test_that("optimization_alg defaults to 'lbfgs'", {
	expect_identical(prop_kk_glmm_fixture()$get_optimization_alg(), "lbfgs")
})
