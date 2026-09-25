library(testthat)
library(EDI)

# InferenceSurvivalGLMMWeibullFrailtyNormalOneLik's compute_treatment_estimate_during_randomization_
# inference() (inference_survival_GLMM_weibull_frailty_normal.R) re-derives private$y/private$dead
# before refitting, since they may have been transformed for randomization. Commit 073b3f52
# (2026-09-23) fixed a real, silent-corruption bug here: the previous code read `private$y =
# private$des_obj_priv_int$y` directly and derived `dead = as.numeric(!is.na(y))`, but post the y/
# y_L/y_R migration the Design's own `y` field is NA for every CENSORED subject (the true time lives
# in y_L/y_R instead) -- so every censored subject's `dead` came out 1 (wrong -- it should be 0), and
# its `y` was fed to the fitter as a literal NA on every single randomization-inference call. The fix
# instead calls des_obj$get_effective_time()/get_effective_dead() (or get_y() when has_general_
# censoring), matching how InferenceAll's own initialize() derives these fields. The existing
# dedicated test file for this method (test-kk-weibull-frailty-onelik-randomization-estimate-refit-
# reference.R) already mocks fast_weibull_frailty_cpp() for all 4 of its own branches, but never once
# asserts on the actual VALUES of the y/dead arguments passed to it -- so a regression reintroducing
# this exact bug would not be caught by any existing test, confirmed via reading that file in full.
# This file closes that specific gap: same fixture/mocking technique, but asserting the captured y/
# dead match Design's own get_effective_time()/get_effective_dead() exactly, with zero NAs, on a
# fixture with real (~20%) right-censoring.

frailty_fixture <- function(seed = 4L, n = 30L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	add_all_subject_responses_seq(des, rexp(n, exp(0.3 * X$x1 + 0.2 * w)), deads = rbinom(n, 1, 0.8))
	inf <- InferenceSurvivalGLMMWeibullFrailtyNormalOneLik$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, des = des)
}

test_that("the fixture genuinely has real (interval-encoded) right-censoring, not just a dead flag on always-observed y", {
	f <- frailty_fixture()
	expect_false(f$priv$has_general_censoring)
	expect_true(any(f$des$get_effective_dead() == 0L))     # at least one censored subject
	expect_false(any(is.na(f$des$get_effective_time())))   # get_effective_time() is never itself NA
})

test_that("compute_treatment_estimate_during_randomization_inference() passes the fitter the correct effective time/dead, with zero NAs, matching Design's own accessors exactly", {
	f <- frailty_fixture()
	f$inf$compute_estimate()  # populate best_X_colnames via the real (main) fit, as this class requires
	f$priv$cached_vc_params <- NA_real_  # force the full (unfixed) refit path, not the fast fixed-dispersion shortcut

	captured <- NULL
	local_mocked_bindings(
		fast_weibull_frailty_cpp = function(X, y, dead, group_id, ...) {
			captured <<- list(y = y, dead = dead)
			list(converged = TRUE, b = c(0.1, rep(0, ncol(X) - 1L)))
		},
		.package = "EDI"
	)

	res <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(res, 0.1)

	expect_false(is.null(captured))
	expect_false(anyNA(captured$dead))
	expect_false(anyNA(captured$y))
	expect_equal(captured$y, f$des$get_effective_time())
	expect_equal(captured$dead, f$des$get_effective_dead())
})
