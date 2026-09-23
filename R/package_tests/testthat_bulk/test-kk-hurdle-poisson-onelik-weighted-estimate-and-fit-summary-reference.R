library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonOneLik's private compute_weighted_combined_hurdle_estimate() and
# record_combined_hurdle_fit_summary() (inference_count_KK_cond_poisson.R) had no functional test
# reference anywhere -- test-mixin-contracts.R and test-proportion-count-family-contracts.R only
# assert compute_estimate_with_bootstrap_weights exists as a method name, never call it with genuinely
# varying weights. The class's own point-estimate/likelihood-derivative machinery IS well tested
# elsewhere (test-kk-hurdle-poisson-onelik-combined-fit-constraints-and-covariate-reduction-
# reference.R, test-kk-hurdle-poisson-onelik-combined-likelihood-derivatives-and-conservative-helpers-
# reference.R), but the weighted-refit dispatch layer these two functions add is not.
#
# compute_weighted_combined_hurdle_estimate():
#   1. Effectively-constant weights delegate directly to self$compute_estimate() rather than refitting.
#   2. A row_weights length mismatch returns NA with the documented nonestimable reason.
#   3. A design that reduce_design_matrix_preserving_treatment() can't use returns NA with the
#      documented nonestimable reason.
#   4. With genuinely varying weights, the result matches independently re-deriving the same weighted
#      fit via reduce_design_matrix_preserving_treatment() + build_weighted_combined_hurdle_data() +
#      fit_combined_hurdle(), verifying the dispatch/wiring (not the underlying optimizer, already
#      covered elsewhere) is correct.
#   5. When the full-covariate weighted fit fails to converge and ncol(X_fit) > 2, it falls back to a
#      treatment-only 2-column refit, matching that reduced fit's own coefficient exactly.
#
# record_combined_hurdle_fit_summary():
#   6. The coefficient/SE/z/p-value table matches an independently hand-computed
#      z = coef/se, p = 2*pnorm(-|z|), with the Fisher-information matrix inverted for the SEs.
#   7. fallback_used = TRUE populates cached_values$model_fit_fallback with all six documented fields.
#   8. A fit shorter than the design (length(beta_fit) < length(fit_names)) is a silent no-op guard:
#      cached_values$summary_table is left untouched.

hurdle_onelik_fixture <- function(seed, n = 60L, x_df) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(x_df[i, , drop = FALSE])
	des$add_all_subject_responses(rpois(n, 2))
	inf <- InferenceCountKKHurdlePoissonOneLik$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("effectively-constant weights delegate directly to self$compute_estimate()", {
	set.seed(1L); n <- 60
	f <- hurdle_onelik_fixture(1L, n, data.frame(x1 = rnorm(n)))
	main_est <- f$inf$compute_estimate(estimate_only = TRUE)
	res <- f$priv$compute_weighted_combined_hurdle_estimate(rep(1, n), estimate_only = TRUE)
	expect_equal(res, as.numeric(main_est)[1L])
})

test_that("a row_weights length mismatch returns NA with the documented nonestimable reason", {
	set.seed(2L); n <- 60
	f <- hurdle_onelik_fixture(2L, n, data.frame(x1 = rnorm(n)))
	f$inf$compute_estimate()
	res <- f$priv$compute_weighted_combined_hurdle_estimate(rep(1, 3), estimate_only = TRUE)
	expect_true(is.na(res))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_hurdle_poisson_onelik_weighted_length_mismatch")
})

test_that("a design that reduce_design_matrix_preserving_treatment() can't use returns NA with the documented nonestimable reason", {
	set.seed(3L); n <- 60
	f <- hurdle_onelik_fixture(3L, n, data.frame(x1 = rnorm(n)))
	f$inf$compute_estimate()
	unlockBinding("reduce_design_matrix_preserving_treatment", f$priv)
	f$priv$reduce_design_matrix_preserving_treatment <- function(X_full) list(X = NULL, j_treat = NA_integer_, keep = integer(0))
	res <- f$priv$compute_weighted_combined_hurdle_estimate(rep(1, n), estimate_only = TRUE)
	expect_true(is.na(res))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_hurdle_poisson_onelik_weighted_design_unusable")
})

test_that("with genuinely varying weights, the estimate matches an independently re-derived weighted refit", {
	set.seed(4L); n <- 60
	f <- hurdle_onelik_fixture(4L, n, data.frame(x1 = rnorm(n)))
	main_est <- as.numeric(f$inf$compute_estimate())[1L]                            # captured before the weighted call overwrites the shared cache

	set.seed(5L); row_weights <- runif(n, 0.3, 2)
	res <- f$priv$compute_weighted_combined_hurdle_estimate(row_weights, estimate_only = TRUE)

	X_full <- f$priv$build_model_matrix()
	reduced <- f$priv$reduce_design_matrix_preserving_treatment(X_full)
	X_fit <- reduced$X
	colnames(X_fit) <- colnames(X_full)[reduced$keep]
	dat <- f$priv$build_weighted_combined_hurdle_data(X_fit, reduced$j_treat, row_weights = row_weights)
	fit_ref <- f$priv$fit_combined_hurdle(dat, estimate_only = TRUE)

	expect_equal(res, as.numeric(fit_ref$b[dat$j_treat]), tolerance = 1e-10)
	expect_false(isTRUE(all.equal(res, main_est, tolerance = 1e-3)))
})

test_that("when the full-covariate weighted fit fails, and ncol(X_fit) > 2, it falls back to a treatment-only 2-column refit matching that reduced fit's own coefficient", {
	set.seed(6L); n <- 60
	f <- hurdle_onelik_fixture(6L, n, data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	priv <- f$priv
	f$inf$compute_estimate()
	X_full <- priv$build_model_matrix()
	expect_gt(ncol(X_full), 2L)

	orig_fit_combined_hurdle <- priv$fit_combined_hurdle
	call_ncols <- integer(0)
	unlockBinding("fit_combined_hurdle", priv)
	priv$fit_combined_hurdle <- function(dat, ...) {
		call_ncols <<- c(call_ncols, ncol(dat$X_fit))
		if (ncol(dat$X_fit) > 2L) return(NULL)                                     # force the full-covariate attempt to fail
		orig_fit_combined_hurdle(dat, ...)
	}
	set.seed(7L); row_weights <- runif(n, 0.3, 2)
	res <- priv$compute_weighted_combined_hurdle_estimate(row_weights, estimate_only = TRUE)
	expect_true(any(call_ncols > 2L))                                               # the full-covariate attempt really was tried first
	expect_true(any(call_ncols == 2L))                                              # and the treatment-only fallback was tried second
	expect_true(is.finite(res))

	reduced <- priv$reduce_design_matrix_preserving_treatment(X_full)
	X_fit <- reduced$X
	colnames(X_fit) <- colnames(X_full)[reduced$keep]
	keep2 <- sort(unique(c(1L, reduced$j_treat)))
	X_fit_2col <- X_fit[, keep2, drop = FALSE]
	j_treat_2col <- match(colnames(X_fit)[reduced$j_treat], colnames(X_fit_2col))
	dat_2col <- priv$build_weighted_combined_hurdle_data(X_fit_2col, j_treat_2col, row_weights = row_weights)
	fit_2col_ref <- orig_fit_combined_hurdle(dat_2col, estimate_only = TRUE)
	expect_equal(res, as.numeric(fit_2col_ref$b[j_treat_2col]), tolerance = 1e-10)
})

test_that("record_combined_hurdle_fit_summary(): the coefficient/SE/z/p table matches an independent hand computation from the inverted Fisher information", {
	set.seed(8L); n <- 60
	priv <- hurdle_onelik_fixture(8L, n, data.frame(x1 = rnorm(n)))$priv
	X_model <- matrix(1, n, 2, dimnames = list(NULL, c("w", "x1")))
	fisher_info <- diag(c(4, 9, 1))
	fit <- list(b = c(0.5, -0.2), log_sigma = -1, params = c(0.5, -0.2, -1), fisher_information = fisher_info)

	priv$record_combined_hurdle_fit_summary(fit, X_model, X_model, fallback_used = FALSE)
	tbl <- priv$cached_values$summary_table
	se_ref <- unname(sqrt(diag(solve(fisher_info))))
	coef_ref <- unname(c(w = 0.5, x1 = -0.2, log_sigma = -1))
	z_ref <- coef_ref / se_ref
	p_ref <- 2 * pnorm(-abs(z_ref))
	expect_equal(unname(tbl[, "Value"]), coef_ref, tolerance = 1e-10)
	expect_equal(unname(tbl[, "Std. Error"]), se_ref, tolerance = 1e-10)
	expect_equal(unname(tbl[, "z value"]), z_ref, tolerance = 1e-10)
	expect_equal(unname(tbl[, "Pr(>|z|)"]), p_ref, tolerance = 1e-10)
	expect_equal(as.numeric(priv$cached_values$full_coefficients), c(0.5, -0.2))
	expect_null(priv$cached_values$model_fit_fallback)
})

test_that("record_combined_hurdle_fit_summary(): fallback_used = TRUE populates cached_values$model_fit_fallback with all documented fields", {
	set.seed(9L); n <- 60
	priv <- hurdle_onelik_fixture(9L, n, data.frame(x1 = rnorm(n)))$priv
	X_model <- matrix(1, n, 2, dimnames = list(NULL, c("w", "x1")))
	fit <- list(b = c(0.5), log_sigma = -1, params = c(0.5, -1))                    # reduced (treatment-only) fit
	X_fit_reduced <- X_model[, "w", drop = FALSE]

	priv$record_combined_hurdle_fit_summary(fit, X_model, X_fit_reduced, fallback_used = TRUE, fallback_reason = "custom_reason")
	fb <- priv$cached_values$model_fit_fallback
	expect_true(fb$used)
	expect_equal(fb$reason, "custom_reason")
	expect_equal(fb$requested_model, "full covariate-adjusted KK combined hurdle-Poisson likelihood")
	expect_equal(fb$fitted_model, "treatment-only KK combined hurdle-Poisson likelihood")
	expect_equal(fb$omitted_conditional, "x1")
	expect_equal(fb$family, "KK combined hurdle-Poisson")

	priv$record_combined_hurdle_fit_summary(fit, X_model, X_fit_reduced, fallback_used = TRUE)   # default reason
	expect_equal(priv$cached_values$model_fit_fallback$reason, "full_kk_hurdle_poisson_onelik_fit_failed_to_converge")
})

test_that("record_combined_hurdle_fit_summary(): a fit shorter than the design's own columns is a silent no-op that leaves cached_values$summary_table untouched", {
	set.seed(10L); n <- 60
	priv <- hurdle_onelik_fixture(10L, n, data.frame(x1 = rnorm(n)))$priv
	X_model <- matrix(1, n, 2, dimnames = list(NULL, c("w", "x1")))
	fit_full <- list(b = c(0.5, -0.2), log_sigma = -1, params = c(0.5, -0.2, -1), fisher_information = diag(c(4, 9, 1)))
	priv$record_combined_hurdle_fit_summary(fit_full, X_model, X_model, fallback_used = FALSE)
	before <- priv$cached_values$summary_table

	fit_short <- list(b = c(0.5), log_sigma = -1, params = c(0.5, -1))              # length(b) < ncol(X_fit)
	priv$record_combined_hurdle_fit_summary(fit_short, X_model, X_model, fallback_used = FALSE)
	expect_identical(priv$cached_values$summary_table, before)
})
