library(testthat)
library(EDI)

# InferenceContinKKOLSIVWC's private shared() (inference_continuous_KK_ols_ivwc.R) combines an OLS
# fit on the matched-pair differences (ols_for_matched_pairs()) and an OLS fit on the reservoir
# (ols_for_reservoir()) via inverse-variance weighting -- the same IVWC-combination pattern already
# closed this stretch for several sibling classes -- but additionally computes a Satterthwaite-
# approximation degrees-of-freedom for the combined estimate via its own private satterthwaite_df()
# helper, which had no test reference anywhere (confirmed via grep), nor did any of shared()'s own
# combination branches: the class's 3 existing references (test-kk-ols-ivwc-weighted-passthrough-
# reference.R, test-full-likelihood-migration-baseline.R, test-mixin-contracts.R) exercise
# compute_estimate_with_bootstrap_weights() and migration parity, never shared()'s own branches or
# satterthwaite_df() directly.
#   satterthwaite_df(var_terms, dfs) = (sum var_terms)^2 / sum(var_terms^2 / dfs), restricted to the
#   finite-and-positive (var_terms, dfs) pairs; NA if none remain.
# Reached by unlockBinding-replacing ols_for_matched_pairs()/ols_for_reservoir() with stubs that set
# exact beta/ssq/df cache values, independent of the real OLS-fitting machinery (already tested
# elsewhere).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w + 0.3 * X$x1
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKOLSIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, ssq_m, df_m, beta_r, ssq_r, df_r) {
	unlockBinding("ols_for_matched_pairs", priv)
	priv$ols_for_matched_pairs <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_matched <- beta_m
		priv$cached_values$ssq_beta_T_matched <- ssq_m
		priv$cached_values$df_beta_T_matched <- df_m
	}
	unlockBinding("ols_for_reservoir", priv)
	priv$ols_for_reservoir <- function(estimate_only = FALSE) {
		priv$cached_values$beta_T_reservoir <- beta_r
		priv$cached_values$ssq_beta_T_reservoir <- ssq_r
		priv$cached_values$df_beta_T_reservoir <- df_r
	}
}

# Independent OLS/HC2 oracle for the real-estimator fixture below. This uses
# only base R linear algebra, not the EDI OLS or IVWC helpers.
ols_hc2_reference <- function(X, y, treatment_col) {
	X <- as.matrix(X)
	y <- as.numeric(y)
	fit <- stats::lm.fit(x = X, y = y)
	if (fit$rank != ncol(X)) stop("reference fixture design is not full rank")
	bread <- solve(crossprod(X))
	h <- rowSums((X %*% bread) * X)
	e <- as.numeric(fit$residuals)
	meat <- crossprod(X, X * (e^2 / (1 - h)))
	vcov_hc2 <- bread %*% meat %*% bread
	list(beta = unname(fit$coefficients[treatment_col]),
	     ssq = unname(vcov_hc2[treatment_col, treatment_col]),
	     df = nrow(X) - ncol(X))
}

ols_ivwc_reference <- function(y, w, m, X) {
	y <- as.numeric(y)
	w <- as.integer(w)
	m <- as.integer(m)
	X <- as.matrix(X)
	matched_ids <- sort(unique(m[m > 0L]))
	pair_diffs <- lapply(matched_ids, function(id) {
		i_t <- which(m == id & w == 1L)
		i_c <- which(m == id & w == 0L)
		if (length(i_t) != 1L || length(i_c) != 1L) {
			stop("reference fixture must contain one treated and one control per matched pair")
		}
		list(y = y[i_t] - y[i_c], X = X[i_t, , drop = FALSE] - X[i_c, , drop = FALSE])
	})
	y_diff <- vapply(pair_diffs, `[[`, numeric(1L), "y")
	X_diff <- do.call(rbind, lapply(pair_diffs, `[[`, "X"))
	X_matched <- cbind(1, X_diff)
	matched <- ols_hc2_reference(X_matched, y_diff, treatment_col = 1L)

	i_res <- which(m == 0L)
	X_reservoir <- cbind(1, w[i_res], X[i_res, , drop = FALSE])
	reservoir <- ols_hc2_reference(X_reservoir, y[i_res], treatment_col = 2L)
	if (!is.finite(matched$ssq) || matched$ssq <= 0 ||
	    !is.finite(reservoir$ssq) || reservoir$ssq <= 0) {
		stop("reference fixture must have two positive finite HC2 variances")
	}
	w_matched <- reservoir$ssq / (matched$ssq + reservoir$ssq)
	variance_terms <- c(w_matched^2 * matched$ssq,
	                    (1 - w_matched)^2 * reservoir$ssq)
	list(
		beta = w_matched * matched$beta + (1 - w_matched) * reservoir$beta,
		ssq = matched$ssq * reservoir$ssq / (matched$ssq + reservoir$ssq),
		df = sum(variance_terms)^2 /
			sum(variance_terms^2 / c(matched$df, reservoir$df)),
		matched = matched,
		reservoir = reservoir,
		w_matched = w_matched
	)
}

test_that("satterthwaite_df() matches the closed-form formula, restricted to finite-and-positive pairs, and is NA when none remain", {
	f <- mk_fixture(1L)
	sw <- f$priv$satterthwaite_df(c(2, 3), c(5, 8))
	ref <- (2 + 3)^2 / (2^2 / 5 + 3^2 / 8)
	expect_equal(sw, ref)

	sw_one_na <- f$priv$satterthwaite_df(c(2, 3), c(5, NA))
	expect_equal(sw_one_na, 5)   # only the (2, 5) term is finite/positive, so it collapses to df_m alone

	sw_all_na <- f$priv$satterthwaite_df(c(NA, NA), c(5, 8))
	expect_true(is.na(sw_all_na))
})

test_that("both pieces succeed: beta_hat_T/s_beta_hat_T match the closed-form IVWC formula, and df matches satterthwaite_df() on the combination's own variance terms", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, 1.2, 0.2, 10, 0.8, 0.5, 15)
	f$priv$shared(estimate_only = FALSE)
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(f$priv$cached_values$beta_hat_T, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
	ref_df <- f$priv$satterthwaite_df(c(w_star^2 * 0.2, (1 - w_star)^2 * 0.5), c(10, 15))
	expect_equal(f$priv$cached_values$df, ref_df)
})

test_that("only the matched-pairs piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = sqrt(ssq_m), df = df_m", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, 0.2, 10, NA_real_, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$beta_hat_T, 1.2)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2))
	expect_equal(f$priv$cached_values$df, 10)
})

test_that("only the reservoir piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r), df = df_r", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, 0.8, 0.5, 15)
	f$priv$shared(estimate_only = FALSE)
	expect_equal(f$priv$cached_values$beta_hat_T, 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.5))
	expect_equal(f$priv$cached_values$df, 15)
})

test_that("neither piece succeeds: beta_hat_T, s_beta_hat_T and df are all NA_real_", {
	f <- mk_fixture(5L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_)
	f$priv$shared(estimate_only = FALSE)
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(is.na(f$priv$cached_values$df))
})

test_that("real OLS-IVWC fit uses estimable matched and reservoir regressions and matches an independent HC2 reference", {
	# n=40, one varying covariate, and seed 1 yield enough complete KK14 pairs
	# for the matched design (more rows than columns) and a two-arm reservoir.
	# This exercises the real OLS components and IVWC/Satterthwaite combination,
	# unlike the mocked branch tests or an estimate_only randomization fallback.
	f <- mk_fixture(1L, n = 40L)
	priv <- f$priv
	X <- as.matrix(priv$get_X())
	y <- as.numeric(priv$y)
	w <- as.integer(priv$w)
	m <- as.integer(priv$m)
	ids <- sort(unique(m[m > 0L]))
	reservoir <- which(m == 0L)

	ref <- ols_ivwc_reference(y, w, m, X)
	expect_gt(length(ids), ncol(X) + 1L)
	expect_true(qr(cbind(1, do.call(rbind, lapply(ids, function(id) {
		i_t <- which(m == id & w == 1L)
		i_c <- which(m == id & w == 0L)
		X[i_t, , drop = FALSE] - X[i_c, , drop = FALSE]
	}))))$rank == ncol(X) + 1L)
	expect_gt(sum(w[reservoir] == 0L), 1L)
	expect_gt(sum(w[reservoir] == 1L), 1L)
	expect_true(is.finite(ref$matched$beta) && is.finite(ref$reservoir$beta))
	expect_true(ref$matched$ssq > 0 && ref$reservoir$ssq > 0)
	expect_true(ref$w_matched > 0 && ref$w_matched < 1)
	# Make the combination non-vacuous, not merely finite: both estimated
	# components differ, so a strict inverse-variance weight must land between
	# them rather than reproducing either component estimate.
	expect_gt(abs(ref$matched$beta - ref$reservoir$beta), 1e-8)
	expect_gt(abs(ref$beta - ref$matched$beta), 1e-8)
	expect_gt(abs(ref$beta - ref$reservoir$beta), 1e-8)
	expect_equal(
		ref$beta,
		ref$w_matched * ref$matched$beta + (1 - ref$w_matched) * ref$reservoir$beta,
		tolerance = 1e-12
	)

	actual_beta <- f$inf$compute_estimate(estimate_only = FALSE)
	expect_equal(actual_beta, ref$beta, tolerance = 1e-8)
	expect_equal(priv$cached_values$s_beta_hat_T, sqrt(ref$ssq), tolerance = 1e-8)
	expect_equal(priv$cached_values$df, ref$df, tolerance = 1e-8)
	expect_equal(priv$cached_values$beta_T_matched, ref$matched$beta, tolerance = 1e-8)
	expect_equal(priv$cached_values$beta_T_reservoir, ref$reservoir$beta, tolerance = 1e-8)
})
