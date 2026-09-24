library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonOneLik's private shared_combined_hurdle() (inference_count_KK_cond_
# poisson.R) -- the main (unweighted) estimate dispatcher compute_estimate() and every other public
# method route through -- had no direct test reference anywhere. The class's own combined-likelihood
# optimizer (fit_combined_hurdle()) and its covariate-reduction upstream step are well covered
# (test-kk-hurdle-poisson-onelik-combined-fit-constraints-and-covariate-reduction-reference.R), and
# the WEIGHTED sibling compute_weighted_combined_hurdle_estimate() was closed a few iterations earlier
# this session, but shared_combined_hurdle()'s own dispatch logic -- caching, the fall-back-to-a-
# treatment-only-2-column-model cascade on fit failure, and its two distinct nonestimable-reason
# guards -- was never exercised as a unit (the happy path is implicitly reached by every migration-
# golden test, but none of them ever force the fallback or failure branches).
#   1. The happy path sets cached_values$beta_hat_T, cached_mod, and leaves model_fit_fallback NULL
#      (fallback_used = FALSE) -- matching a direct compute_estimate() call.
#   2. Caching: a second estimate_only = TRUE call does not re-invoke fit_combined_hurdle() at all
#      (call-count probe).
#   3. When the full-covariate fit fails to converge and ncol(X_fit) > 2, the cascade falls back to a
#      treatment-only 2-column refit; cached_values$model_fit_fallback is populated with the
#      documented reason and omitted-conditional-covariate list.
#   4. A design reduce_design_matrix_preserving_treatment() can't use is nonestimable with reason
#      "kk_hurdle_poisson_onelik_design_unusable".
#   5. When both the full and the 2-column fallback fits fail, the result is nonestimable with reason
#      "kk_hurdle_poisson_onelik_fit_failed".
#   6. estimate_only = FALSE additionally populates cached_values$s_beta_hat_T as sqrt(fit$ssq_b_T).

hurdle_shared_fixture <- function(seed, n = 60L, x_df) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x_df[i, , drop = FALSE])
	des$add_all_subject_responses(rpois(n, 2))
	inf <- InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("the happy path sets beta_hat_T, cached_mod, and leaves model_fit_fallback NULL, matching compute_estimate()", {
	f <- hurdle_shared_fixture(1L, x_df = data.frame(x1 = rnorm(60L)))
	est <- as.numeric(f$inf$compute_estimate())[1L]
	expect_equal(f$priv$cached_values$beta_hat_T, est)
	expect_false(is.null(f$priv$cached_mod))
	expect_null(f$priv$cached_values$model_fit_fallback)
})

test_that("caching: a second estimate_only = TRUE call does not re-invoke fit_combined_hurdle() at all", {
	f <- hurdle_shared_fixture(2L, x_df = data.frame(x1 = rnorm(60L)))
	f$priv$shared_combined_hurdle(estimate_only = TRUE)

	call_count <- 0L
	orig_fit <- f$priv$fit_combined_hurdle
	unlockBinding("fit_combined_hurdle", f$priv)
	f$priv$fit_combined_hurdle <- function(...) { call_count <<- call_count + 1L; orig_fit(...) }
	f$priv$shared_combined_hurdle(estimate_only = TRUE)
	expect_equal(call_count, 0L)
})

test_that("when the full-covariate fit fails and ncol(X_fit) > 2, the cascade falls back to a treatment-only 2-column refit and records the fallback", {
	f <- hurdle_shared_fixture(3L, x_df = data.frame(x1 = rnorm(60L), x2 = rnorm(60L)))
	X_full <- f$priv$build_model_matrix()
	expect_gt(ncol(X_full), 2L)

	# Reference computed BEFORE shared_combined_hurdle() runs, on a still warm-start-clean private
	# env -- the same starting condition the fallback cascade itself uses internally -- so a later
	# warm-started re-fit doesn't drift to a slightly different (but equally valid) local optimum.
	orig_fit <- f$priv$fit_combined_hurdle
	reduced <- f$priv$reduce_design_matrix_preserving_treatment(X_full)
	X_fit <- reduced$X
	colnames(X_fit) <- colnames(X_full)[reduced$keep]
	keep2 <- sort(unique(c(1L, reduced$j_treat)))
	X_fit_2col <- X_fit[, keep2, drop = FALSE]
	j_treat_2col <- match(colnames(X_fit)[reduced$j_treat], colnames(X_fit_2col))
	dat_2col <- f$priv$build_combined_hurdle_data(X_fit_2col, j_treat_2col)
	fit_2col_ref <- orig_fit(dat_2col, estimate_only = TRUE)

	unlockBinding("fit_combined_hurdle", f$priv)
	f$priv$fit_combined_hurdle <- function(dat, ...) {
		if (ncol(dat$X_fit) > 2L) return(NULL)                                     # force the full-covariate attempt to fail
		orig_fit(dat, ...)
	}
	f$priv$shared_combined_hurdle(estimate_only = TRUE)

	expect_equal(f$priv$cached_values$beta_hat_T, as.numeric(fit_2col_ref$b[j_treat_2col]), tolerance = 1e-8)
	fb <- f$priv$cached_values$model_fit_fallback
	expect_true(fb$used)
	expect_equal(fb$reason, "full_kk_hurdle_poisson_onelik_fit_failed_to_converge")
	expect_setequal(fb$omitted_conditional, c("x1", "x2"))
})

test_that("a design reduce_design_matrix_preserving_treatment() can't use is nonestimable with the documented reason", {
	f <- hurdle_shared_fixture(4L, x_df = data.frame(x1 = rnorm(60L)))
	unlockBinding("reduce_design_matrix_preserving_treatment", f$priv)
	f$priv$reduce_design_matrix_preserving_treatment <- function(X_full) list(X = NULL, j_treat = NA_integer_, keep = integer(0))
	f$priv$shared_combined_hurdle(estimate_only = TRUE)
	expect_equal(f$inf$get_nonestimable_reason(), "kk_hurdle_poisson_onelik_design_unusable")
})

test_that("when both the full and the 2-column fallback fits fail, the result is nonestimable with the documented reason", {
	f <- hurdle_shared_fixture(5L, x_df = data.frame(x1 = rnorm(60L)))
	unlockBinding("fit_combined_hurdle", f$priv)
	f$priv$fit_combined_hurdle <- function(...) NULL
	f$priv$shared_combined_hurdle(estimate_only = TRUE)
	expect_equal(f$inf$get_nonestimable_reason(), "kk_hurdle_poisson_onelik_fit_failed")
})

test_that("estimate_only = FALSE sets s_beta_hat_T from sqrt(fit$ssq_b_T), before any jackknife inflation", {
	f <- hurdle_shared_fixture(6L, x_df = data.frame(x1 = rnorm(60L)))
	local_mocked_bindings(.inflate_kk_onelik_standard_error_with_jackknife = function(...) invisible(NULL), .package = "EDI")
	f$priv$shared_combined_hurdle(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(as.numeric(f$priv$cached_mod$ssq_b_T)), tolerance = 1e-6)
})
