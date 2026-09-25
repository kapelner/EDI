library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik's compute_treatment_estimate_during_randomization_
# inference() (inference_survival_GLMM_weibull_frailty_loggamma.R) re-derives private$y/private$dead
# before refitting. This is the THIRD instance (after InferenceSurvivalKKLWACoxPHOneLik and
# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik, both already regression-guarded this session) of
# the identical bug fixed in commit 073b3f52 (2026-09-23): reading private$des_obj_priv_int$y directly
# and deriving dead = as.numeric(!is.na(y)) silently fed real NAs into the fitter for every censored
# subject (the Design's own y field is NA for censored observations post the y/y_L/y_R migration),
# marking every censored subject as an event instead. The fix re-derives y/dead via des_obj$get_
# effective_time()/get_effective_dead() instead. The existing dedicated test file for this method
# (test-kk-weibull-frailty-loggamma-onelik-randomization-estimate-refit-reference.R) mocks fast_
# clayton_weibull_aft_optim_cpp() and captures its y/dead arguments in one of its three tests, but --
# confirmed by reading that file in full -- never once asserts on their actual VALUES (only fixed_idx/
# fixed_values/params), so a regression reintroducing this exact bug would not be caught by any
# existing test. This file closes that gap: same fixture/mocking technique (fixed-VC fast-path gate
# set directly), but asserting the captured y/dead match Design's own get_effective_time()/get_
# effective_dead() exactly, with zero NAs, on a fixture with real (~20%) right-censoring.

loggamma_fixture <- function(seed = 3L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))
	inf <- InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, des = des)
}

test_that("the fixture genuinely has real (interval-encoded) right-censoring, not just a dead flag on always-observed y", {
	f <- loggamma_fixture()
	expect_false(f$priv$has_general_censoring)
	expect_true(any(f$des$get_effective_dead() == 0L))     # at least one censored subject
	expect_false(any(is.na(f$des$get_effective_time())))   # get_effective_time() is never itself NA
})

test_that("compute_treatment_estimate_during_randomization_inference() (fixed-VC fast path) passes the fitter the correct effective time/dead, with zero NAs, matching Design's own accessors exactly", {
	f <- loggamma_fixture()
	p <- f$priv
	p$best_par <- c(0, 0, -0.2, -0.5)  # makes the fixed-VC fast-path gate eligible
	p$best_X_colnames <- character(0)

	captured <- NULL
	local_mocked_bindings(
		fast_clayton_weibull_aft_optim_cpp = function(X, y, dead, pair_idx, singleton_rows, ..., fixed_idx = NULL, fixed_values = NULL) {
			captured <<- list(y = y, dead = dead)
			list(converged = TRUE, params = c(0, 0.55))
		},
		.package = "EDI"
	)

	res <- p$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.55)

	expect_false(is.null(captured))
	expect_false(anyNA(captured$dead))
	expect_false(anyNA(captured$y))
	expect_equal(captured$y, f$des$get_effective_time())
	expect_equal(captured$dead, f$des$get_effective_dead())
})
