library(testthat)
library(EDI)

# Regression test (2026-10-23, release_v1_0_5.md TODO-131). The robust C++ kernel
# (fast_robust_regression_cpp() and the parallel BRT kernel built on the same IRLS)
# silently returns a 0 coefficient on non-finite input. That turned a stale
# FixedBinaryMatch BRT replay (NA pair differences) into an all-zero null for
# InferenceContinKKRobustRegrOneLik. Every R caller now treats non-finite input
# rows as nonestimable (NULL / NA), never beta = 0. The kernel itself is patched
# separately (cpp_patches_v105, uncompiled).

robust_fixture = function(design_name = "DesignFixedBernoulli", n = 30L, seed = 1L) {
	set.seed(seed)
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
	gen = get(design_name, envir = asNamespace("EDI"))
	des = gen$new(response_type = "continuous", n = n)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x1 + stats::rnorm(n))
	des
}

test_that("InferenceContinRobustRegr fit_rlm_model returns NULL on non-finite rows", {
	des = robust_fixture()
	for (use_rcpp in c(TRUE, FALSE)) {
		inf = InferenceContinRobustRegr$new(des, use_rcpp = use_rcpp, verbose = FALSE)
		priv = inf$.__enclos_env__$private
		X_fit = priv$build_design_matrix()
		expect_false(is.null(priv$fit_rlm_model(X_fit, estimate_only = TRUE)), info = use_rcpp)
		X_bad = X_fit
		X_bad[4L, ncol(X_bad)] = NA_real_
		expect_null(priv$fit_rlm_model(X_bad, estimate_only = TRUE), info = use_rcpp)
		y_saved = priv$y
		priv$y[2L] = NaN
		expect_null(priv$fit_rlm_model(X_fit, estimate_only = TRUE), info = use_rcpp)
		priv$y = y_saved
	}
})

test_that("InferenceContinRobustRegr weighted-bootstrap estimate is NA, not 0, on non-finite input", {
	des = robust_fixture()
	inf = InferenceContinRobustRegr$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
	n = des$get_n()
	expect_true(is.finite(inf$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)))
	priv$y[5L] = NA_real_
	priv$cached_values = list()
	est = inf$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE)
	expect_true(is.na(est))
})

test_that("InferenceContinRobustRegr fast BRT kernel marks draws touching non-finite rows NA", {
	des = robust_fixture()
	inf = InferenceContinRobustRegr$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	n = des$get_n()
	set.seed(7)
	w0 = as.numeric(des$get_w())
	draws = lapply(1:6, function(b) {
		i_b = if (b <= 3L) setdiff(seq_len(n), 3L)[sample.int(n - 1L, n, replace = TRUE)] else c(3L, sample.int(n, n - 1L, replace = TRUE))
		list(i_b = i_b, m_vec_b = NULL, w_b = sample(w0))
	})
	y0 = as.numeric(priv$y)
	ok = priv$compute_fast_rand_bootstrap_distr(y0, draws, delta = 0, transform_responses = "none")
	expect_true(all(is.finite(ok)))
	y0[3L] = NA_real_
	out = priv$compute_fast_rand_bootstrap_distr(y0, draws, delta = 0, transform_responses = "none")
	expect_equal(out[1:3], ok[1:3])
	expect_true(all(is.na(out[4:6])))
})

test_that("InferenceContinKKRobustRegrIVWC fit_rlm_with_treatment returns NULL on non-finite rows", {
	des = robust_fixture("DesignFixedBinaryMatch", n = 20L)
	inf = InferenceContinKKRobustRegrIVWC$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	set.seed(2)
	X = cbind(1, stats::rnorm(12L))
	y = stats::rnorm(12L)
	expect_false(is.null(priv$fit_rlm_with_treatment(X, y, 1L, estimate_only = TRUE)))
	y_bad = y
	y_bad[12L] = NA_real_
	expect_null(priv$fit_rlm_with_treatment(X, y_bad, 1L, estimate_only = TRUE))
	X_bad = X
	X_bad[1L, 2L] = Inf
	expect_null(priv$fit_rlm_with_treatment(X_bad, y, 1L, estimate_only = TRUE))
})
