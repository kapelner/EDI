library(testthat)
library(EDI)

# InferenceIncidRiskDiff's compute_estimate(estimate_only = TRUE) fast
# lm.fit() shortcut (taken only when private$harden is FALSE), its
# randomization-inference treatment-estimate helper, and the
# "too few positive-weight rows" NA branch of the weighted refit. The sibling
# file test-incidence-risk-diff-weighted-refit-reference.R covers the ordinary
# weighted numerics and the all-zero-weights case only.

risk_diff_sparse_fixture <- function(seed = 4L, n = 60L, formula = ~ x) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- as.numeric(0.4 + 0.15 * w + 0.1 * x + rnorm(n, sd = 0.2) > 0.5)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidRiskDiff$new(des, model_formula = formula, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n
	)
	list(inf = inf, priv = priv, x = x, w = w, y = y, n = n)
}

test_that("estimate_only with harden = FALSE takes the lm.fit() shortcut, caches, and records covariate columns", {
	f <- risk_diff_sparse_fixture()
	expect_true(f$priv$harden)
	f$priv$harden <- FALSE
	ref <- unname(coef(lm(f$y ~ f$w + f$x))[2])

	est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est, ref, tolerance = 1e-10)
	expect_equal(f$priv$cached_values$beta_hat_T, ref, tolerance = 1e-10)
	expect_equal(f$priv$best_X_colnames, "x")
	# Second call returns the cached value without refitting.
	f$priv$cached_values$beta_hat_T <- 123
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 123)
})

test_that("the harden = FALSE shortcut returns NA for a rank-deficient treatment column", {
	f <- risk_diff_sparse_fixture()
	f$priv$harden <- FALSE
	f$priv$w <- rep(1L, f$n)
	expect_true(is.na(f$inf$compute_estimate(estimate_only = TRUE)))
})

test_that("compute_treatment_estimate_during_randomization_inference matches lm() and lazily discovers the kept covariates", {
	f <- risk_diff_sparse_fixture(seed = 8L)
	expect_null(f$priv$best_X_colnames)
	ref <- unname(coef(lm(f$y ~ f$w + f$x))[2])
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(), ref, tolerance = 1e-8)
	expect_equal(f$priv$best_X_colnames, "x")

	# With a known kept-column set, the treatment coefficient is refit under a
	# reassigned w (the randomization-inference use case).
	f$priv$w <- rev(f$w)
	ref_perm <- unname(coef(lm(f$y ~ rev(f$w) + f$x))[2])
	expect_equal(f$priv$compute_treatment_estimate_during_randomization_inference(), ref_perm, tolerance = 1e-8)
})

test_that("weighted refit drops covariates when positive rows are too few for the full design, and returns NA when even the reduced design is unidentifiable", {
	f <- risk_diff_sparse_fixture()
	ncols <- ncol(f$priv$build_design_matrix())
	expect_equal(ncols, 3L)

	# Exactly ncols positive-weight rows: the full design fails the
	# sum(ok) <= ncol(X_fit) guard, so the hardened column-dropping retry falls
	# back to the intercept + treatment design, which is identifiable.
	wt <- rep(0, f$n)
	wt[1:3] <- 1
	est <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	ref <- unname(stats::lm.wfit(cbind(1, f$w[1:3]), f$y[1:3], rep(1, 3))$coefficients[2])
	expect_equal(est, ref, tolerance = 1e-10)
	expect_equal(f$priv$best_X_colnames, character(0))

	# Only two positive-weight rows cannot identify intercept + treatment. SOURCE
	# QUIRK (noted, not fixed): the hardened retry here uses the default
	# required_cols = 1L (intercept only), so it drops the treatment column too,
	# after which `which(attempt$keep == 2L)` is integer(0) and the cached
	# estimate is a zero-length numeric rather than the intended NA_real_. Either
	# way no finite treatment estimate is produced, which is what is pinned.
	f1 <- risk_diff_sparse_fixture()
	wt1 <- rep(0, f1$n)
	wt1[1:2] <- 1
	est1 <- f1$inf$compute_estimate_with_bootstrap_weights(wt1)
	expect_false(isTRUE(is.finite(est1)))
	expect_false(isTRUE(is.finite(f1$priv$last_weighted_refit$beta_hat_T)))
	expect_true(is.na(f1$priv$last_weighted_refit$s_beta_hat_T))

	# One more positive-weight row than columns keeps the full design and matches lm.wfit.
	f2 <- risk_diff_sparse_fixture()
	wt2 <- rep(0, f2$n)
	set.seed(1)
	idx <- sample(f2$n, ncols + 4L)
	wt2[idx] <- runif(length(idx), 0.5, 2)
	est2 <- f2$inf$compute_estimate_with_bootstrap_weights(wt2)
	X <- cbind(1, f2$w, f2$x)[idx, , drop = FALSE]
	ref2 <- unname(stats::lm.wfit(X, f2$y[idx], wt2[idx])$coefficients[2])
	expect_equal(est2, ref2, tolerance = 1e-10)
})
