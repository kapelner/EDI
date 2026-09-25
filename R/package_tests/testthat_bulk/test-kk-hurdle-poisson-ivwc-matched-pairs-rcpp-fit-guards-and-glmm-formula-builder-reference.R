library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC's private fit_hurdle_for_matched_pairs_rcpp() and build_glmm_formula()
# (inference_count_KK_cond_poisson.R) had zero test references anywhere: the class's existing shared()
# tests (test-kk-hurdle-poisson-ivwc-shared-matched-reservoir-combination-branches-reference.R) stub
# fit_hurdle_for_matched_pairs() itself (one level up, skipping both the rcpp/glmmTMB split and this
# rcpp wrapper's own post-processing entirely), and the underlying kernel fast_hurdle_poisson_glmm_cpp()
# has its own dedicated equivalence test (R/EDI/tests/testthat/test-glmm-cpp-equivalence.R) but nothing
# exercises THIS wrapper's own gating logic: not-converged/error -> NA, a too-extreme beta -> NA, se =
# FALSE short-circuits to se = 1.0 without needing ssq_b_T at all, and a non-finite/non-positive/too-
# extreme ssq_b_T -> NA. Reached by mocking fast_hurdle_poisson_glmm_cpp() directly via with_mocked_
# bindings(.package = "EDI"), independent of any real GLMM fit. build_glmm_formula() is a small, pure,
# untested string-building helper (fixed covariate terms plus a "(1 | pair_group)" random-intercept
# term) exercised directly with hand-built data frames.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 * w)))
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

X_fit <- matrix(c(1, 0, 1, 1), 2, 2)  # toy 2-row design matrix, column 1 is treatment
y_fit <- c(1, 2)
group_id <- c(1, 1)

test_that("build_glmm_formula(): a single treatment column becomes 'y ~ w + (1 | pair_group)'", {
	priv <- fx(1L)
	dat <- data.frame(y = 1:3, w = c(1, 0, 1), pair_group = factor(c(1, 1, 2)))
	expect_equal(priv$build_glmm_formula(dat), y ~ w + (1 | pair_group))
})

test_that("build_glmm_formula(): additional covariates are all included as fixed terms, in column order, before the random-intercept term", {
	priv <- fx(2L)
	dat <- data.frame(y = 1:3, w = c(1, 0, 1), x1 = c(0.1, 0.2, 0.3), x2 = c(1, 2, 3), pair_group = factor(c(1, 1, 2)))
	expect_equal(priv$build_glmm_formula(dat), y ~ w + x1 + x2 + (1 | pair_group))
})

test_that("fit_hurdle_for_matched_pairs_rcpp(): a kernel error or non-converged fit gives NA beta/se", {
	priv <- fx(3L)
	with_mocked_bindings(
		fast_hurdle_poisson_glmm_cpp = function(...) stop("boom"),
		.package = "EDI",
		code = {
			res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L)
			expect_true(is.na(res$beta_hat)); expect_true(is.na(res$se))
		}
	)
	with_mocked_bindings(
		fast_hurdle_poisson_glmm_cpp = function(...) list(converged = FALSE, b = c(0.5, 0.2), ssq_b_T = 0.01),
		.package = "EDI",
		code = {
			res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L)
			expect_true(is.na(res$beta_hat)); expect_true(is.na(res$se))
		}
	)
})

test_that("fit_hurdle_for_matched_pairs_rcpp(): a converged fit with a too-extreme treatment coefficient gives NA beta/se", {
	priv <- fx(4L)
	with_mocked_bindings(
		fast_hurdle_poisson_glmm_cpp = function(...) list(converged = TRUE, b = c(1e5, 0.2), ssq_b_T = 0.01),
		.package = "EDI",
		code = {
			res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L)
			expect_true(is.na(res$beta_hat)); expect_true(is.na(res$se))
		}
	)
})

test_that("fit_hurdle_for_matched_pairs_rcpp(): se = FALSE short-circuits to se = 1.0 without consulting ssq_b_T at all", {
	priv <- fx(5L)
	with_mocked_bindings(
		fast_hurdle_poisson_glmm_cpp = function(...) list(converged = TRUE, b = c(0.5, 0.2), ssq_b_T = NA_real_),
		.package = "EDI",
		code = {
			res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L, se = FALSE)
			expect_equal(res$beta_hat, 0.5)
			expect_equal(res$se, 1.0)
		}
	)
})

test_that("fit_hurdle_for_matched_pairs_rcpp(): a non-finite, non-positive, or too-extreme ssq_b_T gives NA beta/se (se = TRUE, the default)", {
	priv <- fx(6L)
	for (bad_ssq in list(-1, 0, NA_real_, 1e10)) {  # 1e10 -> se = sqrt(1e10) exceeds max_abs_reasonable_coef
		with_mocked_bindings(
			fast_hurdle_poisson_glmm_cpp = function(...) list(converged = TRUE, b = c(0.5, 0.2), ssq_b_T = bad_ssq),
			.package = "EDI",
			code = {
				res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L)
				expect_true(is.na(res$beta_hat), info = paste("ssq_b_T =", bad_ssq))
				expect_true(is.na(res$se), info = paste("ssq_b_T =", bad_ssq))
			}
		)
	}
})

test_that("fit_hurdle_for_matched_pairs_rcpp(): a well-formed, converged fit passes through with beta_hat and se = sqrt(ssq_b_T)", {
	priv <- fx(7L)
	with_mocked_bindings(
		fast_hurdle_poisson_glmm_cpp = function(...) list(converged = TRUE, b = c(0.7, -0.3), ssq_b_T = 0.04),
		.package = "EDI",
		code = {
			res <- priv$fit_hurdle_for_matched_pairs_rcpp(X_fit, y_fit, group_id, j_treat = 1L)
			expect_equal(res$beta_hat, 0.7)
			expect_equal(res$se, 0.2, tolerance = 1e-12)
		}
	)
})
