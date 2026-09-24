library(testthat)
library(EDI)

# InferenceCountKKGLMM's private compute_weighted_glmm_bootstrap_estimate() (inference_count_KK_
# combined.R) had no test reference anywhere despite compute_estimate_with_bootstrap_weights() (its
# only caller) being explicitly documented as the mechanism in the class's own roxygen. It dispatches
# a fast Rcpp Poisson-GLMM weighted refit, with a two-stage fallback: on non-convergence or an
# unreasonably extreme coefficient, it retries via glmm_predictors_df_candidates() + glmmTMB.
#   1. With use_rcpp = TRUE, a genuinely weighted refit matches an independently re-derived call to
#      fast_poisson_glmm_cpp() with the same construction (dispatch-wiring check, since no simple
#      external reference package reproduces this exact internal Rcpp Poisson-GLMM parametrization).
#   2. All-zero (or otherwise unusable) row weights return NA_real_.
#   3. When the Rcpp fit fails to converge (or errors), the glmmTMB fallback path engages and
#      produces a finite result.
#   4. When the Rcpp fit converges but with too-extreme a coefficient (> max_abs_reasonable_coef),
#      the same glmmTMB fallback engages instead of returning the extreme value.
#   5. When BOTH the Rcpp fit and every glmmTMB fallback candidate fail, the result is NA_real_.
#   6. FIXED 2026-09-24 (was: BUG, use_rcpp = FALSE branch called the undefined callSuper() -- an
#      R5/Reference-Classes construct, not part of R6's API, and there is no `super$` reachable
#      either under this package's flattened component-composition model). The component's original
#      glmmTMB-only implementation (InferenceMixinKKGLMMShared$private$compute_weighted_glmm_
#      bootstrap_estimate) is now aliased as compute_weighted_glmm_bootstrap_estimate_generic and
#      called directly on the use_rcpp = FALSE branch, matching the compute_lik_ratio_*_generic
#      alias pattern already used elsewhere in this class.

kk_glmm_count_fixture <- function(seed, n = 40L, use_rcpp = TRUE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountKKGLMM$new(des, use_rcpp = use_rcpp, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("with use_rcpp = TRUE, a genuinely weighted refit matches an independently re-derived fast_poisson_glmm_cpp() call", {
	priv <- kk_glmm_count_fixture(1L)
	set.seed(2L); row_weights <- runif(priv$n, 0.3, 2)
	res <- priv$compute_weighted_glmm_bootstrap_estimate(row_weights)

	m_vec <- priv$m
	if (is.null(m_vec)) m_vec <- rep(NA_integer_, priv$n)
	m_vec[is.na(m_vec)] <- 0L
	group_id <- m_vec
	reservoir_idx <- which(group_id == 0L)
	if (length(reservoir_idx) > 0L) group_id[reservoir_idx] <- max(group_id) + seq_along(reservoir_idx)
	ok <- is.finite(row_weights) & row_weights > 0 & is.finite(as.numeric(priv$y))
	X_fit <- as.matrix(priv$create_design_matrix())[ok, , drop = FALSE]
	n_params <- ncol(X_fit) + 1L
	fit_ref <- EDI:::fast_poisson_glmm_cpp(
		X = X_fit, y = as.numeric(priv$y)[ok], group_id = as.integer(group_id)[ok], j_T = 1L,
		row_weights = as.numeric(row_weights)[ok],
		warm_start_params = priv$get_fit_warm_start_for_length("params", n_params),
		smart_cold_start = priv$smart_cold_start_default, estimate_only = TRUE,
		optimization_alg = priv$optimization_alg
	)
	expect_true(fit_ref$converged)
	expect_equal(res, as.numeric(fit_ref$b[2L]), tolerance = 1e-10)
})

test_that("all-zero row weights return NA_real_", {
	priv <- kk_glmm_count_fixture(3L)
	res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(0, priv$n))
	expect_true(is.na(res))
})

test_that("when the Rcpp fit fails to converge, the glmmTMB fallback path engages and produces a finite result", {
	priv <- kk_glmm_count_fixture(4L)
	local_mocked_bindings(fast_poisson_glmm_cpp = function(...) NULL, .package = "EDI")
	res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n))
	expect_true(is.finite(res))
})

test_that("when the Rcpp fit converges but with too-extreme a coefficient, the glmmTMB fallback engages instead of the extreme value", {
	priv <- kk_glmm_count_fixture(5L)
	expect_equal(priv$max_abs_reasonable_coef, 10000)
	local_mocked_bindings(fast_poisson_glmm_cpp = function(X, ...) list(converged = TRUE, b = c(0, 1e6)), .package = "EDI")
	res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n))
	expect_true(is.finite(res))
	expect_lt(abs(res), 1e6)
})

test_that("when both the Rcpp fit and every glmmTMB fallback candidate fail, the result is NA_real_", {
	priv <- kk_glmm_count_fixture(6L)
	local_mocked_bindings(fast_poisson_glmm_cpp = function(...) NULL, .package = "EDI")
	unlockBinding(".is_usable_glmm_fit", priv)
	priv$.is_usable_glmm_fit <- function(mod, se) FALSE
	res <- priv$compute_weighted_glmm_bootstrap_estimate(rep(1, priv$n))
	expect_true(is.na(res))
})

test_that("use_rcpp = FALSE dispatches to the glmmTMB-only generic implementation and returns a finite estimate", {
	priv <- kk_glmm_count_fixture(7L, use_rcpp = FALSE)
	set.seed(8L); row_weights <- runif(priv$n, 0.3, 2)
	res <- priv$compute_weighted_glmm_bootstrap_estimate(row_weights)
	expect_true(is.finite(res))
	expect_equal(res, priv$compute_weighted_glmm_bootstrap_estimate_generic(row_weights))
})
