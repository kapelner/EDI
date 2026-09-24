library(testthat)
library(EDI)

# InferenceIncidKKGEE's shared private fit_gee_with_fallback() (inference_mixin_kk_gee_shared.R) has
# a two-level fallback: for each predictors_df candidate, it first tries fit_gee(include_reservoir =
# TRUE); if that fit isn't usable (gee_fit_ok() fails) AND gee_has_reservoir() is TRUE, it retries the
# SAME candidate with include_reservoir = FALSE. Existing coverage exercises gee_has_reservoir() as a
# standalone predicate (test-incid-kk-gee-logistic-estimate-se-and-dispatch-reference.R) and build_gee_
# fit_data(include_reservoir = FALSE)'s own data construction directly
# (test-kk-gee-shared-extractors-fit-data-and-jackknife-calibration-reference.R), and the "every
# candidate/attempt fails entirely" guard is covered elsewhere (test-kk-gee-fit-failed-guard-reference.R)
# -- but the actual orchestration branch where the reservoir-inclusive fit FAILS and the reservoir-
# exclusive retry SUCCEEDS, within a single fit_gee_with_fallback() call, had never been exercised.
# Reached by wrapping (not replacing) fit_gee(): forcing the include_reservoir = TRUE attempt to
# return NULL while delegating include_reservoir = FALSE to the real fitter, the same "wrap and count"
# technique already used elsewhere in this suite to prove a fallback is genuinely reached.

kk_gee_fixture <- function(seed = 4L, np = 40L, ns = 20L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w()
	g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns))
	u <- rnorm(max(g), 0, 0.7)
	y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.4 * X$x1 + u[g]))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKGEE$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("a reservoir-inclusive fit failure retries reservoir-exclusive within the same call, and succeeds", {
	skip_if_not_installed("geepack")
	f <- kk_gee_fixture()
	expect_true(f$priv$gee_has_reservoir())

	calls <- list()
	unlockBinding("fit_gee", f$priv)
	orig_fit_gee <- f$priv$fit_gee
	f$priv$fit_gee <- function(std_err = TRUE, include_reservoir = TRUE, predictors_df = NULL, estimate_only = FALSE) {
		calls[[length(calls) + 1L]] <<- include_reservoir
		if (isTRUE(include_reservoir)) return(NULL)                        # forced failure on the first attempt
		orig_fit_gee(std_err = std_err, include_reservoir = include_reservoir, predictors_df = predictors_df, estimate_only = estimate_only)
	}

	mod <- f$priv$fit_gee_with_fallback()
	expect_identical(unlist(calls), c(TRUE, FALSE))
	expect_false(is.null(mod))

	# The returned fit matches the real reservoir-exclusive fit directly, confirming the fallback
	# genuinely used that fit rather than some other value.
	direct <- orig_fit_gee(include_reservoir = FALSE)
	expect_equal(as.numeric(mod$beta), as.numeric(direct$beta))
})

test_that("with no reservoir subjects, a failed reservoir-inclusive fit is NOT retried (no reservoir to fall back to)", {
	skip_if_not_installed("geepack")
	f <- kk_gee_fixture(seed = 6L, ns = 0L)
	expect_false(f$priv$gee_has_reservoir())

	calls <- list()
	unlockBinding("fit_gee", f$priv)
	f$priv$fit_gee <- function(std_err = TRUE, include_reservoir = TRUE, predictors_df = NULL, estimate_only = FALSE) {
		calls[[length(calls) + 1L]] <<- include_reservoir
		NULL
	}

	mod <- f$priv$fit_gee_with_fallback()
	expect_identical(unlist(calls), TRUE)                                  # only the single include_reservoir = TRUE attempt
	expect_null(mod)
})
