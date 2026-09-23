library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik's compute_treatment_estimate_during_
# randomization_inference() (inference_survival_GLMM_weibull_frailty_loggamma.R) had no test
# reference anywhere. This class is already documented elsewhere in this suite
# (test-parametric-bootstrap-lr-all-capable-classes.R's all_param_boot_quarantined_classes list) as
# numerically unstable enough that its parametric-bootstrap smoke test "flip[s] pass/fail on the
# identical commit" -- so, as with the sibling InferenceSurvivalGLMMWeibullFrailtyNormalOneLik test
# closed earlier this session, every branch here is reached by mocking
# fast_clayton_weibull_aft_optim_cpp() and the fallback private$shared() directly rather than relying
# on organic convergence.
#   1. private$best_par unset (NULL, the fresh-instance default): the fast-path gate
#      (length(best_par) >= 3 && all finite tail(best_par, 2)) is FALSE, so it falls straight through
#      to private$shared() + private$cached_values$beta_hat_T -- a DIFFERENT fallback shape from the
#      Normal-frailty sibling (which calls the raw fitter a second time, not shared()).
#   2. private$best_par set (fixed-VC fast path eligible) and fast_clayton_weibull_aft_optim_cpp()
#      converges with a finite, within-threshold b_w: returns it directly, short-circuiting
#      private$shared() entirely.
#   3. Same eligibility, but the fast path fails (NULL, not converged, or b_w non-finite/extreme):
#      falls through to the private$shared() fallback.

loggamma_fixture <- function(seed = 2L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))
	inf <- InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("falls through to private$shared() when best_par is unset (the fresh-instance default)", {
	f <- loggamma_fixture()
	p <- f$priv
	expect_null(p$best_par)
	unlockBinding("shared", p)
	p$shared <- function(estimate_only = FALSE) {
		p$cached_values$beta_hat_T <- 0.77
	}

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.77)
})

test_that("a converged fixed-VC fast path short-circuits private$shared() entirely", {
	f <- loggamma_fixture(seed = 3L)
	p <- f$priv
	p$best_par <- c(0, 0, -0.2, -0.5)
	p$best_X_colnames <- character(0)
	shared_called <- FALSE
	unlockBinding("shared", p)
	p$shared <- function(...) shared_called <<- TRUE

	local_mocked_bindings(
		fast_clayton_weibull_aft_optim_cpp = function(X, y, dead, pair_idx, singleton_rows, ..., fixed_idx = NULL, fixed_values = NULL) {
			expect_equal(fixed_idx, c(ncol(X) + 1L, ncol(X) + 2L))
			expect_equal(fixed_values, c(-0.2, -0.5))
			list(converged = TRUE, params = c(0, 0.55))
		},
		.package = "EDI"
	)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.55)
	expect_false(shared_called)
})

test_that("a failed fixed-VC fast path (NULL, not converged, or extreme b_w) falls through to private$shared()", {
	f <- loggamma_fixture(seed = 4L)
	p <- f$priv
	p$best_par <- c(0, 0, -0.2, -0.5)
	p$best_X_colnames <- character(0)
	unlockBinding("shared", p)
	p$shared <- function(estimate_only = FALSE) {
		p$cached_values$beta_hat_T <- -0.33
	}

	local_mocked_bindings(fast_clayton_weibull_aft_optim_cpp = function(...) NULL, .package = "EDI")
	expect_equal(p$compute_treatment_estimate_during_randomization_inference(), -0.33)

	local_mocked_bindings(
		fast_clayton_weibull_aft_optim_cpp = function(X, ...) list(converged = FALSE, params = c(0, 0.55)),
		.package = "EDI"
	)
	expect_equal(p$compute_treatment_estimate_during_randomization_inference(), -0.33)

	local_mocked_bindings(
		fast_clayton_weibull_aft_optim_cpp = function(X, ...) list(converged = TRUE, params = c(0, 1e5)),  # exceeds max_abs_reasonable_coef
		.package = "EDI"
	)
	expect_equal(p$compute_treatment_estimate_during_randomization_inference(), -0.33)
})
