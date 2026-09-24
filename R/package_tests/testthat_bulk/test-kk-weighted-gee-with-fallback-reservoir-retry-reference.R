library(testthat)
library(EDI)

# InferenceIncidKKGEE's shared private fit_weighted_gee_with_fallback() (inference_mixin_kk_gee_
# shared.R) is the weighted-refit sibling of fit_gee_with_fallback() -- the same two-level fallback
# shape (reservoir-inclusive fit first, reservoir-exclusive retry if that fails and a reservoir
# exists), used by compute_estimate_with_bootstrap_weights(). test-kk-gee-predictors-df-candidates-
# hardening-reference.R already covers the CANDIDATE-LIST generation this function loops over, but
# its own reservoir-inclusive-fails/reservoir-exclusive-succeeds orchestration branch had never been
# exercised -- the exact same gap already closed for the unweighted fit_gee_with_fallback() in the
# immediately preceding iteration. Reached by wrapping (not replacing) fit_weighted_gee_on_data():
# forcing its first call (the reservoir-inclusive attempt) to fail and delegating every subsequent
# call to the real fitter.

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

test_that("a reservoir-inclusive weighted fit failure retries reservoir-exclusive, and its result matches the real reservoir-exclusive fit directly", {
	skip_if_not_installed("geepack")
	f <- kk_gee_fixture()
	expect_true(f$priv$gee_has_reservoir())
	set.seed(9L)
	row_weights <- rexp(2L * 40L + 20L)

	n_calls <- 0L
	unlockBinding("fit_weighted_gee_on_data", f$priv)
	orig_fit <- f$priv$fit_weighted_gee_on_data
	f$priv$fit_weighted_gee_on_data <- function(fit_data) {
		n_calls <<- n_calls + 1L
		if (n_calls == 1L) return(NULL)                                    # forced failure on the reservoir-inclusive attempt
		orig_fit(fit_data)
	}

	res <- f$priv$fit_weighted_gee_with_fallback(row_weights)
	expect_identical(n_calls, 2L)
	expect_true(is.finite(res))

	fit_data_excl <- f$priv$build_gee_fit_data(include_reservoir = FALSE, predictors_df = f$priv$gee_predictors_df(), row_weights = row_weights)
	direct <- orig_fit(fit_data_excl)
	expect_equal(res, f$priv$extract_gee_treatment_estimate(direct))
})

test_that("fit_weighted_gee_with_fallback() returns NA_real_ (not an error) when both attempts fail for every candidate", {
	skip_if_not_installed("geepack")
	f <- kk_gee_fixture(seed = 5L)
	unlockBinding("fit_weighted_gee_on_data", f$priv)
	f$priv$fit_weighted_gee_on_data <- function(fit_data) NULL

	set.seed(10L)
	row_weights <- rexp(2L * 40L + 20L)
	res <- f$priv$fit_weighted_gee_with_fallback(row_weights)
	expect_true(is.na(res))
})
