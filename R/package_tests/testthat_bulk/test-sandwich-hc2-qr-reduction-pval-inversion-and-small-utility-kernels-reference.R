library(testthat)
library(EDI)

# C++ kernels: glm_sandwich_post_fit_cpp / glm_cluster_sandwich_post_fit_cpp (HC0 with working
# weights, plain and clustered) and ols_hc2_setup_cpp / ols_hc2_post_fit_cpp /
# ols_hc2_post_fit_precomputed_cpp against the sandwich package; qr_reduce_full_rank_cpp (column
# span preserved, full column rank); pval_invert_ci_cpp (bracket + bisection CI inversion of a
# p-value function) against the closed-form normal interval; count_unique_values_cpp and
# sample_mode_cpp.

skip_if_not_installed("sandwich")
K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("OLS HC2 (direct and via precomputed bread / hat) equals sandwich::vcovHC(type = 'HC2')", {
	set.seed(1)
	n <- 40L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	y <- as.numeric(X %*% c(1, 0.5, 0.8) + rnorm(n) * (1 + abs(X[, 2])))
	m <- lm(y ~ X - 1); b <- as.numeric(coef(m))
	ref <- sandwich::vcovHC(m, type = "HC2")
	r <- K("ols_hc2_post_fit_cpp")(X, y, b, 3L)
	expect_equal(unname(r$vcov), unname(ref), tolerance = 1e-8)
	expect_equal(as.numeric(r$std_err), unname(sqrt(diag(ref))), tolerance = 1e-8)
	expect_equal(r$se, sqrt(ref[3, 3]), tolerance = 1e-8)
	expect_equal(r$ssq_hat, ref[3, 3], tolerance = 1e-8)
	expect_equal(r$beta_hat, b[3])
	expect_equal(as.numeric(r$z_vals), b / unname(sqrt(diag(ref))), tolerance = 1e-8)
	s <- K("ols_hc2_setup_cpp")(X)
	expect_equal(as.numeric(s$hat), as.numeric(hatvalues(m)), tolerance = 1e-8)
	expect_equal(unname(s$bread), unname(solve(crossprod(X))), tolerance = 1e-8)
	r2 <- K("ols_hc2_post_fit_precomputed_cpp")(X, y, b, s$bread, s$hat, 3L)
	expect_equal(r2$vcov, r$vcov, tolerance = 1e-10)
})

test_that("GLM sandwich (logistic working weights) equals sandwich::sandwich / vcovCL(HC0)", {
	set.seed(2)
	n <- 120L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	yb <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.3, 0.6, 0.4))))
	g <- glm(yb ~ X - 1, family = binomial())
	mu <- as.numeric(fitted(g)); ww <- mu * (1 - mu)
	r <- K("glm_sandwich_post_fit_cpp")(X, yb, as.numeric(coef(g)), mu, ww, 3L)
	ref <- sandwich::vcovHC(g, type = "HC0")
	expect_equal(unname(r$vcov), unname(ref), tolerance = 1e-8)
	expect_equal(as.numeric(r$std_err), unname(sqrt(diag(ref))), tolerance = 1e-8)
	expect_equal(r$se, sqrt(ref[3, 3]), tolerance = 1e-8)
	cl <- rep(1:30, each = 4L)
	rc <- K("glm_cluster_sandwich_post_fit_cpp")(X, yb, as.numeric(coef(g)), mu, ww, cl, 3L)
	refc <- sandwich::vcovCL(g, cluster = cl, type = "HC0", cadjust = FALSE)
	expect_equal(unname(rc$vcov), unname(refc), tolerance = 1e-8)
	expect_equal(rc$se, sqrt(refc[3, 3]), tolerance = 1e-8)
	# Singleton clusters reduce to the plain HC0 sandwich.
	r1 <- K("glm_cluster_sandwich_post_fit_cpp")(X, yb, as.numeric(coef(g)), mu, ww, seq_len(n), 3L)
	expect_equal(unname(r1$vcov), unname(r$vcov), tolerance = 1e-8)
})

test_that("qr_reduce_full_rank keeps a full-column-rank subset spanning every original column", {
	set.seed(3)
	n <- 40L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	Xd <- cbind(X, 2 * X[, 2], X[, 1] + X[, 3], rnorm(n))                  # two exact dependencies
	out <- K("qr_reduce_full_rank_cpp")(Xd)
	expect_equal(ncol(out$X_reduced), qr(Xd)$rank)
	expect_equal(ncol(out$X_reduced), length(out$keep))
	expect_equal(unname(out$X_reduced), unname(Xd[, out$keep, drop = FALSE]))
	expect_equal(qr(out$X_reduced)$rank, ncol(out$X_reduced))
	for (j in setdiff(seq_len(ncol(Xd)), out$keep)) {                      # dropped columns lie in the kept span
		expect_lt(max(abs(resid(lm(Xd[, j] ~ out$X_reduced - 1)))), 1e-8)
	}
	# A full-rank matrix is returned untouched.
	full <- K("qr_reduce_full_rank_cpp")(X)
	expect_equal(full$keep, 1:3)
	expect_equal(unname(full$X_reduced), unname(X))
})

test_that("pval_invert_ci_cpp inverts a normal-shaped two-sided p-value to the closed-form interval, with or without Wald seeds", {
	pf <- function(d) 2 * pnorm(-abs(d - 0.5) / 0.2)
	for (alpha in c(0.05, 0.2)) {
		ref <- 0.5 + c(-1, 1) * qnorm(1 - alpha / 2) * 0.2
		expect_equal(K("pval_invert_ci_cpp")(pf, 0.5, alpha, 0.1, NA_real_, NA_real_), ref, tolerance = 1e-5)
		expect_equal(K("pval_invert_ci_cpp")(pf, 0.5, alpha, 0.1, ref[1] - 0.05, ref[2] + 0.05), ref, tolerance = 1e-5)
	}
	# A p-value that never falls below alpha cannot be bracketed.
	expect_true(all(is.na(K("pval_invert_ci_cpp")(function(d) 0.9, 0.5, 0.05, 0.1, NA_real_, NA_real_, max_bracket = 5L))))
})

test_that("count_unique_values counts distinct values per column (NA counted as a value); sample_mode returns a most frequent value", {
	df <- data.frame(a = c(1, 1, 2, NA), b = c("x", "y", "x", "x"))
	cu <- K("count_unique_values_cpp")(df)
	expect_equal(as.numeric(cu["a"]), 3); expect_equal(as.numeric(cu["b"]), 2)
	expect_equal(K("sample_mode_cpp")(c(3, 1, 3, 2, 2, 3)), 3)
	expect_equal(K("sample_mode_cpp")(5), 5)
	expect_true(K("sample_mode_cpp")(c(2, 2, 1, 1)) %in% c(1, 2))
	expect_length(K("sample_mode_cpp")(numeric(0)), 0L)
})
